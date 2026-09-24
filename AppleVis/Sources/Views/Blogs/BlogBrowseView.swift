import SwiftUI

struct BlogBrowseView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var toast: ToastStore
    @State private var posts: [BlogPost] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var page = 0
    @State private var hasMore = false
    @State private var searchText = ""
    @State private var isLoadingMore = false
    @ObservedObject private var networkStatus = NetworkStatusStore.shared
    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        Group {
            if isLoading && posts.isEmpty {
                LoadingView()
            } else if let error, posts.isEmpty {
                ErrorView(message: error) { await load(reset: true) }
            } else if posts.isEmpty && searchText.isEmpty {
                // A legitimately empty successful load previously fell
                // through to a blank List — indistinguishable from a silent
                // failure, with no title, message, or retry (BLOGS-01).
                EmptyStateView(
                    title: "No Blog Posts",
                    message: "There are no blog posts to show right now.",
                    systemImage: "newspaper"
                )
            } else {
                postList
            }
        }
        .navigationTitle("AppleVis Blog")
        .task { await load(reset: true) }
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
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

            ForEach(Array(visible.enumerated()), id: \.element.id) { index, post in
                let row = BlogPostRow(post: post, onDelete: { posts.removeAll { $0.id == post.id } })
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                if index == 0 {
                    row.accessibilityFocused($isTitleFocused)
                } else {
                    row
                }
            }

            if hasMore && searchText.isEmpty {
                ProgressView().frame(maxWidth: .infinity).accessibilityLabel(String(localized: "Loading more…"))
                    .listRowSeparator(.hidden)
                    .task { await loadMore() }
            }

            if !posts.isEmpty && !hasMore && searchText.isEmpty {
                Text("Posts loaded: \(posts.count)")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .accessibilityLabel(String(localized: "\(posts.count) posts loaded."))
            }
        }
        .listStyle(.plain)
        .themedList(preferences.colors)
    }

    private func load(reset: Bool) async {
        if reset { page = 0; posts = [] }
        isLoading = true; error = nil
        do {
            let fetched = try await APIClient.shared.blogs.list(page: page)
            posts = fetched.items
            hasMore = fetched.hasMore
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Couldn't load posts." }
        isLoading = false
    }

    private func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        do {
            let more = try await APIClient.shared.blogs.list(page: page + 1)
            page += 1
            posts += more.items
            hasMore = more.hasMore
        } catch {
            toast.error(String(localized: "Couldn't load more blog posts."))
        }
        isLoadingMore = false
    }
}
