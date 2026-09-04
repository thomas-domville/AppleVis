import SwiftUI

struct ForYouView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var keyCommands: KeyCommandRouter
    @ObservedObject private var downloads = DownloadManager.shared
    @State private var selectedTab: ForYouTab = .saved
    // Following/Recommended are server-backed, so unlike Saved (a local
    // read), Queue (PlayerStore, already observed above), and Downloads
    // (DownloadManager, observed above), their counts aren't known ambiently
    // — only once that section has actually loaded at least once this
    // session (see FollowingView/RecommendedAppsView's `onLoaded`). nil
    // means "not yet known," not "zero" — the picker shows the plain
    // section name until then rather than a misleading "(0)".
    @State private var followingCount: Int?
    @State private var recommendedCount: Int?
    @AccessibilityFocusState private var isPickerFocused: Bool

    /// "Saved (12)" once a count is known, otherwise just the plain name —
    /// lets someone glance at what's inside each section without opening it,
    /// which the single collapsed picker (chosen over 5 separate segments
    /// for VoiceOver reasons — see the Picker's own comment below) otherwise
    /// hides completely. Requested directly.
    private func pickerLabel(_ tab: ForYouTab) -> String {
        guard let count = itemCount(for: tab) else { return tab.displayName }
        return "\(tab.displayName) (\(count))"
    }

    private func pickerAccessibilityLabel(_ tab: ForYouTab) -> String {
        guard let count = itemCount(for: tab) else { return tab.accessibilityLabel }
        return "\(tab.accessibilityLabel), \(count) item\(count == 1 ? "" : "s")"
    }

    private func itemCount(for tab: ForYouTab) -> Int? {
        switch tab {
        case .saved:       return PersistenceStore.shared.savedItems().count
        case .following:   return followingCount
        case .recommended: return recommendedCount
        case .queue:       return player.queue.count
        case .downloads:   return downloads.downloadedEpisodes.count
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Matches the setup wizard/Welcome Tour convention of a
                // heading announcing the screen name — the tab-switch focus
                // move introduced earlier landed on the section picker
                // instead, which never actually says "For You." Invisible
                // to sighted users so it doesn't duplicate the nav bar
                // title visually. Reported directly.
                Color.clear
                    .frame(width: 0, height: 0)
                    .accessibilityElement()
                    .accessibilityLabel("For You")
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($isPickerFocused)

                // Orientation text and section-accent strip are sighted/
                // low-vision affordances, not decoration — RN hid both from
                // VoiceOver (accessibilityElementsHidden, foryou.tsx
                // ~1169-1185) precisely because it already had another way
                // to convey the same info to screen-reader users (the
                // picker's own label/selection announcement), while
                // low-vision users who don't run VoiceOver still benefit
                // from a plain-language explainer and an at-a-glance color
                // cue for which section is active.
                Text("Your personal AppleVis hub. Revisit saved items, keep up with content you follow, see apps you've recommended, continue listening, and manage downloads.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .accessibilityHidden(true)

                // .menu instead of .segmented — a segmented control puts
                // all four sections on screen as separate adjacent
                // elements, which VoiceOver reads as a row of same-sounding
                // "button"s with no indication they're a connected set. A
                // menu picker collapses to one element announcing the
                // current section, and opens a standard single-choice list
                // to switch — the same pattern already used for the
                // Platform picker in App Directory. Reported directly.
                Picker("Section", selection: $selectedTab) {
                    ForEach(ForYouTab.allCases) { tab in
                        Text(pickerLabel(tab))
                            .tag(tab)
                            .accessibilityLabel(Text(pickerAccessibilityLabel(tab)))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityHint(String(localized: "Choose which For You section to view."))
                // Adds swipe-up/down to move to the next/previous section
                // without giving up the .menu style above — matches the
                // identical addition on App Directory's Platform picker.
                .accessibilityAdjustableAction { direction in
                    guard let idx = ForYouTab.allCases.firstIndex(of: selectedTab) else { return }
                    switch direction {
                    case .increment:
                        selectedTab = ForYouTab.allCases[(idx + 1) % ForYouTab.allCases.count]
                    case .decrement:
                        selectedTab = ForYouTab.allCases[(idx - 1 + ForYouTab.allCases.count) % ForYouTab.allCases.count]
                    @unknown default: break
                    }
                }
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
                    case .saved:       SavedItemsView()
                    case .following:   FollowingView(onLoaded: { followingCount = $0 })
                    case .recommended: RecommendedAppsView(onLoaded: { recommendedCount = $0 })
                    case .queue:       QueueView()
                    case .downloads:   DownloadsView()
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
                    .accessibilityHint(String(localized: "Sign in, manage your account, and access app settings."))
                }
            }
            // TabView keeps every tab's content alive, so this view is
            // never recreated on a later switch back to it — watching
            // selectedTab directly is what catches "the user just switched
            // to For You," matching the announcement ContentView.swift
            // already posts on the same change, so a VoiceOver user's
            // cursor lands on the section picker instead of wherever it
            // happened to be on the previous tab.
            .onChange(of: keyCommands.selectedTab) { _, newTab in
                guard newTab == 2 else { return }
                Task { await retryAccessibilityFocus(into: $isPickerFocused) }
            }
        }
    }
}

