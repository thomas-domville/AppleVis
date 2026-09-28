import SwiftUI
import UIKit

/// Where a row inside Ask the Mouse leads.
enum MouseRoute: Hashable {
    case help(String)
    case whatsNew
    case place(MousePlace)
    case saved(ContentKind, String)
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
    @State private var searchStartedAt: Date?
    @State private var sheetPlace: MousePlace?
    @State private var forumQuestion: ForumQuestion?
    @State private var webSearch: WebSearch?
    @FocusState private var isFieldFocused: Bool
    @AccessibilityFocusState private var focus: MouseFocus?

    private enum MouseFocus: Hashable {
        case greeting
        case answer(UUID)
    }

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
        NavigationStack {
            List {
                introSection
                if IntelligenceService.isAvailable {
                    questionSection
                    if mouse.turns.isEmpty {
                        suggestionsSection
                        recentSection
                    }
                    ForEach(mouse.turns) { turn in
                        turnSections(turn)
                    }
                    if !mouse.turns.isEmpty, !mouse.isBusy {
                        Section {
                            Button(String(localized: "Start a New Conversation")) {
                                mouse.clearConversation()
                                question = ""
                                Task { await retryAccessibilityFocus(.greeting, into: $focus) }
                            }
                        } footer: {
                            Text("Follow-up questions use what you asked before. A new conversation starts fresh.")
                        }
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
                MouseMascotView(pose: .searching, size: 56, style: .face)
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
            Button {
                ask()
            } label: {
                Label(String(localized: "Ask"), systemImage: "arrow.up.circle.fill")
            }
            .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || mouse.isBusy)
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
                }
                Button(String(localized: "Clear Recent Questions"), role: .destructive) {
                    mouse.clearRecent()
                }
            } header: {
                Text("Recent Questions")
            } footer: {
                Text("Kept on this device only.")
            }
        }
    }

    // MARK: - One question and its answer

    @ViewBuilder
    private func turnSections(_ turn: MouseTurn) -> some View {
        Section {
            if let step = turn.step {
                MouseSearchingRow(status: step.status)
                Button(String(localized: "Stop"), role: .cancel) { mouse.stop() }
            } else {
                answerRow(turn)
                sourceRows(turn)
                actionRows(turn)
            }
        } header: {
            Text(turn.question)
                .textCase(nil)
                .accessibilityLabel(String(localized: "You asked: \(turn.question)"))
        }

        if turn.step == nil {
            appSections(turn)
            moreSection(turn)
            communitySection(turn)
        }
    }

    @ViewBuilder
    private func answerRow(_ turn: MouseTurn) -> some View {
        Group {
            if let answer = turn.answer {
                Text(answer)
            } else if let intro = turn.appsIntro, turn.answered {
                Text(intro)
            } else if turn.switchOffer != nil {
                Text("I can change that for you.")
            } else if turn.answered {
                Text("Here's what I found on AppleVis.")
            } else {
                Text("I couldn't find that on AppleVis. The community might know, so you could ask in the Forums.")
            }
        }
        .accessibilityFocused($focus, equals: .answer(turn.id))
    }

    @ViewBuilder
    private func sourceRows(_ turn: MouseTurn) -> some View {
        ForEach(turn.helpUsed) { article in
            NavigationLink(value: MouseRoute.help(article.id)) {
                sourceLabel(kind: String(localized: "From Help"), title: article.title, note: nil)
            }
        }
        ForEach(turn.guidesUsed) { guide in
            NavigationLink(value: guide) {
                sourceLabel(
                    kind: String(localized: "From a guide"), title: guide.title,
                    note: AskTheMouse.isOld(guide.updatedAt)
                        ? String(localized: "Last updated in \(String(Calendar.current.component(.year, from: guide.updatedAt))), so some steps may have changed.")
                        : nil)
            }
        }
        ForEach(turn.notesUsed) { note in
            if note.id.hasPrefix("whatsnew:") {
                NavigationLink(value: MouseRoute.whatsNew) {
                    sourceLabel(kind: String(localized: "From \(note.source)"), title: note.title, note: nil)
                }
            } else {
                sourceLabel(kind: String(localized: "From a tip"), title: note.title, note: nil)
                    .accessibilityElement(children: .combine)
            }
        }
    }

    private func sourceLabel(kind: String, title: String, note: String?) -> some View {
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
        .accessibilityElement(children: .combine)
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
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Everything else it found

    @ViewBuilder
    private func moreSection(_ turn: MouseTurn) -> some View {
        let hasMore = !turn.moreGuides.isEmpty || !turn.forums.isEmpty || !turn.podcasts.isEmpty
            || !turn.blogs.isEmpty || !turn.bugs.isEmpty || !turn.otherApps.isEmpty || !turn.saved.isEmpty
        if hasMore {
            Section(String(localized: "More From AppleVis")) {
                ForEach(turn.saved) { item in
                    NavigationLink(value: MouseRoute.saved(item.kind, item.id)) {
                        sourceLabel(kind: String(localized: "Saved \(item.kind.displayName)"), title: item.title, note: nil)
                    }
                }
                ForEach(turn.moreGuides) { ResourceRow(resource: $0) }
                ForEach(turn.otherApps) { AppListingRow(app: $0) }
                ForEach(turn.forums) { ForumTopicRow(topic: $0) }
                ForEach(turn.podcasts) { PodcastEpisodeRow(episode: $0) }
                ForEach(turn.blogs) { BlogPostRow(post: $0) }
                ForEach(turn.bugs) { bug in
                    NavigationLink(value: bug) { BugReportRow(bug: bug) }
                }
            }
        }
    }

    /// Not what you needed? AppleVis is a community, so the next step is
    /// asking it, not the editorial team. Requested directly.
    private func communitySection(_ turn: MouseTurn) -> some View {
        Section {
            Button {
                forumQuestion = ForumQuestion(text: turn.question)
            } label: {
                Label(String(localized: "Ask in the Forums"), systemImage: "bubble.left.and.bubble.right")
            }
            .accessibilityHint(String(localized: "Starts a new forum topic with your question filled in."))
            Button {
                searchTheWeb(turn.question)
            } label: {
                Label(String(localized: "Search the Web"), systemImage: "globe")
            }
            .accessibilityHint(String(localized: "Opens DuckDuckGo with your question. These results aren't from AppleVis."))
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
        Task { await retryAccessibilityFocus(.answer(turn.id), into: $focus) }
    }

    private func searchTheWeb(_ text: String) {
        var components = URLComponents(string: "https://duckduckgo.com/")!
        components.queryItems = [URLQueryItem(name: "q", value: text)]
        guard let url = components.url else { return }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scurry = false

    var body: some View {
        HStack(spacing: 12) {
            MouseMascotView(pose: .searching, size: 40, style: .face)
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
