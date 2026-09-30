import Foundation
import Combine
import UIKit

/// One question and everything the Mouse found for it.
struct MouseTurn: Identifiable {
    enum Step: Equatable {
        case thinking, help, guides, apps, forums, writing, closerLook

        /// What the Mouse is doing, shown and (after a few seconds) spoken.
        var status: String {
            switch self {
            case .thinking: return String(localized: "Thinking about your question…")
            case .help: return String(localized: "Sniffing through Help…")
            case .guides: return String(localized: "Scurrying through the guides…")
            case .apps: return String(localized: "Peeking into the App Directory…")
            case .forums: return String(localized: "Nibbling on the forums…")
            case .writing: return String(localized: "Putting it all together…")
            case .closerLook: return String(localized: "Taking a closer look at the guides…")
            }
        }
    }

    struct PickedApp: Identifiable {
        let app: AppListing
        let blurb: String
        var id: String { app.id }
    }

    /// A one-line answer for a More From AppleVis result: what that page
    /// says about the question. `isQuote` when it's the page's own sentence
    /// because Apple Intelligence couldn't write one. `alsoIn` lists other
    /// pages that said the same. Requested directly (2026-09-29).
    struct ResultNote: Equatable {
        var line: String
        var isQuote: Bool
        var alsoIn: [String] = []
        var versionNote: String?
    }

    var id = UUID()
    let question: String
    var step: Step? = .thinking
    /// Per-result answers, by result id, filled in after the main answer.
    var resultNotes: [String: ResultNote] = [:]
    var isReadingResults = false
    /// The passage each guide's answer came from, so opening the guide
    /// lands on it.
    var guideFocus: [String: String] = [:]
    /// "Written for iOS 17. It may have changed.", by source id ("guide-…").
    var versionNotes: [String: String] = [:]
    /// Did this answer the question? Kept on the device.
    var feedback: Bool?

    var answer: String?
    /// The answer as it's being written, shown on screen only. VoiceOver
    /// gets the finished answer.
    var draft: String?
    /// The answer is an introduction and numbered steps, one per line,
    /// shown one step at a time.
    var hasSteps = false
    /// Questions the person might ask next, from Apple Intelligence.
    var followUps: [String] = []
    /// Why Apple Intelligence couldn't answer, when it's worth saying.
    var failure: IntelligenceService.MouseFailure?
    /// False when nothing the Mouse could find answers the question.
    var answered = true
    var helpUsed: [HelpArticle] = []
    var guidesUsed: [Resource] = []
    var notesUsed: [MouseKnowledge.Note] = []
    /// Guides whose members' comments the answer used.
    var commentsUsedOn: [Resource] = []
    /// Forum topics whose replies the answer used.
    var forumsUsed: [ForumTopic] = []

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
            || !helpUsed.isEmpty || !notesUsed.isEmpty || !commentsUsedOn.isEmpty || !forumsUsed.isEmpty
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
    /// Guides older than this get a gentle "may have changed" note.
    private static let oldAfter: TimeInterval = 3 * 365 * 24 * 3600

    var isBusy: Bool { turns.first?.isSearching ?? false }

    /// The longest question, in characters. Real questions run about 50 to
    /// 150; much longer ones crowd out the sources Apple Intelligence reads
    /// to answer. Siri and Discover questions are held to it too.
    /// Requested directly (2026-09-30).
    static let maxQuestionLength = 300

