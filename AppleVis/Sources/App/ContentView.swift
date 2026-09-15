import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @EnvironmentObject private var keyCommands: KeyCommandRouter
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var preferences: PreferencesStore
    @ObservedObject private var homeBadge = HomeBadgeStore.shared
    @State private var showTourPrompt = false
    @State private var showWelcomeTourFromPrompt = false
    @State private var showTranslatePrompt = false
    @State private var detectedLanguageCode: String?

    var body: some View {
        TabView(selection: $keyCommands.selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)
                .badge(homeBadge.unreadForumTopicCount)

            DiscoverView()
                .tabItem { Label("Discover", systemImage: "safari") }
                .tag(1)

            ForYouView()
                .tabItem { Label("For You", systemImage: "person.crop.circle") }
                .tag(2)
        }
        .onChange(of: keyCommands.selectedTab) { _, newTab in
            SoundPlayer.shared.play(.tabChange)
            // Double-tapping a tab bar item to switch to it doesn't
            // reliably re-announce the new selected state on this SDK's
            // TabView the way exploring back onto an already-selected
            // tab by touch does (that read comes for free from the
            // .isSelected trait; this doesn't). Reported directly: a
            // VoiceOver user double-tapping Discover heard only the
            // tab-change tone, with no confirmation it had switched.
            UIAccessibility.post(notification: .announcement, argument: String(localized: "\(tabName(for: newTab)) tab, selected."))
        }
        // Second attempt at this fix — the first (a `ZStack` sibling sized
        // via `VStack { Spacer(); content }`, matching how
        // GuidedExperienceResumeBanner pins its own floating bottom bar)
        // still let the mini player end up pinned to the top after leaving
        // a screen with its own `.safeAreaInset(edge: .bottom)`
        // (EpisodeDetailView's playback bar) — a ZStack sibling's Spacer-
        // based layout is computed independently of the TabView's actual
        // frame, and can end up resolving against stale/incorrect geometry
        // across a NavigationStack push/pop that changes the ambient safe
        // area. `.overlay(alignment: .bottom)` binds the mini player
        // directly to the TabView's own frame instead of to an independent
        // sibling computation, which removes that whole failure mode rather
        // than working around one specific trigger of it. Reported directly
        // — confirmed still broken after the first fix, so re-diagnosed
        // rather than assumed fixed.
        .overlay(alignment: .bottom) {
            if player.currentEpisode != nil {
                MiniPlayerView()
                    .transition(.move(edge: .bottom))
                    .padding(.bottom, 49) // above tab bar
            }
        }
        .animation(UIAccessibility.isReduceMotionEnabled ? nil : .spring(duration: 0.3), value: player.currentEpisode != nil)
        .sheet(item: Binding(
            get: { deepLinkRouter.pendingContent.map { DeepLinkContent(kind: $0.kind, id: $0.id) } },
            set: { if $0 == nil { closePendingContent() } }
        )) { content in
            NavigationStack {
                destination(for: content)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { closePendingContent() }
                                .accessibilityLabel("Close detail")
                        }
                    }
            }
        }
        // Externally-triggered web links (universal links, share-extension
        // hand-offs) previously always opened in-app regardless of the Web
        // Links preference — intercepted here before the sheet ever sees a
        // value, rather than inside SafariView, since this is the one
        // place a web link can arrive without going through WebLink at
        // all. Reported directly.
        .onChange(of: deepLinkRouter.pendingWebURL) { _, url in
            guard let url, preferences.webBrowsingMode == .external else { return }
            UIApplication.shared.open(url)
            deepLinkRouter.pendingWebURL = nil
        }
        .sheet(item: Binding(
            get: { deepLinkRouter.pendingWebURL.map { IdentifiableURL(url: $0) } },
            set: { if $0 == nil { deepLinkRouter.pendingWebURL = nil } }
        )) { wrapped in
            SafariView(url: wrapped.url)
        }
        .sheet(isPresented: $keyCommands.showSettings) {
            ProfileView()
        }
        .sheet(item: $deepLinkRouter.pendingSubmit) { submit in
            submitDestination(for: submit)
        }
        .sheet(item: $deepLinkRouter.pendingSiriDestination) { destination in
            siriDestination(for: destination)
        }
        .sheet(isPresented: $showWelcomeTourFromPrompt) {
            GuidedExperienceView(experience: GuidedExperienceRegistry.welcome)
        }
        .alert("Take a quick tour of AppleVis?", isPresented: $showTourPrompt) {
            Button("Start Tour") { showWelcomeTourFromPrompt = true }
            Button("Maybe Later", role: .cancel) {}
            Button("No Thanks") { GuidedExperienceStore.disableAutoPrompt() }
        } message: {
            Text("A tab-by-tab walkthrough of Home, Discover, For You, and Profile & Settings — go at your own pace, and skip or pause anytime.")
        }
        .alert(
            "AppleVis is written in English",
            isPresented: $showTranslatePrompt
        ) {
            Button("Turn On Auto-Translate") {
                guard let detectedLanguageCode else { return }
                preferences.autoTranslateEnabled = true
                preferences.contentLanguageCode = detectedLanguageCode
                preferences.contentTranslationPromptShown = true
                Task { await TranslationCoordinator.shared.prepareLanguagePack(for: detectedLanguageCode) }
            }
            Button("Not Now", role: .cancel) {
                preferences.contentTranslationPromptShown = true
            }
        } message: {
            Text("Our community spans people from all over the world, speaking many different languages — so we use English as AppleVis's one shared language, to keep everyone reading and talking together in the same place. It looks like your device is set to \(detectedLanguageDisplayName). Want AppleVis to automatically translate posts into \(detectedLanguageDisplayName) as you browse? You can turn this off anytime in Settings.")
        }
        .onAppear {
            offerWelcomeTourIfNeeded()
            offerContentTranslationPromptIfNeeded()
        }
    }

    private var detectedLanguageDisplayName: String {
        guard let detectedLanguageCode, let name = Locale.current.localizedString(forLanguageCode: detectedLanguageCode) else {
            return String(localized: "your language")
        }
        return name.localizedCapitalized
    }

    /// Mirrors the `.tabItem` labels above — kept as a plain switch rather
    /// than reading the label back out of the TabView, since there's no
    /// direct way to do that from an `.onChange(of: selection)` handler.
    private func tabName(for tab: Int) -> String {
        switch tab {
        case 0:  return String(localized: "Home")
        case 1:  return String(localized: "Discover")
        case 2:  return String(localized: "For You")
        default: return ""
        }
    }

    /// Matches RN's post-setup "Take a quick tour?" alert (app/onboarding/
    /// ready.tsx) — offered once, right after onboarding finishes, unless the
    /// user already completed/skipped the tour or opted out via "No Thanks."
    private func offerWelcomeTourIfNeeded() {
        guard auth.justCompletedOnboarding else { return }
        auth.justCompletedOnboarding = false
        let progress = GuidedExperienceStore.getProgress(GuidedExperienceRegistry.welcome.id)
        guard GuidedExperienceStore.autoPromptEnabled, !progress.completed, !progress.skipped else { return }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            showTourPrompt = true
        }
    }

    /// One-time, on-device check: does this device's preferred language
    /// differ from English, and can Apple's Translation framework actually
    /// do something about it? If so, offer auto-translate once — declining
    /// just marks it shown; Settings > Content Translation remains the
    /// permanent way to turn it on later. Guarded against firing in the
    /// same moment as the tour prompt (`auth.justCompletedOnboarding`,
    /// checked by `offerWelcomeTourIfNeeded()` above) since both are
    /// otherwise reachable from the same brand-new-user, non-English-device
    /// first launch.
    private func offerContentTranslationPromptIfNeeded() {
        guard !preferences.contentTranslationPromptShown,
              !preferences.autoTranslateEnabled,
              !auth.justCompletedOnboarding
        else { return }
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        guard languageCode != "en" else { return }
        Task {
            guard await TranslationCoordinator.availability(for: languageCode) != .unsupported else { return }
            try? await Task.sleep(for: .seconds(5))
            detectedLanguageCode = languageCode
            showTranslatePrompt = true
        }
    }

    private func closePendingContent() {
        deepLinkRouter.pendingContent = nil
        deepLinkRouter.pendingContentIntent = nil
    }

    @ViewBuilder
    private func submitDestination(for submit: PendingSubmit) -> some View {
        switch submit {
        case .app(let url): SubmitAppView(prefillAppStoreURL: url)
        case .blog(let text): SubmitBlogView(prefillText: text)
        case .podcast(let url): SubmitPodcastView(prefillSharedURL: url)
        case .podcastAudio(let data, let fileName): SubmitPodcastView(prefillAudioData: data, prefillAudioFileName: fileName)
        case .bug: SubmitBugView()
        }
    }

    @ViewBuilder
    private func siriDestination(for destination: SiriDestination) -> some View {
        switch destination {
        case .forums(let filter): NavigationStack { ForumsBrowseView(initialFilter: filter) }
        case .savedItems(let filter): NavigationStack { SavedItemsView(initialFilter: filter) }
        case .search(let query): DiscoverView(initialSearchQuery: query)
        }
    }

    @ViewBuilder
    private func destination(for content: DeepLinkContent) -> some View {
        let jumpToFirstNewComment = deepLinkRouter.pendingContentIntent == .firstNewComment
        switch content.kind {
        case .forumTopic:
            ForumTopicDetailView(topicId: content.id, focusFirstNewCommentOnAppear: jumpToFirstNewComment)
        case .podcastEpisode:
            EpisodeDetailView(episodeId: content.id, focusFirstNewCommentOnAppear: jumpToFirstNewComment)
        case .appListing:
            AppDetailView(appId: content.id, focusFirstNewCommentOnAppear: jumpToFirstNewComment)
        case .resource:
            ResourceDetailView(resourceId: content.id, focusFirstNewCommentOnAppear: jumpToFirstNewComment)
        case .blogPost:
            BlogDetailView(postId: content.id, focusFirstNewCommentOnAppear: jumpToFirstNewComment)
        case .bugReport:
            BugDetailView(bugId: content.id, focusFirstNewCommentOnAppear: jumpToFirstNewComment)
        }
    }
}

private struct DeepLinkContent: Identifiable {
    // Drupal JSON:API UUIDs are globally unique regardless of entity type,
    // so the raw content id alone is a safe Identifiable key here.
    let kind: ContentKind
    let id: String
}

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
