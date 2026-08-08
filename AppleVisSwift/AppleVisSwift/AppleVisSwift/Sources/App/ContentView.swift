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
        ZStack(alignment: .bottom) {
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
            .onChange(of: keyCommands.selectedTab) { _, _ in
                SoundPlayer.shared.play(.tabChange)
            }

            if player.currentEpisode != nil {
                MiniPlayerView()
                    .transition(.move(edge: .bottom))
                    .padding(.bottom, 49) // above tab bar
            }
        }
        .animation(.spring(duration: 0.3), value: player.currentEpisode != nil)
        .sheet(item: Binding(
            get: { deepLinkRouter.pendingContent.map { DeepLinkContent(kind: $0.kind, id: $0.id) } },
            set: { if $0 == nil { deepLinkRouter.pendingContent = nil } }
        )) { content in
            NavigationStack { destination(for: content) }
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

    @ViewBuilder
    private func submitDestination(for submit: PendingSubmit) -> some View {
        switch submit {
        case .app(let url): SubmitAppView(prefillAppStoreURL: url)
        case .blog(let text): SubmitBlogView(prefillText: text)
        case .podcast(let url): SubmitPodcastView(prefillSharedURL: url)
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
        switch content.kind {
        case .forumTopic: ForumTopicDetailView(topicId: content.id)
        case .podcastEpisode: EpisodeDetailView(episodeId: content.id)
        case .appListing: AppDetailView(appId: content.id)
        case .resource: ResourceDetailView(resourceId: content.id)
        case .blogPost: BlogDetailView(postId: content.id)
        case .bugReport: BugDetailView(bugId: content.id)
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
