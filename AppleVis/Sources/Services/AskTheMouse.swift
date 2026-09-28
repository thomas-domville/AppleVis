import Foundation
import Combine

/// One question and everything the Mouse found for it.
struct MouseTurn: Identifiable {
    enum Step: Equatable {
        case thinking, help, guides, apps, forums, writing

        /// What the Mouse is doing, shown and (after a few seconds) spoken.
        var status: String {
            switch self {
            case .thinking: return String(localized: "Thinking about your question…")
            case .help: return String(localized: "Sniffing through Help…")
            case .guides: return String(localized: "Scurrying through the guides…")
            case .apps: return String(localized: "Peeking into the App Directory…")
            case .forums: return String(localized: "Nibbling on the forums…")
            case .writing: return String(localized: "Putting it all together…")
            }
        }
    }

    struct PickedApp: Identifiable {
        let app: AppListing
        let blurb: String
        var id: String { app.id }
    }

    let id = UUID()
    let question: String
    var step: Step? = .thinking

    var answer: String?
    /// False when nothing the Mouse could find answers the question.
    var answered = true
    var helpUsed: [HelpArticle] = []
    var guidesUsed: [Resource] = []
    var notesUsed: [MouseKnowledge.Note] = []

    var appsIntro: String?
    var mainHeading: String?
    var relatedHeading: String?
    var mainApps: [PickedApp] = []
    var relatedApps: [PickedApp] = []

    var moreGuides: [Resource] = []
    var forums: [ForumTopic] = []
    var podcasts: [PodcastEpisode] = []
    var blogs: [BlogPost] = []
    var bugs: [BugReport] = []
    var otherApps: [AppListing] = []
    var saved: [SavedItem] = []

    var place: MousePlace?
    var switchOffer: MouseSwitch?
    var switchTurnOn = true
    /// Set once the person answered the "Change it for me" offer.
    var switchDone: Bool?

    var isSearching: Bool { step != nil }
    var foundAnything: Bool {
        answer != nil || !mainApps.isEmpty || !relatedApps.isEmpty || !moreGuides.isEmpty || !forums.isEmpty
            || !podcasts.isEmpty || !blogs.isEmpty || !bugs.isEmpty || !otherApps.isEmpty || !saved.isEmpty
            || !helpUsed.isEmpty || !notesUsed.isEmpty
    }
}

/// Runs Ask the Mouse: understands the question with Apple Intelligence,
/// searches Help, the rest of the app, and applevis.com all at once, then
/// answers only from what it found. Requested directly (2026-09-28).
@MainActor
final class AskTheMouse: ObservableObject {
    @Published private(set) var turns: [MouseTurn] = []
    @Published private(set) var recentQuestions: [String] = AskTheMouse.loadRecent()

    private var task: Task<Void, Never>?
    private static let recentKey = "mouse.recentQuestions"
    /// Guides older than this get a gentle "may have changed" note.
    private static let oldAfter: TimeInterval = 3 * 365 * 24 * 3600

    var isBusy: Bool { turns.first?.isSearching ?? false }

    func ask(_ rawQuestion: String) {
        let question = rawQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isBusy else { return }
        // Newest first, so the latest answer sits right under the question field.
        let earlier = turns.prefix(2).map(\.question)
        turns.insert(MouseTurn(question: question), at: 0)
        remember(question)
        let turnId = turns[0].id
        task = Task { await run(question, earlier: Array(earlier), turnId: turnId) }
    }

    func stop() {
        task?.cancel()
        update(turns.first?.id) { turn in
            turn.step = nil
            if !turn.foundAnything { turn.answered = false }
        }
    }

    func clearConversation() {
        task?.cancel()
        turns = []
    }

    func clearRecent() {
        recentQuestions = []
        UserDefaults.standard.removeObject(forKey: Self.recentKey)
    }

    func recordSwitch(_ turnId: UUID, done: Bool) {
        update(turnId) { $0.switchDone = done }
    }

    // MARK: - Running a question

