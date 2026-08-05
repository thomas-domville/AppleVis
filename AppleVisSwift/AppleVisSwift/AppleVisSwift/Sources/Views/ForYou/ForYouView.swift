import SwiftUI

struct ForYouView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerStore
    @State private var selectedTab: ForYouTab = .queue

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $selectedTab) {
                    ForEach(ForYouTab.allCases) { tab in
                        Text(tab.displayName).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: selectedTab) { _, _ in
                    SoundPlayer.shared.play(.pickerTick)
                }

                Group {
                    switch selectedTab {
                    case .queue:     QueueView()
                    case .downloads: DownloadsView()
                    case .saved:     SavedItemsView()
                    case .following: FollowingView()
                    }
                }
            }
            .navigationTitle("For You")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if auth.isSignedIn {
                        NavigationLink(destination: ProfileView()) {
                            Image(systemName: "person.circle")
                        }
                    } else {
                        NavigationLink(destination: SignInView()) {
                            Text("Sign In")
                        }
                    }
                }
            }
        }
    }
}

enum ForYouTab: String, CaseIterable, Identifiable {
    case queue, downloads, saved, following

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .queue:     return "Queue"
        case .downloads: return "Downloads"
        case .saved:     return "Saved"
        case .following: return "Following"
        }
    }
}

// MARK: - Downloads

struct DownloadsView: View {
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var tips: TipStore
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @ObservedObject private var downloads = DownloadManager.shared
    @State private var showRemoveAllConfirm = false

