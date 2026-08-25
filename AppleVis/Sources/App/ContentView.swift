import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @EnvironmentObject private var keyCommands: KeyCommandRouter
    @EnvironmentObject private var auth: AuthStore
    @ObservedObject private var homeBadge = HomeBadgeStore.shared
    @State private var showTourPrompt = false
    @State private var showWelcomeTourFromPrompt = false

    var body: some View {
        ZStack {
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

            // `ZStack(alignment: .bottom)` sizing the mini player off the
            // TabView's own bounds was landing it at the top of the screen
            // instead of just above the tab bar. GuidedExperienceResumeBanner
            // pins its own floating bottom bar reliably with
            // `VStack { Spacer(); content }` instead, which forces the
            // container to full height and anchors content to the bottom
            // itself rather than depending on ZStack's alignment computation
            // against a sibling — matching that working pattern here.
            // Reported directly.
            VStack {
                Spacer()
                if player.currentEpisode != nil {
                    MiniPlayerView()
                        .transition(.move(edge: .bottom))
                        .padding(.bottom, 49) // above tab bar
                }
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
            Text("See a short, skippable walkthrough of Home, Discover, For You, Search, Profile, and Settings.")
        }
        .onAppear { offerWelcomeTourIfNeeded() }
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
