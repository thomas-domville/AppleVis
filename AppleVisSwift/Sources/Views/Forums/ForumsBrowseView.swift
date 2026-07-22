import SwiftUI

struct ForumsBrowseView: View {
    @State private var topics: [ForumTopic] = []
    @State private var categories: [ForumCategory] = []
    @State private var selectedCategory: ForumCategory? = nil
    @State private var appleOnly = false
    @State private var isLoading = false
    @State private var error: String?
    @State private var page = 0
    @State private var hasMore = false
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        Group {
            if isLoading && topics.isEmpty {
                LoadingView()
            } else if let error, topics.isEmpty {
                ErrorView(message: error) { await load(reset: true) }
            } else {
                topicList
            }
        }
        .navigationTitle("Forums")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    if auth.isSignedIn {
                        NavigationLink(destination: ComposeTopicView()) {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                    filterMenu
                }
            }
        }
        .task { await load(reset: true) }
        .refreshable { await load(reset: true) }
    }

    private var topicList: some View {
        List {
            ForEach(topics) { topic in
                ForumTopicRow(topic: topic)
            }
            if hasMore {
                ProgressView().frame(maxWidth: .infinity)
                    .task { await loadMore() }
            }
        }
        .listStyle(.plain)
    }

    private var filterMenu: some View {
        Menu {
            Toggle("Apple Topics Only", isOn: $appleOnly)
                .onChange(of: appleOnly) { _, _ in Task { await load(reset: true) } }
            if !categories.isEmpty {
                Section("Category") {
                    Button("All") { selectedCategory = nil; Task { await load(reset: true) } }
                    ForEach(categories) { cat in
                        Button(cat.name) { selectedCategory = cat; Task { await load(reset: true) } }
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }

    private func load(reset: Bool) async {
        if reset { page = 0; topics = [] }
        isLoading = true
        error = nil
        do {
            async let topicsResult = APIClient.shared.forums.recent(page: page, appleOnly: appleOnly)
            async let categoriesResult = categories.isEmpty ? APIClient.shared.forums.categories() : []
            let (fetched, cats) = try await (topicsResult, categoriesResult)
            topics = fetched
            if !cats.isEmpty { categories = cats }
            hasMore = fetched.count >= 20
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Couldn't load forums." }
        isLoading = false
    }

    private func loadMore() async {
        page += 1
        if let more = try? await APIClient.shared.forums.recent(page: page, appleOnly: appleOnly) {
            topics += more
            hasMore = more.count >= 20
        }
    }
}