    private func run(_ question: String, earlier: [String], turnId: UUID) async {
        let plan = await IntelligenceService.mousePlan(for: question, earlier: earlier)
            ?? IntelligenceService.MousePlan(searchPhrases: [question])
        if Task.isCancelled { return }
        let phrases = plan.searchPhrases.isEmpty ? [question] : plan.searchPhrases
        let words = MouseKnowledge.terms(([question] + phrases).joined(separator: " "))

        // On the device: instant.
        set(turnId, step: .help)
        let help = MouseKnowledge.searchHelp(question, phrases: phrases)
        var notes = plan.kind == .whatsNew ? MouseKnowledge.latestChanges() : MouseKnowledge.searchWhatsNew(question, phrases: phrases)
        notes += MouseKnowledge.searchTips(question, phrases: phrases)
        let lower = question.lowercased()
        let wantsSaved = plan.kind == .savedItems || ["saved", "bookmark"].contains { lower.contains($0) }
        let saved = wantsSaved ? MouseKnowledge.searchSaved(question, phrases: phrases) : []

        // On the website: every search at the same time.
        set(turnId, step: .guides)
        let searchPhrase = phrases[0]
        async let siteResults = try? APIClient.shared.search.query(searchPhrase)
        async let appResults: [AppListing]? = plan.kind == .findApps
            ? (try? APIClient.shared.apps.mouseSearch(
                keyword: plan.appKeyword.isEmpty ? searchPhrase : plan.appKeyword,
                fullyAccessibleOnly: plan.fullyAccessibleOnly,
                category: plan.appCategory))
            : nil

        var site = await siteResults
        if Task.isCancelled { return }
        // A second wording when the first found no guides.
        if (site?.guides.isEmpty ?? true), phrases.count > 1, let second = try? await APIClient.shared.search.query(phrases[1]) {
            site = site.map { merged($0, second) } ?? second
        }
        if plan.kind == .findApps { set(turnId, step: .apps) }
        let apps = await appResults ?? []
        if Task.isCancelled { return }
        set(turnId, step: .forums)

        // The two best guides, read in full so the answer can use them.
        let guides = Array((site?.guides ?? []).prefix(plan.kind == .findApps ? 0 : 2))
        let guideTexts = await readGuides(guides)
        if Task.isCancelled { return }

        var sources: [IntelligenceService.MouseSource] = []
        for article in help.prefix(2) {
            let text = MouseKnowledge.bestPassages(in: MouseKnowledge.helpArticleText(article), terms: words, maxCharacters: 900)
            sources.append(.init(id: "help-\(article.id)", title: article.title, text: article.summary + "\n" + text))
        }
        for (guide, text) in zip(guides, guideTexts) where !text.isEmpty {
            sources.append(.init(id: "guide-\(guide.id)", title: guide.title,
                                 text: MouseKnowledge.bestPassages(in: text, terms: words, maxCharacters: 900)))
        }
        for note in notes.prefix(plan.kind == .whatsNew ? 6 : 2) {
            sources.append(.init(id: note.id, title: note.title, text: String(note.text.prefix(plan.kind == .whatsNew ? 260 : 600))))
        }

        set(turnId, step: .writing)
        var answer: IntelligenceService.MouseAnswer?
        if plan.kind != .findApps || apps.isEmpty {
            answer = await IntelligenceService.mouseAnswer(to: question, earlier: earlier, sources: sources)
        }
        var picks: IntelligenceService.MousePicks?
        if !apps.isEmpty {
            let items = apps.prefix(15).map { app in
                IntelligenceService.MouseItem(
                    id: app.id, title: app.name,
                    details: String(HTMLText.plainText(fromHTML: app.summary).prefix(200)) + (app.price.isEmpty ? "" : " (\(app.price))"))
            }
            picks = await IntelligenceService.mousePicks(for: question, items: Array(items))
        }
        if Task.isCancelled { return }

        update(turnId) { turn in
            if let answer {
                turn.answered = answer.answered
                turn.answer = answer.answered ? answer.text : nil
                let used = Set(answer.sourceIds)
                // When the model didn't say which it used, show the best matches.
                let usedAny = !used.isEmpty
                turn.helpUsed = answer.answered ? help.prefix(2).filter { !usedAny || used.contains("help-\($0.id)") } : []
                turn.guidesUsed = answer.answered ? guides.filter { !usedAny || used.contains("guide-\($0.id)") } : []
                turn.notesUsed = answer.answered ? notes.filter { !usedAny || used.contains($0.id) } : []
            } else if plan.kind != .findApps {
                // No model answer (it failed or found nothing to read):
                // still show the best matches rather than nothing.
                turn.helpUsed = Array(help.prefix(2))
                turn.guidesUsed = guides
                turn.notesUsed = Array(notes.prefix(2))
                turn.answered = !help.isEmpty || !guides.isEmpty || !notes.isEmpty
            }

            if let picks {
                turn.appsIntro = picks.intro.isEmpty ? nil : picks.intro
                turn.mainHeading = picks.mainHeading.isEmpty ? nil : picks.mainHeading
                turn.relatedHeading = picks.relatedHeading.isEmpty ? nil : picks.relatedHeading
                let byId = Dictionary(apps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                for pick in picks.picks {
                    guard let app = byId[pick.id] else { continue }
                    let entry = MouseTurn.PickedApp(app: app, blurb: Self.withAge(pick.blurb, updated: app.lastUpdatedAt))
                    if pick.isMain { turn.mainApps.append(entry) } else { turn.relatedApps.append(entry) }
                }
            } else if !apps.isEmpty {
                turn.mainApps = apps.prefix(10).map {
                    MouseTurn.PickedApp(app: $0, blurb: Self.withAge(String(HTMLText.plainText(fromHTML: $0.summary).prefix(140)), updated: $0.lastUpdatedAt))
                }
            }
            if plan.kind == .findApps, turn.answer == nil, !(turn.mainApps.isEmpty && turn.relatedApps.isEmpty) {
                turn.answered = true
            }

            if let site {
                let usedGuideIds = Set(turn.guidesUsed.map(\.id))
                turn.moreGuides = Array(site.guides.filter { !usedGuideIds.contains($0.id) }.prefix(3))
                turn.forums = Array(site.forums.prefix(3))
                turn.podcasts = Array(site.podcasts.prefix(2))
                turn.blogs = Array(site.blogs.prefix(2))
                turn.bugs = Array(site.bugs.prefix(2))
                turn.otherApps = plan.kind == .findApps ? [] : Array(site.apps.prefix(3))
            }
            turn.saved = saved
            if wantsSaved, !saved.isEmpty { turn.answered = true }

            turn.place = plan.place
            if plan.kind == .changeSetting, let mouseSwitch = plan.mouseSwitch {
                turn.switchOffer = mouseSwitch
                turn.switchTurnOn = plan.turnOn
                turn.place = mouseSwitch.place
                turn.answered = true
            }
            if !turn.foundAnything && turn.switchOffer == nil { turn.answered = false }
            turn.step = nil
        }
    }

    /// "Entry last updated in 2017" on anything the site hasn't touched in years.
    static func withAge(_ text: String, updated: Date) -> String {
        guard Date().timeIntervalSince(updated) > oldAfter else { return text }
        let year = Calendar.current.component(.year, from: updated)
        return text + " " + String(localized: "Last updated in \(String(year)), so check it's still current.")
    }

    static func isOld(_ date: Date) -> Bool { Date().timeIntervalSince(date) > oldAfter }

    private func readGuides(_ guides: [Resource]) async -> [String] {
        await withTaskGroup(of: (Int, String).self) { group in
            for (index, guide) in guides.enumerated() {
                group.addTask {
                    guard let detail = try? await APIClient.shared.resources.detail(id: guide.id) else { return (index, "") }
                    return (index, HTMLText.plainText(fromHTML: detail.body))
                }
            }
            var texts = Array(repeating: "", count: guides.count)
            for await (index, text) in group { texts[index] = text }
            return texts
        }
    }

    private func merged(_ first: SearchResults, _ second: SearchResults) -> SearchResults {
        func combine<T: Identifiable>(_ a: [T], _ b: [T]) -> [T] {
            let ids = Set(a.map { AnyHashable($0.id) })
            return a + b.filter { !ids.contains(AnyHashable($0.id)) }
        }
        return SearchResults(
            forums: combine(first.forums, second.forums), apps: combine(first.apps, second.apps),
            guides: combine(first.guides, second.guides), blogs: combine(first.blogs, second.blogs),
            podcasts: combine(first.podcasts, second.podcasts), bugs: combine(first.bugs, second.bugs),
            failedCategories: first.failedCategories)
    }

    private func set(_ turnId: UUID, step: MouseTurn.Step) {
        update(turnId) { $0.step = step }
    }

    private func update(_ turnId: UUID?, _ change: (inout MouseTurn) -> Void) {
        guard let turnId, let index = turns.firstIndex(where: { $0.id == turnId }) else { return }
        change(&turns[index])
    }

    // MARK: - Recent questions (this device only)

    private func remember(_ question: String) {
        var list = recentQuestions.filter { $0.caseInsensitiveCompare(question) != .orderedSame }
        list.insert(question, at: 0)
        recentQuestions = Array(list.prefix(8))
        UserDefaults.standard.set(recentQuestions, forKey: Self.recentKey)
    }

    private static func loadRecent() -> [String] {
        UserDefaults.standard.stringArray(forKey: recentKey) ?? []
    }
}
