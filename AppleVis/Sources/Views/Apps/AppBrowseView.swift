import SwiftUI

// MARK: - App Directory browser (platform → categories → apps)

struct AppBrowseView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var toast: ToastStore
    @State private var platform: AppPlatform = .ios
    @State private var categories: [AppCategory] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var searchText = ""
    /// Command-F moves here (Adaptive Experience, 2026-10-06).
    @FocusState private var isSearchFocused: Bool
    @State private var searchResults: [AppListing] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @AccessibilityFocusState private var isTitleFocused: Bool
    /// The search result showing beside the results on a wide window.
    @State private var selectedApp: ContentSelection?

    private var isSearchActive: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        // Search results can show the chosen app beside them on a wide
        // window. The platform and category picker never does: an empty
        // pane beside it would only be in the way (Adaptive Experience,
        // 2026-10-06).
        AdaptiveListDetail(
            selection: $selectedApp,
            placeholder: "Choose an app to read about it here.",
            placeholderSystemImage: "square.grid.2x2",
            onDetailClosed: { closed in searchResults.removeAll { $0.id == closed.id } },
            isEnabled: isSearchActive
        ) {
            directoryContent
        } detail: { selection in
            AppDetailView(appId: selection.id,
                          platform: searchResults.first { $0.id == selection.id }?.platform,
                          focusFirstNewCommentOnAppear: selection.focusFirstNewComment)
        }
        .navigationTitle("App Directory")
        .task { await load() }
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
        .onChange(of: platform) { _, _ in Task { await load() } }
        .searchable(text: $searchText, prompt: "Search apps")
        .applySearchFocus($isSearchFocused)
        .keyboardSearchTarget($isSearchFocused)
        .inputLimit($searchText, maximum: InputLimit.searchMaximum, warnWithin: 20) {
            toast.warning(InputLimit.searchShortened)
        }
        .onChange(of: searchText) { _, newValue in runSearch(newValue) }
    }

    private var directoryContent: some View {
        Group {
            if isSearchActive {
                searchResultsSection
            } else if isLoading && categories.isEmpty {
                LoadingView()
            } else if let error, categories.isEmpty {
                ErrorView(message: error) { await load() }
            } else if categories.isEmpty {
                EmptyStateView(title: String(localized: "No Categories"), message: String(localized: "Pull to refresh."), systemImage: "square.grid.2x2")
            } else {
                categoryList
            }
        }
        // On the list, so pulling down inside an app beside it doesn't
        // reload the directory.
        .refreshable { await RefreshHeartbeat.during { await load() }; SoundPlayer.shared.play(.refresh) }
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        if isSearching {
            LoadingView()
        } else if searchResults.isEmpty {
            EmptyStateView(
                title: String(localized: "No Results"),
                message: String(localized: "No apps match \"\(searchText)\"."),
                systemImage: "magnifyingglass"
            )
        } else {
            List {
                ForEach(searchResults) { app in
                    AppListingRow(app: app)
                }
            }
            .listStyle(.plain)
            .themedList(preferences.colors)
        }
    }

    /// Same synchronous-before-debounce fix already applied to Discover's
    /// search (SEARCH-01) — flipping isSearching only after the debounce
    /// briefly rendered a fabricated "No Results" on every fresh search.
    private func runSearch(_ query: String) {
        searchTask?.cancel()
        guard query.trimmingCharacters(in: .whitespaces).count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            do {
                searchResults = try await APIClient.shared.apps.search(query)
            } catch {
                toast.error(String(localized: "Couldn't search apps."))
                searchResults = []
            }
            isSearching = false
        }
    }

    /// `.pickerStyle(.menu)`, not `.segmented` — see ForYouView's identical
    /// picker for the direct report explaining why (segmented reads as a
    /// row of same-sounding "button"s with no indication they're one
    /// connected control). Adding a swipe-up/down adjustable action on top
    /// gives the "swipe to move to the next platform" gesture without
    /// reverting to that already-reported problem — double-tap still opens
    /// the menu to jump straight to a specific platform.
    private var platformPicker: some View {
        Picker("Platform", selection: $platform) {
            ForEach(AppPlatform.allCases) { p in
                Text(p.displayName).tag(p)
            }
        }
        .pickerStyle(.menu)
        .accessibilityHint(String(localized: "Choose which App Directory platform to browse."))
        // Explicit value, not left to whatever SwiftUI synthesizes for a
        // .menu-style Picker — without it, swiping up/down only played the
        // "value changed" tone with no spoken platform name. Same fix as
        // PlayerView's playback-speed control (PODCAST-06). Reported directly.
        .accessibilityValue(Text(platform.displayName))
        .accessibilityAdjustableAction { direction in
            guard let idx = AppPlatform.allCases.firstIndex(of: platform) else { return }
            switch direction {
            case .increment:
                platform = AppPlatform.allCases[(idx + 1) % AppPlatform.allCases.count]
            case .decrement:
                platform = AppPlatform.allCases[(idx - 1 + AppPlatform.allCases.count) % AppPlatform.allCases.count]
            @unknown default: break
            }
        }
    }

    private var categoryList: some View {
        List {
            Section("Platform") {
                platformPicker
                    .accessibilityFocused($isTitleFocused)
            }
            ForEach(groupedCategories, id: \.letter) { group in
                Section {
                    ForEach(group.categories) { category in
                        NavigationLink(value: AppCategoryDestination(platform: platform, category: category)) {
                            HStack {
                                Text(category.name)
                                Spacer()
                                // Apple TV categories have no live count
                                // available (see `categories(platform:)` —
                                // the REST endpoint that provides it for
                                // every other platform doesn't exist for
                                // tvOS), reported as `count: 0`. Showing
                                // "0" next to every category would read as
                                // "empty," which isn't known to be true —
                                // hidden instead of shown wrong.
                                if category.count > 0 {
                                    Text("\(category.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .accessibilityLabel(category.count > 0
                            ? String(localized: "\(category.name), \(category.count) apps")
                            : category.name)
                    }
                } header: {
                    // Bare "B" reads ambiguously to VoiceOver landing on it
                    // mid-swipe — sounds like it could be a category itself
                    // rather than an alphabetical divider. Kept visually
                    // compact (matches the familiar Contacts-style index
                    // look for sighted users) while making what it actually
                    // means explicit for VoiceOver. Reported directly.
                    Text(group.letter)
                        .accessibilityLabel(String(localized: "Categories starting with \(group.letter)"))
                }
            }
        }
        .listStyle(.insetGrouped)
        .themedList(preferences.colors)
    }

    private var groupedCategories: [(letter: String, categories: [AppCategory])] {
        var groups: [(letter: String, categories: [AppCategory])] = []
        var currentLetter = ""
        for cat in categories.sorted(by: { $0.name < $1.name }) {
            let first = String(cat.name.prefix(1)).uppercased()
            let letter = (first >= "A" && first <= "Z") ? first : "#"
            if letter != currentLetter {
                currentLetter = letter
                groups.append((letter: letter, categories: []))
            }
            groups[groups.count - 1].categories.append(cat)
        }
        return groups
    }

    private func load() async {
        isLoading = true; error = nil
        do {
            categories = try await APIClient.shared.apps.categories(platform: platform)
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = String(localized: "Couldn't load categories.") }
        isLoading = false
    }
}

// MARK: - Routing value for a platform + category pair

struct AppCategoryDestination: Hashable {
    let platform: AppPlatform
    let category: AppCategory
}

// MARK: - Apps within one category

struct AppCategoryView: View {
    let destination: AppCategoryDestination
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var apps: [AppListing] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var pageLimit = 20
    @ObservedObject private var networkStatus = NetworkStatusStore.shared
    @AccessibilityFocusState private var isTitleFocused: Bool
    /// The app showing beside the category's list on a wide window. Kept
    /// across refreshes while the app is still in the category.
    @State private var selectedApp: ContentSelection?
    /// The category's App Store types, such as Board or Card for Games,
    /// from Apple's own list; empty for a category without types. Which
    /// type each app is comes from its App Store listing (`AppGenres`), so
    /// the AppleVis website doesn't need to store it. Requested directly
    /// (2026-10-09): All first, every type listed even when empty, and any
    /// category that has types gets them.
    @State private var types: [AppGenre] = []
    @State private var typeIndex: [String: [String]] = [:]
    @State private var isFindingTypes = false
    @State private var selectedType: String?

    private var shownApps: [AppListing] {
        guard let selectedType else { return apps }
        return apps.filter { typeIndex[$0.id]?.contains(selectedType) == true }
    }

    private func count(of typeId: String) -> Int {
        apps.filter { typeIndex[$0.id]?.contains(typeId) == true }.count
    }

    private var selectedTypeName: String {
        types.first { $0.id == selectedType }?.name ?? String(localized: "All")
    }

    var body: some View {
        // On a wide window the chosen app shows beside the category's list;
        // on a narrow one this is the list alone, exactly as before
        // (Adaptive Experience, 2026-10-06).
        AdaptiveListDetail(
            selection: $selectedApp,
            placeholder: "Choose an app to read about it here.",
            placeholderSystemImage: "square.grid.2x2",
            onDetailClosed: { closed in apps.removeAll { $0.id == closed.id } }
        ) {
            categoryContent
        } detail: { selection in
            AppDetailView(appId: selection.id,
                          platform: apps.first { $0.id == selection.id }?.platform ?? destination.platform,
                          focusFirstNewCommentOnAppear: selection.focusFirstNewComment)
        }
        .navigationTitle(destination.category.name)
        .task { await load(reset: true) }
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
        .task { await loadTypes() }
    }

    private var categoryContent: some View {
        Group {
            if isLoading && apps.isEmpty {
                LoadingView(message: initialLoadingMessage)
            } else if let error, apps.isEmpty {
                ErrorView(message: error) { await load(reset: true) }
            } else if apps.isEmpty {
                EmptyStateView(
                    title: String(localized: "No Apps Yet"),
                    message: String(localized: "No \(destination.platform.displayName) apps loaded for \(destination.category.name). Pull to refresh."),
                    systemImage: "square.grid.2x2"
                )
            } else {
                List {
                    Text("\(destination.platform.displayName) apps in \(destination.category.name)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($isTitleFocused)
                    if networkStatus.degradedGroups.contains(.apps) {
                        OfflineBanner()
                            .listRowSeparator(.hidden)
                    }
                    if !types.isEmpty {
                        typePicker
                            .listRowSeparator(.hidden)
                    }
                    if selectedType != nil, shownApps.isEmpty {
                        Text("No \(selectedTypeName) apps here yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(shownApps) { app in
                        AppListingRow(app: app, onDelete: {
                            if selectedApp?.id == app.id { selectedApp = nil }
                            apps.removeAll { $0.id == app.id }
                        })
                    }
                }
                .listStyle(.plain)
                .themedList(preferences.colors)
            }
        }
        // forceRefresh: true — a deliberate pull is the user asking "is
        // there anything new," and this category's pages can sit cached as
        // "fresh" for up to 6 hours (ContentCache's default apps: TTL); an
        // ordinary tab visit is fine reusing that, a manual pull shouldn't
        // silently replay the same stale response.
        .refreshable { await RefreshHeartbeat.during { await load(reset: true, forceRefresh: true) }; SoundPlayer.shared.play(.refresh) }
    }

    @ViewBuilder
    private var typePicker: some View {
        if isFindingTypes {
            HStack(spacing: 8) {
                ProgressView().accessibilityHidden(true)
                Text("Finding each app's type…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        } else {
            Picker("Type", selection: $selectedType) {
                Text("\(String(localized: "All")) (\(apps.count))").tag(String?.none)
                ForEach(types) { type in
                    Text("\(type.name) (\(count(of: type.id)))").tag(Optional(type.id))
                }
            }
            .accessibilityValue(Text(selectedType == nil
                                     ? String(localized: "\(String(localized: "All")), \(apps.count) apps")
                                     : String(localized: "\(selectedTypeName), \(shownApps.count) apps")))
            .onChange(of: selectedType) { _, _ in
                SoundPlayer.shared.play(.pickerTick)
                UIAccessibility.post(notification: .announcement, argument: String(localized: "\(shownApps.count) apps"))
            }
        }
    }

    /// Apple's types for this category, then which app is which. Only for
    /// a category Apple gives types, and not Apple TV, whose entries have no
    /// App Store link to look up.
    private func loadTypes() async {
        guard destination.platform != .tvos else { return }
        let found = await AppGenres.shared.types(forCategory: destination.category.name, platform: destination.platform)
        guard !found.isEmpty else { return }
        types = found
        isFindingTypes = true
        typeIndex = await AppGenres.shared.typeIndex(platform: destination.platform, categoryTid: destination.category.tid)
        isFindingTypes = false
        // Couldn't work them out (offline, say): no picker rather than one
        // that filters everything away.
        if typeIndex.isEmpty { types = [] }
    }

    /// Names the wait up front for a category too big for one request (see
    /// the 200-item cap in `load(reset:)`) — otherwise a VoiceOver user
    /// staring at a bare "Loading apps…" for a 500+ item category has no
    /// way to tell a long wait is expected rather than stuck. `LoadingView`
    /// already speaks whatever message it's given via `.screenChanged`, so
    /// this needs no extra announcement plumbing of its own.
    private var initialLoadingMessage: String {
        let count = destination.category.count
        guard count > 200 else { return String(localized: "Loading apps…") }
        return String(localized: "Loading \(count) apps in \(destination.category.name). This may take a few moments.")
    }

    // Fetches every page before showing any of them, rather than revealing
    // results 200 at a time — merging a later page into an already-visible,
    // already-alphabetized list can reshuffle rows the user already swiped
    // past (an item from page 2 can sort earlier than one already shown
    // from page 1). A longer wait up front — with initialLoadingMessage
    // naming it for anything past the single-page cap — was judged the
    // better tradeoff than a list that reorders itself mid-browse.
    // Reported directly.
    private func load(reset: Bool, forceRefresh: Bool = false) async {
        if reset {
            apps = []
            // The category row already told the user the total (e.g.
            // "Books, 47 apps") — request that many per page instead of
            // always paging 20 at a time, so a small category like this
            // arrives in a single request. Clamped so a very large category
            // (e.g. Games) can't trigger one enormous request; anything
            // past the cap is simply fetched as further pages below, all
            // before anything is shown.
            pageLimit = min(max(destination.category.count, 20), 200)
        }
        isLoading = true; error = nil
        do {
            var allItems: [AppListing] = []
            var page = 0
            var hasMore = true
            // 50 pages at the current limit is already 1,000-10,000 apps —
            // comfortably past any real category size, just a backstop
            // against a backend pagination bug leaving this looping forever
            // with the user staring at an unmoving loading screen.
            while hasMore, page < 50 {
                let fetched: (items: [AppListing], hasMore: Bool)
                if destination.platform == .tvos {
                    // `list(categoryTid:)` assumes a numeric Drupal tid,
                    // which Apple TV categories don't have here (see
                    // `categories(platform:)` — they're built from taxonomy
                    // UUIDs, not the REST directory API). Calls
                    // `categoryListing` directly with that UUID instead.
                    fetched = try await APIClient.shared.apps.categoryListing(
                        platform: .tvos,
                        categoryId: destination.category.id,
                        page: page,
                        limit: pageLimit,
                        forceRefresh: forceRefresh
                    )
                } else {
                    let pageResult = try await APIClient.shared.apps.list(
                        page: page,
                        platform: destination.platform,
                        categoryTid: destination.category.tid,
                        limit: pageLimit,
                        forceRefresh: forceRefresh
                    )
                    fetched = (items: pageResult.items, hasMore: pageResult.hasMore)
                }
                allItems += fetched.items
                hasMore = fetched.hasMore
                page += 1
            }
            apps = alphabetized(allItems)
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = String(localized: "Couldn't load apps.") }
        isLoading = false
    }

    /// The native app-directory category endpoint accepts no sort
    /// parameter at all — ordering is whatever the backend returns by
    /// default. Applied client-side after every fetch/append instead.
    private func alphabetized(_ items: [AppListing]) -> [AppListing] {
        items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
