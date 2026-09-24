import SwiftUI

struct GuideBrowseView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var toast: ToastStore
    @State private var resources: [Resource] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var page = 0
    @State private var hasMore = false
    @State private var selectedFilter: GuideFilter = .all
    @State private var searchText = ""
    @State private var isLoadingMore = false
    @ObservedObject private var networkStatus = NetworkStatusStore.shared
    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        Group {
            if isLoading && resources.isEmpty {
                LoadingView(message: "Loading guides…")
            } else if let error, resources.isEmpty {
                ErrorView(message: error) { await load(reset: true) }
            } else if resources.isEmpty {
                EmptyStateView(title: "No Guides Yet", message: "Pull to refresh guides", systemImage: "book")
            } else {
                resourceList
            }
        }
        .navigationTitle("Guides")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { filterMenu }
        }
        .task { await load(reset: true) }
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
        .refreshable { await load(reset: true); SoundPlayer.shared.play(.refresh) }
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
                EmptyStateView(title: String(localized: "No Results"), message: String(localized: "No guides match \"\(searchText)\"."), systemImage: "magnifyingglass")
                    .listRowSeparator(.hidden)
            }

            ForEach(Array(visible.enumerated()), id: \.element.id) { index, resource in
                let row = ResourceRow(resource: resource, onDelete: { resources.removeAll { $0.id == resource.id } })
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                if index == 0 {
                    row.accessibilityFocused($isTitleFocused)
                } else {
                    row
                }
            }

            if hasMore && searchText.isEmpty {
                ProgressView().frame(maxWidth: .infinity).accessibilityLabel(String(localized: "Loading more…"))
                    .listRowSeparator(.hidden)
                    .task { await loadMore() }
            }

            if !resources.isEmpty && !hasMore && searchText.isEmpty {
                // No English-only plural "s" slot: most languages don't pluralize
                // with a suffix, and the old "%lld resource%@ loaded" key had
                // picked up translations with two %@ for one argument.
                Text("Guides loaded: \(resources.count)")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .accessibilityLabel(String(localized: "Guides loaded: \(resources.count)"))
            }
        }
        .listStyle(.plain)
        .themedList(preferences.colors)
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
                .accessibilityLabel(String(localized: "Filter guides"))
        }
    }

    private func load(reset: Bool) async {
        if reset { page = 0; resources = [] }
        isLoading = true; error = nil
        do {
            let fetched = try await APIClient.shared.resources.list(page: page, categoryTids: selectedFilter.tids)
            resources = fetched.items
            hasMore = fetched.hasMore
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Couldn't load guides." }
        isLoading = false
    }

    private func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        do {
            let more = try await APIClient.shared.resources.list(page: page + 1, categoryTids: selectedFilter.tids)
            page += 1
            resources += more.items
            hasMore = more.hasMore
        } catch {
            toast.error(String(localized: "Couldn't load more guides."))
        }
        isLoadingMore = false
    }
}

// MARK: - Filter options

enum GuideFilter: String, CaseIterable, Identifiable {
    // iPhone/iPad/Programming were missing entirely — the old app has 3
    // more category filters than this, so guides tagged only under those
    // categories had no dedicated filter to find them by.
    case all, apps, iOS, iPadOS, iPhone, iPad, macOS, voiceOver, braille, accessories, gaming, programming, misc

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:         return "All"
        case .apps:        return "Apps"
        case .iOS:         return "iOS"
        case .iPadOS:      return "iPadOS"
        case .iPhone:      return "iPhone"
        case .iPad:        return "iPad"
        case .macOS:       return "macOS"
        case .voiceOver:   return "VoiceOver"
        case .braille:     return "Braille"
        case .accessories: return "Accessories"
        case .gaming:      return "Gaming"
        case .programming: return String(localized: "Programming")
        case .misc:        return String(localized: "Miscellaneous")
        }
    }

    var tids: [Int] {
        switch self {
        case .all:         return []
        case .apps:        return [27, 28, 115]
        case .iOS:         return [26]
        case .iPadOS:      return [244]
        case .iPhone:      return [93]
        case .iPad:        return [92]
        case .macOS:       return [114]
        case .voiceOver:   return [101]
        case .braille:     return [88]
        case .accessories: return [97]
        case .gaming:      return [90]
        case .programming: return [194, 195]
        case .misc:        return [31]
        }
    }
}