    var body: some View {
        Group {
            if downloads.downloadedEpisodes.isEmpty && downloads.activeDownloads.isEmpty {
                EmptyStateView(
                    title: "No Downloads",
                    message: "Download episodes for offline playback from any episode's detail page.",
                    systemImage: "arrow.down.circle"
                )
            } else {
                List {
                    if !downloads.activeDownloads.isEmpty {
                        Section("Downloading") {
                            ForEach(Array(downloads.activeDownloads), id: \.self) { id in
                                let title = downloads.downloadedEpisodes.first { $0.id == id }?.title ?? "Episode"
                                let percent = Int((downloads.progress[id] ?? 0) * 100)
                                HStack {
                                    Text(title)
                                    Spacer()
                                    ProgressView(value: downloads.progress[id] ?? 0)
                                        .frame(width: 60)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(title), downloading, \(percent) percent.")
                            }
                        }
                    }
                    Section {
                        downloadsSummaryHeader
                        ForEach(downloads.downloadedEpisodes, id: \.id) { meta in
                            downloadRow(meta)
                        }
                    }
                    if !downloads.downloadedEpisodes.isEmpty {
                        Button("Remove Downloads", role: .destructive) { showRemoveAllConfirm = true }
                            .frame(maxWidth: .infinity)
                    }
                }
                .onAppear { tips.show(.downloadsOffline) }
                .confirmationDialog(
                    "Remove all \(downloads.downloadedEpisodes.count) downloaded episode\(downloads.downloadedEpisodes.count == 1 ? "" : "s")?",
                    isPresented: $showRemoveAllConfirm, titleVisibility: .visible
                ) {
                    Button("Remove Downloads", role: .destructive) {
                        DownloadManager.shared.deleteAll()
                        UIAccessibility.post(notification: .announcement, argument: "All downloads removed.")
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This deletes downloaded episodes from this device. Queue and Saved items are not affected.")
                }
            }
        }
    }

    private var downloadsSummaryHeader: some View {
        Text("\(downloads.downloadedEpisodes.count) downloaded episode\(downloads.downloadedEpisodes.count == 1 ? "" : "s")")
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
            .accessibilityAction(named: Text("Downloads summary")) {
                let total = downloads.downloadedEpisodes.count
                let totalBytes = downloads.downloadedEpisodes.reduce(0) { $0 + $1.fileSizeBytes }
                UIAccessibility.post(notification: .announcement, argument: total == 0
                    ? "No downloaded episodes."
                    : "\(total) downloaded episode\(total == 1 ? "" : "s"), \(formattedSize(totalBytes)) total.")
            }
    }

    /// Tapping opens the episode's detail page (matches every other row type
    /// in this tab) — previously this only started playback, with no way to
    /// see the episode's description, chapters, or comments from Downloads.
    private func downloadRow(_ meta: DownloadedEpisodeMeta) -> some View {
        let isQueued = player.queue.contains { $0.id == meta.id }
        let isCurrentlyPlaying = player.currentEpisode?.id == meta.id && player.isPlaying

        return Button {
            deepLinkRouter.pendingContent = (kind: .podcastEpisode, id: meta.id)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(meta.title).foregroundStyle(.primary)
                Text(formattedSize(meta.fileSizeBytes))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(meta.title). Downloaded. \(formattedSize(meta.fileSizeBytes)).")
        .accessibilityHint("Double-tap to open episode details.")
        .accessibilityAction(named: Text(isCurrentlyPlaying ? "Pause" : "Play")) {
            Task { await playDownloaded(meta) }
        }
        .accessibilityAction(named: Text(isQueued ? "Remove from Queue" : "Add to Queue")) {
            if isQueued {
                player.removeFromQueue(id: meta.id)
            } else {
                player.enqueue(episode(for: meta))
            }
        }
        .accessibilityAction(named: Text("Remove Download")) {
            downloads.delete(meta.id)
        }
        .swipeActions {
            Button("Delete", role: .destructive) { downloads.delete(meta.id) }
                .accessibilityHidden(true)
        }
    }

    private func episode(for meta: DownloadedEpisodeMeta) -> PodcastEpisode {
        PodcastEpisode(
            id: meta.id, title: meta.title, showTitle: meta.showTitle, audioUrl: "",
            duration: nil, publishedAt: meta.downloadedAt, lastActivityAt: meta.downloadedAt,
            description: "", artworkUrl: nil, transcriptUrl: nil, chapters: [], tags: [],
            commentCount: 0, authorName: "", url: "", isSaved: false, isDownloaded: true, downloadProgress: nil
        )
    }

    private func playDownloaded(_ meta: DownloadedEpisodeMeta) async {
        await player.load(episode(for: meta))
    }

    private func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Saved Items

struct SavedItemsView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var tips: TipStore
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @State private var items: [SavedItem] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var filter: ContentKind? = nil
    @State private var showUnsaveAllConfirm = false

    var filtered: [SavedItem] {
        guard let f = filter else { return items }
        return items.filter { $0.kind == f }
    }

    var body: some View {
        Group {
            if !auth.isSignedIn {
                EmptyStateView(title: "Sign In Required", message: "Sign in to view your saved items.", systemImage: "bookmark")
            } else if isLoading {
                LoadingView()
            } else if let error {
                ErrorView(message: error) { await load() }
            } else if filtered.isEmpty {
                EmptyStateView(title: "Nothing Saved", message: "Tap the bookmark icon on any item to save it.", systemImage: "bookmark")
            } else {
                savedList
            }
        }
        .task { await load() }
    }

    private var savedList: some View {
        List {
            filterPicker
            summaryHeader
            ForEach(filtered) { item in
                Button {
                    deepLinkRouter.pendingContent = (kind: item.kind, id: item.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(item.kind.displayName, systemImage: item.kind.systemImage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(item.title)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "\(item.title). \(item.kind.displayName). Saved \(item.savedAt.formatted(.relative(presentation: .named)))."
                )
                .accessibilityHint("Double-tap to open.")
                .accessibilityAction(named: Text("Open \(item.kind.displayName)")) {
                    deepLinkRouter.pendingContent = (kind: item.kind, id: item.id)
                }
                .accessibilityAction(named: Text("Unsave")) { unsave(item) }
                .swipeActions {
                    Button("Remove", role: .destructive) { unsave(item) }
                        .accessibilityHidden(true)
                }
            }
            if !filtered.isEmpty {
                Button("Unsave All", role: .destructive) { showUnsaveAllConfirm = true }
                    .frame(maxWidth: .infinity)
            }
        }
        .onAppear { tips.show(.savedSwipeActions) }
        .confirmationDialog(
            "Unsave all \(filtered.count) item\(filtered.count == 1 ? "" : "s")?",
            isPresented: $showUnsaveAllConfirm, titleVisibility: .visible
        ) {
            Button("Unsave All", role: .destructive) { unsaveAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes them from Saved. It does not delete the original content.")
        }
    }

    private var summaryHeader: some View {
        let counts = Dictionary(grouping: items, by: { $0.kind }).mapValues(\.count)
        return Text(filter == nil
            ? "\(items.count) item\(items.count == 1 ? "" : "s")"
            : "\(filtered.count) \(filter!.displayName.lowercased())\(filtered.count == 1 ? "" : "s")"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityAddTraits(.isHeader)
        .accessibilityAction(named: Text("Saved summary")) {
            announceSummary(counts: counts)
        }
    }

    private func announceSummary(counts: [ContentKind: Int]) {
        guard !items.isEmpty else {
            UIAccessibility.post(notification: .announcement, argument: "No saved items.")
            return
        }
        let parts = ContentKind.allCases.compactMap { kind -> String? in
            guard let count = counts[kind], count > 0 else { return nil }
            return "\(count) \(kind.displayName.lowercased())\(count == 1 ? "" : "s")"
        }
        UIAccessibility.post(
            notification: .announcement,
            argument: "\(items.count) saved item\(items.count == 1 ? "" : "s"): \(parts.joined(separator: ", "))."
        )
    }

    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                FilterChip(title: "All", isSelected: filter == nil) { filter = nil }
                ForEach(ContentKind.allCases, id: \.self) { kind in
                    FilterChip(title: kind.displayName, isSelected: filter == kind) { filter = kind }
                }
            }
            .padding(.horizontal)
        }
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
    }

    private func unsave(_ item: SavedItem) {
        PersistenceStore.shared.unsave(id: item.id)
        items.removeAll { $0.id == item.id }
    }

    private func unsaveAll() {
        let toRemove = Set(filtered.map(\.id))
        for id in toRemove { PersistenceStore.shared.unsave(id: id) }
        items.removeAll { toRemove.contains($0.id) }
        UIAccessibility.post(notification: .announcement, argument: "Removed saved items.")
    }

    private func load() async {
        guard auth.isSignedIn else { return }
        items = PersistenceStore.shared.savedItems()
    }
}

// MARK: - Following

struct FollowingView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @State private var items: [FollowedItem] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        Group {
            if !auth.isSignedIn {
                EmptyStateView(title: "Sign In Required", message: "Sign in to view topics you're following.", systemImage: "bell")
            } else if isLoading {
                LoadingView()
            } else if let error {
                ErrorView(message: error) { await load() }
            } else if items.isEmpty {
                EmptyStateView(title: "Not Following Anything", message: "Follow forum topics to get notified of new replies.", systemImage: "bell")
            } else {
                List {
                    summaryHeader
                    ForEach(items) { item in
                        Button {
                            deepLinkRouter.pendingContent = (kind: item.kind, id: item.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label(item.kind.displayName, systemImage: item.kind.systemImage)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(item.title)
                                    if let activity = item.lastActivityAt {
                                        RelativeDateLabel(date: activity)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .accessibilityHidden(true)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            "\(item.title). \(item.kind.displayName). Following." +
                            (item.lastActivityAt.map { ", last activity \($0.formatted(.relative(presentation: .named)))." } ?? "")
                        )
                        .accessibilityHint("Double-tap to open.")
                        .accessibilityAction(named: Text("Open \(item.kind.displayName)")) {
                            deepLinkRouter.pendingContent = (kind: item.kind, id: item.id)
                        }
                        .accessibilityAction(named: Text("Unfollow")) { unfollow(item) }
                        .swipeActions {
                            Button("Unfollow", role: .destructive) { unfollow(item) }
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
        .task { await load() }
    }

    private var summaryHeader: some View {
        Text("\(items.count) followed item\(items.count == 1 ? "" : "s")")
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
            .accessibilityAction(named: Text("Following summary")) {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: items.isEmpty ? "No followed items." : "\(items.count) followed item\(items.count == 1 ? "" : "s")."
                )
            }
    }

    private func unfollow(_ item: FollowedItem) {
        items.removeAll { $0.id == item.id }
        PersistenceStore.shared.markUnfollowed(id: item.id)
        guard let user = auth.user else { return }
        Task { try? await APIClient.shared.flags.unfollow(nodeUuid: item.id, token: user.csrfToken) }
    }

    private func load() async {
        guard auth.isSignedIn else { return }
        items = PersistenceStore.shared.followedItems()
    }
}

// MARK: - Filter chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
