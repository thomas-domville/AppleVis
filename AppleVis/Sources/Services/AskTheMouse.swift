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
        /// "AppleVis Golden Apple winner, Best Game 2024", when it has one.
        var honor: String?
        /// Members who recommend it, once AppleVis shares the count.
        var recommendations: Int?
        var id: String { app.id }
    }

    /// A one-line answer for a More From AppleVis result: what that page
    /// says about the question. `isQuote` when it's the page's own sentence
    /// because Apple Intelligence couldn't write one. `alsoIn` lists other
    /// pages that said the same. Requested directly (2026-09-29).
    struct ResultNote: Equatable {
        enum Agreement: Equatable { case same, different }

        var line: String
        var isQuote: Bool
        var alsoIn: [String] = []
        var versionNote: String?
        /// Whether this page says the same as the answer, when there is one.
        var agreement: Agreement?
        /// When the page was posted, for newest-first ordering.
        var date: Date?
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
    /// The answer says what came close, because nothing answered it.
    var isNearMiss = false
    /// Nothing to do with Apple, accessibility, or AppleVis: a friendly
    /// redirect, and nothing was searched.
    var isOffTopic = false
    /// A sharper search for Search the Web, from Apple Intelligence.
    var webQuery = ""
    /// An Apple Support page that covers the question.
    var appleLink: MouseAppleLink?
    /// A page from Apple's user guides that covers it, when no hand-picked
    /// page does.
    var catalogLink: MouseAppleCatalog.Entry?
    /// About an Apple device or feature, so Apple Support's own search
    /// is worth offering.
    var isAppleTopic = false
    /// False when nothing the Mouse could find answers the question.
    var answered = true
    var helpUsed: [HelpArticle] = []
    var guidesUsed: [Resource] = []
    var notesUsed: [MouseKnowledge.Note] = []
    /// Guides whose members' comments the answer used.
    var commentsUsedOn: [Resource] = []
    /// Forum topics whose replies the answer used.
    var forumsUsed: [ForumTopic] = []
    /// Known bugs from the Bug Tracker the answer used.
    var bugsUsed: [BugReport] = []
    /// Podcast episodes whose transcript the answer used.
    var podcastsUsed: [PodcastEpisode] = []
    /// AppleVis blog posts the answer used, for news like "What's new in
    /// iOS 26 for VoiceOver?".
    var blogsUsed: [BlogPost] = []
    /// App entries whose members' comments the answer used.
    var appCommentsUsedOn: [AppListing] = []

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
    /// Asking back what a vague question means: the questions it might
    /// mean, to choose from. Requested directly (2026-10-01).
    var clarifyChoices: [String] = []
    /// The settings screen the Mouse checked, when the answer used it.
    var setupChecked: MousePlace?
    /// Reopened from Past Conversations: the sources as they were.
    var restoredSources: [SavedMouseAnswer.Source] = []
    var isRestored = false

    var isSearching: Bool { step != nil }
    var foundAnything: Bool {
        answer != nil || !mainApps.isEmpty || !relatedApps.isEmpty || !moreGuides.isEmpty || !forums.isEmpty
            || !podcasts.isEmpty || !blogs.isEmpty || !bugs.isEmpty || !otherApps.isEmpty || !saved.isEmpty
            || !helpUsed.isEmpty || !notesUsed.isEmpty || !commentsUsedOn.isEmpty || !forumsUsed.isEmpty
            || !bugsUsed.isEmpty || !podcastsUsed.isEmpty || !appCommentsUsedOn.isEmpty || !blogsUsed.isEmpty
    }
}

extension MouseTurn {
    /// A turn reopened from Past Conversations: the question, the answer,
    /// and its sources, ready for follow-ups.
    init(restoring saved: SavedMouseAnswer) {
        self.init(question: saved.question)
        id = UUID(uuidString: saved.id) ?? UUID()
        step = nil
        answer = saved.answer
        answered = saved.answered ?? true
        restoredSources = saved.sources
        isRestored = true
    }

    /// The answer as shown, for saving, copying, and Past Conversations.
    var savedAnswerText: String {
        answer ?? appsIntro ?? (answered
            ? String(localized: "Here's what I found on AppleVis.")
            : String(localized: "I couldn't find that on AppleVis. The community might know, so you could ask in the Forums."))
    }

