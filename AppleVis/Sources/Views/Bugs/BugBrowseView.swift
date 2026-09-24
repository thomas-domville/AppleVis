import SwiftUI

struct BugBrowseView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var toast: ToastStore
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
    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        Group {
            if isLoading && bugs.isEmpty {
                LoadingView()
            } else if let error, bugs.isEmpty {
                ErrorView(message: error) { await load(reset: true) }
            } else if bugs.isEmpty && searchText.isEmpty {
                // The default .active filter combined with zero currently-
                // active bugs previously rendered a blank list with no
                // explanation (BUGS-01) — worded to reflect the active
                // filter so it doesn't read as "the tracker is empty."
                EmptyStateView(
                    title: "No Bug Reports",
                    message: statusFilter == .active
                        ? "No active bugs for \(platform.displayName) right now."
                        : "No bug reports for \(platform.displayName) right now.",
                    systemImage: "ladybug"
                )
            } else {
                bugList
            }
        }
        .navigationTitle(platform == .ios ? "iOS Bug Tracker" : "macOS Bug Tracker")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { filterMenu }
        }
        .task { await load(reset: true) }
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
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

            ForEach(Array(visible.enumerated()), id: \.element.id) { index, bug in
                let row = NavigationLink(value: bug) {
                    BugReportRow(bug: bug, onDelete: { bugs.removeAll { $0.id == bug.id } })
                }
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

            if !bugs.isEmpty && !hasMore && searchText.isEmpty {
                Text("Reports loaded: \(bugs.count)")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .accessibilityLabel(String(localized: "\(bugs.count) reports loaded."))
            }
        }
        .listStyle(.plain)
        .themedList(preferences.colors)
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
                .accessibilityLabel(String(localized: "Filter bug reports"))
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
            bugs = fetched.items
            hasMore = fetched.hasMore
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Couldn't load bug reports." }
        isLoading = false
    }

    private func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        do {
            let more = try await APIClient.shared.bugReports.list(
                page: page + 1, platform: platform, status: statusFilter
            )
            page += 1
            bugs += more.items
            hasMore = more.hasMore
        } catch {
            toast.error(String(localized: "Couldn't load more bug reports."))
        }
        isLoadingMore = false
    }
}

// MARK: - Bug report row

struct BugReportRow: View {
    let bug: BugReport
    var onDelete: (() -> Void)? = nil
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var translatedTitle: String?

    // BUGS-06: maps severity to a theme-consistent semantic color rather
    // than a fixed system color, so it stays readable/distinct across all
    // 13 palettes (including both high-contrast themes) the same way
    // status already did.
    private var severityColor: Color {
        switch bug.severity {
        case .low: return preferences.colors.success
        case .medium: return preferences.colors.warning
        case .high: return preferences.colors.error
        }
    }

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
                Image(systemName: bug.severity.iconName)
                    .font(.caption)
                    .foregroundStyle(severityColor)
                    .accessibilityHidden(true)
                Text(bug.severity.displayName)
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if newCount > 0 {
                    NewCountBadge(count: newCount)
                }
                RelativeDateLabel(date: bug.changedAt)
            }
            HStack(spacing: 4) {
                Text(translatedTitle ?? bug.title)
                    .font(.body).lineLimit(2)
                if translatedTitle != nil { TranslatedTitleBadge() }
            }
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
        .overlay(alignment: .leading) {
            Rectangle().fill(ContentKind.bugReport.accentColor).frame(width: 4).clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(.leading, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(bugLabel)
        .readAloudAction(bugLabel)
        .contentActions(
            // BugReport (the browse-list row model) carries no `nid` today,
            // unlike BugReportDetail — 0 falls through canOfferFollow's
            // `entityId > 0` guard, so Follow simply doesn't show here
            // rather than attempting a request guaranteed to fail server-side.
            id: bug.id, entityId: 0, kind: .bugReport, title: bug.title, lastActivityAt: bug.changedAt, url: bug.url,
            currentCommentCount: bug.commentCount, onContentDeleted: onDelete
        )
        .cardDensityPadding()
        .task(id: ContentTranslation.taskId(title: bug.title, targetLanguage: preferences.effectiveContentLanguage)) {
            translatedTitle = await ContentTranslation.resolvedTitle(
                kind: "bugReport", id: bug.id, originalTitle: bug.title, targetLanguage: preferences.effectiveContentLanguage
            )
        }
    }

    private var newCount: Int {
        PersistenceStore.shared.newReplyCount(kind: .bugReport, id: bug.id, currentCount: bug.commentCount)
    }

    private var bugLabel: String {
        let newLabel = newCommentsSuffix(newCount) + (newCount > 0 ? "." : "")
        return detailLevelLabel(
            title: ContentTranslation.accessibilityTitle(original: bug.title, translated: translatedTitle),
            contentType: String(localized: "\(bug.status.displayName), \(bug.severity.displayName) severity"),
            authorAndCount: commentCountPhrase(bug.commentCount),
            newActivityLabel: newLabel,
            date: bug.changedAt.formatted(.relative(presentation: .named)),
            alwaysAppend: ""
        )
    }
}
