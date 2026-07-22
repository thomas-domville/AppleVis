import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var player: PlayerStore

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.items.isEmpty {
                    LoadingView()
                } else if let error = vm.error, vm.items.isEmpty {
                    ErrorView(message: error) { await vm.load() }
                } else {
                    feedList
                }
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    filterMenu
                }
            }
            .refreshable { await vm.load() }
            .overlay(alignment: .top) { ToastOverlay() }
        }
        .task { await vm.load() }
    }

    // MARK: - Feed list

    private var feedList: some View {
        List {
            if !vm.newActivitySummary.isEmpty {
                Section {
                    Text(vm.newActivitySummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(vm.items) { item in
                FeedRow(item: item)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if vm.hasMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .task { await vm.loadMore() }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Filter menu

    private var filterMenu: some View {
        Menu {
            Section("Content Types") {
                Toggle("Forums", isOn: $preferences.showForums)
                Toggle("Podcasts", isOn: $preferences.showPodcasts)
                Toggle("Apps", isOn: $preferences.showApps)
                Toggle("Guides", isOn: $preferences.showGuides)
                Toggle("Blogs", isOn: $preferences.showBlogs)
            }
            Section("Forums") {
                Toggle("Apple Topics Only", isOn: $preferences.appleOnlyForums)
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .accessibilityLabel("Filter feed")
        }
        .onChange(of: preferences.showForums)   { _, _ in Task { await vm.load() } }
        .onChange(of: preferences.showPodcasts) { _, _ in Task { await vm.load() } }
        .onChange(of: preferences.showApps)     { _, _ in Task { await vm.load() } }
        .onChange(of: preferences.showGuides)   { _, _ in Task { await vm.load() } }
        .onChange(of: preferences.showBlogs)    { _, _ in Task { await vm.load() } }
    }
}

// MARK: - Feed row

struct FeedRow: View {
    let item: FeedItem

    var body: some View {
        Group {
            switch item {
            case .forumTopic(let t):     ForumTopicRow(topic: t)
            case .podcastEpisode(let e): PodcastEpisodeRow(episode: e)
            case .appListing(let a):     AppListingRow(app: a)
            case .resource(let r):       ResourceRow(resource: r)
            case .blogPost(let b):       BlogPostRow(post: b)
            }
        }
        .unreadIndicator(item.isUnread)
    }
}
