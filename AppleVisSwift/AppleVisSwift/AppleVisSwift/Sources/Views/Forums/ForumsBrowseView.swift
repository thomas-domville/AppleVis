import SwiftUI

/// Splits the old binary "Apple Topics Only" toggle into three states,
/// matching the old app's current (non-deprecated) forums-browse screen —
/// which added a dedicated "Non-Apple Related" browsing mode alongside
/// "All Topics" and "Apple Related", rather than only being able to hide
/// non-Apple topics without ever isolating them.
enum AppleTopicsFilter: String, CaseIterable, Identifiable {
    case all, appleOnly, nonAppleOnly
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .all:         return "All Topics"
        case .appleOnly:    return "Apple Related"
        case .nonAppleOnly: return "Non-Apple Related"
        }
    }
}

struct ForumsBrowseView: View {
    @State private var topics: [ForumTopic] = []
    @State private var categories: [ForumCategory] = []
    @State private var selectedCategory: ForumCategory? = nil
    @State private var appleTopicsFilter: AppleTopicsFilter = .all
    @State private var filter: ForumFilter = .recent
    @State private var isLoading = false
    @State private var error: String?
    @State private var page = 0
    @State private var hasMore = false
    @State private var isLoadingMore = false
    @State private var showFilterSheet = false
    @State private var searchText = ""
    @AccessibilityFocusState private var focusedTopicId: String?
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var preferences: PreferencesStore
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

    private static let nonAppleCategoryNames: Set<String> = [
        "windows", "android", "smart home tech and gadgets", "assistive technology",
    ]

    private static func isNonAppleCategory(_ category: String) -> Bool {
        let c = category.lowercased()
        return nonAppleCategoryNames.contains(c) || c.contains("non-apple") || c.contains("non apple")
    }

    /// Category selection has no `categoryId` to match against — the recent-
    /// topics feed's mapper leaves `categoryId` empty (only the full node
    /// mapper populates it), so this matches on the category display name
    /// instead, the same string both `categories()` and the recent feed
    /// already surface.
    private func applyRefinements(to fetched: [ForumTopic]) -> [ForumTopic] {
        var result = filter.apply(to: fetched)
        if appleTopicsFilter == .nonAppleOnly {
            result = result.filter { ForumsBrowseView.isNonAppleCategory($0.category) }
        }
        if let selectedCategory {
            result = result.filter { $0.category.caseInsensitiveCompare(selectedCategory.name) == .orderedSame }
        }
        return result
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
                    .themedList(preferences.colors)
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
                        NavigationLink(destination: ComposeTopicView(onPosted: { topic in
                            topics.insert(topic, at: 0)
                            focusOnTopic(topic.id)
                        })) {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                    Button {
                        showFilterSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel(String(localized: "Filter: \(filter.displayName)"))
                }
            }
        }
        .sheet(isPresented: $showFilterSheet, onDismiss: {
            Task {
                await load(reset: true)
                // Previously the reloaded list (a completely different
                // result set after a filter change) left VoiceOver focus
                // wherever the OS defaulted it — typically back near the
                // toolbar filter button — instead of on the new content.
                UIAccessibility.post(notification: .announcement, argument: String(localized: "Showing \(filter.displayName)."))
                if let first = filteredTopics.first { focusOnTopic(first.id) }
            }
        }) {
            ForumFilterSheetView(filter: $filter, appleTopicsFilter: $appleTopicsFilter, selectedCategory: $selectedCategory, categories: categories)
        }
        .task { await load(reset: true) }
        .refreshable { await load(reset: true); SoundPlayer.shared.play(.refresh) }
    }

    private var topicList: some View {
        List {
            if networkStatus.degradedGroups.contains(.forums) {
                OfflineBanner()
                    .listRowSeparator(.hidden)
            }
            ForEach(filteredTopics) { topic in
                ForumTopicRow(topic: topic, onDelete: { topics.removeAll { $0.id == topic.id } })
                    .accessibilityFocused($focusedTopicId, equals: topic.id)
            }
            if hasMore {
                ProgressView().frame(maxWidth: .infinity)
                    .task { await loadMore() }
            }
        }
        .listStyle(.plain)
        .themedList(preferences.colors)
    }

    /// Delayed since setting focus before the target row has laid out is a
    /// common way for it to silently fail (same pattern used for wizard
    /// step transitions elsewhere in the app).
    private func focusOnTopic(_ id: String) {
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            focusedTopicId = id
        }
    }

    private func load(reset: Bool) async {
        if reset { page = 0; topics = [] }
        isLoading = true
        error = nil
        do {
            async let topicsResult = APIClient.shared.forums.recent(page: page, appleOnly: appleTopicsFilter == .appleOnly)
            async let categoriesResult = categories.isEmpty ? APIClient.shared.forums.categories() : []
            let (fetched, cats) = try await (topicsResult, categoriesResult)
            topics = applyRefinements(to: fetched)
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
        if let more = try? await APIClient.shared.forums.recent(page: page, appleOnly: appleTopicsFilter == .appleOnly) {
            topics += applyRefinements(to: more)
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
    @Binding var appleTopicsFilter: AppleTopicsFilter
    @Binding var selectedCategory: ForumCategory?
    let categories: [ForumCategory]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var preferences: PreferencesStore

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
                    Section("Apple Relevance") {
                        ForEach(AppleTopicsFilter.allCases) { option in
                            Button {
                                appleTopicsFilter = option
                                SoundPlayer.shared.play(.pickerTick)
                            } label: {
                                HStack {
                                    Text(option.displayName).foregroundStyle(.primary)
                                    Spacer()
                                    if appleTopicsFilter == option {
                                        Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                            .accessibilityAddTraits(appleTopicsFilter == option ? [.isSelected] : [])
                        }
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
            .themedList(preferences.colors)
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
