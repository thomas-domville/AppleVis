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
    /// Snapshot of `forumsLastVisit` taken once per genuine visit (in
    /// `.task`, when the Forums tab is actually entered) rather than read
    /// live from the ever-advancing store — see `ForumFilter.apply`'s doc
    /// comment and FORUM-01. The persisted value itself only advances in
    /// `.onDisappear`, a real end-of-visit signal, decoupled from
    /// `load(reset:)` which runs many times per visit (pull-to-refresh,
    /// filter changes, pagination).
    @State private var sessionLastVisit: Date = PersistenceStore.shared.forumsLastVisit
    @State private var autoPaginateAttempts = 0
    private static let maxAutoPaginateAttempts = 20
    /// Target for the background top-up in `loadMoreUntilEnoughOrCap()` —
    /// matches `APIPaging.pageSize`, the app's standard single-page count,
    /// so a sparse category filter still feels like a normal-sized list
    /// once the top-up settles, not an arbitrary round number.
    private static let minDesiredMatches = APIPaging.pageSize
    @AccessibilityFocusState private var focusedTopicId: String?
    @AccessibilityFocusState private var isEmptyStateFocused: Bool
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var toast: ToastStore
    @ObservedObject private var networkStatus = NetworkStatusStore.shared
    private let showsPersonalFilters: Bool

    init(initialFilter: ForumFilter = .recent, showsPersonalFilters: Bool = true) {
        self.showsPersonalFilters = showsPersonalFilters
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

    private var forumsEmptyMessage: String {
        switch filter {
        case .unread:          return "You are all caught up."
        case .sinceLastVisit: return "No new activity since your last visit."
        default:                return "Pull to refresh forums"
        }
    }

    private var filterButtonAccessibilityLabel: String {
        showsPersonalFilters
            ? String(localized: "Filter: \(filter.displayName)")
            : String(localized: "Filter forums")
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
        var result = filter.apply(to: fetched, lastVisit: sessionLastVisit)
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
                            ? "You are not following any topics yet."
                            : "You have not saved any topics yet.",
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
                LoadingView(message: "Loading \(filter.displayName)…")
            } else if let error, topics.isEmpty {
                ErrorView(message: error) { await load(reset: true) }
            } else if filteredTopics.isEmpty && hasMore && autoPaginateAttempts < Self.maxAutoPaginateAttempts {
                // A page filtering down to zero doesn't mean no matches
                // exist — Unread/New/Since Last Visit are applied
                // client-side to a filter-agnostic "recent" feed, so a later
                // page can still have matches even though this one didn't.
                // Purely a display condition — the actual fetching is
                // already running in the background (kicked off from
                // `.task`/the filter-sheet dismiss handler below), so this
                // doesn't start its own `.task`; two concurrent callers of
                // loadMoreUntilEnoughOrCap() could otherwise race on `page`.
                LoadingView(message: "Looking for \(filter.displayName)…")
            } else if filteredTopics.isEmpty {
                EmptyStateView(
                    title: "No topics",
                    message: hasMore ? "No matches in the topics checked so far." : forumsEmptyMessage,
                    systemImage: "bubble.left.and.bubble.right",
                    primaryActionLabel: hasMore ? "Keep Looking" : nil,
                    primaryAction: hasMore ? { autoPaginateAttempts = 0 } : nil,
                    titleFocus: $isEmptyStateFocused
                )
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
                            revealAndFocus(topic)
                        })) {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                    Button {
                        showFilterSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel(filterButtonAccessibilityLabel)
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
                UIAccessibility.post(
                    notification: .announcement,
                    argument: showsPersonalFilters ? String(localized: "Showing \(filter.displayName).") : String(localized: "Forum filters updated.")
                )
                if let first = filteredTopics.first {
                    focusOnTopic(first.id)
                } else {
                    // Previously nothing moved focus to the empty state
                    // itself after a filter change landed on zero results
                    // (FORUM-18) — VoiceOver's cursor stayed on the
                    // now-hidden filter control.
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        isEmptyStateFocused = true
                    }
                }
                // Fire-and-forget: tops up a sparse filter in the
                // background without blocking the focus logic above on it.
                Task { await loadMoreUntilEnoughOrCap() }
            }
        }) {
            ForumFilterSheetView(
                filter: $filter,
                appleTopicsFilter: $appleTopicsFilter,
                selectedCategory: $selectedCategory,
                categories: categories,
                showsPersonalFilters: showsPersonalFilters
            )
        }
        .task {
            // Snapshot once per genuine visit — NOT inside load(reset:),
            // which also runs on pull-to-refresh and filter changes within
            // the same visit and must not shift the New/Since-Last-Visit
            // baseline each time. See FORUM-01.
            sessionLastVisit = PersistenceStore.shared.forumsLastVisit
            await load(reset: true)
            restoreLastViewedTopicIfPresent()
            // Fire-and-forget: tops up a sparse filter in the background
            // without blocking the focus/restore logic above on it.
            Task { await loadMoreUntilEnoughOrCap() }
        }
        .onDisappear {
            // A real end-of-visit signal: fires on tab switch away, not on
            // pushing/popping a topic detail screen within this same
            // NavigationStack (SwiftUI doesn't toggle a stack root's
            // onAppear/onDisappear for child pushes).
            PersistenceStore.shared.markForumsVisited()
        }
        .refreshable {
            await load(reset: true)
            SoundPlayer.shared.play(.refresh)
            Task { await loadMoreUntilEnoughOrCap() }
        }
    }

    private var topicList: some View {
        List {
            if networkStatus.degradedGroups.contains(.forums) {
                OfflineBanner()
                    .listRowSeparator(.hidden)
            }
            ForEach(filteredTopics) { topic in
                ForumTopicRow(topic: topic, onDelete: { deleteTopicWithFocus(topic) })
                    .accessibilityFocused($focusedTopicId, equals: topic.id)
            }
            if hasMore {
                ProgressView().frame(maxWidth: .infinity).accessibilityLabel(String(localized: "Loading more…"))
                    .task { await loadMore() }
            }
        }
        .listStyle(.plain)
        .themedList(preferences.colors)
    }

    /// Delayed since setting focus before the target row has laid out is a
    /// common way for it to silently fail (same pattern used for wizard
    /// step transitions elsewhere in the app).
    /// Focuses a stable neighbor after deleting a topic from the list
    /// (FORUM-12) — same class of gap, same fix pattern, as FORUM-11's
    /// reply-deletion focus in ForumTopicDetailView.
    private func deleteTopicWithFocus(_ topic: ForumTopic) {
        let list = filteredTopics
        guard let idx = list.firstIndex(where: { $0.id == topic.id }) else {
            topics.removeAll { $0.id == topic.id }
            return
        }
        let neighborId: String? = idx + 1 < list.count ? list[idx + 1].id : (idx > 0 ? list[idx - 1].id : nil)
        topics.removeAll { $0.id == topic.id }
        if let neighborId {
            focusOnTopic(neighborId)
        }
    }

    /// FORUM-14: "remember forum list position by content ID." Scrolls/
    /// focuses back to the topic the user most recently opened, if it's
    /// still present in the currently loaded, currently filtered list —
    /// tolerating that new activity may have reordered or dropped it.
    /// Consumed once (cleared after use) so it doesn't keep yanking focus
    /// back on every later pull-to-refresh within the same visit.
    private func restoreLastViewedTopicIfPresent() {
        if let lastId = PersistenceStore.shared.lastViewedForumTopicId {
            PersistenceStore.shared.lastViewedForumTopicId = nil
            if filteredTopics.contains(where: { $0.id == lastId }) {
                focusOnTopic(lastId)
                return
            }
        }
        // No last-viewed topic to restore — a genuine cold open (first-ever
        // visit, or nothing previously opened this session) previously left
        // this as a silent no-op, so VoiceOver's cursor stayed on the back
        // button after the push, same failure mode already fixed for the
        // filter-sheet-dismiss case just above. Reported directly.
        if let first = filteredTopics.first {
            focusOnTopic(first.id)
        } else {
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                isEmptyStateFocused = true
            }
        }
    }

    private func focusOnTopic(_ id: String) {
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            focusedTopicId = id
        }
    }

    /// Following/Saved render `localFilterItems` instead of `topicList` —
    /// a completely different List that never wires up `focusedTopicId` at
    /// all. Composing while one of those is active would insert the new
    /// topic into `topics` (which isn't even on screen) and then try to
    /// focus a row that doesn't exist in the rendered view, silently
    /// stranding VoiceOver focus wherever it already was. `topics.insert`
    /// bypasses `applyRefinements`, so the server-side filters (category,
    /// Apple-only) don't need resetting here — the new topic is already
    /// unconditionally visible in `filteredTopics` for every other filter.
    private func revealAndFocus(_ topic: ForumTopic) {
        if filter == .following || filter == .saved {
            filter = .recent
        }
        focusOnTopic(topic.id)
    }

    private func load(reset: Bool) async {
        if reset { page = 0; topics = []; autoPaginateAttempts = 0 }
        isLoading = true
        error = nil
        do {
            async let topicsResult = APIClient.shared.forums.recent(page: page, appleOnly: appleTopicsFilter == .appleOnly)
            async let categoriesResult = categories.isEmpty ? APIClient.shared.forums.categories() : []
            let (fetched, cats) = try await (topicsResult, categoriesResult)
            topics = applyRefinements(to: fetched)
            if !cats.isEmpty { categories = cats }
            hasMore = fetched.count >= APIPaging.pageSize
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Could not load topics" }
        isLoading = false
    }

    /// Keeps calling `loadMore()` in the background while the current
    /// filter has fewer than `minDesiredMatches` visible matches — a
    /// filter-agnostic "recent" feed page can legitimately filter down to
    /// zero, or to just a couple, while later pages still have plenty more
    /// (FORUM-02, extended): a sparse category (e.g. "Android") previously
    /// only kept auto-fetching while the visible count was literally zero,
    /// so landing on exactly one match stopped the search entirely and left
    /// the rest to a user noticing a spinner at the bottom of a one-row
    /// list. Runs unconditionally after every (re)load rather than only
    /// while the screen shows its own empty state — whatever's already
    /// been found stays visible immediately; this just keeps quietly
    /// topping it up underneath. Reported directly. A single `.task` loops
    /// internally rather than relying on SwiftUI to start a fresh task on
    /// every re-render, since an already-attached `.task` doesn't restart
    /// just because surrounding state changed.
    private func loadMoreUntilEnoughOrCap() async {
        while filteredTopics.count < Self.minDesiredMatches && hasMore && autoPaginateAttempts < Self.maxAutoPaginateAttempts {
            let pageBefore = page
            autoPaginateAttempts += 1
            await loadMore()
            // loadMore() failed (page didn't advance) — it already toasted
            // the error once; stop instead of retrying in a tight loop.
            if page == pageBefore { break }
        }
    }

    /// `hasMore` is intentionally driven by the raw (pre-filter) page size,
    /// not the filtered `topics` count: there's no server-side "New"/"Unread"/
    /// "Since Last Visit" filter, so a narrow filter can show few items per
    /// raw page yet still correctly keep paging until the underlying recent
    /// feed itself is exhausted.
    private func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        do {
            // `page` only advances on success — a transient failure used to
            // still increment it, permanently skipping that page's content
            // once a later attempt succeeded.
            let more = try await APIClient.shared.forums.recent(page: page + 1, appleOnly: appleTopicsFilter == .appleOnly)
            page += 1
            topics += applyRefinements(to: more)
            hasMore = more.count >= APIPaging.pageSize
        } catch {
            toast.error(String(localized: "Couldn't load more topics."))
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
    let showsPersonalFilters: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var preferences: PreferencesStore

    var body: some View {
        NavigationStack {
            Form {
                if showsPersonalFilters {
                    Section("Show") {
                        ForEach(ForumFilter.allCases) { option in
                            Button {
                                filter = option
                                SoundPlayer.shared.play(.pickerTick)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.displayName).foregroundStyle(.primary)
                                        if let description = option.filterDescription {
                                            Text(description)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if filter == option {
                                        Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                            .accessibilityAddTraits(filter == option ? [.isSelected] : [])
                        }
                    }
                }
                if refinementFiltersVisible {
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

    private var refinementFiltersVisible: Bool {
        showsPersonalFilters ? filter.supportsRefinement : true
    }
}
