import SwiftUI

struct ForYouView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerStore
    @State private var selectedTab: ForYouTab = .queue

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Orientation text and section-accent strip are sighted/
                // low-vision affordances, not decoration — RN hid both from
                // VoiceOver (accessibilityElementsHidden, foryou.tsx
                // ~1169-1185) precisely because it already had another way
                // to convey the same info to screen-reader users (the
                // picker's own label/selection announcement), while
                // low-vision users who don't run VoiceOver still benefit
                // from a plain-language explainer and an at-a-glance color
                // cue for which section is active.
                Text("Your personal AppleVis hub. Continue listening, manage downloads, revisit saved items, and keep up with content you follow.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .accessibilityHidden(true)

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

                Rectangle()
                    .fill(selectedTab.accentColor)
                    .frame(height: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .padding(.horizontal)
                    .padding(.top, -8)
                    .padding(.bottom, 8)
                    .accessibilityHidden(true)

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
                // RN's shared header button is always "Profile and
                // Settings" regardless of sign-in state (src/components/
                // Screen.tsx) — ProfileView itself already shows a sign-in
                // prompt when signed out, matching Home's own toolbar
                // button, which never had this swap-to-"Sign In" behavior
                // in the first place. This was a For You-only deviation.
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ProfileView()) {
                        Image(systemName: "person.circle")
                    }
                    .accessibilityLabel(String(localized: "Profile and Settings"))
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

    /// Matches RN's `SECTION_ACCENT` palette (foryou.tsx).
    var accentColor: Color {
        switch self {
        case .queue:     return Color(red: 0.976, green: 0.451, blue: 0.086) // orange
        case .downloads: return Color(red: 0.063, green: 0.725, blue: 0.506) // green
        case .saved:     return Color(red: 0.388, green: 0.400, blue: 0.945) // indigo
        case .following: return Color(red: 0.545, green: 0.361, blue: 0.965) // purple
        }
    }
}

// MARK: - Downloads