enum ForYouTab: String, CaseIterable, Identifiable {
    case saved, following, recommended, queue, downloads

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .saved:       return "Saved"
        case .following:   return "Following"
        case .recommended: return "Recommended"
        case .queue:       return "Queue"
        case .downloads:   return "Downloads"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .saved:       return "Saved Items"
        case .recommended: return "Apps You've Recommended"
        case .queue:       return "Podcast Queue"
        case .downloads:   return "Podcast Downloads"
        default:           return displayName
        }
    }

    /// Matches RN's `SECTION_ACCENT` palette (foryou.tsx).
    var accentColor: Color {
        switch self {
        case .saved:       return Color(red: 0.388, green: 0.400, blue: 0.945) // indigo
        case .following:   return Color(red: 0.545, green: 0.361, blue: 0.965) // purple
        case .recommended: return Color(red: 0.976, green: 0.451, blue: 0.086) // orange
        case .queue:       return Color(red: 0.961, green: 0.620, blue: 0.043) // amber
        case .downloads:   return Color(red: 0.063, green: 0.725, blue: 0.506) // green
        }
    }
}

// MARK: - Downloads

struct DownloadsView: View {
    @EnvironmentObject private var tips: TipStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @ObservedObject private var downloads = DownloadManager.shared
    @State private var showRemoveAllConfirm = false
    @State private var showBrowsePodcasts = false
    /// Had no focus management at all, unlike its Saved/Following/
    /// Recommended siblings — noticed while wiring translation into this
    /// view's rows and fixed alongside it, matching the same pattern
    /// already used in the other three ForYou sections.
    @AccessibilityFocusState private var summaryFocused: Bool

    var body: some View {
        Group {
            if downloads.downloadedEpisodes.isEmpty && downloads.activeDownloads.isEmpty {
                // Previously descriptive text only, no direct next step
                // (FORYOU-07) — a first-time user with nothing downloaded
                // had no path forward besides leaving the tab on their own.
                EmptyStateView(
                    title: "No Downloads",
                    message: "Download episodes for offline playback from any episode's detail page.",
                    systemImage: "arrow.down.circle",
                    primaryActionLabel: "Browse Podcasts",
                    primaryAction: { showBrowsePodcasts = true }
                )
                .sheet(isPresented: $showBrowsePodcasts) {
                    NavigationStack { PodcastBrowseView() }
                }
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
                                // DownloadManager.cancelDownload(_:) existed but
                                // nothing in the app called it anywhere — no one
                                // had a way to stop an unwanted download (PODCAST-03).
                                .accessibilityAction(named: Text("Cancel Download")) {
                                    downloads.cancelDownload(id)
                                }
                                // .accessibilityHidden(true) on this button did not
                                // stop it from also being announced as a bare "Cancel"
                                // custom action alongside "Cancel Download" above — see
                                // VoiceOverAwareSwipeActions's doc comment.
                                .voiceOverAwareSwipeActions {
                                    Button(role: .destructive) {
                                        downloads.cancelDownload(id)
                                    } label: {
                                        Label("Cancel", systemImage: "xmark.circle")
                                    }
                                }
                            }
                        }
                    }
                    Section {
                        downloadsSummaryHeader
                            .accessibilityFocused($summaryFocused)
                        ForEach(downloads.downloadedEpisodes, id: \.id) { meta in
                            DownloadedEpisodeRow(meta: meta)
                        }
                    }
                    if !downloads.downloadedEpisodes.isEmpty {
                        Button("Remove Downloads", role: .destructive) { showRemoveAllConfirm = true }
                            .frame(maxWidth: .infinity)
                    }
                }
                .onAppear { tips.show(.downloadsOffline) }
                .task { await retryAccessibilityFocus(into: $summaryFocused) }
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
        let total = downloads.downloadedEpisodes.count
        return CollectionSummaryHeader(
            text: "\(total) downloaded episode\(total == 1 ? "" : "s")",
            summaryActionName: "Downloads summary",
            onSummaryAction: {
                let totalBytes = downloads.downloadedEpisodes.reduce(0) { $0 + $1.fileSizeBytes }
                UIAccessibility.post(notification: .announcement, argument: total == 0
                    ? "No downloaded episodes."
                    : "\(total) downloaded episode\(total == 1 ? "" : "s"), \(formattedSize(totalBytes)) total.")
            },
            bulkActionName: total == 0 ? nil : "Remove All Downloads",
            onBulkAction: total == 0 ? nil : { showRemoveAllConfirm = true }
        )
    }

    private func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

