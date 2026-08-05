import SwiftUI

// MARK: - App Directory browser (platform → categories → apps)

struct AppBrowseView: View {
    @State private var platform: AppPlatform = .ios
    @State private var categories: [AppCategory] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading && categories.isEmpty {
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
        .refreshable { await load() }
        .onChange(of: platform) { _, _ in Task { await load() } }
        .navigationDestination(for: AppCategoryDestination.self) { dest in
            AppCategoryView(destination: dest)
        }
        .navigationDestination(for: AppListing.self) { app in
            AppDetailView(appId: app.id)
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
                        .accessibilityLabel("\(category.name), \(category.count) apps")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
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
                LoadingView()
            } else if let error, apps.isEmpty {
                ErrorView(message: error) { await load(reset: true) }
            } else if apps.isEmpty {
                EmptyStateView(
                    title: "No Apps",
                    message: "No apps found in this category.",
                    systemImage: "square.grid.2x2"
                )
            } else {
                List {
                    if networkStatus.degradedGroups.contains(.apps) {
                        OfflineBanner()
                            .listRowSeparator(.hidden)
                    }
                    ForEach(apps) { app in
                        AppListingRow(app: app)
                    }
                    if hasMore {
                        ProgressView().frame(maxWidth: .infinity)
                            .listRowSeparator(.hidden)
                            .task { await loadMore() }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(destination.category.name)
        .task { await load(reset: true) }
        .refreshable { await load(reset: true) }
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
            apps = fetched
            hasMore = fetched.count >= APIPaging.pageSize
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Couldn't load apps." }
        isLoading = false
    }

    private func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        page += 1
        if let more = try? await APIClient.shared.apps.list(
            page: page,
            platform: destination.platform,
            categoryTid: destination.category.tid
        ) {
            apps += more
            hasMore = more.count >= APIPaging.pageSize
        }
        isLoadingMore = false
    }
}
