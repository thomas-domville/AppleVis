import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                HomeView()
                    .tabItem { Label("Home", systemImage: "house") }

                DiscoverView()
                    .tabItem { Label("Discover", systemImage: "safari") }

                ForYouView()
                    .tabItem { Label("For You", systemImage: "person.crop.circle") }

                ProfileView()
                    .tabItem { Label("Profile", systemImage: "person") }
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
