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
    @State private var searchResults: [AppListing] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    private var isSearchActive: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        Group {
            if isSearchActive {
                searchResultsSection
            } else if isLoading && categories.isEmpty {
                LoadingView()
            } else if let error, categories.isEmpty {
                ErrorView(message: error) { await load() }
            } else if categories.isEmpty {
                EmptyStateView(title: "No Categories", message: "Pull to refresh.", systemImage: "square.grid.2x2")
            } else {
                categoryList
            }
        }
        .navigationTitle("App Directory")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { platformMenu }
        }
        .task { await load() }
        .refreshable { await load(); SoundPlayer.shared.play(.refresh) }
        .onChange(of: platform) { _, _ in Task { await load() } }
        .searchable(text: $searchText, prompt: "Search apps")
        .onChange(of: searchText) { _, newValue in runSearch(newValue) }
        .navigationDestination(for: AppCategoryDestination.self) { dest in
            AppCategoryView(destination: dest)
        }
        .navigationDestination(for: AppListing.self) { app in
            AppDetailView(appId: app.id)
        }
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        if isSearching {
            LoadingView()
        } else if searchResults.isEmpty {
            EmptyStateView(
                title: "No Results",
                message: "No apps match \"\(searchText)\".",
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

    private var platformMenu: some View {
        Menu {
            ForEach(AppPlatform.allCases) { p in
                Button {
                    platform = p
                } label: {
                    if platform == p {
                        Label(p.displayName, systemImage: "checkmark")
                    } else {
                        Text(p.displayName)
                    }
                }
            }
        } label: {
            Label(platform.displayName, systemImage: "chevron.up.chevron.down")
                .labelStyle(.titleOnly)
        }
    }

    private var categoryList: some View {
        List {
            Section {
                // No local Saved filter existed anywhere in the Apps tab
                // (APPS-02) — the master spec's Saved Model explicitly
                // requires "Apps Saved" as a local filter, reachable from
                // within the content area itself, not just via Home/For You.
                NavigationLink(destination: SavedItemsView(initialFilter: .appListing)) {
                    Label("Saved Apps", systemImage: "bookmark")
                }
            }
            ForEach(groupedCategories, id: \.letter) { group in
                Section(group.letter) {
                    ForEach(group.categories) { category in
                        NavigationLink(value: AppCategoryDestination(platform: platform, category: category)) {
                            HStack {
                                Text(category.name)
                                Spacer()
                                Text("\(category.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityLabel(String(localized: "\(category.name), \(category.count) apps"))
                    }
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
        } catch { self.error = "Couldn't load categories." }
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
    @EnvironmentObject private var toast: ToastStore
    @State private var apps: [AppListing] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var page = 0
    @State private var hasMore = false
    @State private var isLoadingMore = false
    @ObservedObject private var networkStatus = NetworkStatusStore.shared

    var body: some View {
        Group {
            if isLoading && apps.isEmpty {
                LoadingView(message: "Loading apps…")
            } else if let error, apps.isEmpty {
                ErrorView(message: error) { await load(reset: true) }
            } else if apps.isEmpty {
                EmptyStateView(
                    title: "No apps yet",
                    message: "Pull to refresh apps",
                    systemImage: "square.grid.2x2"
                )
            } else {
                List {
                    if networkStatus.degradedGroups.contains(.apps) {
                        OfflineBanner()
                            .listRowSeparator(.hidden)
                    }
                    ForEach(apps) { app in
                        AppListingRow(app: app, onDelete: { apps.removeAll { $0.id == app.id } })
                    }
                    if hasMore {
                        ProgressView().frame(maxWidth: .infinity).accessibilityLabel(String(localized: "Loading more…"))
                            .listRowSeparator(.hidden)
                            .task { await loadMore() }
                    }
                }
                .listStyle(.plain)
                .themedList(preferences.colors)
            }
        }
        .navigationTitle(destination.category.name)
        .task { await load(reset: true) }
        .refreshable { await load(reset: true); SoundPlayer.shared.play(.refresh) }
    }

    private func load(reset: Bool) async {
        if reset { page = 0; apps = [] }
        isLoading = true; error = nil
        do {
            let fetched = try await APIClient.shared.apps.list(
                page: page,
                platform: destination.platform,
                categoryTid: destination.category.tid
            )
            apps = fetched.items
            hasMore = fetched.hasMore
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Could not load apps" }
        isLoading = false
    }

    private func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        do {
            let more = try await APIClient.shared.apps.list(
                page: page + 1,
                platform: destination.platform,
                categoryTid: destination.category.tid
            )
            page += 1
            apps += more.items
            hasMore = more.hasMore
        } catch {
            toast.error(String(localized: "Couldn't load more apps."))
        }
        isLoadingMore = false
    }
}
