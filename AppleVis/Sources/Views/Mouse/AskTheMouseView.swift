import SwiftUI
import UIKit

/// Where a row inside Ask the Mouse leads.
enum MouseRoute: Hashable {
    case help(String)
    /// A guide, opened at the paragraph an answer came from.
    case guide(String, focusText: String?)
    case whatsNew
    case place(MousePlace)
    case saved(ContentKind, String)
    /// About Me, Past Conversations, and one past conversation.
    /// Requested directly (2026-10-01).
    case aboutMe
    case pastConversations
    case conversation(String)
}

/// Ask the Mouse: ask anything about AppleVis in your own words. Answers
/// come only from Help, the rest of the app, and applevis.com, found with
/// Apple Intelligence on the device. Opened from Home, Help, Discover, and
/// Siri. Requested directly (2026-09-28).
struct AskTheMouseView: View {
    var initialQuestion: String? = nil

    @StateObject private var mouse = AskTheMouse()
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss

    @State private var question = ""
    /// The question was cut to the limit; says so under the field.
    @State private var wasShortened = false

    private static var shortenedMessage: String {
        String(localized: "Questions can be up to 300 characters, so yours was shortened. Try asking it more briefly.")
    }
    @State private var searchStartedAt: Date?
    @State private var sheetPlace: MousePlace?
    @State private var forumQuestion: ForumQuestion?
    @State private var webSearch: WebSearch?
    @State private var path = NavigationPath()
    /// Answers saved to For You > Saved, by turn id.
    @State private var savedAnswerIds: Set<String> = Set(PersistenceStore.shared.savedMouseAnswers().map(\.id))
    @FocusState private var isFieldFocused: Bool
    @AccessibilityFocusState private var focus: MouseFocus?

    private enum MouseFocus: Hashable {
        case greeting
        case answer(UUID)
        case answerPart(UUID, Int)
        case needMore(UUID)
    }

    /// Answers switched with Ungroup Answer or Group Answer from how they
    /// started, by turn (see `isUngrouped`).
    @State private var toggledTurns: Set<UUID> = []
    /// Makes the Mouse hop: on arrival, and when an answer helped.
    @State private var hop = 0
    /// Questions already suggested to the editorial team, by turn, and the
    /// one being sent.
    @State private var suggestedTurns: Set<UUID> = []
    @State private var suggestingTurn: UUID?

    private struct ForumQuestion: Identifiable {
        let text: String
        var id: String { text }
    }

