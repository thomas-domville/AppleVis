import SwiftUI

struct BugBrowseView: View {
    @State private var bugs: [BugReport] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var page = 0
    @State private var hasMore = false
    @State private var platform: BugPlatform = .ios
    @State private var statusFilter: BugStatus? = .active
    @State private var searchText = ""
    @State private var isLoadingMore = false
    @ObservedObject private var networkStatus = NetworkStatusStore.shared

    var body: some View {
        Group {
            if isLoading && bugs.isEmpty {
                LoadingView()
            } else if let error, bugs.isEmpty {
                ErrorView(message: error) { await load(reset: true) }
            } else {
                bugList
            }
        }
        .navigationTitle(platform == .ios ? "iOS Bug Tracker" : "macOS Bug Tracker")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { filterMenu }
        }
        .task { await load(reset: true) }
        .refreshable { await load(reset: true); SoundPlayer.shared.play(.refresh) }
        .searchable(text: $searchText, prompt: "Search bug reports")
    }

    private var visible: [BugReport] {
        guard !searchText.isEmpty else { return bugs }
        return bugs.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private var bugList: some View {
        List {
            if networkStatus.degradedGroups.contains(.bugs) {
                OfflineBanner()
                    .listRowSeparator(.hidden)
            }
            if !searchText.isEmpty && visible.isEmpty {
                EmptyStateView(
                    title: "No Results",
                    message: "No reports match \"\(searchText)\".",
                    systemImage: "magnifyingglass"
                )
                .listRowSeparator(.hidden)
            }

            ForEach(visible) { bug in
                NavigationLink(value: bug) {
                    BugReportRow(bug: bug)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if hasMore && searchText.isEmpty {
                ProgressView().frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .task { await loadMore() }
            }

            if !bugs.isEmpty && !hasMore && searchText.isEmpty {
                Text("\(bugs.count) report\(bugs.count == 1 ? "" : "s") loaded")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .accessibilityLabel("\(bugs.count) reports loaded.")
            }
        }
        .listStyle(.plain)
    }

    private var filterMenu: some View {
        Menu {
            Section("Platform") {
                ForEach(BugPlatform.allCases) { p in
                    Button {
                        platform = p
                        Task { await load(reset: true) }
                    } label: {
                        if platform == p {
                            Label(p.displayName, systemImage: "checkmark")
                        } else {
                            Text(p.displayName)
                        }
                    }
                }
            }
            Section("Status") {
                Button {
                    statusFilter = .active
                    Task { await load(reset: true) }
                } label: {
                    if statusFilter == .active {
                        Label("Active Only", systemImage: "checkmark")
                    } else {
                        Text("Active Only")
                    }
                }
                Button {
                    statusFilter = nil
                    Task { await load(reset: true) }
                } label: {
                    if statusFilter == nil {
                        Label("All Bugs", systemImage: "checkmark")
                    } else {
                        Text("All Bugs")
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .accessibilityLabel("Filter bug reports")
        }
    }

    private func load(reset: Bool) async {
        if reset { page = 0; bugs = [] }
        isLoading = true; error = nil
        do {
            let fetched = try await APIClient.shared.bugReports.list(
                page: page,
                platform: platform,
                status: statusFilter
            )
            bugs = fetched
            hasMore = fetched.count >= APIPaging.pageSize
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Couldn't load bug reports." }
        isLoading = false
    }

    private func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        page += 1
        if let more = try? await APIClient.shared.bugReports.list(
            page: page, platform: platform, status: statusFilter
        ) {
            bugs += more
            hasMore = more.count >= APIPaging.pageSize
        }
        isLoadingMore = false
    }
}

// MARK: - Bug report row

struct BugReportRow: View {
    let bug: BugReport

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Status dot
                Circle()
                    .fill(bug.status == .active ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(bug.status.displayName)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(bug.status == .active ? .orange : .green)
                Text("·")
                    .font(.caption).foregroundStyle(.secondary)
                Text(bug.severity.displayName)
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                RelativeDateLabel(date: bug.changedAt)
            }
            Text(bug.title)
                .font(.body).lineLimit(2)
            HStack {
                if let fixedIn = bug.fixedIn {
                    Text("Fixed in \(fixedIn)")
                        .font(.caption).foregroundStyle(.secondary)
                } else if let firstSeen = bug.firstSeen {
                    Text("First seen in \(firstSeen)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if bug.commentCount > 0 {
                    ActivityCountLabel(count: bug.commentCount, noun: "comment")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(bug.title). \(bug.status.displayName). \(bug.severity.displayName) severity. " +
            "\(bug.commentCount) comments."
        )
    }
}