struct DownloadsView: View {
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var tips: TipStore
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
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
                                .accessibilityLabel(String(localized: "\(title), downloading, \(percent) percent."))
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
                .refreshable {
                    downloads.applyAutoDeletePolicy()
                    SoundPlayer.shared.play(.refresh)
                    UIAccessibility.post(notification: .announcement, argument: String(localized: "\("Downloads") refreshed"))
                }
                .themedList(preferences.colors)
            }
        }
        .onChange(of: downloads.lastFailure) { _, failure in
            guard let failure else { return }
            toast.error(String(localized: "Couldn't download \"\(failure.episodeTitle)\". Try again."))
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

    /// Tapping the title opens the episode's detail page (matches every
    /// other row type in this tab). Play/Queue are also visible icon
    /// buttons now, not just VoiceOver custom actions — RN showed them as
    /// on-screen pill buttons (foryou.tsx ~499-528), so a sighted user could
    /// use them without opening the episode first, which the Swift version
    /// previously couldn't do.
    private func downloadRow(_ meta: DownloadedEpisodeMeta) -> some View {
        let isQueued = player.queue.contains { $0.id == meta.id }
        let isCurrentlyPlaying = player.currentEpisode?.id == meta.id && player.isPlaying

        return HStack(spacing: 12) {
            Button {
                deepLinkRouter.pendingContent = (kind: .podcastEpisode, id: meta.id)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(meta.title).foregroundStyle(.primary)
                    Text(formattedSize(meta.fileSizeBytes))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button {
                Task { await playDownloaded(meta) }
            } label: {
                Image(systemName: isCurrentlyPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)

            Button {
                if isQueued {
                    player.removeFromQueue(id: meta.id)
                } else {
                    player.enqueue(episode(for: meta))
                }
            } label: {
                Image(systemName: isQueued ? "text.badge.minus" : "text.badge.plus")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(meta.title). Downloaded. \(formattedSize(meta.fileSizeBytes))."))
        .accessibilityHint(String(localized: "Double-tap to open episode details."))
        .readAloudAction(meta.title)
        .accessibilityAction(named: Text(isCurrentlyPlaying ? "Pause" : "Play")) {
            Task { await playDownloaded(meta) }
        }
        .accessibilityAction(named: Text(isQueued ? "Remove from Queue" : "Add to queue")) {
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

    /// The play/pause button and its matching VoiceOver action both showed
    /// a "Pause" affordance while this episode was the one actively
    /// playing, but both always called `load()` — `load()`'s own guard
    /// only resumes if `!isPlaying`, so tapping "Pause" while playing was a
    /// complete no-op, both for sighted taps and VoiceOver's action.
    private func playDownloaded(_ meta: DownloadedEpisodeMeta) async {
        if player.currentEpisode?.id == meta.id && player.isPlaying {
            player.togglePlayPause()
        } else {
            await player.load(episode(for: meta))
        }
    }

    private func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Saved Items

struct SavedItemsView: View {
    @EnvironmentObject private var tips: TipStore
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var items: [SavedItem] = []
    /// Full episode metadata for saved podcasts, fetched on load — Saved
    /// only persists id/kind/title locally (see `SavedItem`), which isn't
    /// enough to show artwork/duration/Play/Queue the way RN's SavedSection
    /// did (foryou.tsx ~707-825), so podcast rows get enriched once this
    /// resolves and fall back to the plain row until then.
    @State private var enrichedEpisodes: [String: PodcastEpisode] = [:]
    @State private var isLoading = false
    @State private var error: String?
    @State private var filter: ContentKind?
    @State private var showUnsaveAllConfirm = false
    @AccessibilityFocusState private var summaryFocused: Bool

    /// Saved has no server concept and needs no sign-in (see
    /// ContentActionsModifier) — this used to gate the whole screen behind
    /// `auth.isSignedIn` even though Save itself works while signed out,
    /// so a signed-out user could save items they could then never see.
    init(initialFilter: ContentKind? = nil) {
        _filter = State(initialValue: initialFilter)
    }

    var filtered: [SavedItem] {
        guard let f = filter else { return items }
        return items.filter { $0.kind == f }
    }

    var body: some View {
        Group {
            if isLoading {
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
                .accessibilityFocused($summaryFocused)
            ForEach(filtered) { item in
                rowView(for: item)
            }
            if !filtered.isEmpty {
                Button("Unsave All", role: .destructive) { showUnsaveAllConfirm = true }
                    .frame(maxWidth: .infinity)
            }
        }
        .onAppear { tips.show(.savedSwipeActions) }
        .refreshable { await load(); SoundPlayer.shared.play(.refresh) }
        .confirmationDialog(
            "Unsave all \(filtered.count) item\(filtered.count == 1 ? "" : "s")?",
            isPresented: $showUnsaveAllConfirm, titleVisibility: .visible
        ) {
            Button("Unsave All", role: .destructive) { unsaveAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes them from Saved. It does not delete the original content.")
        }
        .themedList(preferences.colors)
    }

    @ViewBuilder
    private func rowView(for item: SavedItem) -> some View {
        if item.kind == .podcastEpisode, let episode = enrichedEpisodes[item.id] {
            SavedPodcastEpisodeCard(episode: episode, savedItem: item) {
                removeFromList(item)
            }
        } else {
            genericRow(item)
        }
    }

    private func genericRow(_ item: SavedItem) -> some View {
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
        .overlay(alignment: .leading) {
            Rectangle().fill(item.kind.accentColor).frame(width: 4).clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(.leading, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "\(item.title). \(item.kind.displayName). Saved \(item.savedAt.formatted(.relative(presentation: .named))).")
        )
        .accessibilityHint(String(localized: "Double-tap to open."))
        .readAloudAction(item.title)
        .accessibilityAction(named: Text("Open \(item.kind.displayName)")) {
            deepLinkRouter.pendingContent = (kind: item.kind, id: item.id)
        }
        .contentActions(
            id: item.id, kind: item.kind, title: item.title, lastActivityAt: item.lastActivityAt,
            onSaveToggle: { isSaved in
                guard !isSaved else { return }
                removeFromList(item)
            }
        )
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

    /// Called after a row's own `.contentActions` swipe/context/VoiceOver
    /// unsave already persisted the change — this just prunes it from the
    /// list still on screen and moves focus back to the summary, matching
    /// RN's post-unsave focus handling (foryou.tsx ~611-618).
    private func removeFromList(_ item: SavedItem) {
        items.removeAll { $0.id == item.id }
        enrichedEpisodes.removeValue(forKey: item.id)
        focusSummaryAfterDelay()
    }

    private func unsaveAll() {
        let toRemove = Set(filtered.map(\.id))
        for id in toRemove { PersistenceStore.shared.unsave(id: id) }
        items.removeAll { toRemove.contains($0.id) }
        toast.success(String(localized: "Removed \(toRemove.count) item\(toRemove.count == 1 ? "" : "s") from Saved"))
        UIAccessibility.post(notification: .announcement, argument: "Removed saved items.")
        focusSummaryAfterDelay()
    }

    /// A short delay before moving VoiceOver focus, same pattern Home uses —
    /// setting focus before the List has re-laid-out after a row disappears
    /// is a common way for it to silently fail.
    private func focusSummaryAfterDelay() {
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            summaryFocused = true
        }
    }

    private func load() async {
        items = PersistenceStore.shared.savedItems()
        await enrichPodcastEpisodes()
    }

    private func enrichPodcastEpisodes() async {
        let podcastIds = items.filter { $0.kind == .podcastEpisode }.map(\.id)
        guard !podcastIds.isEmpty else { return }
        await withTaskGroup(of: (String, PodcastEpisode?).self) { group in
            for id in podcastIds where enrichedEpisodes[id] == nil {
                group.addTask { (id, try? await APIClient.shared.podcasts.episode(id: id)) }
            }
            for await (id, episode) in group {
                if let episode { enrichedEpisodes[id] = episode }
            }
        }
    }
}

/// Richer saved-podcast card with artwork, duration, and visible Play/Queue
/// buttons — matches RN's SavedSection treatment for saved episodes
/// (foryou.tsx ~707-825), which every other saved kind doesn't have enough
/// local metadata to support.
private struct SavedPodcastEpisodeCard: View {
    let episode: PodcastEpisode
    let savedItem: SavedItem
    let onUnsave: () -> Void

    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter

    private var isCurrentlyPlaying: Bool {
        player.currentEpisode?.id == episode.id && player.isPlaying
    }
    private var isQueued: Bool {
        player.queue.contains { $0.id == episode.id }
    }

    /// The play/pause button and its matching VoiceOver action both showed
    /// a "Pause" affordance while this episode was actively playing, but
    /// both always called `load()` — its own guard only resumes if
    /// `!isPlaying`, so tapping "Pause" while playing was a complete no-op.
    private func playOrToggle() async {
        if isCurrentlyPlaying {
            player.togglePlayPause()
        } else {
            await player.load(episode)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                deepLinkRouter.pendingContent = (kind: .podcastEpisode, id: episode.id)
            } label: {
                HStack(spacing: 12) {
                    AsyncImage(url: episode.artworkUrl.flatMap(URL.init)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "mic.fill").foregroundStyle(.secondary)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(episode.showTitle).font(.caption).foregroundStyle(.secondary)
                        Text(episode.title).font(.body).lineLimit(2)
                        if let duration = episode.duration {
                            Text(Duration.seconds(duration).formatted(.units(allowed: [.hours, .minutes])))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button {
                Task { await playOrToggle() }
            } label: {
                Image(systemName: isCurrentlyPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)

            Button {
                if isQueued { player.removeFromQueue(id: episode.id) } else { player.enqueue(episode) }
            } label: {
                Image(systemName: isQueued ? "text.badge.minus" : "text.badge.plus")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        }
        .overlay(alignment: .leading) {
            Rectangle().fill(ContentKind.podcastEpisode.accentColor).frame(width: 4).clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(.leading, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "\(episode.title), \(episode.showTitle) podcast, saved \(savedItem.savedAt.formatted(.relative(presentation: .named))).")
        )
        .readAloudAction(episode.title)
        .accessibilityAction(named: Text(isCurrentlyPlaying ? "Pause" : "Play")) {
            Task { await playOrToggle() }
        }
        .accessibilityAction(named: Text(isQueued ? "Remove from Queue" : "Add to queue")) {
            if isQueued { player.removeFromQueue(id: episode.id) } else { player.enqueue(episode) }
        }
        .contentActions(
            id: episode.id, kind: .podcastEpisode, title: episode.title,
            lastActivityAt: episode.lastActivityAt, url: episode.url,
            onSaveToggle: { isSaved in
                guard !isSaved else { return }
                onUnsave()
            }
        )
    }
}

// MARK: - Following

struct FollowingView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var items: [FollowedItem] = []
    @State private var isLoading = false
    @State private var error: String?
    @AccessibilityFocusState private var summaryFocused: Bool

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
                        .accessibilityFocused($summaryFocused)
                    ForEach(items) { item in
                        row(for: item)
                    }
                }
                .refreshable { await load(); SoundPlayer.shared.play(.refresh) }
                .themedList(preferences.colors)
            }
        }
        .task { await load() }
    }

    private func row(for item: FollowedItem) -> some View {
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
        .overlay(alignment: .leading) {
            Rectangle().fill(item.kind.accentColor).frame(width: 4).clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(.leading, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "\(item.title). \(item.kind.displayName). Following.") +
            (item.lastActivityAt.map { String(localized: ", last activity \($0.formatted(.relative(presentation: .named))).") } ?? "")
        )
        .accessibilityHint(String(localized: "Double-tap to open."))
        .readAloudAction(item.title)
        .accessibilityAction(named: Text("Open \(item.kind.displayName)")) {
            deepLinkRouter.pendingContent = (kind: item.kind, id: item.id)
        }
        .contentActions(
            id: item.id, kind: item.kind, title: item.title, lastActivityAt: item.lastActivityAt, url: item.url,
            onFollowToggle: { isFollowing in
                guard !isFollowing else { return }
                items.removeAll { $0.id == item.id }
                focusSummaryAfterDelay()
            }
        )
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

    private func focusSummaryAfterDelay() {
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            summaryFocused = true
        }
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
    @EnvironmentObject private var preferences: PreferencesStore

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : preferences.colors.pill, in: Capsule())
                .foregroundStyle(isSelected ? preferences.colors.accentText : preferences.colors.pillText)
        }
        .buttonStyle(.plain)
    }
}
