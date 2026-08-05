import SwiftUI

struct GuideBrowseView: View {
    @State private var resources: [Resource] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var page = 0
    @State private var hasMore = false
    @State private var selectedFilter: GuideFilter = .all
    @State private var searchText = ""
    @State private var isLoadingMore = false
    @ObservedObject private var networkStatus = NetworkStatusStore.shared

    var body: some View {
        Group {
            if isLoading && resources.isEmpty {
                LoadingView()
            } else if let error, resources.isEmpty {
                ErrorView(message: error) { await load(reset: true) }
            } else {
                resourceList
            }
        }
        .navigationTitle("Guides & Resources")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { filterMenu }
        }
        .task { await load(reset: true) }
        .refreshable { await load(reset: true) }
        .searchable(text: $searchText, prompt: "Search guides")
    }

    private var visible: [Resource] {
        guard !searchText.isEmpty else { return resources }
        return resources.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private var resourceList: some View {
        List {
            if networkStatus.degradedGroups.contains(.resources) {
                OfflineBanner()
                    .listRowSeparator(.hidden)
            }
            if !searchText.isEmpty && visible.isEmpty {
                EmptyStateView(title: "No Results", message: "No guides match \"\(searchText)\".", systemImage: "magnifyingglass")
                    .listRowSeparator(.hidden)
            }

            ForEach(visible) { resource in
                ResourceRow(resource: resource)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if hasMore && searchText.isEmpty {
                ProgressView().frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .task { await loadMore() }
            }

            if !resources.isEmpty && !hasMore && searchText.isEmpty {
                Text("\(resources.count) resource\(resources.count == 1 ? "" : "s") loaded")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .accessibilityLabel("\(resources.count) resources loaded.")
            }
        }
        .listStyle(.plain)
    }

    private var filterMenu: some View {
        Menu {
            ForEach(GuideFilter.allCases) { filter in
                Button {
                    selectedFilter = filter
                    Task { await load(reset: true) }
                } label: {
                    if selectedFilter == filter {
                        Label(filter.displayName, systemImage: "checkmark")
                    } else {
                        Text(filter.displayName)
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .accessibilityLabel("Filter guides")
        }
    }

    private func load(reset: Bool) async {
        if reset { page = 0; resources = [] }
        isLoading = true; error = nil
        do {
            let fetched = try await APIClient.shared.resources.list(page: page, categoryTids: selectedFilter.tids)
            resources = fetched
            hasMore = fetched.count >= APIPaging.pageSize
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Couldn't load guides." }
        isLoading = false
    }

    private func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        page += 1
        if let more = try? await APIClient.shared.resources.list(page: page, categoryTids: selectedFilter.tids) {
            resources += more
            hasMore = more.count >= APIPaging.pageSize
        }
        isLoadingMore = false
    }
}

// MARK: - Filter options

enum GuideFilter: String, CaseIterable, Identifiable {
    case all, apps, iOS, iPadOS, macOS, voiceOver, braille, accessories, gaming, misc

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:         return "All"
        case .apps:        return "Apps"
        case .iOS:         return "iOS"
        case .iPadOS:      return "iPadOS"
        case .macOS:       return "macOS"
        case .voiceOver:   return "VoiceOver"
        case .braille:     return "Braille"
        case .accessories: return "Accessories"
        case .gaming:      return "Gaming"
        case .misc:        return "Miscellaneous"
        }
    }

    var tids: [Int] {
        switch self {
        case .all:         return []
        case .apps:        return [27, 28, 115]
        case .iOS:         return [26]
        case .iPadOS:      return [244]
        case .macOS:       return [114]
        case .voiceOver:   return [101]
        case .braille:     return [88]
        case .accessories: return [97]
        case .gaming:      return [90]
        case .misc:        return [31]
        }
    }
}
