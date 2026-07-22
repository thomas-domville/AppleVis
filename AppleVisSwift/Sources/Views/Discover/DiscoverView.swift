import SwiftUI

struct DiscoverView: View {
    @State private var searchText = ""
    @State private var searchResults: SearchResults?
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    hubGrid
                } else {
                    SearchResultsView(results: searchResults, isSearching: isSearching)
                }
            }
            .navigationTitle("Discover")
            .searchable(text: $searchText, prompt: "Search AppleVis")
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                guard !newValue.isEmpty else { searchResults = nil; return }
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    isSearching = true
                    searchResults = try? await APIClient.shared.search.query(newValue)
                    isSearching = false
                }
            }
        }
    }

    // MARK: - Hub grid (shown when not searching)

    private var hubGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                HubCard(title: "Forums", subtitle: "Discussion & help", systemImage: "bubble.left.and.bubble.right", color: .blue) {
                    AnyView(ForumsBrowseView())
                }
                HubCard(title: "Podcasts", subtitle: "Audio content", systemImage: "mic.fill", color: .purple) {
                    AnyView(PodcastBrowseView())
                }
                HubCard(title: "Apps", subtitle: "iOS accessibility apps", systemImage: "square.grid.2x2", color: .green) {
                    AnyView(AppBrowseView())
                }
                HubCard(title: "Guides", subtitle: "Tutorials & resources", systemImage: "book", color: .orange) {
                    AnyView(GuideBrowseView())
                }
                HubCard(title: "Blogs", subtitle: "Articles & news", systemImage: "newspaper", color: .red) {
                    AnyView(BlogBrowseView())
                }
                HubCard(title: "Bug Reports", subtitle: "Known accessibility bugs", systemImage: "ant", color: .brown) {
                    AnyView(BugBrowseView())
                }
            }
            .padding()
        }
    }
}

struct HubCard<Destination: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination()) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(color, in: RoundedRectangle(cornerRadius: 10))

                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.secondarySystemBackground, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
