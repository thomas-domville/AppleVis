import SwiftUI

struct PodcastBrowseView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var toast: ToastStore
    @State private var episodes: [PodcastEpisode] = []
    @State private var tags: [PodcastTag] = []
    @State private var selectedTag: PodcastTag? = nil
    @State private var sort: PodcastSort = .recent
    @State private var isLoading = false
    @State private var error: String?
    @State private var page = 0
    @State private var hasMore = false
    @State private var isLoadingMore = false
    @ObservedObject private var networkStatus = NetworkStatusStore.shared

    var body: some View {
        Group {
            if isLoading && episodes.isEmpty {
                LoadingView(message: "Loading episodes…")
            } else if let error, episodes.isEmpty {
                ErrorView(message: error) { await load(reset: true) }
            } else if episodes.isEmpty {
                EmptyStateView(title: "No episodes yet", message: "Pull to refresh podcast episodes", systemImage: "mic")
            } else {
                episodeList
            }
        }
        .navigationTitle("Podcasts")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Section("Sort") {
                        Button("Recent") { sort = .recent; Task { await load(reset: true) } }
                        Button("Popular") { sort = .popular; Task { await load(reset: true) } }
                    }
                    if !tags.isEmpty {
                        Section("Filter by Show") {
                            Button("All Shows") { selectedTag = nil; Task { await load(reset: true) } }
                            ForEach(tags) { tag in
                                Button(tag.name) { selectedTag = tag; Task { await load(reset: true) } }
                            }
                        }
                    }
                } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
                    .accessibilityLabel(String(localized: "Filter podcasts"))
            }
        }
        .task { await load(reset: true) }
        .refreshable { await load(reset: true); SoundPlayer.shared.play(.refresh) }
    }

    private var episodeList: some View {
        List {
            if networkStatus.degradedGroups.contains(.podcasts) {
                OfflineBanner()
                    .listRowSeparator(.hidden)
            }
            ForEach(episodes) { episode in
                PodcastEpisodeRow(episode: episode, onDelete: { episodes.removeAll { $0.id == episode.id } })
            }
            if hasMore {
                ProgressView().frame(maxWidth: .infinity).accessibilityLabel(String(localized: "Loading more…"))
                    .task { await loadMore() }
            }
        }
        .listStyle(.plain)
        .themedList(preferences.colors)
    }

    private func load(reset: Bool) async {
        if reset { page = 0; episodes = [] }
        isLoading = true
        error = nil
        do {
            async let eps = APIClient.shared.podcasts.episodes(page: page, sort: sort, tagTid: selectedTag?.tid)
            async let tagList = tags.isEmpty ? APIClient.shared.podcasts.tags() : []
            let (fetched, fetchedTags) = try await (eps, tagList)
            episodes = fetched
            if !fetchedTags.isEmpty { tags = fetchedTags }
            hasMore = fetched.count >= APIPaging.pageSize
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Could not load episodes" }
        isLoading = false
    }

    private func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        do {
            let more = try await APIClient.shared.podcasts.episodes(page: page + 1, sort: sort, tagTid: selectedTag?.tid)
            page += 1
            episodes += more
            hasMore = more.count >= APIPaging.pageSize
        } catch {
            toast.error(String(localized: "Couldn't load more episodes."))
        }
        isLoadingMore = false
    }
}
