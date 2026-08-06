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
    @State private var isLoadingMore = false
    @State private var showFilterSheet = false
    @State private var searchText = ""
    @EnvironmentObject private var auth: AuthStore
    @ObservedObject private var networkStatus = NetworkStatusStore.shared

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

    private func matchesSearch(title: String, author: String = "") -> Bool {
        guard !searchText.isEmpty else { return true }
        return title.localizedCaseInsensitiveContains(searchText)
            || (!author.isEmpty && author.localizedCaseInsensitiveContains(searchText))
    }

    private var filteredTopics: [ForumTopic] {
        topics.filter { matchesSearch(title: $0.title, author: $0.authorName) }
    }

    var body: some View {
        Group {
            if let localItems = localFilterItems {
                let filteredLocalItems = localItems.filter { matchesSearch(title: $0.title) }
                if localItems.isEmpty {
                    EmptyStateView(
                        title: filter == .following ? "Not Following Any Topics" : "No Saved Topics",
                        message: filter == .following
                            ? "Follow forum topics to get notified of new replies."
                            : "Tap the bookmark icon on any topic to save it.",
                        systemImage: filter == .following ? "bell" : "bookmark"
                    )
                } else {
                    List(filteredLocalItems, id: \.id) { item in
                        NavigationLink(value: ForumTopic(
                            id: item.id, title: item.title, authorName: "", authorId: "",
                            createdAt: item.lastActivityAt ?? .distantPast, lastActivityAt: item.lastActivityAt ?? .distantPast,
                            replyCount: 0, category: "", categoryId: "", url: "",
                            isUnread: false,
                            isFollowing: PersistenceStore.shared.isFollowed(id: item.id),
                            isSaved: PersistenceStore.shared.isSaved(id: item.id)
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
        .searchable(text: $searchText, prompt: "Search topics")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    if auth.isSignedIn {
                        NavigationLink(destination: ComposeTopicView()) {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                    Button {
                        showFilterSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Filter: \(filter.displayName)")
                }
            }
        }
        .sheet(isPresented: $showFilterSheet, onDismiss: { Task { await load(reset: true) } }) {
            ForumFilterSheetView(filter: $filter, appleOnly: $appleOnly, selectedCategory: $selectedCategory, categories: categories)
        }
        .task { await load(reset: true) }
        .refreshable { await load(reset: true) }
    }

    private var topicList: some View {
        List {
            if networkStatus.degradedGroups.contains(.forums) {
                OfflineBanner()
                    .listRowSeparator(.hidden)
            }
            ForEach(filteredTopics) { topic in
                ForumTopicRow(topic: topic)
            }
            if hasMore {
                ProgressView().frame(maxWidth: .infinity)
                    .task { await loadMore() }
            }
        }
        .listStyle(.plain)
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
            hasMore = fetched.count >= APIPaging.pageSize
            PersistenceStore.shared.markForumsVisited()
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Couldn't load forums." }
        isLoading = false
    }

    /// `hasMore` is intentionally driven by the raw (pre-filter) page size,
    /// not the filtered `topics` count: there's no server-side "New"/"Unread"/
    /// "Since Last Visit" filter, so a narrow filter can show few items per
    /// raw page yet still correctly keep paging until the underlying recent
    /// feed itself is exhausted.
    private func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        page += 1
        if let more = try? await APIClient.shared.forums.recent(page: page, appleOnly: appleOnly) {
            topics += filter.apply(to: more)
            hasMore = more.count >= APIPaging.pageSize
        }
        isLoadingMore = false
    }
}

/// A real screen instead of a Menu containing a Toggle — same VoiceOver
/// quirk fixed elsewhere in the app (CustomizeHomeView): double-tapping a
/// Toggle inside a Menu dismisses the whole menu on this SDK, so a
/// VoiceOver user could never reach the category list below "Apple Topics
/// Only" without reopening the menu each time.
private struct ForumFilterSheetView: View {
    @Binding var filter: ForumFilter
    @Binding var appleOnly: Bool
    @Binding var selectedCategory: ForumCategory?
    let categories: [ForumCategory]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Show") {
                    ForEach(ForumFilter.allCases) { option in
                        Button {
                            filter = option
                            SoundPlayer.shared.play(.pickerTick)
                        } label: {
                            HStack {
                                Text(option.displayName).foregroundStyle(.primary)
                                Spacer()
                                if filter == option {
                                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .accessibilityAddTraits(filter == option ? [.isSelected] : [])
                    }
                }
                if filter.supportsRefinement {
                    Section("Forums") {
                        Toggle("Apple Topics Only", isOn: $appleOnly)
                            .accessibilityHint("Hides non-Apple forum categories from results.")
                    }
                    if !categories.isEmpty {
                        Section("Category") {
                            Button {
                                selectedCategory = nil
                            } label: {
                                HStack {
                                    Text("All").foregroundStyle(.primary)
                                    Spacer()
                                    if selectedCategory == nil {
                                        Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                            .accessibilityAddTraits(selectedCategory == nil ? [.isSelected] : [])
                            ForEach(categories) { cat in
                                Button {
                                    selectedCategory = cat
                                } label: {
                                    HStack {
                                        Text(cat.name).foregroundStyle(.primary)
                                        Spacer()
                                        if selectedCategory?.id == cat.id {
                                            Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                                        }
                                    }
                                }
                                .accessibilityAddTraits(selectedCategory?.id == cat.id ? [.isSelected] : [])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Forums")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