    private struct WebSearch: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }

    private var suggestions: [String] {
        [
            String(localized: "What's new in this version?"),
            String(localized: "Find a fully accessible game"),
            String(localized: "How do I follow a topic?"),
            String(localized: "How do I submit a blog post?"),
            String(localized: "What does a three-finger double tap do?"),
        ]
    }

    private var greeting: String {
        if let name = auth.user?.name, !name.isEmpty {
            return String(localized: "\(Greeting.text()), \(name)! What can I help you find?")
        }
        return String(localized: "Hi there! What can I help you find?")
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                introSection
                if IntelligenceService.isAvailable {
                    questionSection
                    if mouse.turns.isEmpty {
                        suggestionsSection
                        recentSection
                        memorySection
                        savedAnswersSection
                    }
                    ForEach(mouse.turns) { turn in
                        turnSections(turn)
                    }
                } else {
                    Section {
                        Text("Ask the Mouse needs Apple Intelligence, which isn't available on this device or isn't turned on. You can still search in Discover and Help.")
                    }
                }
            }
            .themedList(preferences.colors)
            .navigationTitle("Ask the Mouse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
            .navigationDestination(for: MouseRoute.self) { route in
                destination(for: route)
            }
            .navigationDestination(for: ForumTopic.self) { ForumTopicDetailView(topicId: $0.id) }
            .navigationDestination(for: PodcastEpisode.self) { EpisodeDetailView(episodeId: $0.id) }
            .navigationDestination(for: AppListing.self) { AppDetailView(appId: $0.id, platform: $0.platform) }
            .navigationDestination(for: Resource.self) { ResourceDetailView(resourceId: $0.id) }
            .navigationDestination(for: BlogPost.self) { BlogDetailView(postId: $0.id) }
            .navigationDestination(for: BugReport.self) { BugDetailView(bugId: $0.id) }
            .navigationDestination(item: $pushedPlace) { place in
                placeView(place)
            }
            .sheet(item: $sheetPlace) { place in
                sheet(for: place)
            }
            .sheet(item: $forumQuestion) { item in
                ComposeTopicView(prefillTitle: item.text)
            }
            .sheet(item: $webSearch) { item in
                SafariView(url: item.url)
            }
            .onChange(of: mouse.turns.first?.step) { oldStep, newStep in
                searchStepChanged(from: oldStep, to: newStep)
            }
            .task {
                // Loads Apple Intelligence now, so the first answer is quicker.
                IntelligenceService.prewarmMouse()
                // Conversations synced from another device since last time.
                mouse.reloadConversations()
                if let initialQuestion, !initialQuestion.isEmpty, mouse.turns.isEmpty {
                    question = initialQuestion
                    ask()
                } else {
                    await retryAccessibilityFocus(.greeting, into: $focus)
                }
            }
        }
    }

    // MARK: - Top

    private var introSection: some View {
        Section {
            HStack(alignment: .center, spacing: 12) {
                // The whole Mouse, holding a question bubble, with a little
                // hop hello. Decorative, still with Reduce Motion, and
                // hidden at the largest text sizes. Requested directly
                // (2026-09-29).
                MouseMascotView(pose: .asking, size: 84)
                    .modifier(CharacterHop(trigger: hop))
                    .onAppear { hop += 1 }
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($focus, equals: .greeting)
                    Text("Ask about the app, find apps and guides, or look for a discussion. I answer only from AppleVis, and it all happens on your device.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var questionSection: some View {
        Section {
            TextField(String(localized: "Your question"), text: $question)
                .focused($isFieldFocused)
                .submitLabel(.search)
                .onSubmit(ask)
                .accessibilityHint(String(localized: "Ask in your own words, then choose Ask."))
                // A question longer than this can crowd out what the Mouse
                // reads to answer it. Requested directly (2026-09-30).
                .inputLimit($question, maximum: AskTheMouse.maxQuestionLength, warnWithin: 50) {
                    wasShortened = true
                    UIAccessibility.post(notification: .announcement, argument: Self.shortenedMessage)
                }
            if wasShortened {
                Text(Self.shortenedMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if AskTheMouse.maxQuestionLength - question.count <= 50 {
                Text(InputLimit.remaining(AskTheMouse.maxQuestionLength - question.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                ask()
            } label: {
                Label(String(localized: "Ask"), systemImage: "arrow.up.circle.fill")
            }
            .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || mouse.isBusy)
            // Right by the question field, where you'd decide between a
            // follow-up and a fresh start. It used to be at the very bottom,
            // past every answer, and was called Start a New Conversation,
            // which sounded like a forum post. Requested directly (2026-09-29).
            if !mouse.turns.isEmpty, !mouse.isBusy {
                Button {
                    mouse.clearConversation()
                    question = ""
                    UIAccessibility.post(notification: .announcement, argument: String(localized: "Started over."))
                    Task { await retryAccessibilityFocus(.greeting, into: $focus) }
                } label: {
                    Label(String(localized: "Start Over"), systemImage: "arrow.counterclockwise")
                }
                .accessibilityHint(String(localized: "Clears these answers so your next question starts fresh. Saved answers and recent questions are kept."))
            }
        }
    }

    private var suggestionsSection: some View {
        Section(String(localized: "Try Asking")) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button(suggestion) {
                    question = suggestion
                    ask()
                }
            }
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        if !mouse.recentQuestions.isEmpty {
            Section {
                ForEach(mouse.recentQuestions, id: \.self) { recent in
                    Button(recent) {
                        question = recent
                        ask()
                    }
                    .accessibilityHint(String(localized: "Asks this again. To keep an answer, use Save Answer on it."))
                    .voiceOverAwareSwipeActions {
                        Button(role: .destructive) {
                            removeRecent(recent)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                    .accessibilityAction(named: Text("Remove from Recent Questions")) { removeRecent(recent) }
                    .contextMenu {
                        Button {
                            question = recent
                            ask()
                        } label: {
                            Label("Ask Again", systemImage: "arrow.clockwise")
                        }
                        Button(role: .destructive) {
                            removeRecent(recent)
                        } label: {
                            Label("Remove from Recent Questions", systemImage: "trash")
                        }
                    }
                }
                Button(String(localized: "Clear Recent Questions"), role: .destructive) {
                    mouse.clearRecent()
                }
            } header: {
                Text("Recent Questions")
            } footer: {
                Text("Your last 8 questions. They sync with your other devices when Saved Items sync is on in Settings > Saved & Sync.")
            }
        }
    }

    private func removeRecent(_ recent: String) {
        mouse.removeRecent(recent)
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Removed from Recent Questions."))
    }

    /// About Me, and Past Conversations once there are any. Requested
    /// directly (2026-10-01).
    private var memorySection: some View {
        Section {
            NavigationLink(value: MouseRoute.aboutMe) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(String(localized: "About Me"), systemImage: "person.crop.circle")
                    Text(aboutMeSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
            if !mouse.conversations.isEmpty {
                NavigationLink(value: MouseRoute.pastConversations) {
                    Label(String(localized: "Past Conversations (\(mouse.conversations.count))"), systemImage: "clock.arrow.circlepath")
                }
            }
        }
    }

    /// Re-read each time the screen draws, so a change in About Me shows
    /// on the way back.
    private var aboutMeSummary: String {
        let profile = MouseProfile.load()
        return profile.isEmpty ? String(localized: "Tell the Mouse which devices and features you use.") : profile.summary
    }

    /// Reopens a past conversation here, ready for a follow-up.
    private func continueConversation(_ conversation: MouseConversation) {
        mouse.restore(conversation)
        path = NavigationPath()
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Conversation reopened. Ask a follow-up, or choose Start Over."))
        if let latest = mouse.turns.first {
            let target = answerFocus(latest)
            Task { await retryAccessibilityFocus(target, into: $focus, delaysMs: [900, 1300, 1800]) }
        }
    }

    @ViewBuilder
    private var savedAnswersSection: some View {
        if !savedAnswerIds.isEmpty {
            Section {
                NavigationLink {
                    SavedItemsView(showsMouseAnswers: true)
                } label: {
                    Label {
                        Text(String(localized: "Saved Answers"))
                    } icon: {
                        MouseMascotView(pose: .bookmarking, size: 30, style: .face)
                    }
                }
            } footer: {
                Text("Answers you've saved are also in For You > Saved.")
            }
        }
    }

    // MARK: - One question and its answer

    @ViewBuilder
    private func turnSections(_ turn: MouseTurn) -> some View {
        Section {
            if let step = turn.step {
                MouseSearchingRow(status: step.status, prop: step.prop)
                // The answer appearing as it's written. On screen only:
                // VoiceOver moves to the finished answer, so it never
                // reads half a sentence.
                if let draft = turn.draft {
                    Text(draft)
                        .modifier(AnswerBubble(showsMouse: true, isEmpty: false))
                        .accessibilityHidden(true)
                }
                Button(String(localized: "Stop"), role: .cancel) { mouse.stop() }
            } else {
                answerRow(turn)
                clarifyRows(turn)
                sourceRows(turn)
                actionRows(turn)
                followUpRows(turn)
                if turn.answered, !turn.isRestored {
                    feedbackRows(turn)
                }
            }
        } header: {
            // Your question as a small bubble on the right, like a chat.
            Text(turn.question)
                .textCase(nil)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.secondary.opacity(0.15)))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel(String(localized: "You asked: \(turn.question)"))
        }

        if turn.step == nil {
            appSections(turn)
            otherSourcesSection(turn)
            moreSection(turn)
            // Asking back what a question means isn't an answer to get more
            // help with.
            if turn.clarifyChoices.isEmpty {
                communitySection(turn)
            }
        }
    }

    /// "Did you mean…": the questions a vague one might mean, to choose
    /// from. Only on the latest answer. Requested directly (2026-10-01).
    @ViewBuilder
    private func clarifyRows(_ turn: MouseTurn) -> some View {
        if !turn.clarifyChoices.isEmpty, turn.id == mouse.turns.first?.id, !mouse.isBusy {
            ForEach(turn.clarifyChoices, id: \.self) { choice in
                Button {
                    question = choice
                    ask()
                } label: {
                    Label(choice, systemImage: "questionmark.bubble")
                }
                .accessibilityHint(String(localized: "Asks this instead."))
            }
        }
    }

    @ViewBuilder
    private func answerRow(_ turn: MouseTurn) -> some View {
        let text = displayedAnswer(turn)
        let parts = answerParts(text)
        if isUngrouped(turn), parts.count > 1 {
            // One stop per paragraph, or per sentence when it's all one
            // paragraph: easier on a braille display for long answers like
            // "What's new?". Group Answer joins them again.
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                Text(part)
                    .modifier(AnswerBubble(showsMouse: index == 0, isEmpty: !turn.answered))
                    .accessibilityFocused($focus, equals: .answerPart(turn.id, index))
                    .accessibilityAction(named: Text("Group Answer")) { group(turn) }
                    .modifier(answerActions(turn))
            }
        } else {
            Text(text)
                .modifier(AnswerBubble(showsMouse: true, isEmpty: !turn.answered))
                .accessibilityFocused($focus, equals: .answer(turn.id))
                .modifier(ConditionalAccessibilityAction(isActive: parts.count > 1, name: "Ungroup Answer") { ungroup(turn) })
                .modifier(answerActions(turn))
        }

        if savedAnswerIds.contains(turn.id.uuidString) {
            Label {
                Text(String(localized: "Saved in For You > Saved"))
            } icon: {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.bounce, value: savedAnswerIds.count)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func displayedAnswer(_ turn: MouseTurn) -> String {
        if let answer = turn.answer { return answer }
        // Why Apple Intelligence couldn't answer, when there's something
        // the person can do about it. Requested directly (2026-09-29).
        switch turn.failure {
        case .blocked?:
            return String(localized: "Apple Intelligence wouldn't answer that, which sometimes happens by mistake. Try asking another way.")
        case .unsupportedLanguage?:
            return String(localized: "Apple Intelligence can't answer in this language yet. Try asking in English.")
        case .busy?:
            return String(localized: "Apple Intelligence is busy. Try again in a moment.")
        case nil:
            break
        }
        if let intro = turn.appsIntro, turn.answered { return intro }
        if turn.switchOffer != nil { return String(localized: "I can change that for you.") }
        if turn.answered { return String(localized: "Here's what I found on AppleVis.") }
        // Nothing on AppleVis, but a page outside it covers this: say so,
        // so the person knows the answer is one step away under Need More
        // Help. Found testing "How do I take a screenshot on my iPad?"
        // (2026-10-01).
        if let link = turn.appleLink, !turn.isOffTopic {
            return String(localized: "I couldn't find that on AppleVis, but \(link.providerName) has a page about it: \(link.title). You'll find it under Need More Help.")
        }
        if let entry = turn.catalogLink, !turn.isOffTopic {
            return String(localized: "I couldn't find that on AppleVis, but \("Apple Support") has a page about it: \(entry.title). You'll find it under Need More Help.")
        }
        return String(localized: "I couldn't find that on AppleVis. The community might know, so you could ask in the Forums.")
    }

    /// Paragraphs, or sentences when the answer is a single paragraph.
    private func answerParts(_ text: String) -> [String] {
        let paragraphs = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return paragraphs.count > 1 ? paragraphs : TextSegmentation.sentenceGroups(text, groupSize: 1)
    }

    /// Ungroup Answer, in the Actions rotor on a long answer. Requested
    /// directly (2026-09-29).
    /// Step-by-step answers start ungrouped, one step per stop, so you can
    /// follow along while you try each one; other answers start grouped.
    /// `toggledTurns` holds the answers switched from how they started.
    /// Requested directly (2026-09-29).
    private func isUngrouped(_ turn: MouseTurn) -> Bool {
        toggledTurns.contains(turn.id) != turn.hasSteps
    }

    private func setUngrouped(_ turn: MouseTurn, _ ungrouped: Bool) {
        if ungrouped != turn.hasSteps { toggledTurns.insert(turn.id) } else { toggledTurns.remove(turn.id) }
    }

    /// Where VoiceOver lands on an answer: its first step or part when it's
    /// shown in parts.
    private func answerFocus(_ turn: MouseTurn) -> MouseFocus {
        isUngrouped(turn) && answerParts(displayedAnswer(turn)).count > 1 ? .answerPart(turn.id, 0) : .answer(turn.id)
    }

    private func ungroup(_ turn: MouseTurn) {
        setUngrouped(turn, true)
        Task { await retryAccessibilityFocus(.answerPart(turn.id, 0), into: $focus) }
    }

    private func group(_ turn: MouseTurn) {
        setUngrouped(turn, false)
        Task { await retryAccessibilityFocus(.answer(turn.id), into: $focus) }
    }

    private func answerActions(_ turn: MouseTurn) -> AnswerActions {
        AnswerActions(
            hasAnswer: turn.answered,
            isSaved: savedAnswerIds.contains(turn.id.uuidString),
            hasSource: !sources(for: turn).isEmpty,
            copyAnswer: { copy(answerText(turn)) },
            copyWithSources: { copy(fullText(turn)) },
            share: { MouseAnswerText.presentShareSheet(fullText(turn)) },
            openSource: { openFirstSource(turn) },
            toggleSave: { toggleSave(turn) },
            followUp: { isFieldFocused = true },
            askForums: { forumQuestion = ForumQuestion(text: turn.question) }
        )
    }

    // MARK: - Answer actions

    /// The answer as it's shown, for Copy Answer and saving.
    private func answerText(_ turn: MouseTurn) -> String {
        turn.answer ?? turn.appsIntro ?? String(localized: "Here's what I found on AppleVis.")
    }

    private func fullText(_ turn: MouseTurn) -> String {
        MouseAnswerText.full(question: turn.question, answer: answerText(turn), sources: sources(for: turn))
    }

    /// Where the answer came from, including any apps it listed.
    private func sources(for turn: MouseTurn) -> [SavedMouseAnswer.Source] {
        turn.savedSources
    }

    private func openFirstSource(_ turn: MouseTurn) {
        if let article = turn.helpUsed.first { path.append(MouseRoute.help(article.id)) }
        else if let guide = turn.guidesUsed.first ?? turn.commentsUsedOn.first { path.append(MouseRoute.guide(guide.id, focusText: turn.guideFocus[guide.id])) }
        else if let topic = turn.forumsUsed.first { path.append(topic) }
        else if let bug = turn.bugsUsed.first { path.append(bug) }
        else if let episode = turn.podcastsUsed.first { path.append(episode) }
        else if let app = turn.appCommentsUsedOn.first { path.append(app) }
        else if let post = turn.blogsUsed.first { path.append(post) }
        else if turn.notesUsed.contains(where: { $0.id.hasPrefix("whatsnew:") }) { path.append(MouseRoute.whatsNew) }
        else if let app = turn.mainApps.first?.app ?? turn.relatedApps.first?.app { path.append(app) }
        else if let source = turn.restoredSources.first {
            if let kind = source.contentKind, let id = source.contentId { path.append(MouseRoute.saved(kind, id)) }
            else if source.kind == .help, let id = source.helpArticleId { path.append(MouseRoute.help(id)) }
        }
    }

    private func toggleSave(_ turn: MouseTurn) {
        let id = turn.id.uuidString
        if savedAnswerIds.contains(id) {
            PersistenceStore.shared.unsaveMouseAnswer(id: id)
            savedAnswerIds.remove(id)
            UIAccessibility.post(notification: .announcement, argument: String(localized: "Removed from Saved."))
        } else {
            PersistenceStore.shared.saveMouseAnswer(SavedMouseAnswer(
                id: id, question: turn.question, answer: answerText(turn), sources: sources(for: turn), savedAt: Date()
            ))
            savedAnswerIds.insert(id)
            UIAccessibility.post(notification: .announcement, argument: String(localized: "Saved. Find it in For You > Saved."))
        }
    }

    private func copy(_ text: String) {
        UIPasteboard.general.string = text
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Copied."))
    }

    @ViewBuilder
    private func sourceRows(_ turn: MouseTurn) -> some View {
        // A reopened conversation's sources, as they were saved.
        ForEach(turn.restoredSources, id: \.self) { source in
            MouseSourceLink(source: source)
        }
        // The settings the Mouse checked, opening that screen.
        // Requested directly (2026-10-01).
        if let place = turn.setupChecked {
            NavigationLink(value: MouseRoute.place(place)) {
                sourceLabel(kind: String(localized: "I checked your app settings"), title: place.name, note: nil, icon: "gearshape.fill", tint: .gray)
            }
        }
        ForEach(turn.helpUsed) { article in
            NavigationLink(value: MouseRoute.help(article.id)) {
                sourceLabel(kind: String(localized: "From Help"), title: article.title, note: nil, icon: "book.fill", tint: .teal)
            }
        }
        ForEach(turn.guidesUsed) { guide in
            NavigationLink(value: MouseRoute.guide(guide.id, focusText: turn.guideFocus[guide.id])) {
                sourceLabel(
                    kind: turn.isNearMiss ? String(localized: "Closest match, a guide") : String(localized: "From a guide"), title: guide.title,
                    icon: "doc.text.fill", tint: ContentKind.resource.accentColor,
                    note: [Self.posted(guide.createdAt),
                           turn.versionNotes["guide-\(guide.id)"] ?? (AskTheMouse.isOld(guide.updatedAt)
                               ? String(localized: "Last updated in \(String(Calendar.current.component(.year, from: guide.updatedAt))), so some steps may have changed.")
                               : nil)]
                        .compactMap { $0 }.joined(separator: " "))
            }
        }
        ForEach(turn.commentsUsedOn) { guide in
            NavigationLink(value: guide) {
                sourceLabel(kind: String(localized: "From members' comments on a guide"), title: guide.title, note: nil, icon: "person.2.fill", tint: ContentKind.resource.accentColor)
            }
        }
        ForEach(turn.forumsUsed) { topic in
            NavigationLink(value: topic) {
                sourceLabel(kind: turn.isNearMiss ? String(localized: "Closest match, a forum discussion") : String(localized: "From a forum discussion"),
                            title: topic.title, note: Self.posted(topic.createdAt), icon: "bubble.left.and.bubble.right.fill", tint: ContentKind.forumTopic.accentColor)
            }
        }
        // Known bugs, podcast episodes, and members' comments on an app.
        // Requested directly (2026-10-01).
        ForEach(turn.bugsUsed) { bug in
            NavigationLink(value: bug) {
                sourceLabel(kind: String(localized: "From the Bug Tracker"), title: bug.title,
                            note: bug.status == .active
                                ? String(localized: "Still active. Reported \(bug.createdAt.formatted(.dateTime.month(.wide).year())).")
                                : String(localized: "Fixed. Reported \(bug.createdAt.formatted(.dateTime.month(.wide).year()))."),
                            icon: "ant.fill", tint: ContentKind.bugReport.accentColor)
            }
        }
        ForEach(turn.podcastsUsed) { episode in
            NavigationLink(value: episode) {
                sourceLabel(kind: String(localized: "From a podcast episode"), title: episode.title,
                            note: Self.posted(episode.publishedAt), icon: "headphones", tint: ContentKind.podcastEpisode.accentColor)
            }
        }
        ForEach(turn.blogsUsed) { post in
            NavigationLink(value: post) {
                sourceLabel(kind: String(localized: "From the AppleVis blog"), title: post.title,
                            note: Self.posted(post.publishedAt), icon: "newspaper.fill", tint: ContentKind.blogPost.accentColor)
            }
        }
        ForEach(turn.appCommentsUsedOn) { app in
            NavigationLink(value: app) {
                sourceLabel(kind: String(localized: "From members' comments on an app entry"), title: app.name,
                            note: nil, icon: "person.2.fill", tint: ContentKind.appListing.accentColor)
            }
        }
        ForEach(turn.notesUsed) { note in
            if note.id.hasPrefix("whatsnew:") {
                NavigationLink(value: MouseRoute.whatsNew) {
                    sourceLabel(kind: String(localized: "From \(note.source)"), title: note.title, note: nil, icon: "sparkles", tint: .orange)
                }
            } else {
                sourceLabel(kind: String(localized: "From a tip"), title: note.title, note: nil, icon: "lightbulb.fill", tint: .yellow)
                    .accessibilityElement(children: .combine)
            }
        }
    }

    private func sourceLabel(kind: String, title: String, icon: String = "doc.fill", tint: Color = .accentColor, note: String?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Which kind of source, at a glance. Decorative: the words say it.
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(tint)
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func sourceLabel(kind: String, title: String, note: String?, icon: String, tint: Color) -> some View {
        sourceLabel(kind: kind, title: title, icon: icon, tint: tint, note: note)
    }

    @ViewBuilder
    private func actionRows(_ turn: MouseTurn) -> some View {
        if let mouseSwitch = turn.switchOffer {
            switchRows(turn, mouseSwitch)
        }
        if let place = turn.place {
            Button {
                open(place)
            } label: {
                Label(String(localized: "Take Me There: \(place.name)"), systemImage: "arrow.right.circle")
            }
        }
    }

    /// Questions you might ask next, written by Apple Intelligence from the
    /// answer's subject. Choosing one asks it as a follow-up, so there's
    /// nothing to type. Only on the latest answer. Requested directly
    /// (2026-09-29).
    @ViewBuilder
    private func followUpRows(_ turn: MouseTurn) -> some View {
        if !turn.followUps.isEmpty, turn.id == mouse.turns.first?.id, !mouse.isBusy {
            Text("You Might Also Ask")
                .font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            ForEach(turn.followUps, id: \.self) { followUp in
                Button {
                    question = followUp
                    ask()
                } label: {
                    Label(followUp, systemImage: "arrow.turn.down.right")
                }
                .accessibilityHint(String(localized: "Asks this as a follow-up."))
            }
        }
    }

    @ViewBuilder
    private func switchRows(_ turn: MouseTurn, _ mouseSwitch: MouseSwitch) -> some View {
        let isOn = preferences[keyPath: mouseSwitch.keyPath]
        switch turn.switchDone {
        case nil:
            if isOn == turn.switchTurnOn {
                Text(isOn
                     ? String(localized: "\(mouseSwitch.name) is already on.")
                     : String(localized: "\(mouseSwitch.name) is already off."))
            } else {
                Text(turn.switchTurnOn
                     ? String(localized: "Want me to turn on \(mouseSwitch.name)?")
                     : String(localized: "Want me to turn off \(mouseSwitch.name)?"))
                Button(turn.switchTurnOn ? String(localized: "Yes, Turn It On") : String(localized: "Yes, Turn It Off")) {
                    preferences[keyPath: mouseSwitch.keyPath] = turn.switchTurnOn
                    mouse.recordSwitch(turn.id, done: true)
                    UIAccessibility.post(notification: .announcement, argument: turn.switchTurnOn
                        ? String(localized: "Done. \(mouseSwitch.name) is now on.")
                        : String(localized: "Done. \(mouseSwitch.name) is now off."))
                }
                Button(String(localized: "No Thanks")) {
                    mouse.recordSwitch(turn.id, done: false)
                }
            }
        case true?:
            Text(isOn
                 ? String(localized: "Done. \(mouseSwitch.name) is now on. You can change it back in \(mouseSwitch.place.name).")
                 : String(localized: "Done. \(mouseSwitch.name) is now off. You can change it back in \(mouseSwitch.place.name)."))
            Button(String(localized: "Undo")) {
                preferences[keyPath: mouseSwitch.keyPath] = !turn.switchTurnOn
                mouse.recordSwitch(turn.id, done: false)
                UIAccessibility.post(notification: .announcement, argument: String(localized: "Changed back."))
            }
        case false?:
            Text("OK, I've left it as it is.")
        }
    }

    // MARK: - Apps

    @ViewBuilder
    private func appSections(_ turn: MouseTurn) -> some View {
        if !turn.mainApps.isEmpty {
            Section(turn.mainHeading ?? String(localized: "Apps")) {
                ForEach(turn.mainApps) { appRow($0) }
            }
        }
        if !turn.relatedApps.isEmpty {
            Section {
                ForEach(turn.relatedApps) { appRow($0) }
            } header: {
                Text(turn.relatedHeading ?? String(localized: "Related Apps"))
            } footer: {
                Text("From the App Directory. Open an app to read what members say about it.")
            }
        } else if !turn.mainApps.isEmpty {
            Section {
                EmptyView()
            } footer: {
                Text("From the App Directory. Open an app to read what members say about it.")
            }
        }
    }

    private func appRow(_ picked: MouseTurn.PickedApp) -> some View {
        appRowLink(picked)
            // The same Save, Share, and other actions app entries have
            // everywhere else. Requested directly (2026-09-28).
            .contentActions(
                id: picked.app.id, entityId: picked.app.nid ?? 0, kind: .appListing, title: picked.app.name,
                lastActivityAt: picked.app.lastActivityAt, url: picked.app.url
            )
    }

    private func appRowLink(_ picked: MouseTurn.PickedApp) -> some View {
        NavigationLink(value: picked.app) {
            VStack(alignment: .leading, spacing: 4) {
                Text(picked.app.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if !picked.blurb.isEmpty {
                    Text(picked.blurb)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !picked.app.price.isEmpty {
                    Text(picked.app.price)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                // Honors and popularity: the community's own picks, and how
                // much members have to say. Requested directly (2026-10-01).
                if let honor = picked.honor {
                    Label(honor, systemImage: "trophy.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let line = Self.popularityLine(picked) {
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Other sources that answer it

    /// A result that answered the question, for Other Sources.
    private enum OtherSource: Identifiable {
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
    }

    /// Every result with its own answer, newest first. Requested directly
    /// (2026-10-01): the answer, its source, then other sources, saying
    /// whether each agrees.
    private func otherSources(_ turn: MouseTurn) -> [OtherSource] {
        var list: [OtherSource] = []
        list += turn.moreGuides.filter { turn.resultNotes[$0.id] != nil }.map(OtherSource.guide)
        list += turn.forums.filter { turn.resultNotes[$0.id] != nil }.map(OtherSource.forum)
        list += turn.blogs.filter { turn.resultNotes[$0.id] != nil }.map(OtherSource.blog)
        list += turn.podcasts.filter { turn.resultNotes[$0.id] != nil }.map(OtherSource.podcast)
        list += turn.bugs.filter { turn.resultNotes[$0.id] != nil }.map(OtherSource.bug)
        return list.sorted { (turn.resultNotes[$0.id]?.date ?? .distantPast) > (turn.resultNotes[$1.id]?.date ?? .distantPast) }
    }

    @ViewBuilder
    private func otherSourcesSection(_ turn: MouseTurn) -> some View {
        let sources = otherSources(turn)
        if !sources.isEmpty {
            Section {
                ForEach(sources) { source in
                    otherSourceRow(source, turn: turn)
                }
            } header: {
                Text(turn.answered && !turn.isNearMiss ? String(localized: "Other Sources, Newest First") : String(localized: "What I Found, Newest First"))
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }

    @ViewBuilder
    private func otherSourceRow(_ source: OtherSource, turn: MouseTurn) -> some View {
        let note = turn.resultNotes[source.id]
        switch source {
        case .guide(let guide):
            resultRow(kind: String(localized: "Guide"), icon: "doc.text.fill", tint: ContentKind.resource.accentColor, title: guide.title, note: note,
                      route: MouseRoute.guide(guide.id, focusText: turn.guideFocus[guide.id]))
                .contentActions(id: guide.id, entityId: guide.nid ?? 0, kind: .resource, title: guide.title, url: guide.url)
        case .forum(let topic):
            resultRow(kind: String(localized: "Forum Topic"), icon: "bubble.left.and.bubble.right.fill", tint: ContentKind.forumTopic.accentColor, title: topic.title, note: note, route: topic)
                .contentActions(id: topic.id, entityId: topic.nid ?? 0, kind: .forumTopic, title: topic.title, url: topic.url)
        case .blog(let post):
            resultRow(kind: String(localized: "Blog Post"), icon: "newspaper.fill", tint: ContentKind.blogPost.accentColor, title: post.title, note: note, route: post)
                .contentActions(id: post.id, entityId: post.nid ?? 0, kind: .blogPost, title: post.title, url: post.url)
        case .podcast(let episode):
            resultRow(kind: String(localized: "Podcast Episode"), icon: "headphones", tint: ContentKind.podcastEpisode.accentColor, title: episode.title, note: note, route: episode)
                .contentActions(id: episode.id, entityId: episode.nid, kind: .podcastEpisode, title: episode.title, url: episode.url)
        case .bug(let bug):
            resultRow(kind: String(localized: "Bug Report"), icon: "ant.fill", tint: ContentKind.bugReport.accentColor, title: bug.title, note: note, route: bug)
        }
    }

    /// "Posted March 2017."
    static func posted(_ date: Date) -> String {
        String(localized: "Posted \(date.formatted(.dateTime.month(.wide).year())).")
    }

    /// "Recommended by 12 members. 14 member comments."
    static func popularityLine(_ picked: MouseTurn.PickedApp) -> String? {
        var parts: [String] = []
        if let count = picked.recommendations, count > 0 {
            parts.append(String(localized: "Recommended by \(count) members."))
        }
        if picked.app.reviewCount > 0 {
            parts.append(String(localized: "\(picked.app.reviewCount) member comments."))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    // MARK: - Everything else it found

    @ViewBuilder
    private func moreSection(_ turn: MouseTurn) -> some View {
        // Results with their own answer are in Other Sources; once the
        // Mouse has read them, only the rest stay here.
        let unanswered: (String) -> Bool = { turn.resultNotes[$0] == nil }
        let hasMore = turn.moreGuides.contains { unanswered($0.id) } || turn.forums.contains { unanswered($0.id) }
            || turn.podcasts.contains { unanswered($0.id) } || turn.blogs.contains { unanswered($0.id) }
            || turn.bugs.contains { unanswered($0.id) } || !turn.otherApps.isEmpty || !turn.saved.isEmpty
        if hasMore {
            Section {
                ForEach(turn.saved) { item in
                    NavigationLink(value: MouseRoute.saved(item.kind, item.id)) {
                        sourceLabel(kind: String(localized: "Saved \(item.kind.displayName)"), title: item.title, note: nil)
                    }
                }
                // Groups that have helped most come first.
                ForEach(MouseFeedback.groupOrder(), id: \.self) { group in
                    switch group {
                    case "guide":
                        ForEach(turn.moreGuides.filter { unanswered($0.id) }) { guide in
                            resultRow(kind: String(localized: "Guide"), icon: "doc.text.fill", tint: ContentKind.resource.accentColor, title: guide.title, note: turn.resultNotes[guide.id],
                                      route: MouseRoute.guide(guide.id, focusText: turn.guideFocus[guide.id]))
                                .contentActions(id: guide.id, entityId: guide.nid ?? 0, kind: .resource, title: guide.title, url: guide.url)
                        }
                    case "forum":
                        ForEach(turn.forums.filter { unanswered($0.id) }) { topic in
                            resultRow(kind: String(localized: "Forum Topic"), icon: "bubble.left.and.bubble.right.fill", tint: ContentKind.forumTopic.accentColor, title: topic.title, note: turn.resultNotes[topic.id], route: topic)
                                .contentActions(id: topic.id, entityId: topic.nid ?? 0, kind: .forumTopic, title: topic.title, url: topic.url)
                        }
                    case "blog":
                        ForEach(turn.blogs.filter { unanswered($0.id) }) { post in
                            resultRow(kind: String(localized: "Blog Post"), icon: "newspaper.fill", tint: ContentKind.blogPost.accentColor, title: post.title, note: turn.resultNotes[post.id], route: post)
                                .contentActions(id: post.id, entityId: post.nid ?? 0, kind: .blogPost, title: post.title, url: post.url)
                        }
                    case "podcast":
                        ForEach(turn.podcasts.filter { unanswered($0.id) }) { episode in
                            resultRow(kind: String(localized: "Podcast Episode"), icon: "headphones", tint: ContentKind.podcastEpisode.accentColor, title: episode.title, note: turn.resultNotes[episode.id], route: episode)
                                .contentActions(id: episode.id, entityId: episode.nid, kind: .podcastEpisode, title: episode.title, url: episode.url)
                        }
                    default:
                        EmptyView()
                    }
                }
                ForEach(turn.otherApps) { AppListingRow(app: $0) }
                ForEach(turn.bugs.filter { unanswered($0.id) }) { bug in
                    resultRow(kind: String(localized: "Bug Report"), icon: "ant.fill", tint: ContentKind.bugReport.accentColor, title: bug.title, note: turn.resultNotes[bug.id], route: bug)
                }
            } header: {
                // Changes while the Mouse reads each result for a line.
                Text(turn.isReadingResults
                     ? String(localized: "More From AppleVis. The Mouse is reading these…")
                     : String(localized: "More From AppleVis"))
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }

    /// "Says the same: " or "Says something different: " before a result's
    /// line, when there's an answer to compare it with.
    static func agreementPrefix(_ note: MouseTurn.ResultNote) -> String {
        switch note.agreement {
        case .same?: return String(localized: "Says the same:") + " "
        case .different?: return String(localized: "Says something different:") + " "
        case nil: return ""
        }
    }

    /// A result with its own answer: what that page says about the
    /// question, in the Mouse's words or, failing that, the page's own
    /// best sentence in quotes. Requested directly (2026-09-29).
    private func resultRow<Route: Hashable>(kind: String, icon: String, tint: Color, title: String, note: MouseTurn.ResultNote?, route: Route) -> some View {
        NavigationLink(value: route) {
            HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(tint)
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(kind)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if let note {
                    Text(Self.agreementPrefix(note) + (note.isQuote ? "\u{201C}\(note.line)\u{201D}" : note.line))
                        .font(.subheadline)
                    if let date = note.date {
                        Text(Self.posted(date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !note.alsoIn.isEmpty {
                        Text(String(localized: "Also in: \(ListFormatter.localizedString(byJoining: note.alsoIn))"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let versionNote = note.versionNote {
                        Text(versionNote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Did this answer your question?

    @ViewBuilder
    private func feedbackRows(_ turn: MouseTurn) -> some View {
        switch turn.feedback {
        case nil:
            Text("Did this answer your question?")
                .font(.subheadline)
            Button {
                mouse.recordFeedback(turn.id, helpful: true)
                UIAccessibility.post(notification: .announcement, argument: String(localized: "Thanks. Glad it helped."))
            } label: {
                Label(String(localized: "Yes, It Did"), systemImage: "hand.thumbsup")
            }
            Button {
                mouse.recordFeedback(turn.id, helpful: false)
                UIAccessibility.post(notification: .announcement, argument: String(localized: "Thanks for letting me know. The community might be able to help."))
                Task { await retryAccessibilityFocus(.needMore(turn.id), into: $focus, delaysMs: [900, 1300, 1800]) }
            } label: {
                Label(String(localized: "No, It Didn't"), systemImage: "hand.thumbsdown")
            }
            .accessibilityHint(String(localized: "Moves to Need More Help?, where you can ask the community."))
        case true?:
            HStack(spacing: 8) {
                MouseMascotView(pose: .celebrating, size: 36, style: .face)
                    .modifier(CharacterHop(trigger: hop))
                Image(systemName: "sparkles")
                    .foregroundStyle(.yellow)
                    .symbolEffect(.bounce, value: hop)
                    .accessibilityHidden(true)
                Text("Thanks for letting me know.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .onAppear { hop += 1 }
        case false?:
            Text("Thanks for letting me know. Try Ask in the Forums below.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Not what you needed? AppleVis is a community, so the next step is
    /// asking it, not the editorial team. Requested directly.
    private func communitySection(_ turn: MouseTurn) -> some View {
        Section {
            // Apple's own page on the subject, when one covers it: a plain
            // link the person reads themselves. Requested directly
            // (2026-10-01).
            if let link = turn.appleLink {
                Button {
                    openLink(link.url)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(link.label, systemImage: link.provider == .apple ? "apple.logo" : "arrow.up.forward.square")
                        Text(String(localized: "From \(link.providerName), not AppleVis"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            // A page from Apple's user guides, when none of the hand-picked
            // ones fits. Requested directly (2026-10-01).
            if let entry = turn.catalogLink, let url = entry.url {
                Button {
                    openLink(url)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(String(localized: "Apple's Guide: \(entry.label)"), systemImage: "apple.logo")
                        Text(String(localized: "From \("Apple Support"), not AppleVis"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            // Apple's own search, for any Apple question, so there's always
            // an Apple path even when no hand-picked page fits.
            if turn.isAppleTopic, !turn.isOffTopic,
               let url = MouseAppleLink.appleSupportSearch(turn.webQuery.isEmpty ? turn.question : turn.webQuery) {
                let query = turn.webQuery.isEmpty ? turn.question : turn.webQuery
                Button {
                    openLink(url)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(String(localized: "Search Apple Support"), systemImage: "apple.logo")
                        Text(String(localized: "Searches for: \(query)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
                .accessibilityHint(String(localized: "Opens Apple Support's own search. These results are from Apple, not AppleVis."))
            }
            // Sends just the question to the editorial team when the Mouse
            // couldn't answer it well, so missing guides get written.
            // Signed-in members only, and only when they choose to.
            // Requested directly (2026-10-01).
            if !turn.isOffTopic, auth.user?.email != nil,
               !turn.answered || turn.isNearMiss || turn.feedback == false {
                if suggestedTurns.contains(turn.id) {
                    Label(String(localized: "Suggested. Thank you!"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        suggestTopic(turn)
                    } label: {
                        Label(suggestingTurn == turn.id ? String(localized: "Sending…") : String(localized: "Suggest This Topic to AppleVis"),
                              systemImage: "lightbulb")
                    }
                    .disabled(suggestingTurn != nil)
                    .accessibilityHint(String(localized: "Sends your question to the AppleVis editorial team, so they know a guide is needed. Only your question, name, and email are sent."))
                }
            }
            // Not offered for an off-topic question: the forums are for
            // Apple and accessibility.
            if !turn.isOffTopic {
                Button {
                    forumQuestion = ForumQuestion(text: turn.question)
                } label: {
                    Label(String(localized: "Ask in the Forums"), systemImage: "bubble.left.and.bubble.right")
                }
                .accessibilityHint(String(localized: "Starts a new forum topic with your question filled in."))
            }
            // A sharper search than the question as typed, when Apple
            // Intelligence wrote one, and it says what it will search for.
            let webQuery = turn.webQuery.isEmpty ? turn.question : turn.webQuery
            Button {
                searchTheWeb(webQuery)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Label(String(localized: "Search the Web"), systemImage: "globe")
                    Text(String(localized: "Searches for: \(webQuery)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
            .accessibilityHint(String(localized: "Opens \(preferences.webSearchEngine.displayName). These results aren't from AppleVis."))
        } header: {
            // A heading, so the Headings rotor reaches these straight from
            // the answer. Requested directly (2026-09-28).
            Text("Need More Help?")
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focus, equals: .needMore(turn.id))
        } footer: {
            if turn.answered {
                Text("Not quite what you needed? The AppleVis community is happy to help.")
            }
        }
    }

    // MARK: - Asking

    private func ask() {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !mouse.isBusy else { return }
        isFieldFocused = false
        searchStartedAt = Date()
        question = ""
        wasShortened = false
        mouse.ask(text)
        UIAccessibility.post(notification: .announcement, argument: String(localized: "The Mouse is searching."))
    }

    /// Speaks progress only once a search has run for a few seconds, and
    /// then only when the step changes, so it isn't chatty. When it's done,
    /// a sound, a tap, and VoiceOver moves to the answer.
    private func searchStepChanged(from oldStep: MouseTurn.Step?, to newStep: MouseTurn.Step?) {
        if let newStep, let started = searchStartedAt, Date().timeIntervalSince(started) > 3 {
            UIAccessibility.post(notification: .announcement, argument: newStep.status)
        }
        guard oldStep != nil, newStep == nil, let turn = mouse.turns.first else { return }
        searchStartedAt = nil
        SoundPlayer.shared.play(.searchComplete)
        if preferences.hapticsEnabled, turn.answered {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        let target = answerFocus(turn)
        Task { await retryAccessibilityFocus(target, into: $focus) }
    }

    private func suggestTopic(_ turn: MouseTurn) {
        guard let user = auth.user, let email = user.email, suggestingTurn == nil else { return }
        suggestingTurn = turn.id
        let outcome: MouseGapReporter.Outcome = turn.feedback == false ? .notHelpful : turn.isNearMiss ? .nearMiss : .notFound
        let titles = sources(for: turn).map { "\($0.kindLabel): \($0.title)" }
        Task {
            let ok = await MouseGapReporter.report(question: turn.question, outcome: outcome, sourceTitles: titles,
                                                   reporterName: user.name, reporterEmail: email)
            suggestingTurn = nil
            if ok {
                suggestedTurns.insert(turn.id)
                SoundPlayer.shared.play(.success)
                UIAccessibility.post(notification: .announcement, argument: String(localized: "Suggested. Thank you! The editorial team will see your question."))
            } else {
                UIAccessibility.post(notification: .announcement, argument: String(localized: "Couldn't send that. Try again."))
            }
        }
    }

    private func searchTheWeb(_ text: String) {
        // The engine chosen in Settings > General > Web Search.
        guard let url = preferences.webSearchEngine.searchURL(for: text) else { return }
        openLink(url)
    }

    /// Opens a page the way Settings > General > Web Links says.
    private func openLink(_ url: URL) {
        switch preferences.webBrowsingMode {
        case .inApp: webSearch = WebSearch(url: url)
        case .external: UIApplication.shared.open(url)
        }
    }

    // MARK: - Places

    @State private var pushedPlace: MousePlace?

    private func open(_ place: MousePlace) {
        if place.opensAsSheet {
            sheetPlace = place
        } else {
            pushedPlace = place
        }
    }

    @ViewBuilder
    private func destination(for route: MouseRoute) -> some View {
        switch route {
        case .help(let id):
            if let article = MouseKnowledge.allHelpArticles.first(where: { $0.id == id }) {
                HelpArticleDetailView(article: article)
            }
        case .guide(let id, let focusText):
            ResourceDetailView(resourceId: id, focusText: focusText)
        case .whatsNew:
            WhatsNewView()
        case .place(let place):
            placeView(place)
        case .saved(let kind, let id):
            switch kind {
            case .forumTopic: ForumTopicDetailView(topicId: id)
            case .podcastEpisode: EpisodeDetailView(episodeId: id)
            case .appListing: AppDetailView(appId: id)
            case .resource: ResourceDetailView(resourceId: id)
            case .blogPost: BlogDetailView(postId: id)
            case .bugReport: BugDetailView(bugId: id)
            }
        case .aboutMe:
            MouseAboutMeView()
        case .pastConversations:
            MousePastConversationsView(mouse: mouse)
        case .conversation(let id):
            MouseConversationView(conversationId: id, mouse: mouse, onContinue: continueConversation)
        }
    }

    @ViewBuilder
    private func placeView(_ place: MousePlace) -> some View {
        switch place {
        case .generalSettings: GeneralSettingsView()
        case .appearanceSettings: AppearanceSettingsView()
        case .accessibilitySettings: AccessibilitySettingsView()
        case .notificationSettings: NotificationSettingsView()
        case .soundsHapticsSettings: SoundsHapticsSettingsView()
        case .homeFeedSettings: HomeFeedSettingsView()
        case .podcastSettings: PodcastSettingsView()
        case .savedSyncSettings: SavedSyncSettingsView()
        case .privacySettings: PrivacySettingsView()
        case .intelligenceSettings: IntelligenceSettingsView()
        case .contentTranslationSettings: ContentTranslationSettingsView()
        case .siriSettings: SiriShortcutsSettingsView()
        case .storageSettings: StorageView()
        case .whatsNew: WhatsNewView()
        case .savedItems: SavedItemsView(initialFilter: nil)
        case .newTopic, .submitApp, .submitBlog, .submitBug, .submitPodcast, .welcomeTour:
            // Opened as sheets instead (see `open(_:)`).
            EmptyView()
        }
    }

    @ViewBuilder
    private func sheet(for place: MousePlace) -> some View {
        switch place {
        case .newTopic: ComposeTopicView()
        case .submitApp: SubmitAppView()
        case .submitBlog: SubmitBlogView()
        case .submitBug: SubmitBugView()
        case .submitPodcast: SubmitPodcastView()
        case .welcomeTour: GuidedExperienceView(experience: GuidedExperienceRegistry.welcome)
        default: EmptyView()
        }
    }
}

/// The Mouse scurrying back and forth while it searches. With Reduce
/// Motion on it sits still beside a spinner. VoiceOver hears the status.
private struct MouseSearchingRow: View {
    let status: String
    /// What the Mouse holds for this step.
    let prop: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scurry = false

    var body: some View {
        HStack(spacing: 12) {
            MouseMascotView(pose: .holding(prop), size: 40, style: .face)
                .offset(x: reduceMotion ? 0 : (scurry ? 26 : -2))
                .frame(width: 72, alignment: .leading)
            Text(status)
                .font(.subheadline)
            Spacer(minLength: 0)
            ProgressView()
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { scurry = true }
        }
    }
}

/// What you can do with an answer: in the VoiceOver Actions rotor (swipe
/// up or down on the answer) and the touch-and-hold menu. Requested
/// directly (2026-09-28).
private struct AnswerActions: ViewModifier {
    let hasAnswer: Bool
    let isSaved: Bool
    let hasSource: Bool
    let copyAnswer: () -> Void
    let copyWithSources: () -> Void
    let share: () -> Void
    let openSource: () -> Void
    let toggleSave: () -> Void
    let followUp: () -> Void
    let askForums: () -> Void

    func body(content: Content) -> some View {
        if hasAnswer {
            content
                .accessibilityAction(named: Text("Copy Answer"), copyAnswer)
                .accessibilityAction(named: Text("Copy Answer with Sources"), copyWithSources)
                .accessibilityAction(named: Text("Share Answer"), share)
                .modifier(ConditionalAccessibilityAction(isActive: hasSource, name: "Open Source") { openSource() })
                .accessibilityAction(named: isSaved ? Text("Unsave Answer") : Text("Save Answer"), toggleSave)
                .accessibilityAction(named: Text("Ask a Follow-Up"), followUp)
                .accessibilityAction(named: Text("Ask in the Forums"), askForums)
                .contextMenu {
                    Button(action: copyAnswer) { Label("Copy Answer", systemImage: "doc.on.doc") }
                    Button(action: copyWithSources) { Label("Copy Answer with Sources", systemImage: "doc.on.clipboard") }
                    Button(action: share) { Label("Share Answer", systemImage: "square.and.arrow.up") }
                    if hasSource {
                        Button(action: openSource) { Label("Open Source", systemImage: "arrow.up.forward.square") }
                    }
                    Button(action: toggleSave) {
                        if isSaved {
                            Label("Unsave Answer", systemImage: "bookmark.slash")
                        } else {
                            Label("Save Answer", systemImage: "bookmark")
                        }
                    }
                    Button(action: followUp) { Label("Ask a Follow-Up", systemImage: "text.bubble") }
                    Button(action: askForums) { Label("Ask in the Forums", systemImage: "bubble.left.and.bubble.right") }
                }
        } else {
            content
                .accessibilityAction(named: Text("Ask a Follow-Up"), followUp)
                .accessibilityAction(named: Text("Ask in the Forums"), askForums)
        }
    }
}

/// The answer in a soft speech bubble with the Mouse beside it, so it reads
/// like the Mouse talking. When nothing was found, the Mouse shrugs with a
/// question mark. Purely visual; VoiceOver reads the text as before.
/// Requested directly (2026-09-29).
private struct AnswerBubble: ViewModifier {
    let showsMouse: Bool
    let isEmpty: Bool

    func body(content: Content) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if showsMouse {
                MouseMascotView(pose: isEmpty ? .holding("questionmark") : .plain, size: 32, style: .face)
            } else {
                Color.clear.frame(width: 32, height: 1).accessibilityHidden(true)
            }
            content
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.accentColor.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                )
        }
        .accessibilityElement(children: .combine)
    }
}

extension MouseTurn.Step {
    /// What the Mouse holds while on this step.
    var prop: String {
        switch self {
        case .thinking: return "lightbulb.fill"
        case .help: return "book.fill"
        case .guides: return "newspaper.fill"
        case .apps: return "square.grid.2x2.fill"
        case .forums: return "bubble.left.and.bubble.right.fill"
        case .writing: return "pencil"
        case .closerLook: return "text.magnifyingglass"
        }
    }
}