    /// Where the answer came from, including any apps it listed.
    var savedSources: [SavedMouseAnswer.Source] {
        var list: [SavedMouseAnswer.Source] = restoredSources
        list += helpUsed.map { .init(kind: .help, title: $0.title, helpArticleId: $0.id) }
        list += guidesUsed.map { .init(kind: .guide, title: $0.title, url: $0.url, contentId: $0.id) }
        list += commentsUsedOn.map { .init(kind: .guideComments, title: $0.title, url: $0.url, contentId: $0.id) }
        list += forumsUsed.map { .init(kind: .forum, title: $0.title, url: $0.url, contentId: $0.id) }
        list += bugsUsed.map { .init(kind: .bug, title: $0.title, url: $0.url, contentId: $0.id) }
        list += podcastsUsed.map { .init(kind: .podcast, title: $0.title, url: $0.url, contentId: $0.id) }
        list += appCommentsUsedOn.map { .init(kind: .appComments, title: $0.name, url: $0.url, contentId: $0.id) }
        list += blogsUsed.map { .init(kind: .blog, title: $0.title, url: $0.url, contentId: $0.id) }
        list += notesUsed.map { .init(kind: $0.id.hasPrefix("whatsnew:") ? .whatsNew : .tip, title: $0.title) }
        if let setupChecked { list.append(.init(kind: .settings, title: setupChecked.name)) }
        list += (mainApps + relatedApps).prefix(10).map { .init(kind: .app, title: $0.app.name, url: $0.app.url, contentId: $0.app.id) }
        return list
    }
}