    func ask(_ rawQuestion: String) {
        let question = String(rawQuestion.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxQuestionLength))
        guard !question.isEmpty, !isBusy else { return }
        // Newest first, so the latest answer sits right under the question field.
        let earlier = turns.prefix(2).map(\.question)
        remember(question)
        // The same question within the hour, not as a follow-up: the answer
        // it got then, straight away. Requested directly (2026-09-29).
        if earlier.isEmpty, let hit = Self.answerCache[Self.cacheKey(question)], Date().timeIntervalSince(hit.at) < 3600 {
            var copy = hit.turn
            copy.id = UUID()
            copy.step = .writing
            copy.feedback = nil
            copy.isReadingResults = false
            turns.insert(copy, at: 0)
            let turnId = copy.id
            // Finishing a moment later is what moves VoiceOver to the answer.
            task = Task {
                try? await Task.sleep(for: .milliseconds(300))
                self.update(turnId) { $0.step = nil }
            }
            return
        }
        turns.insert(MouseTurn(question: question), at: 0)
        let turnId = turns[0].id
        task = Task { await run(question, earlier: Array(earlier), turnId: turnId) }
    }

    /// Answers from the last hour, by question, for this session.
    private static var answerCache: [String: (turn: MouseTurn, at: Date)] = [:]

    private static func cacheKey(_ question: String) -> String {
        question.lowercased().split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// "Did this answer your question?", kept on the device. Sources that
    /// help most are read first next time. Requested directly (2026-09-29).
    func recordFeedback(_ turnId: UUID, helpful: Bool) {
        guard let turn = turns.first(where: { $0.id == turnId }) else { return }
        var kinds: [String] = []
        if !turn.helpUsed.isEmpty { kinds.append("help") }
        if !turn.guidesUsed.isEmpty || !turn.moreGuides.filter({ turn.resultNotes[$0.id] != nil }).isEmpty { kinds.append("guide") }
        if !turn.commentsUsedOn.isEmpty { kinds.append("comments") }
        if !turn.forumsUsed.isEmpty || !turn.forums.filter({ turn.resultNotes[$0.id] != nil }).isEmpty { kinds.append("forum") }
        if !turn.blogs.filter({ turn.resultNotes[$0.id] != nil }).isEmpty { kinds.append("blog") }
        if !turn.podcasts.filter({ turn.resultNotes[$0.id] != nil }).isEmpty { kinds.append("podcast") }
        if !turn.notesUsed.isEmpty { kinds.append("whatsNew") }
        MouseFeedback.record(helpful: helpful, kinds: kinds)
        update(turnId) { $0.feedback = helpful }
    }

    func stop() {
        task?.cancel()
        update(turns.first?.id) { turn in
            turn.step = nil
            turn.draft = nil
            if !turn.foundAnything { turn.answered = false }
        }
    }

    func clearConversation() {
        task?.cancel()
        turns = []
    }

    func clearRecent() {
        store([])
    }

    func removeRecent(_ question: String) {
        store(recentQuestions.filter { $0 != question })
    }

    func recordSwitch(_ turnId: UUID, done: Bool) {
        update(turnId) { $0.switchDone = done }
    }

    // MARK: - Running a question

    private func run(_ question: String, earlier: [String], turnId: UUID) async {
        // Without a plan, only the question's main words go to the website,
        // never the whole question, as Help promises. It used to send the
        // question as typed. Found 2026-09-30.
        let fallback = Self.searchWords(question)
        let plan = await IntelligenceService.mousePlan(for: question, earlier: earlier)
            ?? IntelligenceService.MousePlan(searchPhrases: [fallback])
        if Task.isCancelled { return }
        let phrases = plan.searchPhrases.isEmpty ? [fallback] : plan.searchPhrases
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
        // What's new in the app, a setting, or your saved items: only the
        // app can answer, and a website search for "what's new" just
        // brought back unrelated posts under More From AppleVis.
        // Reported directly (2026-09-28).
        let appOnly = [.whatsNew, .changeSetting, .savedItems].contains(plan.kind)
        async let siteResults: SearchResults? = appOnly ? nil : (try? APIClient.shared.search.query(searchPhrase))
        async let appResults: [AppListing]? = plan.kind == .findApps
            ? (try? APIClient.shared.apps.mouseSearch(
                keyword: plan.appKeyword.isEmpty ? searchPhrase : plan.appKeyword,
                fullyAccessibleOnly: plan.fullyAccessibleOnly,
                category: plan.appCategory))
            : nil

        var site = await siteResults
        if Task.isCancelled { return }
        // A second wording when the first found no guides.
        if !appOnly, (site?.guides.isEmpty ?? true), phrases.count > 1, let second = try? await APIClient.shared.search.query(phrases[1]) {
            site = site.map { merged($0, second) } ?? second
        }
        if plan.kind == .findApps { set(turnId, step: .apps) }
        let apps = await appResults ?? []
        if Task.isCancelled { return }
        set(turnId, step: .forums)

        // The two best guides, read in full, with their members' comments,
        // so the answer can use them. For questions about Apple devices or
        // people's experiences, also the best-matching forum topic and its
        // replies. Members' advice is labelled as theirs in the answer.
        // Requested directly (2026-09-28).
        let guides = Array((site?.guides ?? []).prefix(plan.kind == .findApps ? 0 : 2))
        let scorer = Self.relevanceScorer(question: question, words: words)
        let forumTopic: ForumTopic? = [.communityDiscussion, .appleHowTo, .other].contains(plan.kind)
            ? Self.ranked(site?.forums ?? [], by: scorer) { ($0.title, "") }.first
            : nil
        async let guideReads = readGuides(guides)
        async let forumRead = readForum(forumTopic)
        let guideTexts = await guideReads
        let (forumText, forumFullText) = await forumRead
        if Task.isCancelled { return }

        var sources: [IntelligenceService.MouseSource] = []
        var guideFocus: [String: String] = [:]
        var versionNotes: [String: String] = [:]
        for article in help.prefix(2) {
            let text = MouseKnowledge.bestPassages(in: MouseKnowledge.helpArticleText(article), terms: words, maxCharacters: 900)
            sources.append(.init(id: "help-\(article.id)", title: article.title, text: article.summary + "\n" + text))
        }
        for (guide, read) in zip(guides, guideTexts) where !read.text.isEmpty {
            guideFocus[guide.id] = MouseKnowledge.bestParagraph(in: read.text, terms: words)
            versionNotes["guide-\(guide.id)"] = Self.olderIOSNote(read.text)
            sources.append(.init(id: "guide-\(guide.id)", title: guide.title,
                                 text: MouseKnowledge.bestPassages(in: read.text, terms: words, maxCharacters: 800)))
            let comments = Self.bestComments(read.comments, words: words, maxCharacters: 450)
            if !comments.isEmpty {
                sources.append(.init(id: "comments-\(guide.id)", title: "Members' comments on the guide \"\(guide.title)\"", text: comments))
            }
        }
        if let forumTopic, !forumText.isEmpty {
            sources.append(.init(id: "forum-\(forumTopic.id)", title: "Forum discussion among members: \(forumTopic.title)", text: forumText))
        }
        for note in notes.prefix(plan.kind == .whatsNew ? 6 : 2) {
            sources.append(.init(id: note.id, title: note.title, text: String(note.text.prefix(plan.kind == .whatsNew ? 260 : 600))))
        }

        set(turnId, step: .writing)
        var answer: IntelligenceService.MouseAnswer?
        var failure: IntelligenceService.MouseFailure?
        // Shows the answer on screen as it's written.
        let showDraft: @MainActor @Sendable (String) -> Void = { [weak self] text in
            self?.update(turnId) { $0.draft = text.isEmpty ? nil : text }
        }
        if plan.kind != .findApps || apps.isEmpty {
            let result = await IntelligenceService.mouseAnswer(to: question, earlier: earlier, sources: sources,
                                                               iOSVersion: Self.deviceIOSVersion, onPartial: showDraft)
            answer = result.answer
            failure = result.failure
        }
        if Task.isCancelled { return }

        // Not answered from the best passages: read the rest of the guides
        // and the forum discussion a part at a time, most promising part
        // first, and answer from the parts that have it. A long guide is
        // more than the model can read at once. Requested directly
        // (2026-09-29).
        if plan.kind != .findApps, failure == nil, !(answer?.answered ?? false) {
            var long: [(id: String, title: String, text: String)] = []
            for (guide, read) in zip(guides, guideTexts) where !read.text.isEmpty {
                long.append(("guide-\(guide.id)", guide.title, read.text))
                if !read.comments.isEmpty {
                    long.append(("comments-\(guide.id)", "Members' comments on the guide \"\(guide.title)\"",
                                 read.comments.map { "\($0.0): \($0.1)" }.joined(separator: "\n")))
                }
            }
            if let forumTopic, !forumFullText.isEmpty {
                long.append(("forum-\(forumTopic.id)", "Forum discussion among members: \(forumTopic.title)", forumFullText))
            }
            if !long.isEmpty {
                set(turnId, step: .closerLook)
                update(turnId) { $0.draft = nil }
                let found = await closerLook(at: long, question: question, words: words)
                if Task.isCancelled { return }
                if !found.isEmpty {
                    set(turnId, step: .writing)
                    let helpSources = sources.filter { $0.id.hasPrefix("help-") }
                    let result = await IntelligenceService.mouseAnswer(to: question, earlier: earlier, sources: helpSources + found,
                                                                       iOSVersion: Self.deviceIOSVersion, onPartial: showDraft)
                    if result.answer?.answered ?? false { answer = result.answer }
                    failure = result.failure
                }
            }
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
            turn.guideFocus = guideFocus
            turn.versionNotes = versionNotes
            turn.draft = nil
            turn.failure = failure
            if let answer {
                turn.answered = answer.answered
                let composed = Self.composedAnswer(answer)
                turn.answer = answer.answered ? composed.text : nil
                turn.hasSteps = answer.answered && composed.hasSteps
                turn.followUps = Array(answer.followUps.filter { $0.caseInsensitiveCompare(question) != .orderedSame }.prefix(3))
                let used = Set(answer.sourceIds)
                // When the model didn't say which it used, show the best matches.
                let usedAny = !used.isEmpty
                turn.helpUsed = answer.answered ? help.prefix(2).filter { !usedAny || used.contains("help-\($0.id)") } : []
                turn.guidesUsed = answer.answered ? guides.filter { !usedAny || used.contains("guide-\($0.id)") } : []
                turn.notesUsed = answer.answered ? notes.filter { !usedAny || used.contains($0.id) } : []
                // Community sources only when the answer says it used them.
                turn.commentsUsedOn = answer.answered ? guides.filter { used.contains("comments-\($0.id)") } : []
                turn.forumsUsed = answer.answered ? [forumTopic].compactMap { $0 }.filter { used.contains("forum-\($0.id)") } : []
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
                // More From AppleVis is scored, not just matched: each
                // different question word in the title counts 3, one found
                // only in the description counts 1, and words side by side
                // ("three finger") score extra. A result needs at least two
                // different question words (one, for a one-word question),
                // and each group shows its highest scores first. A single
                // stray word used to be enough. Reported directly
                // (2026-09-28). Forum topics only have a title to go on.
                let usedGuideIds = Set(turn.guidesUsed.map(\.id))
                let usedForumIds = Set(turn.forumsUsed.map(\.id))
                turn.moreGuides = Array(Self.ranked(site.guides.filter { !usedGuideIds.contains($0.id) }, by: scorer) { ($0.title, $0.summary) }.prefix(3))
                turn.forums = Array(Self.ranked(site.forums.filter { !usedForumIds.contains($0.id) }, by: scorer) { ($0.title, "") }.prefix(3))
                turn.podcasts = Array(Self.ranked(site.podcasts, by: scorer) { ($0.title, $0.description) }.prefix(2))
                turn.blogs = Array(Self.ranked(site.blogs, by: scorer) { ($0.title, $0.summary) }.prefix(2))
                turn.bugs = Array(Self.ranked(site.bugs, by: scorer) { ($0.title, $0.summary) }.prefix(2))
                turn.otherApps = plan.kind == .findApps ? [] : Array(Self.ranked(site.apps, by: scorer) { ($0.name, $0.summary) }.prefix(3))
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

        // Then read the best few More From AppleVis results for a line each.
        if Task.isCancelled { return }
        await readResults(turnId: turnId, question: question, words: words)
        if earlier.isEmpty, let finished = turns.first(where: { $0.id == turnId }), finished.answered {
            Self.answerCache[Self.cacheKey(question)] = (finished, Date())
        }
    }

    // MARK: - Reading each result

    private enum ResultItem {
        case guide(Resource), forum(ForumTopic), blog(BlogPost), podcast(PodcastEpisode), bug(BugReport)

        var id: String {
            switch self {
            case .guide(let g): return g.id
            case .forum(let t): return t.id
            case .blog(let b): return b.id
            case .podcast(let e): return e.id
            case .bug(let b): return b.id
            }
        }

        var title: String {
            switch self {
            case .guide(let g): return g.title
            case .forum(let t): return t.title
            case .blog(let b): return b.title
            case .podcast(let e): return e.title
            case .bug(let b): return b.title
            }
        }
    }

    /// Reads the best four More From AppleVis results and writes each a
    /// line that answers the question from that page. A page that doesn't
    /// answer it is dropped; one that says the same as another is listed
    /// under it; and if the main answer came up empty, the first page that
    /// does answer becomes the answer. Requested directly (2026-09-29).
    private func readResults(turnId: UUID, question: String, words: [String]) async {
        guard let turn = turns.first(where: { $0.id == turnId }) else { return }
        var candidates: [ResultItem] = []
        for group in MouseFeedback.groupOrder() {
            switch group {
            case "guide": candidates += turn.moreGuides.map(ResultItem.guide)
            case "forum": candidates += turn.forums.map(ResultItem.forum)
            case "blog": candidates += turn.blogs.map(ResultItem.blog)
            case "podcast": candidates += turn.podcasts.map(ResultItem.podcast)
            default: break
            }
        }
        candidates += turn.bugs.map(ResultItem.bug)
        candidates = Array(candidates.prefix(4))
        guard !candidates.isEmpty else { return }

        update(turnId) { $0.isReadingResults = true }
        var promotedTitle: String?
        for item in candidates {
            if Task.isCancelled { break }
            let text = await readText(item)
            let passage = MouseKnowledge.bestPassages(in: text, terms: words, maxCharacters: 700)
            guard !passage.isEmpty else { continue }
            let versionNote = Self.olderIOSNote(text)
            let focus = MouseKnowledge.bestParagraph(in: text, terms: words)
            var note: MouseTurn.ResultNote?
            var drop = false
            if let result = await IntelligenceService.mouseResultLine(question: question, title: item.title, passage: passage) {
                if result.answers {
                    note = .init(line: result.line, isQuote: false, versionNote: versionNote)
                } else {
                    drop = true
                }
            } else if let quote = MouseKnowledge.bestSentence(in: passage, terms: words) {
                // No Apple Intelligence line: the page's own best sentence.
                note = .init(line: quote, isQuote: true, versionNote: versionNote)
            }
            update(turnId) { turn in
                if drop {
                    Self.remove(item, from: &turn)
                    return
                }
                guard let note else { return }
                if case .guide(let guide) = item, let focus { turn.guideFocus[guide.id] = focus }
                if let existing = turn.resultNotes.first(where: { Self.sameAnswer($0.value.line, note.line) })?.key {
                    turn.resultNotes[existing]?.alsoIn.append(item.title)
                    Self.remove(item, from: &turn)
                    return
                }
                if !note.isQuote, turn.answer == nil, turn.mainApps.isEmpty, turn.switchOffer == nil {
                    turn.answer = note.line
                    turn.answered = true
                    promotedTitle = item.title
                    switch item {
                    case .guide(let guide):
                        turn.guidesUsed.append(guide)
                        if let versionNote { turn.versionNotes["guide-\(guide.id)"] = versionNote }
                        Self.remove(item, from: &turn)
                        return
                    case .forum(let topic):
                        turn.forumsUsed.append(topic)
                        Self.remove(item, from: &turn)
                        return
                    default:
                        break
                    }
                }
                turn.resultNotes[item.id] = note
            }
        }
        update(turnId) { $0.isReadingResults = false }
        if let promotedTitle {
            UIAccessibility.post(notification: .announcement, argument: String(localized: "Found an answer in \(promotedTitle)."))
        }
    }

    private func readText(_ item: ResultItem) async -> String {
        switch item {
        case .guide(let guide):
            guard let detail = try? await APIClient.shared.resources.detail(id: guide.id) else { return "" }
            let comments = detail.comments.map { "\($0.authorName): " + HTMLText.plainText(fromHTML: $0.body) }
            return ([HTMLText.plainText(fromHTML: detail.body)] + comments).joined(separator: "\n")
        case .forum(let topic):
            guard let detail = try? await APIClient.shared.forums.topicDetail(id: topic.id) else { return "" }
            let replies = detail.replies.map { "\($0.authorName): " + HTMLText.plainText(fromHTML: $0.body) }
            return ([HTMLText.plainText(fromHTML: detail.body)] + replies).joined(separator: "\n")
        case .blog(let post):
            guard let detail = try? await APIClient.shared.blogs.detail(id: post.id) else { return HTMLText.plainText(fromHTML: post.summary) }
            return HTMLText.plainText(fromHTML: detail.body)
        case .podcast(let episode):
            return HTMLText.plainText(fromHTML: episode.description)
        case .bug(let bug):
            return HTMLText.plainText(fromHTML: bug.summary)
        }
    }

    private static func remove(_ item: ResultItem, from turn: inout MouseTurn) {
        switch item {
        case .guide(let g): turn.moreGuides.removeAll { $0.id == g.id }
        case .forum(let t): turn.forums.removeAll { $0.id == t.id }
        case .blog(let b): turn.blogs.removeAll { $0.id == b.id }
        case .podcast(let e): turn.podcasts.removeAll { $0.id == e.id }
        case .bug(let b): turn.bugs.removeAll { $0.id == b.id }
        }
    }

    /// Up to six of the question's main words, for a site search when
    /// Apple Intelligence couldn't plan one.
    static func searchWords(_ question: String) -> String {
        let words = MouseKnowledge.terms(question).prefix(6).joined(separator: " ")
        return words.isEmpty ? String(question.prefix(60)) : words
    }

    /// Two lines saying the same thing: mostly the same words.
    static func sameAnswer(_ a: String, _ b: String) -> Bool {
        let x = Set(MouseKnowledge.terms(a)), y = Set(MouseKnowledge.terms(b))
        guard !x.isEmpty, !y.isEmpty else { return false }
        return Double(x.intersection(y).count) / Double(x.union(y).count) >= 0.75
    }

    // MARK: - Reading long pages a part at a time

    /// About 450 words: small enough for the model to read one part with
    /// room to spare.
    private static let partLength = 1800
    /// The most parts read before giving up, so it doesn't take too long.
    private static let maxPartsRead = 5

    /// Splits the long pages into parts, reads the most promising parts
    /// one at a time, and returns the parts that answer the question,
    /// stopping once two have. Requested directly (2026-09-29).
    private func closerLook(at pages: [(id: String, title: String, text: String)], question: String, words: [String]) async -> [IntelligenceService.MouseSource] {
        var parts: [(source: IntelligenceService.MouseSource, score: Int, order: Int)] = []
        for page in pages {
            for text in Self.parts(of: page.text) {
                let score = MouseKnowledge.score(title: "", body: text, terms: words)
                guard score > 0 else { continue }
                parts.append((source: IntelligenceService.MouseSource(id: page.id, title: page.title, text: text), score: score, order: parts.count))
            }
        }
        let ordered = parts.sorted { $0.score != $1.score ? $0.score > $1.score : $0.order < $1.order }.prefix(Self.maxPartsRead)
        var found: [IntelligenceService.MouseSource] = []
        for part in ordered {
            if Task.isCancelled || found.count == 2 { break }
            guard let result = await IntelligenceService.mouseResultLine(question: question, title: part.source.title, passage: part.source.text),
                  result.answers else { continue }
            found.append(part.source)
        }
        return found
    }

    /// Paragraphs gathered into parts of about `partLength` characters.
    static func parts(of text: String) -> [String] {
        TextSegmentation.pieces(text, maxLength: partLength)
    }

    // MARK: - Steps

    /// The answer as shown: the introduction, then each step numbered on
    /// its own line. When the model also wrote the steps into the
    /// introduction, only its first sentence is kept, so the steps aren't
    /// read twice.
    static func composedAnswer(_ answer: IntelligenceService.MouseAnswer) -> (text: String, hasSteps: Bool) {
        guard answer.steps.count >= 2 else {
            let text = answer.steps.isEmpty ? answer.text : [answer.text, answer.steps[0]].filter { !$0.isEmpty }.joined(separator: " ")
            return (text, false)
        }
        var intro = answer.text
        let introWords = Set(MouseKnowledge.terms(intro))
        let stepWords = Set(MouseKnowledge.terms(answer.steps.joined(separator: " ")))
        if !stepWords.isEmpty, Double(stepWords.intersection(introWords).count) / Double(stepWords.count) >= 0.6 {
            intro = TextSegmentation.sentenceGroups(intro, groupSize: 1).first ?? intro
        }
        return (IntelligenceService.mouseAnswerText(intro, steps: answer.steps), true)
    }

    // MARK: - iOS version

    static var deviceIOSVersion: String { UIDevice.current.systemVersion }

    /// "Written for iOS 17. It may have changed." when a page's newest
    /// iOS mention is older than this device's. Requested directly
    /// (2026-09-29).
    static func olderIOSNote(_ text: String) -> String? {
        guard let current = Int(deviceIOSVersion.split(separator: ".").first ?? "") else { return nil }
        let pattern = #/iOS\s?(\d{2})\b/#
        let mentioned = text.matches(of: pattern).compactMap { Int($0.output.1) }.filter { (11...40).contains($0) }
        guard let newest = mentioned.max(), newest < current else { return nil }
        return String(localized: "Written for iOS \(String(newest)). It may have changed.")
    }

    /// Words too common to show a title is about the question.
    private static let generalWords: Set<String> = [
        "new", "applevis", "app", "apps", "help", "use", "using", "get", "work", "works", "way", "best",
        "good", "need", "make", "iphone", "ios", "question", "questions", "feature", "features",
    ]

    /// Scores a result against the question, or nil when it isn't about
    /// it. Each different meaningful word in the title counts 3; one found
    /// only in the description counts 1; two question words side by side
    /// ("three finger", "swipe up") add 3 each. At least two different
    /// question words must appear (one, when the question has only one).
    static func relevanceScorer(question: String, words: [String]) -> (_ title: String, _ details: String) -> Int? {
        let meaningful = words.filter { !generalWords.contains($0) }
        let needed = min(2, meaningful.count)
        let questionTerms = MouseKnowledge.terms(question).filter { !generalWords.contains($0) }
        let pairs = zip(questionTerms, questionTerms.dropFirst()).map { "\($0) \($1)" }
        func normalized(_ text: String) -> String {
            text.lowercased().replacingOccurrences(of: "-", with: " ")
        }
        // Whole words, so "up" doesn't match "update"; a longer word also
        // matches its plural or other endings ("gesture", "gestures").
        func has(_ term: String, in words: Set<String>) -> Bool {
            words.contains(term) || (term.count >= 4 && words.contains { $0.hasPrefix(term) && $0.count <= term.count + 3 })
        }
        return { title, details in
            guard needed > 0 else { return nil }
            let lowerTitle = normalized(title)
            let lowerDetails = normalized(HTMLText.plainText(fromHTML: details))
            let titleWords = Set(MouseKnowledge.terms(lowerTitle))
            let detailWords = Set(MouseKnowledge.terms(lowerDetails))
            let inTitle = meaningful.filter { has($0, in: titleWords) }
            let inDetails = meaningful.filter { !inTitle.contains($0) && has($0, in: detailWords) }
            guard inTitle.count + inDetails.count >= needed else { return nil }
            let together = pairs.filter { lowerTitle.contains($0) || lowerDetails.contains($0) }.count
            return inTitle.count * 3 + inDetails.count + together * 3
        }
    }

    /// Results that score, highest first; equal scores keep the site's order.
    static func ranked<T>(_ items: [T], by scorer: (String, String) -> Int?, text: (T) -> (String, String)) -> [T] {
        items.enumerated()
            .compactMap { index, item -> (Int, Int, T)? in
                let (title, details) = text(item)
                return scorer(title, details).map { (index, $0, item) }
            }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
            .map(\.2)
    }

    /// "Entry last updated in 2017" on anything the site hasn't touched in years.
    static func withAge(_ text: String, updated: Date) -> String {
        guard Date().timeIntervalSince(updated) > oldAfter else { return text }
        let year = Calendar.current.component(.year, from: updated)
        return text + " " + String(localized: "Last updated in \(String(year)), so check it's still current.")
    }

    static func isOld(_ date: Date) -> Bool { Date().timeIntervalSince(date) > oldAfter }

    /// A guide's text and its members' comments (author, text).
    struct GuideRead: Sendable {
        var text = ""
        var comments: [(String, String)] = []
    }

    private func readGuides(_ guides: [Resource]) async -> [GuideRead] {
        await withTaskGroup(of: (Int, GuideRead).self) { group in
            for (index, guide) in guides.enumerated() {
                group.addTask {
                    guard let detail = try? await APIClient.shared.resources.detail(id: guide.id) else { return (index, GuideRead()) }
                    return (index, GuideRead(
                        text: HTMLText.plainText(fromHTML: detail.body),
                        comments: detail.comments.map { ($0.authorName, HTMLText.plainText(fromHTML: $0.body)) }
                    ))
                }
            }
            var reads = Array(repeating: GuideRead(), count: guides.count)
            for await (index, read) in group { reads[index] = read }
            return reads
        }
    }

    /// The topic's opening post, briefly, and its replies with the most
    /// in common with the question; and the whole discussion, for a
    /// closer look.
    private func readForum(_ topic: ForumTopic?) async -> (String, String) {
        guard let topic, let detail = try? await APIClient.shared.forums.topicDetail(id: topic.id) else { return ("", "") }
        let words = MouseKnowledge.terms(topic.title)
        let body = HTMLText.plainText(fromHTML: detail.body)
        let post = String(body.prefix(300))
        let allReplies = detail.replies.map { ($0.authorName, HTMLText.plainText(fromHTML: $0.body)) }
        let replies = Self.bestComments(allReplies, words: words, maxCharacters: 650)
        let full = ([body] + allReplies.map { "\($0.0): \($0.1)" }).joined(separator: "\n")
        return (replies.isEmpty ? post : post + "\n" + replies, full)
    }

    /// The comments sharing the most words with the question, in their
    /// original order, each shortened, within `maxCharacters`.
    static func bestComments(_ comments: [(String, String)], words: [String], maxCharacters: Int) -> String {
        let scored = comments.enumerated().map { index, comment in
            (index, MouseKnowledge.score(title: "", body: comment.1, terms: words))
        }
        let chosen = scored.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.prefix(5).map(\.0).sorted()
        var lines: [String] = []
        var length = 0
        for index in chosen {
            let (author, text) = comments[index]
            let line = "\(author): " + String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(250))
            if length + line.count > maxCharacters { break }
            lines.append(line)
            length += line.count + 1
        }
        return lines.joined(separator: "\n")
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

    // MARK: - Recent questions (synced with iCloud when Saved Items sync is on)

    private func remember(_ question: String) {
        var list = recentQuestions.filter { $0.caseInsensitiveCompare(question) != .orderedSame }
        list.insert(question, at: 0)
        store(Array(list.prefix(8)))
    }

    /// Saves the list with the time it changed, so the newest change wins
    /// between devices, removals included. Requested directly (2026-09-29).
    private func store(_ list: [String]) {
        recentQuestions = list
        MouseRecentQuestions.save(MouseRecentQuestions(questions: list, updatedAt: Date()))
        ICloudSyncManager.shared.pushMouseRecentQuestions()
    }

    private static func loadRecent() -> [String] {
        MouseRecentQuestions.load().questions
    }
}

/// The last 8 questions asked, and when the list last changed.
struct MouseRecentQuestions: Codable {
    var questions: [String]
    var updatedAt: Date

    private static let key = "mouse.recentQuestions.v2"
    private static let oldKey = "mouse.recentQuestions"

    static func load() -> MouseRecentQuestions {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(MouseRecentQuestions.self, from: data) {
            return saved
        }
        // Before syncing: just the questions.
        return MouseRecentQuestions(questions: UserDefaults.standard.stringArray(forKey: oldKey) ?? [], updatedAt: .distantPast)
    }

    static func save(_ value: MouseRecentQuestions) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
        UserDefaults.standard.removeObject(forKey: oldKey)
    }
}

/// Which kinds of source helped, from "Did this answer your question?".
/// Kept on the device; the most helpful kinds are read first.
enum MouseFeedback {
    private static let key = "mouse.feedback"

    static func record(helpful: Bool, kinds: [String]) {
        var counts = load()
        for kind in Set(kinds) {
            var entry = counts[kind] ?? [0, 0]
            entry[helpful ? 0 : 1] += 1
            counts[kind] = entry
        }
        UserDefaults.standard.set(counts, forKey: key)
    }

    static func score(_ kind: String) -> Int {
        let entry = load()[kind] ?? [0, 0]
        return entry[0] - entry[1]
    }

    /// More From AppleVis groups, most helpful first; ties keep this order.
    static func groupOrder() -> [String] {
        let base = ["guide", "forum", "blog", "podcast"]
        return base.enumerated().sorted { a, b in
            let x = score(a.element), y = score(b.element)
            return x != y ? x > y : a.offset < b.offset
        }.map(\.element)
    }

    private static func load() -> [String: [Int]] {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: [Int]]) ?? [:]
    }
}
