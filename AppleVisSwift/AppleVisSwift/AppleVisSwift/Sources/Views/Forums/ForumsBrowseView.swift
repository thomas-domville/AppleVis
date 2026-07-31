import SwiftUI

struct ForumsBrowseView: View {
    @State private var topics: [ForumTopic] = []
    @State private var categories: [ForumCategory] = []
    @State private var selectedCategory: ForumCategory? = nil
    @State private var appleOnly = false
    @State private var filter: ForumFilter = .recent
    @State private var isLoading = false
    @State private var error: String?
    @State private var page = 0
    @State private var hasMore = false
    @EnvironmentObject private var auth: AuthStore

    init(initialFilter: ForumFilter = .recent) {
        _filter = State(initialValue: initialFilter)
    }

    /// Following/Saved come from local persistence, not the "recent" feed —
    /// they render as their own lightweight list instead of paged `topics`.
    private var localFilterItems: [(id: String, title: String, lastActivityAt: Date?)]? {
        switch filter {
        case .following:
            return PersistenceStore.shared.followedItems()
                .filter { $0.kind == .forumTopic }
                .map { ($0.id, $0.title, $0.lastActivityAt) }
        case .saved:
            return PersistenceStore.shared.savedItems()
                .filter { $0.kind == .forumTopic }
                .map { ($0.id, $0.title, $0.lastActivityAt) }
        default:
            return nil
        }
    }

    var body: some View {
        Group {
            if let localItems = localFilterItems {
                if localItems.isEmpty {
                    EmptyStateView(
                        title: filter == .following ? "Not Following Any Topics" : "No Saved Topics",
                        message: filter == .following
                            ? "Follow forum topics to get notified of new replies."
                            : "Tap the bookmark icon on any topic to save it.",
                        systemImage: filter == .following ? "bell" : "bookmark"
                    )
                } else {
                    List(localItems, id: \.id) { item in
                        NavigationLink(value: ForumTopic(
                            id: item.id, title: item.title, authorName: "", authorId: "",
                            createdAt: item.lastActivityAt ?? .distantPast, lastActivityAt: item.lastActivityAt ?? .distantPast,
                            replyCount: 0, category: "", categoryId: "", url: "",
                            isUnread: false, isFollowing: filter == .following, isSaved: filter == .saved
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                if let activity = item.lastActivityAt {
                                    RelativeDateLabel(date: activity)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            } else if isLoading && topics.isEmpty {
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
            Section("Show") {
                ForEach(ForumFilter.allCases) { option in
                    Button {
                        filter = option
                        SoundPlayer.shared.play(.pickerTick)
                        if localFilterItems == nil { Task { await load(reset: true) } }
                    } label: {
                        if filter == option {
                            Label(option.displayName, systemImage: "checkmark")
                        } else {
                            Text(option.displayName)
                        }
                    }
                }
            }
            if filter.supportsRefinement {
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
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Filter: \(filter.displayName)")
    }

    private func load(reset: Bool) async {
        if reset { page = 0; topics = [] }
        isLoading = true
        error = nil
        do {
            async let topicsResult = APIClient.shared.forums.recent(page: page, appleOnly: appleOnly)
            async let categoriesResult = categories.isEmpty ? APIClient.shared.forums.categories() : []
            let (fetched, cats) = try await (topicsResult, categoriesResult)
            topics = filter.apply(to: fetched)
            if !cats.isEmpty { categories = cats }
            hasMore = fetched.count >= 20
            PersistenceStore.shared.markForumsVisited()
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Couldn't load forums." }
        isLoading = false
    }

    private func loadMore() async {
        page += 1
        if let more = try? await APIClient.shared.forums.recent(page: page, appleOnly: appleOnly) {
            topics += filter.apply(to: more)
            hasMore = more.count >= 20
        }
    }
}