/// Runs Ask the Mouse: understands the question with Apple Intelligence,
/// searches Help, the rest of the app, and applevis.com all at once, then
/// answers only from what it found. Requested directly (2026-09-28).
@MainActor
final class AskTheMouse: ObservableObject {
    @Published private(set) var turns: [MouseTurn] = []
    @Published private(set) var recentQuestions: [String] = AskTheMouse.loadRecent()
    /// The last 10 conversations, newest first. Requested directly (2026-10-01).
    @Published private(set) var conversations: [MouseConversation] = MouseConversationHistory.load().conversations
    /// The conversation new answers are added to.
    private var conversationId = UUID().uuidString

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
                self.recordConversation(turnId)
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
        // Which guides and topics helped with this kind of question, so
        // the ones that helped are read first next time and the ones that
        // didn't are passed over. Requested directly (2026-10-01).
        var pages = turn.guidesUsed.map { "guide-\($0.id)" } + turn.forumsUsed.map { "forum-\($0.id)" }
        pages += turn.moreGuides.filter { turn.resultNotes[$0.id] != nil }.map { "guide-\($0.id)" }
        pages += turn.forums.filter { turn.resultNotes[$0.id] != nil }.map { "forum-\($0.id)" }
        MouseSourceFeedback.record(helpful: helpful, sourceIds: pages, words: MouseKnowledge.terms(turn.question))
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
        conversationId = UUID().uuidString
    }

    // MARK: - Past conversations

    /// Reopens a past conversation, so the next question follows on from
    /// it. Requested directly (2026-10-01).
    func restore(_ conversation: MouseConversation) {
        task?.cancel()
        turns = conversation.answers.reversed().map(MouseTurn.init(restoring:))
        conversationId = conversation.id
    }

    func removeConversation(_ id: String) {
        var history = MouseConversationHistory.load()
        history.remove(id)
        saveConversations(history)
        if id == conversationId { conversationId = UUID().uuidString }
    }

    func clearConversations() {
        saveConversations(MouseConversationHistory(conversations: [], updatedAt: Date()))
        conversationId = UUID().uuidString
    }

    /// Keeps a finished answer in this conversation. Questions the Mouse
    /// asked back about aren't answers, so they're left out.
    private func recordConversation(_ turnId: UUID) {
        guard let turn = turns.first(where: { $0.id == turnId }), !turn.isSearching, turn.clarifyChoices.isEmpty else { return }
        var history = MouseConversationHistory.load()
        history.record(SavedMouseAnswer(id: turn.id.uuidString, question: turn.question, answer: turn.savedAnswerText,
                                        sources: turn.savedSources, savedAt: Date(), answered: turn.answered),
                       in: conversationId)
        saveConversations(history)
    }

    private func saveConversations(_ history: MouseConversationHistory) {
        conversations = history.conversations
        MouseConversationHistory.save(history)
        ICloudSyncManager.shared.pushMouseConversations()
    }

    /// Picks up conversations synced from another device.
    func reloadConversations() {
        conversations = MouseConversationHistory.load().conversations
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
        // The Apple guide topics most like the question, for Apple
        // Intelligence to choose a link from. Requested directly (2026-10-01).
        // A follow-up like "And on the Mac?" takes its subject from the
        // question before it. Found testing (2026-10-01).
        let catalog = MouseAppleCatalog.candidates(for: question, phrases: Array(earlier.prefix(1)))
        // The devices and features from About Me, when filled in.
        let aboutMe = MouseProfile.load().modelText
        var plan = await IntelligenceService.mousePlan(for: question, earlier: earlier, catalog: catalog, aboutMe: aboutMe)
            ?? IntelligenceService.MousePlan(searchPhrases: [fallback])
        if Task.isCancelled { return }
        // A question in another language matches none of Apple's English
        // page titles before planning. Once Apple Intelligence has put it
        // into English search words, a clear match is offered.
        if plan.appleLink == nil, plan.catalogLink == nil,
           [.appleHowTo, .other, .communityDiscussion].contains(plan.kind) {
            plan.catalogLink = MouseAppleCatalog.confidentMatch(for: question, phrases: plan.searchPhrases + [plan.webQuery])
        }
        // Not about Apple, accessibility, or AppleVis, like "What's the
        // best Kia SUV?": a friendly redirect, without searching AppleVis
        // for it. Requested directly (2026-10-01).
        if plan.kind == .offTopic {
            update(turnId) { turn in
                turn.isOffTopic = true
                turn.answered = false
                turn.answer = String(localized: "That one's outside my burrow! I'm here for questions about Apple devices, accessibility, apps, and AppleVis. Try asking me about one of those.")
                turn.step = nil
            }
            recordConversation(turnId)
            return
        }
        // Too vague to search, such as "How do I turn it off?" with nothing
        // before it: ask back, with the questions it might mean to choose
        // from. Short first questions only, so it rarely happens.
        // Requested directly (2026-10-01).
        if !plan.clarify.isEmpty, plan.clarifyChoices.count >= 2, earlier.isEmpty,
           question.split(whereSeparator: { $0.isWhitespace }).count <= 8 {
            update(turnId) { turn in
                turn.answer = plan.clarify
                turn.clarifyChoices = Array(plan.clarifyChoices.prefix(3))
                turn.answered = false
                turn.step = nil
            }
            return
        }
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
        async let siteResults: SearchResults? = appOnly ? nil : (try? APIClient.shared.search.query(searchPhrase, relaxBugVersions: true))
        // "What's the latest AppleVis podcast?": the site's search ranks by
        // relevance, so it brought back episodes from 2018 to 2022 and the
        // newest one wasn't among them. Questions asking for the latest
        // episodes get the newest from the podcast feed instead. Found
        // testing live questions (2026-10-05).
        let questionWords = Set(MouseKnowledge.terms(question))
        let wantsLatestPodcast = !appOnly && !questionWords.isDisjoint(with: ["latest", "newest", "recent", "week", "last"])
            && (lower.contains("podcast") || lower.contains("episode"))
        async let latestEpisodes: [PodcastEpisode] = wantsLatestPodcast
            ? ((try? await APIClient.shared.podcasts.episodes().items) ?? []) : []
        async let appResults: [AppListing]? = plan.kind == .findApps
            ? (try? APIClient.shared.apps.mouseSearch(
                keyword: plan.appKeyword.isEmpty ? searchPhrase : plan.appKeyword,
                fullyAccessibleOnly: plan.fullyAccessibleOnly,
                category: plan.appCategory,
                platform: plan.appPlatform,
                limit: 60))
            : nil

        // Every other wording at the same time, guides and forums only. It
        // used to try a second wording only when the first found no guides
        // at all, so two wrong guides (a Mac trackpad guide, for "three
        // finger double tap") kept it from the one that answered. Reported
        // directly (2026-10-01).
        async let extraResults: [SearchResults] = appOnly ? [] : Self.searchGuidesAndForums(Array(phrases.dropFirst().prefix(2)))
        // The essential AppleVis guide on the subject, and the app the
        // question names, looked up at the same time. Requested directly
        // (2026-10-01).
        async let essentialFound: Resource? = appOnly ? nil : Self.findEssential(plan.essentialGuide)
        async let namedApp: AppRead? = appOnly || plan.kind == .findApps ? nil : Self.readNamedApp(plan.appName)
        var site = await siteResults
        let latestPodcasts = Array(await latestEpisodes.prefix(3))
        for extra in await extraResults {
            site = site.map { merged($0, extra) } ?? extra
        }
        if Task.isCancelled { return }
        if plan.kind == .findApps { set(turnId, step: .apps) }
        // The directory sends the most recently updated first. Apps with the
        // word in their name go first, then in their description, so the
        // ones Apple Intelligence sorts are the closest matches, not just
        // the newest. "Card games" otherwise left classics like Ears
        // BlackJack (2020) out entirely. Found testing (2026-10-01).
        async let recommended: [String: Int] = plan.kind == .findApps ? Self.recommendationCounts() : [:]
        let apps = Self.rankedApps(await appResults ?? [], keyword: plan.appKeyword.isEmpty ? searchPhrase : plan.appKeyword)
        let recommendations = await recommended
        if Task.isCancelled { return }
        set(turnId, step: .forums)

        // The two best guides, read in full, with their members' comments,
        // so the answer can use them. For questions about Apple devices or
        // people's experiences, also the best-matching forum topic and its
        // replies. Members' advice is labelled as theirs in the answer.
        // Requested directly (2026-09-28).
        let scorer = Self.relevanceScorer(question: question, words: words)
        let feedback = MouseSourceFeedback.load()
        let essential = await essentialFound
        var guideCandidates = plan.kind == .findApps ? [] : Self.guideCandidates(site?.guides ?? [], scorer: scorer)
        if let essential {
            guideCandidates = [essential] + guideCandidates.filter { $0.id != essential.id }
        }
        // A known bug that matches, for "it isn't working" questions.
        let bugCandidate: BugReport? = [.appleHowTo, .communityDiscussion, .other].contains(plan.kind)
            ? Self.ranked(site?.bugs ?? [], by: scorer) { ($0.title, $0.summary) }.first
            : nil
        // Among the three best matches, one members have replied to: a
        // topic with no replies rarely holds the answer. Requested directly
        // (2026-10-01).
        let forumMatches = [.communityDiscussion, .appleHowTo, .other].contains(plan.kind)
            ? Array(Self.ranked(site?.forums ?? [], by: scorer) { ($0.title, "") }.prefix(3))
            : []
        // A topic that answered a similar question before comes first; one
        // that didn't is passed over. Requested directly (2026-10-01).
        let usableForums = forumMatches.filter { MouseSourceFeedback.score("forum-\($0.id)", words: words, in: feedback) >= 0 }
        let forumTopic: ForumTopic? = usableForums.first { MouseSourceFeedback.score("forum-\($0.id)", words: words, in: feedback) > 0 }
            ?? usableForums.first { $0.replyCount > 0 } ?? usableForums.first
        async let guideReads = readGuides(guideCandidates)
        async let forumRead = readForum(forumTopic)
        async let bugRead = Self.readBug(bugCandidate)
        // The best-matching AppleVis blog post, read in full: news and
        // "what's new" answers live there. Found testing (2026-10-01).
        let blogCandidate: BlogPost? = [.appleHowTo, .communityDiscussion, .other].contains(plan.kind)
            ? Self.ranked(site?.blogs ?? [], by: scorer, newestFirst: \.publishedAt) { ($0.title, $0.summary) }.first
            : nil
        async let blogRead = Self.readBlog(blogCandidate)
        let candidateReads = await guideReads
        let (forumText, forumFullText) = await forumRead
        let bugText = await bugRead
        let blogText = await blogRead
        let appRead = await namedApp
        if Task.isCancelled { return }
        // The two that actually say it ("three-finger double tap", "3
        // finger double-tap"…) come first; then the search's best.
        let keyPhrases = Self.keyPhrases(question: question, phrases: phrases)
        // Helped with a similar question before: up; didn't: down.
        // Requested directly (2026-10-01).
        var feedbackBoost: [String: Int] = [:]
        for guide in guideCandidates {
            feedbackBoost[guide.id] = max(-4, min(4, 2 * MouseSourceFeedback.score("guide-\(guide.id)", words: words, in: feedback)))
        }
        let picked = zip(guideCandidates, candidateReads).enumerated()
            .map { (order: $0.offset, guide: $0.element.0, read: $0.element.1,
                    // The essential guide always makes the two.
                    hits: Self.phraseHits($0.element.1.text, keyPhrases) + ($0.element.0.id == essential?.id ? 1000 : 0)
                        + (feedbackBoost[$0.element.0.id] ?? 0)) }
            .sorted { $0.hits != $1.hits ? $0.hits > $1.hits : $0.order < $1.order }
            .prefix(2)
        let guides = picked.map(\.guide)
        let guideTexts = picked.map(\.read)

        var sources: [IntelligenceService.MouseSource] = []
        // "Why don't I get notifications?": the person's own settings on
        // that screen, read on the device, never changed. Requested
        // directly (2026-10-01).
        var setupPlace: MousePlace?
        if plan.checkSetup, let place = plan.place, place.rawValue.hasSuffix("Settings"), let preferences = PreferencesStore.current {
            let facts = await MouseSetupCheck.facts(for: place, preferences: preferences, isSignedIn: AuthStore.current?.user != nil)
            if !facts.isEmpty {
                setupPlace = place
                sources.append(.init(id: "setup-\(place.rawValue)",
                                     title: "The person's own AppleVis app settings on the \(place.name) screen, checked just now", text: facts))
            }
        }
        var guideFocus: [String: String] = [:]
        var versionNotes: [String: String] = [:]
        for article in help.prefix(2) {
            // Inside an article, rank lines by the question's words that
            // aren't already in its title. In "Braille Display Commands",
            // nearly every line has "braille" and "command", so "go home"
            // lost out to generic lines and the answer was cut. The title
            // words already chose the article. Found testing (2026-10-05).
            let titleWords = Set(MouseKnowledge.terms(article.title))
            let focused = words.filter { !titleWords.contains($0) }
            let text = MouseKnowledge.bestPassages(in: MouseKnowledge.helpPassageText(article), terms: focused.isEmpty ? words : focused, maxCharacters: 900)
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
        if let blogCandidate, !blogText.isEmpty {
            sources.append(.init(id: "blog-\(blogCandidate.id)",
                                 title: "AppleVis blog post from \(blogCandidate.publishedAt.formatted(.dateTime.month(.wide).year())): \(blogCandidate.title)",
                                 text: MouseKnowledge.bestPassages(in: blogText, terms: words, maxCharacters: 800)))
        }
        if let bugCandidate, !bugText.isEmpty {
            sources.append(.init(id: "bug-\(bugCandidate.id)", title: "Known bug in the AppleVis Bug Tracker: \(bugCandidate.title)", text: bugText))
        }
        if let appRead, !appRead.text.isEmpty {
            sources.append(.init(id: "appcomments-\(appRead.app.id)", title: "Members' comments on the app entry \"\(appRead.app.name)\"", text: appRead.text))
        }
        // The best podcast episode whose notes or transcript actually
        // mention the question, read like a guide.
        let podcastCandidate: PodcastEpisode? = plan.kind == .findApps ? nil : Self.ranked(site?.podcasts ?? [], by: scorer) { ($0.title, $0.description) }
            .first { Self.phraseHits(HTMLText.plainText(fromHTML: $0.description), keyPhrases) > 0 }
        let podcastText = podcastCandidate.map { HTMLText.plainText(fromHTML: $0.description) } ?? ""
        if let podcastCandidate, !podcastText.isEmpty {
            sources.append(.init(id: "podcast-\(podcastCandidate.id)", title: "AppleVis podcast episode (people talking): \(podcastCandidate.title)",
                                 text: MouseKnowledge.bestPassages(in: podcastText, terms: words, maxCharacters: 700)))
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
                                                               iOSVersion: Self.deviceIOSVersion, aboutMe: aboutMe, onPartial: showDraft)
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
            if let blogCandidate, !blogText.isEmpty {
                long.append(("blog-\(blogCandidate.id)", "AppleVis blog post: \(blogCandidate.title)", blogText))
            }
            if let podcastCandidate, !podcastText.isEmpty {
                long.append(("podcast-\(podcastCandidate.id)", "AppleVis podcast episode (people talking): \(podcastCandidate.title)", podcastText))
            }
            if !long.isEmpty {
                set(turnId, step: .closerLook)
                update(turnId) { $0.draft = nil }
                let found = await closerLook(at: long, question: question, words: words)
                if Task.isCancelled { return }
                if !found.isEmpty {
                    set(turnId, step: .writing)
                    let helpSources = sources.filter { $0.id.hasPrefix("help-") || $0.id.hasPrefix("setup-") }
                    let result = await IntelligenceService.mouseAnswer(to: question, earlier: earlier, sources: helpSources + found,
                                                                       iOSVersion: Self.deviceIOSVersion, aboutMe: aboutMe, onPartial: showDraft)
                    if result.answer?.answered ?? false {
                        answer = result.answer
                    } else if answer?.nearMiss.isEmpty ?? true, let second = result.answer, !second.nearMiss.isEmpty {
                        answer = second
                    }
                    failure = result.failure
                }
            }
        }
        var picks: IntelligenceService.MousePicks?
        if !apps.isEmpty {
            let items = apps.prefix(15).map { app in
                IntelligenceService.MouseItem(
                    id: app.id, title: app.name,
                    details: String(HTMLText.plainText(fromHTML: app.summary).prefix(200)) + (app.price.isEmpty ? "" : " (\(app.price))")
                        + Self.popularityNote(app, recommendations: recommendations[app.id]))
            }
            picks = await IntelligenceService.mousePicks(for: question, items: Array(items))
        }
        if Task.isCancelled { return }

        update(turnId) { turn in
            turn.guideFocus = guideFocus
            turn.versionNotes = versionNotes
            turn.webQuery = plan.webQuery
            turn.appleLink = plan.appleLink
            turn.catalogLink = plan.catalogLink
            turn.isAppleTopic = plan.kind == .appleHowTo || plan.appleLink?.provider == .apple || plan.catalogLink != nil
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
                turn.bugsUsed = [bugCandidate].compactMap { $0 }.filter { used.contains("bug-\($0.id)") }
                turn.podcastsUsed = [podcastCandidate].compactMap { $0 }.filter { used.contains("podcast-\($0.id)") }
                turn.blogsUsed = [blogCandidate].compactMap { $0 }.filter { used.contains("blog-\($0.id)") }
                turn.appCommentsUsedOn = [appRead?.app].compactMap { $0 }.filter { used.contains("appcomments-\($0.id)") }
                turn.setupChecked = answer.answered ? setupPlace.flatMap { !usedAny || used.contains("setup-\($0.rawValue)") ? $0 : nil } : nil
                // Nothing answers it, but something came close: said
                // honestly ("I couldn't find… The closest is…"), with the
                // close sources listed. Never passed off as the answer.
                // Requested directly (2026-10-01).
                if !answer.answered, !answer.nearMiss.isEmpty {
                    turn.answer = answer.nearMiss
                    turn.isNearMiss = true
                    turn.helpUsed = help.prefix(2).filter { used.contains("help-\($0.id)") }
                    turn.guidesUsed = guides.filter { used.contains("guide-\($0.id)") }
                    turn.forumsUsed = [forumTopic].compactMap { $0 }.filter { used.contains("forum-\($0.id)") }
                }
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
                    let entry = MouseTurn.PickedApp(app: app, blurb: Self.withAge(pick.blurb, updated: app.lastUpdatedAt),
                                                    honor: GoldenApples.best(for: app).map(GoldenApples.line),
                                                    recommendations: recommendations[app.id])
                    if pick.isMain { turn.mainApps.append(entry) } else { turn.relatedApps.append(entry) }
                }
            } else if !apps.isEmpty {
                turn.mainApps = apps.prefix(10).map {
                    MouseTurn.PickedApp(app: $0, blurb: Self.withAge(String(HTMLText.plainText(fromHTML: $0.summary).prefix(140)), updated: $0.lastUpdatedAt),
                                        honor: GoldenApples.best(for: $0).map(GoldenApples.line),
                                        recommendations: recommendations[$0.id])
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
                turn.podcasts = latestPodcasts.isEmpty
                    ? Array(Self.ranked(site.podcasts, by: scorer) { ($0.title, $0.description) }.prefix(2))
                    : latestPodcasts
                turn.blogs = Array(Self.ranked(site.blogs.filter { blog in !turn.blogsUsed.contains { $0.id == blog.id } }, by: scorer, newestFirst: \.publishedAt) { ($0.title, $0.summary) }.prefix(2))
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
        recordConversation(turnId)
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

        var date: Date {
            switch self {
            case .guide(let g): return g.createdAt
            case .forum(let t): return t.createdAt
            case .blog(let b): return b.publishedAt
            case .podcast(let e): return e.publishedAt
            case .bug(let b): return b.createdAt
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
        // A real answer to compare each page with; not a near miss.
        let mainAnswer = turn.answered && !turn.isNearMiss ? turn.answer : nil
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
            if let result = await IntelligenceService.mouseResultLine(question: question, title: item.title, passage: passage, answer: mainAnswer) {
                if result.answers {
                    let agreement: MouseTurn.ResultNote.Agreement? = result.agreement == "same" ? .same : result.agreement == "different" ? .different : nil
                    note = .init(line: result.line, isQuote: false, versionNote: versionNote, agreement: agreement, date: item.date)
                } else {
                    drop = true
                }
            } else if let quote = MouseKnowledge.bestSentence(in: passage, terms: words) {
                // No Apple Intelligence line: the page's own best sentence.
                note = .init(line: quote, isQuote: true, versionNote: versionNote, date: item.date)
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
                if !note.isQuote, turn.answer == nil || turn.isNearMiss, turn.mainApps.isEmpty, turn.switchOffer == nil {
                    turn.answer = note.line
                    turn.answered = true
                    promotedTitle = item.title
                    // A real answer replaces a near miss, and its sources.
                    if turn.isNearMiss {
                        turn.helpUsed = []
                        turn.guidesUsed = []
                        turn.forumsUsed = []
                        turn.isNearMiss = false
                    }
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

    // MARK: - Finding the right guides

    /// Apps with the keyword (or its plural) in their name first, then in
    /// their description, keeping the directory's newest-first order within
    /// each.
    static func rankedApps(_ apps: [AppListing], keyword: String) -> [AppListing] {
        let stems = keyword.lowercased().split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { $0.hasSuffix("s") ? String($0.dropLast()) : $0 }
        guard !stems.isEmpty else { return apps }
        // Within each, Golden Apples honors, then how many member comments,
        // so the community's favorites lead among equally good matches.
        // Requested directly (2026-10-01).
        func tiebreak(_ app: AppListing) -> Int {
            (GoldenApples.best(for: app)?.rank ?? 0) * 1000 + min(app.reviewCount, 999)
        }
        // Whole words only, with plurals ("car" and "cars"), or the word
        // inside a run-together name ("BlackJack", "Bardcard"). "Car" used
        // to match "card", so card games led a question about car games.
        // Found testing (2026-10-01).
        func matches(_ words: [String]) -> Bool {
            stems.contains { stem in
                words.contains { $0 == stem || $0 == "\(stem)s" || $0 == "\(stem)es" }
            }
        }
        func score(_ app: AppListing) -> Int {
            let nameWords = normalizedForMatching(app.name).split(separator: " ").map(String.init)
            let joined = nameWords.joined()
            if matches(nameWords) || stems.contains(where: { $0.count >= 5 && joined.contains($0) }) { return 2 }
            let summaryWords = normalizedForMatching(HTMLText.plainText(fromHTML: app.summary)).split(separator: " ").map(String.init)
            return matches(summaryWords) ? 1 : 0
        }
        return apps.enumerated()
            .sorted {
                if score($0.element) != score($1.element) { return score($0.element) > score($1.element) }
                if tiebreak($0.element) != tiebreak($1.element) { return tiebreak($0.element) > tiebreak($1.element) }
                return $0.offset < $1.offset
            }
            .map(\.element)
    }

    /// How many members recommend each app, by app id, from AppleVis's
    /// recommendations (the same source as Community Picks). Empty until
    /// that endpoint is live, so nothing is shown.
    private static func recommendationCounts() async -> [String: Int] {
        guard let picks = try? await APIClient.shared.communityPicks.list(sort: .most, period: .allTime, platform: nil, page: 0) else { return [:] }
        return Dictionary(picks.map { ($0.app.id, $0.totalCount) }, uniquingKeysWith: { first, _ in first })
    }

    /// Honors and popularity, for Apple Intelligence sorting apps.
    private static func popularityNote(_ app: AppListing, recommendations: Int?) -> String {
        var notes: [String] = []
        if let honor = GoldenApples.best(for: app) {
            notes.append("AppleVis Golden Apple \(honor.status), \(honor.award) \(honor.year)")
        }
        if app.reviewCount > 0 { notes.append("\(app.reviewCount) member comments") }
        if let recommendations, recommendations > 0 { notes.append("recommended by \(recommendations) members") }
        return notes.isEmpty ? "" : " [" + notes.joined(separator: "; ") + "]"
    }

    /// The essential guide's full entry, found through the site's search
    /// by its title and matched by id.
    private static func findEssential(_ guide: MouseEssentialGuide?) async -> Resource? {
        guard let guide, let results = try? await APIClient.shared.search.guidesAndForums(guide.title) else { return nil }
        return results.guides.first { $0.id == guide.id }
    }

    /// A blog post's text, as the Mouse reads it.
    private static func readBlog(_ post: BlogPost?) async -> String {
        guard let post else { return "" }
        guard let detail = try? await APIClient.shared.blogs.detail(id: post.id) else { return HTMLText.plainText(fromHTML: post.summary) }
        return HTMLText.plainText(fromHTML: detail.body)
    }

    /// A known bug's status, versions, and workaround, as the Mouse reads it.
    private static func readBug(_ bug: BugReport?) async -> String {
        guard let bug else { return "" }
        var lines = ["Status: " + (bug.status == .active ? "still active" : "fixed")]
        if let firstSeen = bug.firstSeen, !firstSeen.isEmpty { lines.append("First seen in: \(firstSeen)") }
        if let fixedIn = bug.fixedIn, !fixedIn.isEmpty { lines.append("Fixed in: \(fixedIn)") }
        lines.append("Reported: " + bug.createdAt.formatted(date: .abbreviated, time: .omitted))
        if let detail = try? await APIClient.shared.bugReports.detail(platform: bug.platform, id: bug.id) {
            lines.append(String(HTMLText.plainText(fromHTML: detail.body).prefix(350)))
            if let workaround = detail.workaround, !workaround.isEmpty {
                lines.append("Workaround: " + String(HTMLText.plainText(fromHTML: workaround).prefix(300)))
            }
        } else {
            lines.append(String(HTMLText.plainText(fromHTML: bug.summary).prefix(350)))
        }
        return lines.joined(separator: "\n")
    }

    /// The app the person named: the exact name, then a name starting with
    /// it ("Threads, an Instagram app"), then one containing it as a whole
    /// word ("Amazon Kindle"). A name of one or two letters, like X, must
    /// match exactly. It used to take any name containing the letters, so
    /// "Threads" found "Roads Audio: Voice Threads" and "X" found "Vox
    /// libri". Found testing (2026-10-01). A renamed app counts as an exact
    /// match, so X finds "X [Formerly Twitter]" (requested 2026-10-01).
    static func bestNameMatch(_ apps: [AppListing], for wanted: String) -> AppListing? {
        let target = normalizedForMatching(wanted)
        guard !target.isEmpty else { return nil }
        let names = apps.map { (app: $0, name: normalizedForMatching($0.name)) }
        if let exact = names.first(where: { $0.name == target }) { return exact.app }
        if let renamed = names.first(where: { $0.name.hasPrefix(target + " formerly ") }) { return renamed.app }
        guard target.count >= 3 else { return nil }
        if let starts = names.first(where: { $0.name.hasPrefix(target + " ") }) { return starts.app }
        return names.first(where: { (" " + $0.name + " ").contains(" " + target + " ") })?.app
    }

    /// An app named in the question, with its newest members' comments.
    struct AppRead: Sendable {
        let app: AppListing
        let text: String
    }

    /// The app entry whose name best matches, and what members said about
    /// it, newest first, with dates, so the answer can say how recent.
    private static func readNamedApp(_ name: String) async -> AppRead? {
        let wanted = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wanted.isEmpty else { return nil }
        // Names first; descriptions only when no name has it.
        var found = (try? await APIClient.shared.apps.mouseFindByName(wanted)) ?? []
        if found.isEmpty {
            found = (try? await APIClient.shared.apps.mouseSearch(keyword: wanted, fullyAccessibleOnly: false, category: nil, limit: 20)) ?? []
        }
        guard let app = bestNameMatch(found, for: wanted),
              let detail = try? await APIClient.shared.apps.detail(id: app.id, platform: app.platform) else { return nil }
        let comments = detail.reviews.sorted { $0.createdAt > $1.createdAt }.prefix(6).map { review in
            "\(review.createdAt.formatted(date: .abbreviated, time: .omitted)), \(review.authorName): "
                + String(HTMLText.plainText(fromHTML: review.body).prefix(220))
        }
        let summary = String(HTMLText.plainText(fromHTML: app.summary).prefix(200))
        let text = ([summary] + (comments.isEmpty ? ["No member comments yet."] : comments)).joined(separator: "\n")
        return AppRead(app: app, text: text)
    }

    /// Each extra wording's guides and forums, searched at the same time.
    private static func searchGuidesAndForums(_ phrases: [String]) async -> [SearchResults] {
        await withTaskGroup(of: (Int, SearchResults?).self) { group in
            for (index, phrase) in phrases.enumerated() {
                group.addTask { (index, try? await APIClient.shared.search.guidesAndForums(phrase)) }
            }
            var found: [(Int, SearchResults)] = []
            for await (index, result) in group {
                if let result { found.append((index, result)) }
            }
            return found.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    /// Up to four guides worth reading: the best-scoring first, then the
    /// rest in the search's order.
    private static func guideCandidates(_ guides: [Resource], scorer: (String, String) -> Int?) -> [Resource] {
        let scored = ranked(guides, by: scorer) { ($0.title, $0.summary) }
        let ids = Set(scored.map(\.id))
        return Array((scored + guides.filter { !ids.contains($0.id) }).prefix(4))
    }

    /// The question's words and its search wordings, as phrases to look for
    /// in a guide's text.
    static func keyPhrases(question: String, phrases: [String]) -> [String] {
        let fromQuestion = MouseKnowledge.terms(question).joined(separator: " ")
        return Array(Set(([fromQuestion] + phrases)
            .map(normalizedForMatching)
            .filter { $0.split(separator: " ").count >= 2 }))
    }

    /// How many of the phrases the text contains, whole words only.
    static func phraseHits(_ text: String, _ phrases: [String]) -> Int {
        guard !phrases.isEmpty, !text.isEmpty else { return 0 }
        let haystack = " " + normalizedForMatching(text) + " "
        return phrases.filter { haystack.contains(" " + $0 + " ") }.count
    }

    /// Lowercase words with the usual spellings made alike: "3-finger
    /// double-taps" and "three finger double tap" match.
    nonisolated static func normalizedForMatching(_ text: String) -> String {
        let alike: [String: String] = [
            "1": "one", "2": "two", "3": "three", "4": "four", "5": "five",
            "fingers": "finger", "taps": "tap", "swipes": "swipe", "doubletap": "double tap",
            "screenshot": "screen shot", "screenshots": "screen shot", "phone": "iphone",
            // Common spellings: "brail", British "centre" and "colour".
            // Requested directly (2026-10-01).
            "brail": "braille", "brial": "braille", "centre": "center", "colour": "color", "colours": "colors",
            // "commands" alike too, so "braille command" matches Apple's
            // "Common braille commands" page as a pair. Found testing
            // (2026-10-04).
            "braill": "braille", "commands": "command",
        ]
        // "voice over" and "voice-over" are VoiceOver.
        return text.lowercased()
            .replacingOccurrences(of: "voice over", with: "voiceover")
            .replacingOccurrences(of: "voice-over", with: "voiceover")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .map { alike[$0] ?? $0 }
            .joined(separator: " ")
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
        // matches its plural or other endings ("gesture", "gestures"), and
        // a plural matches its singular ("apples" finds "Golden Apple
        // Awards", which it used to miss; found testing 2026-10-05).
        func has(_ term: String, in words: Set<String>) -> Bool {
            words.contains(term)
                || (term.count >= 4 && words.contains { $0.hasPrefix(term) && $0.count <= term.count + 3 })
                || words.contains { $0.count >= 4 && term.hasPrefix($0) && term.count <= $0.count + 2 }
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

    /// Results that score, highest first; equal scores newest first. For
    /// blog posts, which are news: "Who won the Golden Apples?" otherwise
    /// led with the 2013 winners, the site's first match. Found testing
    /// live questions (2026-10-05).
    static func ranked<T>(_ items: [T], by scorer: (String, String) -> Int?, newestFirst date: (T) -> Date, text: (T) -> (String, String)) -> [T] {
        items.compactMap { item -> (Int, Date, T)? in
            let (title, details) = text(item)
            return scorer(title, details).map { ($0, date(item), item) }
        }
        .sorted { $0.0 != $1.0 ? $0.0 > $1.0 : $0.1 > $1.1 }
        .map(\.2)
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
    nonisolated struct GuideRead: Sendable {
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