/// Shared by `DownloadsView` (its summary header) and `DownloadedEpisodeRow`
/// below — factored out to file scope (rather than duplicated, or left as
/// `DownloadsView` instance methods `DownloadedEpisodeRow` can't reach) once
/// the row itself needed extracting into its own View struct for
/// per-row `@State`.
fileprivate func downloadedEpisodePlaceholder(for meta: DownloadedEpisodeMeta) -> PodcastEpisode {
    PodcastEpisode(
        id: meta.id, nid: 0, title: meta.title, showTitle: meta.showTitle, audioUrl: "",
        duration: nil, publishedAt: meta.downloadedAt, lastActivityAt: meta.downloadedAt,
        description: "", artworkUrl: nil, transcriptUrl: nil, chapters: [], tags: [],
        commentCount: 0, authorName: "", url: "", isSaved: false, isDownloaded: true, downloadProgress: nil
    )
}

/// Tapping the title opens the episode's detail page (matches every other
/// row type in this tab). Play/Queue are also visible icon buttons, not
/// just VoiceOver custom actions — RN showed them as on-screen pill buttons
/// (foryou.tsx ~499-528), so a sighted user could use them without opening
/// the episode first.
///
/// Extracted out of `DownloadsView.downloadRow(_:)` — same reasoning as
/// `GenericSavedItemRow`/`FollowedItemRow`/`RecommendedAppRow`:
/// `translatedTitle` needs its own per-row `@State`. `kind: "podcastEpisode"`
/// (not a distinct "downloadedEpisode" kind) deliberately reuses
/// `PodcastEpisodeRow`'s cache namespace — `DownloadedEpisodeMeta.id` is set
/// straight from `episode.id` at download time (`DownloadManager.download`),
/// so this is genuinely the same episode id space, not a coincidental match.
private struct DownloadedEpisodeRow: View {
    let meta: DownloadedEpisodeMeta
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @EnvironmentObject private var preferences: PreferencesStore
    @ObservedObject private var downloads = DownloadManager.shared
    @State private var translatedTitle: String?

    private var isQueued: Bool {
        player.queue.contains { $0.id == meta.id }
    }
    private var isCurrentlyPlaying: Bool {
        player.currentEpisode?.id == meta.id && player.isPlaying
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                deepLinkRouter.pendingContent = (kind: .podcastEpisode, id: meta.id)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(translatedTitle ?? meta.title).foregroundStyle(.primary)
                        if translatedTitle != nil { TranslatedTitleBadge() }
                    }
                    Text(formattedSize(meta.fileSizeBytes))
                        .font(.caption).foregroundStyle(.secondary)
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
                if isQueued {
                    player.removeFromQueue(id: meta.id)
                } else {
                    player.enqueue(downloadedEpisodePlaceholder(for: meta))
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
        .accessibilityLabel(String(localized: "\(ContentTranslation.accessibilityTitle(original: meta.title, translated: translatedTitle)). Downloaded. \(formattedSize(meta.fileSizeBytes))."))
        .accessibilityHint(String(localized: "Double-tap to open episode details."))
        .readAloudAction(ContentTranslation.accessibilityTitle(original: meta.title, translated: translatedTitle))
        .accessibilityAction(named: Text(isCurrentlyPlaying ? "Pause" : "Play")) {
            Task { await playOrToggle() }
        }
        .accessibilityAction(named: Text(isQueued ? "Remove from Queue" : "Add to Queue")) {
            if isQueued {
                player.removeFromQueue(id: meta.id)
            } else {
                player.enqueue(downloadedEpisodePlaceholder(for: meta))
            }
        }
        .accessibilityAction(named: Text("Remove Download")) {
            downloads.delete(meta.id)
        }
        // .accessibilityHidden(true) on this button did not stop it from
        // also being announced as a bare "Remove" custom action alongside
        // "Remove Download" above — see VoiceOverAwareSwipeActions's doc
        // comment. Matches the VoiceOver action ("Remove Download") and the
        // bulk "Remove Downloads" button — a Voice Control user who hears
        // one name from VoiceOver but sees "Delete" on the swipe button
        // itself has no way to know they're the same action.
        .voiceOverAwareSwipeActions {
            Button("Remove", role: .destructive) { downloads.delete(meta.id) }
        }
        .task(id: ContentTranslation.taskId(title: meta.title, targetLanguage: preferences.effectiveContentLanguage)) {
            translatedTitle = await ContentTranslation.resolvedTitle(
                kind: "podcastEpisode", id: meta.id, originalTitle: meta.title, targetLanguage: preferences.effectiveContentLanguage
            )
        }
    }

