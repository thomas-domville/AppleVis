import SwiftUI

struct BlogBrowseView: View {
    @State private var posts: [BlogPost] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var page = 0
    @State private var hasMore = false
    @State private var searchText = ""
    @State private var isLoadingMore = false
    @ObservedObject private var networkStatus = NetworkStatusStore.shared

    var body: some View {
        Group {
            if isLoading && posts.isEmpty {
                LoadingView()
            } else if let error, posts.isEmpty {
                ErrorView(message: error) { await load(reset: true) }
            } else {
                postList
            }
        }
        .navigationTitle("AppleVis Blog")
        .task { await load(reset: true) }
        .refreshable { await load(reset: true); SoundPlayer.shared.play(.refresh) }
        .searchable(text: $searchText, prompt: "Search posts")
    }

    private var visible: [BlogPost] {
        guard !searchText.isEmpty else { return posts }
        return posts.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.authorName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var postList: some View {
        List {
            if networkStatus.degradedGroups.contains(.blogs) {
                OfflineBanner()
                    .listRowSeparator(.hidden)
            }
            if !searchText.isEmpty && visible.isEmpty {
                EmptyStateView(
                    title: "No Results",
                    message: "No posts match \"\(searchText)\".",
                    systemImage: "magnifyingglass"
                )
                .listRowSeparator(.hidden)
            }

            ForEach(visible) { post in
                BlogPostRow(post: post, onDelete: { posts.removeAll { $0.id == post.id } })
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if hasMore && searchText.isEmpty {
                ProgressView().frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .task { await loadMore() }
            }

            if !posts.isEmpty && !hasMore && searchText.isEmpty {
                Text("\(posts.count) post\(posts.count == 1 ? "" : "s") loaded")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .accessibilityLabel("\(posts.count) posts loaded.")
            }
        }
        .listStyle(.plain)
    }

    private func load(reset: Bool) async {
        if reset { page = 0; posts = [] }
        isLoading = true; error = nil
        do {
            let fetched = try await APIClient.shared.blogs.list(page: page)
            posts = fetched
            hasMore = fetched.count >= APIPaging.pageSize
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Couldn't load posts." }
        isLoading = false
    }

    private func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        page += 1
        if let more = try? await APIClient.shared.blogs.list(page: page) {
            posts += more
            hasMore = more.count >= APIPaging.pageSize
        }
        isLoadingMore = false
    }
}