    /// The play/pause button and its matching VoiceOver action both showed
    /// a "Pause" affordance while this episode was the one actively
    /// playing, but both always called `load()` — `load()`'s own guard
    /// only resumes if `!isPlaying`, so tapping "Pause" while playing was a
    /// complete no-op, both for sighted taps and VoiceOver's action.
    private func playOrToggle() async {
        if isCurrentlyPlaying {
            player.togglePlayPause()
        } else {
            await player.load(downloadedEpisodePlaceholder(for: meta))
        }
    }

    private func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Saved Items

struct SavedItemsView: View {
    @EnvironmentObject private var tips: TipStore
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
    @State private var showBrowseContent = false
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
                // Distinguishes "you have other saved items, just none of
                // this filtered kind" from "you have nothing saved at all"
                // (FORYOU-08) — previously both showed the identical
                // generic empty state with no way back to "show everything."
                if filter != nil && !items.isEmpty {
                    EmptyStateView(
                        title: "No Saved Items of This Kind",
                        message: "You have other saved items — clear the filter to see them.",
                        systemImage: "bookmark",
                        primaryActionLabel: "Clear Filter",
                        primaryAction: { filter = nil }
                    )
                } else {
                    EmptyStateView(
                        title: "Nothing Saved",
                        message: "Tap the bookmark icon on any item to save it.",
                        systemImage: "bookmark",
                        primaryActionLabel: "Browse Content",
                        primaryAction: { showBrowseContent = true }
                    )
                    .sheet(isPresented: $showBrowseContent) {
                        NavigationStack { DiscoverView() }
                    }
                }
            } else {
                savedList
            }
        }
        // `load()` is a cheap local read plus an idempotent enrichment fetch
        // (guarded on ids not already cached), so re-running it on every
        // reappearance is safe.
        .loadOnAppearAndTask(load)
        // Previously only focused the summary after a delete/remove action
        // — the section's own initial appearance (switching to Saved for
        // the first time) got no explicit focus at all. A plain `.task`
        // (not `.onAppear`) only fires once per view identity, unlike
        // `loadOnAppearAndTask` above, so this doesn't re-focus on every
        // return to an already-loaded section. Noticed while wiring
        // translation into this section's rows and fixed alongside it.
        .task { await retryAccessibilityFocus(into: $summaryFocused) }
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
            GenericSavedItemRow(item: item) {
                removeFromList(item)
            }
        }
    }

    private var summaryHeader: some View {
        let counts = Dictionary(grouping: items, by: { $0.kind }).mapValues(\.count)
        return CollectionSummaryHeader(
            text: filter == nil
                ? "\(items.count) item\(items.count == 1 ? "" : "s")"
                : "\(filtered.count) \(filter!.displayNamePlural(filtered.count))",
            summaryActionName: "Saved summary",
            onSummaryAction: { announceSummary(counts: counts) },
            bulkActionName: filtered.isEmpty ? nil : "Unsave All",
            onBulkAction: filtered.isEmpty ? nil : { showUnsaveAllConfirm = true }
        )
    }

    private func announceSummary(counts: [ContentKind: Int]) {
        guard !items.isEmpty else {
            UIAccessibility.post(notification: .announcement, argument: "No saved items.")
            return
        }
        let parts = ContentKind.allCases.compactMap { kind -> String? in
            guard let count = counts[kind], count > 0 else { return nil }
            return "\(count) \(kind.displayNamePlural(count))"
        }
        UIAccessibility.post(
            notification: .announcement,
            argument: "\(items.count) saved item\(items.count == 1 ? "" : "s"): \(parts.joined(separator: ", "))."
        )
    }

    private var filterPicker: some View {
        HStack {
            Label("Show", systemImage: "line.3.horizontal.decrease.circle")
                .foregroundStyle(.secondary)
            Spacer()
            Picker("Show Saved Items", selection: $filter) {
                Text("All Saved Items").tag(nil as ContentKind?)
                ForEach(ContentKind.allCases, id: \.self) { kind in
                    Text(kind.savedFilterName).tag(kind as ContentKind?)
                }
            }
            .pickerStyle(.menu)
            .accessibilityHint(String(localized: "Filters the saved items list by content type."))
            // Same swipe-up/down addition as the Section/Platform pickers —
            // moves to the next/previous filter without opening the menu.
            .accessibilityAdjustableAction { direction in
                let options: [ContentKind?] = [nil] + ContentKind.allCases
                guard let idx = options.firstIndex(where: { $0 == filter }) else { return }
                switch direction {
                case .increment:
                    filter = options[(idx + 1) % options.count]
                case .decrement:
                    filter = options[(idx - 1 + options.count) % options.count]
                @unknown default: break
                }
            }
        }
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

    /// Retries at each delay rather than a single guessed one — setting
    /// focus before the List has re-laid-out after a row disappears is a
    /// common way for a single attempt to silently fail on a slower device.
    private func focusSummaryAfterDelay() {
        Task {
            await retryAccessibilityFocus(into: $summaryFocused)
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

/// Non-podcast (and not-yet-enriched podcast) saved rows — extracted out of
/// `SavedItemsView.rowView(for:)` into its own struct (mirroring
/// `SavedPodcastEpisodeCard` below) so `translatedTitle` gets its own
/// per-row `@State` storage; a plain helper function can't own `@State`
/// distinct per call, only a View struct's own stored properties can.
private struct GenericSavedItemRow: View {
    let item: SavedItem
    let onUnsave: () -> Void
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var translatedTitle: String?

    var body: some View {
        Button {
            deepLinkRouter.pendingContent = (kind: item.kind, id: item.id)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label(item.kind.displayName, systemImage: item.kind.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text(translatedTitle ?? item.title)
                        if translatedTitle != nil { TranslatedTitleBadge() }
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
            String(localized: "\(ContentTranslation.accessibilityTitle(original: item.title, translated: translatedTitle)). \(item.kind.displayName). Saved \(item.savedAt.formatted(.relative(presentation: .named))).")
        )
        .accessibilityHint(String(localized: "Double-tap to open."))
        .readAloudAction(ContentTranslation.accessibilityTitle(original: item.title, translated: translatedTitle))
        .accessibilityAction(named: Text("Open \(item.kind.displayName)")) {
            deepLinkRouter.pendingContent = (kind: item.kind, id: item.id)
        }
        .contentActions(
            id: item.id, kind: item.kind, title: item.title, lastActivityAt: item.lastActivityAt,
            onSaveToggle: { isSaved in
                guard !isSaved else { return }
                onUnsave()
            }
        )
        .task(id: ContentTranslation.taskId(title: item.title, targetLanguage: preferences.effectiveContentLanguage)) {
            translatedTitle = await ContentTranslation.resolvedTitle(
                kind: item.kind.rawValue, id: item.id, originalTitle: item.title, targetLanguage: preferences.effectiveContentLanguage
            )
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
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var translatedTitle: String?

    private var isCurrentlyPlaying: Bool {
        player.currentEpisode?.id == episode.id && player.isPlaying
    }
    private var isQueued: Bool {
        player.queue.contains { $0.id == episode.id }
    }

    /// Drupal's `duration` is hardcoded to 0, never nil (see
    /// `PodcastAudioMetadataProbe`), so `episode.duration` alone can't be
    /// trusted for display — falls back to whatever the browse row/detail
    /// page may have already resolved and cached, read-only: this card
    /// doesn't trigger its own live probe, since by the time an episode is
    /// saved it's already been encountered on one of those primary paths.
    private var displayDuration: TimeInterval? {
        if let duration = episode.duration, duration > 0 { return duration }
        return PersistenceStore.shared.cachedAudioMetadata(episodeId: episode.id)?.duration
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
                        HStack(spacing: 4) {
                            Text(translatedTitle ?? episode.title).font(.body).lineLimit(2)
                            if translatedTitle != nil { TranslatedTitleBadge() }
                        }
                        if let duration = displayDuration {
                            Text(PodcastDuration.abbreviated(duration))
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
            String(localized: "\(ContentTranslation.accessibilityTitle(original: episode.title, translated: translatedTitle)), \(episode.showTitle) podcast") +
            (displayDuration.map { String(localized: ", \(PodcastDuration.accessibilityLabel($0))") } ?? "") +
            String(localized: ", saved \(savedItem.savedAt.formatted(.relative(presentation: .named))).")
        )
        .readAloudAction(ContentTranslation.accessibilityTitle(original: episode.title, translated: translatedTitle))
        .accessibilityAction(named: Text(isCurrentlyPlaying ? "Pause" : "Play")) {
            Task { await playOrToggle() }
        }
        .accessibilityAction(named: Text(isQueued ? "Remove from Queue" : "Add to Queue")) {
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
        .task(id: ContentTranslation.taskId(title: episode.title, targetLanguage: preferences.effectiveContentLanguage)) {
            translatedTitle = await ContentTranslation.resolvedTitle(
                kind: "podcastEpisode", id: episode.id, originalTitle: episode.title, targetLanguage: preferences.effectiveContentLanguage
            )
        }
    }
}

// MARK: - Following

struct FollowingView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var items: [FollowedItem] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showBrowseForums = false
    @AccessibilityFocusState private var summaryFocused: Bool
    /// Reports the loaded count back to ForYouView so its section picker
    /// can show "Following (3)" once this section has been visited at
    /// least once this session — Following is server-backed, so unlike
    /// Saved/Queue/Downloads the count isn't known ambiently without a
    /// fetch. Requested directly.
    var onLoaded: ((Int) -> Void)? = nil

    var body: some View {
        Group {
            if !auth.isSignedIn {
                EmptyStateView(title: "Sign In Required", message: "Sign in to view topics you're following.", systemImage: "bell")
            } else if isLoading {
                LoadingView()
            } else if let error {
                ErrorView(message: error) { await load() }
            } else if items.isEmpty {
                EmptyStateView(
                    title: "Not Following Anything",
                    message: "Follow forum topics to get notified of new replies.",
                    systemImage: "bell",
                    primaryActionLabel: "Browse Forums",
                    primaryAction: { showBrowseForums = true }
                )
                .sheet(isPresented: $showBrowseForums) {
                    NavigationStack { ForumsBrowseView() }
                }
            } else {
                List {
                    summaryHeader
                        .accessibilityFocused($summaryFocused)
                    ForEach(items) { item in
                        FollowedItemRow(item: item) {
                            items.removeAll { $0.id == item.id }
                            focusSummaryAfterDelay()
                        }
                    }
                }
                .refreshable { await load(); SoundPlayer.shared.play(.refresh) }
                .themedList(preferences.colors)
            }
        }
        .loadOnAppearAndTask(load)
        // A plain `.task` (not `.onAppear`) only fires once per view
        // identity, unlike `loadOnAppearAndTask` above, so this doesn't
        // re-focus on every return to an already-loaded section. Full
        // noticed while wiring translation into this section's rows and
        // fixed alongside it.
        .task { await retryAccessibilityFocus(into: $summaryFocused) }
    }

    private var summaryHeader: some View {
        CollectionSummaryHeader(
            text: "\(items.count) followed item\(items.count == 1 ? "" : "s")",
            summaryActionName: "Following summary",
            onSummaryAction: {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: items.isEmpty ? "No followed items." : "\(items.count) followed item\(items.count == 1 ? "" : "s")."
                )
            }
        )
    }

    private func focusSummaryAfterDelay() {
        Task {
            await retryAccessibilityFocus(into: $summaryFocused)
        }
    }

    /// Confirmed against the site's own "Subscriptions" page: same
    /// `subscribe_node` flag, so this is a real server fetch (not just
    /// `PersistenceStore.followedItems()`, which only ever knew about
    /// follows made inside this app) — otherwise anyone who followed
    /// something on the website first would see an empty list here.
    private func load() async {
        guard auth.isSignedIn, let user = auth.user else { return }
        isLoading = items.isEmpty
        error = nil
        do {
            items = try await APIClient.shared.flags.followedItems(uid: user.uuid, csrfToken: user.csrfToken)
        } catch let e as APIError {
            // Falls back to whatever's cached locally rather than showing
            // an empty/error state outright — still better than nothing if
            // the server fetch fails.
            let local = PersistenceStore.shared.followedItems()
            if !local.isEmpty {
                items = local
            } else {
                error = e.localizedDescription
            }
        } catch {
            let local = PersistenceStore.shared.followedItems()
            if !local.isEmpty {
                items = local
            } else {
                self.error = "Couldn't load your followed items."
            }
        }
        isLoading = false
        if error == nil { onLoaded?(items.count) }
    }
}

/// Extracted out of `FollowingView.row(for:)` the same way `GenericSavedItemRow`
/// was extracted out of Saved's `genericRow` — a plain helper function can't
/// own per-call `@State`, so `translatedTitle` needs its own View struct.
private struct FollowedItemRow: View {
    let item: FollowedItem
    let onUnfollow: () -> Void
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var translatedTitle: String?

    var body: some View {
        Button {
            deepLinkRouter.pendingContent = (kind: item.kind, id: item.id)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label(item.kind.displayName, systemImage: item.kind.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text(translatedTitle ?? item.title)
                        if translatedTitle != nil { TranslatedTitleBadge() }
                    }
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
            String(localized: "\(ContentTranslation.accessibilityTitle(original: item.title, translated: translatedTitle)). \(item.kind.displayName). Following.") +
            (item.lastActivityAt.map { String(localized: ", last activity \($0.formatted(.relative(presentation: .named))).") } ?? "")
        )
        .accessibilityHint(String(localized: "Double-tap to open."))
        .readAloudAction(ContentTranslation.accessibilityTitle(original: item.title, translated: translatedTitle))
        .accessibilityAction(named: Text("Open \(item.kind.displayName)")) {
            deepLinkRouter.pendingContent = (kind: item.kind, id: item.id)
        }
        .contentActions(
            id: item.id, kind: item.kind, title: item.title, lastActivityAt: item.lastActivityAt, url: item.url,
            onFollowToggle: { isFollowing in
                guard !isFollowing else { return }
                onUnfollow()
            }
        )
        .task(id: ContentTranslation.taskId(title: item.title, targetLanguage: preferences.effectiveContentLanguage)) {
            translatedTitle = await ContentTranslation.resolvedTitle(
                kind: item.kind.rawValue, id: item.id, originalTitle: item.title, targetLanguage: preferences.effectiveContentLanguage
            )
        }
    }
}

// MARK: - Recommended Apps

/// Apps this person has recommended — a real server-backed list (see
/// `FlagEndpoints.recommendedApps`), unlike Saved/Following which are
/// tracked purely on-device: someone's recommendation history very likely
/// predates ever installing this app, so a local-only cache would show
/// nothing for an existing member.
struct RecommendedAppsView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var toast: ToastStore
    @State private var apps: [RecommendedApp] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showBrowseApps = false
    @AccessibilityFocusState private var summaryFocused: Bool
    /// Same purpose as FollowingView's `onLoaded` — lets ForYouView's
    /// section picker show "Recommended (5)" once this section has loaded
    /// at least once this session.
    var onLoaded: ((Int) -> Void)? = nil

    var body: some View {
        Group {
            if !auth.isSignedIn {
                EmptyStateView(title: "Sign In Required", message: "Sign in to view apps you've recommended.", systemImage: "hand.thumbsup")
            } else if isLoading {
                LoadingView()
            } else if let error {
                ErrorView(message: error) { await load() }
            } else if apps.isEmpty {
                EmptyStateView(
                    title: "No Recommendations Yet",
                    message: "When you recommend an app from its App Directory page, it shows up here.",
                    systemImage: "hand.thumbsup",
                    primaryActionLabel: "Browse App Directory",
                    primaryAction: { showBrowseApps = true }
                )
                .sheet(isPresented: $showBrowseApps) {
                    NavigationStack { AppBrowseView() }
                }
            } else {
                List {
                    summaryHeader
                        .accessibilityFocused($summaryFocused)
                    ForEach(apps) { app in
                        RecommendedAppRow(app: app) {
                            Task { await unrecommend(app) }
                        }
                    }
                }
                .refreshable { await load(); SoundPlayer.shared.play(.refresh) }
                .themedList(preferences.colors)
            }
        }
        .loadOnAppearAndTask(load)
        // A plain `.task` (not `.onAppear`) only fires once per view
        // identity, unlike `loadOnAppearAndTask` above, so this doesn't
        // re-focus on every return to an already-loaded section. Full
        // noticed while wiring translation into this section's rows and
        // fixed alongside it.
        .task { await retryAccessibilityFocus(into: $summaryFocused) }
    }

    private var summaryHeader: some View {
        CollectionSummaryHeader(
            text: "\(apps.count) recommended app\(apps.count == 1 ? "" : "s")",
            summaryActionName: "Recommendations summary",
            onSummaryAction: {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: apps.isEmpty ? "No recommended apps." : "\(apps.count) recommended app\(apps.count == 1 ? "" : "s")."
                )
            }
        )
    }

    private func load() async {
        guard auth.isSignedIn, let user = auth.user else { return }
        isLoading = apps.isEmpty
        error = nil
        do {
            apps = try await APIClient.shared.flags.recommendedApps(uid: user.uuid, csrfToken: user.csrfToken)
        } catch let e as APIError {
            error = e.localizedDescription
        } catch {
            self.error = "Couldn't load your recommendations."
        }
        isLoading = false
        if error == nil { onLoaded?(apps.count) }
    }

    private func unrecommend(_ app: RecommendedApp) async {
        guard let user = auth.user else { return }
        do {
            try await APIClient.shared.flags.unrecommend(nodeUuid: app.id, token: user.csrfToken)
            apps.removeAll { $0.id == app.id }
            toast.success(String(localized: "Removed from Recommendations"))
            UIAccessibility.post(notification: .announcement, argument: "Removed \(app.title) from your recommendations.")
        } catch let e as APIError {
            toast.error(e.localizedDescription)
        } catch {
            toast.error(String(localized: "Couldn't remove this recommendation."))
        }
    }
}

/// Extracted out of `RecommendedAppsView.row(for:)` — same reasoning as
/// `GenericSavedItemRow`/`FollowedItemRow`: `translatedTitle` needs its own
/// per-row `@State`, which only a View struct's stored property can provide.
/// `kind: "appListing"` (not a distinct "recommendedApp" kind) deliberately
/// reuses `AppListingRow`'s cache namespace — `RecommendedApp.id` is the same
/// JSON:API node UUID `AppListing.id` uses (both come straight off
/// `flagged_entity`/`node.id`, see `ContentEndpoints.recommendedApps` and
/// `Mappers.swift`'s `AppListing(id: node.id, ...)`), so an app already
/// translated on a browse/detail screen is a free cache hit here too.
private struct RecommendedAppRow: View {
    let app: RecommendedApp
    let onUnrecommend: () -> Void
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var translatedTitle: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label(app.platformLabel, systemImage: "square.grid.2x2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text(translatedTitle ?? app.title)
                    if translatedTitle != nil { TranslatedTitleBadge() }
                }
                RelativeDateLabel(date: app.recommendedAt)
            }
            Spacer()
        }
        .padding(.leading, 6)
        .overlay(alignment: .leading) {
            Rectangle().fill(ContentKind.appListing.accentColor).frame(width: 4).clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "\(ContentTranslation.accessibilityTitle(original: app.title, translated: translatedTitle)). \(app.platformLabel). Recommended \(app.recommendedAt.formatted(.relative(presentation: .named))).")
        )
        .accessibilityAction(named: Text("I No Longer Recommend This App")) {
            onUnrecommend()
        }
        .voiceOverAwareSwipeActions {
            Button(role: .destructive) {
                onUnrecommend()
            } label: {
                Label("Remove", systemImage: "hand.thumbsdown")
            }
        }
        .task(id: ContentTranslation.taskId(title: app.title, targetLanguage: preferences.effectiveContentLanguage)) {
            translatedTitle = await ContentTranslation.resolvedTitle(
                kind: "appListing", id: app.id, originalTitle: app.title, targetLanguage: preferences.effectiveContentLanguage
            )
        }
    }
}

private extension ContentKind {
    var savedFilterName: String {
        switch self {
        case .forumTopic:     return "Forum Topics"
        case .podcastEpisode: return "Podcast Episodes"
        case .appListing:     return "Apps"
        case .resource:       return "Guides"
        case .blogPost:       return "Blog Posts"
        case .bugReport:      return "Bug Reports"
        }
    }
}
