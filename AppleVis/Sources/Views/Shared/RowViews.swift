import SwiftUI

/// Visual "N NEW" pill shown when a browse-list row has new replies/comments
/// since it was last visited — same signal Home already surfaces via
/// HomeViewModel.newReplyCount, now available to every row type via
/// PersistenceStore.newReplyCount so it isn't Home-exclusive. Purely visual;
/// the accompanying text lives in each row's accessibility label instead of
/// duplicating it here.
/// Matches RN's `NowPlayingIndicator` — a small animated 3-bar waveform
/// shown next to whichever episode is currently playing, so a low-vision
/// user scanning a list can spot it at a glance instead of relying on the
/// play/pause icon's state alone. Respects Reduce Motion (stays static).
struct NowPlayingWaveform: View {
    var color: Color = .accentColor
    @State private var scales: [CGFloat] = [0.3, 0.6, 0.45]

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(width: 3, height: 14)
                    .scaleEffect(y: scales[i], anchor: .bottom)
            }
        }
        .frame(height: 14)
        .accessibilityHidden(true)
        .onAppear { animate() }
    }

    private func animate() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        for i in 0..<3 {
            let duration = 0.35 + Double(i) * 0.08
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    scales[i] = 1.0
                }
            }
        }
    }
}

/// Builds a row's accessibility label respecting Settings > Accessibility >
/// VoiceOver Detail Level — previously every row hardcoded the "All"-tier
/// content (title, type, author, count, date) regardless of this setting;
/// Simple/Normal never actually read anywhere, so picking them did nothing.
/// `contentType` is always included (title + type is RN's Simple tier);
/// `authorAndCount` is added at Normal and above; `date` only at All.
/// `alwaysAppend` (new-count/saved/following suffixes — Swift-only
/// additions with no RN equivalent tier) is unconditional at every level,
/// since "this has new activity" is exactly the kind of thing a
/// fast-scanning Simple-mode user still wants to hear.
/// Builds "by <author>, <count>" gracefully when `author` is empty (a real,
/// live data gap on some content — a topic with no author on record) rather
/// than producing "by , 39 replies," which read as a data typo rather than
/// a missing name. Reported directly by a VoiceOver user.
func byAuthorAndCount(_ author: String, _ count: String) -> String {
    author.isEmpty ? count : "by \(author), \(count)"
}

/// Omits the leading space when `category` is blank (a topic whose url
/// didn't resolve to a category) rather than reading as a bare, leading-
/// space "topic". Reported directly by a VoiceOver user.
func forumContentType(category: String) -> String {
    category.isEmpty ? "topic" : "\(category) topic"
}

/// Some show titles already end in "Podcast" (e.g. "AppleVis Podcast") —
/// appending " podcast" unconditionally read as "AppleVis Podcast podcast".
/// Reported via a live transcript.
func podcastContentType(showTitle: String) -> String {
    showTitle.localizedCaseInsensitiveContains("podcast") ? showTitle : "\(showTitle) podcast"
}

/// `newActivityLabel` (the "N new comments" phrase) is deliberately its own
/// parameter, not folded into `alwaysAppend` — it needs to sit right next to
/// `authorAndCount`'s comment total so the two related numbers stay
/// adjacent, instead of trailing after `date` and any saved/following/
/// downloaded suffixes where a listener has to hold both numbers in mind
/// across an unrelated date announcement to connect them. Still unconditional
/// at every detail level, same as `alwaysAppend`, so Simple-mode still hears
/// it even though `authorAndCount` itself is skipped there. Reported directly.
func detailLevelLabel(
    title: String,
    contentType: String,
    authorAndCount: String,
    newActivityLabel: String = "",
    date: String,
    alwaysAppend: String
) -> String {
    let level = PreferencesStore.current?.announcementLevel ?? .normal
    var parts = "\(title), \(contentType)"
    if level != .simple, !authorAndCount.isEmpty {
        parts += ", \(authorAndCount)"
    }
    parts += newActivityLabel
    if level == .all {
        parts += ", \(date)"
    }
    return parts + alwaysAppend
}

struct NewCountBadge: View {
    let count: Int
    @EnvironmentObject private var preferences: PreferencesStore

    var body: some View {
        Text("\(count) NEW")
            .font(.caption2).fontWeight(.bold)
            .foregroundStyle(preferences.colors.accentText)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(preferences.colors.unread, in: Capsule())
            .accessibilityHidden(true)
            .modifier(PopInAppearance())
    }
}

/// Self-contained pop-in for `NewCountBadge`/`NewBadge` — animates on its
/// own `.onAppear` rather than requiring every screen that shows one of
/// these (Home, Forums, Podcasts, App Directory, Guides, Blog, and For
/// You's various lists) to wrap its own data-loading state in
/// `withAnimation`. Since List/LazyVStack rows fire `.onAppear` as they're
/// scrolled into view, not just on first load, this also means a badge
/// scrolled to a minute later still pops in rather than only animating for
/// whatever happened to be on screen at launch — closer to "you noticed
/// this is new" than a one-shot load animation. Sighted-only in effect
/// (`accessibilityHidden` above means VoiceOver never sees this element at
/// all, animated or not); respects Reduce Motion. Requested directly.
private struct PopInAppearance: ViewModifier {
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(hasAppeared ? 1 : 0.6)
            .opacity(hasAppeared ? 1 : 0)
            .onAppear {
                withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : .spring(response: 0.35, dampingFraction: 0.6)) {
                    hasAppeared = true
                }
            }
    }
}

/// Plain "NEW" pill for an item with no reply-count baseline yet (see
/// FeedRow.isNew). Rendered inline in the same badge slot each row already
/// reserves for NewCountBadge — previously drawn as a card-level
/// `.overlay(alignment: .topTrailing)` in FeedRow, which sat on top of
/// whatever that row already had in its top-right corner (the relative date,
/// saved/following/queued icons). Reported directly: the badge visually
/// merged with that corner's existing text/icons.
struct NewBadge: View {
    @EnvironmentObject private var preferences: PreferencesStore

    var body: some View {
        Text("NEW")
            .font(.caption2).fontWeight(.bold)
            .foregroundStyle(preferences.colors.accentText)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.accentColor, in: Capsule())
            .accessibilityHidden(true)
            .modifier(PopInAppearance())
    }
}

// MARK: - Forum Topic Row

struct ForumTopicRow: View {
    let topic: ForumTopic
    var isNew: Bool = false
    var onDelete: (() -> Void)? = nil
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var showComposeReply = false
    @State private var translatedTitle: String?

    /// Was previously computed but never surfaced anywhere — a VoiceOver
    /// user browsing a list had no way to tell they'd already saved or
    /// followed a topic short of checking the swipe/rotor action's current
    /// wording. Spoken here, and shown visually via the icons below.
    private var savedFollowingLabel: String {
        switch (topic.isSaved, topic.isFollowing) {
        case (true, true): return ". Saved, following."
        case (true, false): return ". Saved."
        case (false, true): return ". Following."
        case (false, false): return ""
        }
    }

    private var newCount: Int {
        PersistenceStore.shared.newReplyCount(kind: .forumTopic, id: topic.id, currentCount: topic.replyCount)
    }

    var body: some View {
        NavigationLink(value: topic) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label(topic.category, systemImage: "bubble.left.and.bubble.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if newCount > 0 {
                        NewCountBadge(count: newCount)
                    } else if isNew {
                        NewBadge()
                    }
                    if topic.isSaved {
                        Image(systemName: "bookmark.fill").font(.caption2).foregroundStyle(.secondary).accessibilityHidden(true)
                    }
                    if topic.isFollowing {
                        Image(systemName: "bell.fill").font(.caption2).foregroundStyle(.secondary).accessibilityHidden(true)
                    }
                    RelativeDateLabel(date: topic.lastActivityAt)
                }
                HStack(spacing: 4) {
                    Text(translatedTitle ?? topic.title)
                        .font(.body)
                        .lineLimit(2)
                    if translatedTitle != nil { TranslatedTitleBadge() }
                }
                HStack {
                    if !topic.authorName.isEmpty {
                        Text("by \(topic.authorName)")
                    }
                    Spacer()
                    ActivityCountLabel(count: topic.replyCount, noun: "comment")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .overlay(alignment: .leading) {
            Rectangle().fill(ContentKind.forumTopic.accentColor).frame(width: 4).clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(.leading, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(topicLabel)
        .readAloudAction(topicLabel)
        .contentActions(
            id: topic.id, entityId: topic.nid ?? 0, kind: .forumTopic, title: topic.title, lastActivityAt: topic.lastActivityAt, url: topic.url,
            currentCommentCount: topic.replyCount,
            onAddComment: { showComposeReply = true },
            authorId: topic.authorId, onContentDeleted: onDelete
        )
        .cardDensityPadding()
        .sheet(isPresented: $showComposeReply) {
            ComposeReplyView(topicId: topic.id, topicTitle: topic.title) { _ in }
        }
        .task(id: ContentTranslation.taskId(title: topic.title, targetLanguage: preferences.effectiveContentLanguage)) {
            translatedTitle = await ContentTranslation.resolvedTitle(
                kind: "forumTopic", id: topic.id, originalTitle: topic.title, targetLanguage: preferences.effectiveContentLanguage
            )
        }
    }

    private var topicLabel: String {
        // Every other row kind already says "comment(s)" here (see
        // PodcastEpisodeRow/AppListingRow/ResourceRow/BlogPostRow/
        // BugReportRow below) — this was the one holdout still saying
        // "reply"/"replies". "Reply" stays reserved for the actual compose
        // action (Reply to this Comment); this is the
        // generic new-activity count, same word everywhere else. Reported
        // directly.
        let newLabel = newCount > 0 ? ". \(newCount) new comment\(newCount == 1 ? "" : "s")" : ""
        return detailLevelLabel(
            title: ContentTranslation.accessibilityTitle(original: topic.title, translated: translatedTitle),
            // Previously just the category ("iOS/iPadOS Gaming"), with
            // nothing anywhere in the label saying this was a forum topic
            // at all — inconsistent with Podcast rows, which always say
            // "<show> podcast". Reported by a VoiceOver user: different
            // content kinds on Home read structurally differently with no
            // way to tell them apart by ear.
            contentType: forumContentType(category: topic.category),
            authorAndCount: byAuthorAndCount(topic.authorName, "\(topic.replyCount) comment\(topic.replyCount == 1 ? "" : "s")"),
            newActivityLabel: newLabel,
            date: topic.lastActivityAt.formatted(.relative(presentation: .named)),
            alwaysAppend: savedFollowingLabel
        )
    }
}

// MARK: - Podcast Episode Row

struct PodcastEpisodeRow: View {
    let episode: PodcastEpisode
    var isNew: Bool = false
    var onDelete: (() -> Void)? = nil
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var preferences: PreferencesStore
    @ObservedObject private var downloads = DownloadManager.shared
    @State private var showComposeComment = false
    @State private var translatedTitle: String?
    // Grows moderately with Dynamic Type instead of staying pinned at 48pt
    // while the adjacent title (unbounded, .lineLimit(2)) wraps across
    // several lines at the largest accessibility text sizes.
    @ScaledMetric(relativeTo: .body) private var artworkSize: CGFloat = 48
    /// See `PodcastAudioMetadataProbe` — Drupal's `duration` is always 0, so
    /// `episode.duration` alone can't be trusted for display. Read-only
    /// against the cache first; only falls back to a live probe if this
    /// specific episode hasn't been resolved anywhere yet, via `.task`
    /// below, which — same as `ScreenshotThumbnail`'s AI descriptions on
    /// the App Entry page — only fires once this row actually scrolls into
    /// view, not for every row in a long list at once.
    @State private var resolvedDuration: TimeInterval?

    var body: some View {
        NavigationLink(value: episode) {
            HStack(spacing: 12) {
                AsyncImage(url: episode.artworkUrl.flatMap(URL.init)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.secondary)
                }
                .frame(width: artworkSize, height: artworkSize)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.showTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text(translatedTitle ?? episode.title)
                            .font(.body)
                            .lineLimit(2)
                        if translatedTitle != nil { TranslatedTitleBadge() }
                    }
                    HStack {
                        if isCurrentlyPlaying {
                            NowPlayingWaveform()
                        }
                        if let duration = displayDuration {
                            Text(PodcastDuration.abbreviated(duration))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if newCount > 0 {
                            NewCountBadge(count: newCount)
                        } else if isNew {
                            NewBadge()
                        }
                        if episode.isSaved {
                            Image(systemName: "bookmark.fill").font(.caption2).foregroundStyle(.secondary).accessibilityHidden(true)
                        }
                        if isQueued {
                            // Was "text.badge.plus" — the exact same glyph the
                            // swipe/menu action below uses for "tap to add to
                            // queue," so this status badge visually claimed
                            // the opposite of what it meant. Every other badge
                            // in this cluster (Saved, Downloaded) uses its
                            // *.fill counterpart to mean "already done";
                            // "text.badge.plus" has no such counterpart, so
                            // this uses the same family's checkmark variant
                            // instead. VoiceOver was never affected — the
                            // badge is `.accessibilityHidden` and
                            // `savedQueuedLabel` below already speaks "Queued"
                            // correctly.
                            Image(systemName: "text.badge.checkmark").font(.caption2).foregroundStyle(.secondary).accessibilityHidden(true)
                        }
                        if downloads.isDownloaded(episode.id) {
                            Image(systemName: "arrow.down.circle.fill").font(.caption2).foregroundStyle(.secondary).accessibilityHidden(true)
                        }
                        RelativeDateLabel(date: episode.publishedAt)
                    }
                    if let progressText {
                        Text(progressText)
                            .font(.caption2)
                            .foregroundStyle(Color.accentColor)
                            .lineLimit(1)
                    }
                }

                Button {
                    Task { await playOrToggle() }
                } label: {
                    Image(systemName: isCurrentlyPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .leading) {
            Rectangle().fill(ContentKind.podcastEpisode.accentColor).frame(width: 4).clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(.leading, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(episodeLabel)
        .readAloudAction(episodeLabel)
        .accessibilityAction(named: Text(playActionLabel)) {
            Task { await playOrToggle() }
        }
        .accessibilityAction(named: Text(isQueued ? "Remove from Queue" : "Add to Queue")) {
            if isQueued { player.removeFromQueue(id: episode.id) } else { player.enqueue(episode) }
        }
        // Save bookmarks the episode for later; it never implied a download
        // (data usage/storage the user didn't ask for), and Settings already
        // has a separate, opt-in Auto-Download preference for that. But
        // "Download Episode" itself previously only existed on the episode
        // detail screen — a VoiceOver user browsing the list had no way to
        // download for offline listening without opening the episode first.
        // Three-state like the detail screen's downloadButton: download,
        // then cancel-while-in-flight, then remove-once-downloaded — same
        // wording DownloadsView already uses for the latter two, so a user
        // who has heard either place recognizes the other.
        .accessibilityAction(named: Text(downloadActionLabel)) { performDownloadAction() }
        .contentActions(
            id: episode.id, entityId: episode.nid, kind: .podcastEpisode, title: episode.title, lastActivityAt: episode.lastActivityAt, url: episode.url,
            currentCommentCount: episode.commentCount,
            onAddComment: { showComposeComment = true },
            onContentDeleted: onDelete
        ) {
            // These already exist as VoiceOver-only .accessibilityActions
            // above — .accessibilityHidden here keeps this purely a visual
            // addition for sighted long-press users, not a second
            // VoiceOver-announced "Play"/"Add to Queue"/download action.
            Button {
                Task { await playOrToggle() }
            } label: {
                Label(playActionLabel, systemImage: isCurrentlyPlaying ? "pause.circle" : "play.circle")
            }
            .accessibilityHidden(true)
            Button {
                if isQueued { player.removeFromQueue(id: episode.id) } else { player.enqueue(episode) }
            } label: {
                Label(isQueued ? "Remove from Queue" : "Add to Queue", systemImage: isQueued ? "text.badge.minus" : "text.badge.plus")
            }
            .accessibilityHidden(true)
            Button {
                performDownloadAction()
            } label: {
                Label(downloadActionLabel, systemImage: downloadActionSystemImage)
            }
            .accessibilityHidden(true)
        }
        .cardDensityPadding()
        .task { await resolveDurationIfNeeded() }
        .task(id: ContentTranslation.taskId(title: episode.title, targetLanguage: preferences.effectiveContentLanguage)) {
            translatedTitle = await ContentTranslation.resolvedTitle(
                kind: "podcastEpisode", id: episode.id, originalTitle: episode.title, targetLanguage: preferences.effectiveContentLanguage
            )
        }
        .sheet(isPresented: $showComposeComment) {
            ComposePodcastCommentView(episodeId: episode.id, title: episode.title) { _ in }
        }
    }

    private var isCurrentlyPlaying: Bool {
        player.currentEpisode?.id == episode.id && player.isPlaying
    }

    /// `episode.duration` is never trustworthy on its own — 0 from the API
    /// means "unknown," not "zero seconds long" — so this only ever shows
    /// a value once it's genuinely positive, whether that came from the
    /// server (should it ever start sending real data), the resolved-here
    /// cache, or this row's own live probe.
    private var displayDuration: TimeInterval? {
        resolvedDuration ?? episode.duration.flatMap { $0 > 0 ? $0 : nil }
    }

    private var resumePosition: TimeInterval? {
        player.savedPosition(for: episode.id)
    }

    private var progressText: String? {
        guard let resumePosition, !isCurrentlyPlaying else { return nil }
        let total = displayDuration.map { " of \(PodcastDuration.colon($0))" } ?? ""
        return "Paused \(PodcastDuration.colon(resumePosition))\(total)"
    }

    private var progressAccessibilityText: String {
        guard let resumePosition else { return "" }
        return ". Paused at \(PodcastDuration.accessibilityPosition(current: resumePosition, duration: displayDuration))."
    }

    private var playActionLabel: String {
        if isCurrentlyPlaying { return "Pause" }
        return resumePosition == nil ? "Play" : "Resume Episode"
    }

    private func resolveDurationIfNeeded() async {
        guard displayDuration == nil else { return }
        if let cached = PersistenceStore.shared.cachedAudioMetadata(episodeId: episode.id)?.duration {
            resolvedDuration = cached
            return
        }
        guard let probed = await PodcastAudioMetadataProbe.resolveDuration(audioUrl: episode.audioUrl) else { return }
        PersistenceStore.shared.cacheProbedDuration(episodeId: episode.id, duration: probed)
        resolvedDuration = probed
    }

    /// Was entirely missing from this row — every other podcast-episode
    /// surface in the app (ForYouView's saved-episode card) already has
    /// Add to Queue as an action; this shared row (used by Home and every
    /// podcast browse list) never did. Reported directly.
    private var isQueued: Bool {
        player.queue.contains { $0.id == episode.id }
    }

    /// The visible Play/Pause button and its matching VoiceOver action both
    /// showed a "Pause" affordance while this episode was playing, but both
    /// always called `load()` — its own guard only resumes if `!isPlaying`,
    /// so tapping "Pause" while playing was a complete no-op. Same bug
    /// already fixed in ForYouView's podcast rows.
    private func playOrToggle() async {
        if isCurrentlyPlaying {
            player.togglePlayPause()
        } else {
            await player.load(episode)
        }
    }

    private var downloadActionLabel: String {
        if downloads.isDownloaded(episode.id) { return "Remove Download" }
        if downloads.activeDownloads.contains(episode.id) { return "Cancel Download" }
        return "Download Episode"
    }

    private var downloadActionSystemImage: String {
        if downloads.isDownloaded(episode.id) { return "arrow.down.circle.fill" }
        if downloads.activeDownloads.contains(episode.id) { return "xmark.circle" }
        return "arrow.down.circle"
    }

    private func performDownloadAction() {
        if downloads.isDownloaded(episode.id) {
            downloads.delete(episode.id)
        } else if downloads.activeDownloads.contains(episode.id) {
            downloads.cancelDownload(episode.id)
        } else {
            downloads.download(episode)
        }
    }

    private var newCount: Int {
        PersistenceStore.shared.newReplyCount(kind: .podcastEpisode, id: episode.id, currentCount: episode.commentCount)
    }

    private var episodeLabel: String {
        let newLabel = newCount > 0 ? ". \(newCount) new comment\(newCount == 1 ? "" : "s")" : ""
        let downloadedLabel = downloads.isDownloaded(episode.id) ? ". Downloaded." : ""
        let durationText = displayDuration.map { PodcastDuration.accessibilityLabel($0) } ?? ""
        let countText = episode.commentCount > 0 ? "\(episode.commentCount) comment\(episode.commentCount == 1 ? "" : "s")" : ""
        let authorAndCount = [durationText, countText].filter { !$0.isEmpty }.joined(separator: ", ")
        let base = detailLevelLabel(
            title: ContentTranslation.accessibilityTitle(original: episode.title, translated: translatedTitle),
            contentType: podcastContentType(showTitle: episode.showTitle),
            authorAndCount: authorAndCount,
            newActivityLabel: newLabel,
            date: episode.publishedAt.formatted(.relative(presentation: .named)),
            // Paused/remaining position moved ahead of the Saved/Queued/
            // Downloaded badge info instead of tacked onto the very end
            // of the whole label — reported directly: remaining time was
            // being spoken last, after badges that have nothing to do with
            // playback position.
            alwaysAppend: "\(progressAccessibilityText)\(savedQueuedLabel)\(downloadedLabel)"
        )
        // The visible NowPlayingWaveform and play/pause icon are both
        // .accessibilityHidden — nothing else here ever spoke playing state,
        // so a VoiceOver user had no way to tell which row was playing short
        // of opening the rotor and reading the Play/Pause action's current
        // wording (PODCAST-07). Matches QueueView's NowPlayingQueueCard,
        // which already prepends this correctly.
        if isCurrentlyPlaying {
            return String(localized: "Now playing. \(base)")
        }
        return base
    }

    // Mirrors ForumTopicRow's savedFollowingLabel — episode.isSaved existed
    // on the model but was never surfaced here, and the live player queue
    // state had no VoiceOver announcement at all. Reported directly: saved/
    // queued state used to be announced on cards and no longer is.
    private var savedQueuedLabel: String {
        switch (episode.isSaved, isQueued) {
        case (true, true): return ". Saved, queued."
        case (true, false): return ". Saved."
        case (false, true): return ". Queued."
        case (false, false): return ""
        }
    }
}

// MARK: - App Listing Row

struct AppListingRow: View {
    let app: AppListing
    var isNew: Bool = false
    var onDelete: (() -> Void)? = nil
    @EnvironmentObject private var preferences: PreferencesStore
    // See PodcastEpisodeRow.artworkSize — same fixed-vs-scaling mismatch
    // against the adjacent, unbounded app name.
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 48
    @State private var translatedTitle: String?

    var body: some View {
        NavigationLink(value: app) {
            HStack(spacing: 12) {
                AsyncImage(url: app.iconUrl.flatMap(URL.init)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.secondary.opacity(0.2))
                        .overlay(Image(systemName: "square.grid.2x2").foregroundStyle(.secondary))
                }
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(translatedTitle ?? app.name)
                            .font(.body)
                        if translatedTitle != nil { TranslatedTitleBadge() }
                    }
                    if !app.developer.isEmpty {
                        Text(app.developer)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text(app.category)
                        Spacer()
                        if newCount > 0 {
                            NewCountBadge(count: newCount)
                        } else if isNew {
                            NewBadge()
                        }
                        if app.isSaved {
                            Image(systemName: "bookmark.fill").font(.caption2).foregroundStyle(.secondary).accessibilityHidden(true)
                        }
                        RelativeDateLabel(date: app.lastActivityAt)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .overlay(alignment: .leading) {
            Rectangle().fill(ContentKind.appListing.accentColor).frame(width: 4).clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(.leading, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(appLabel)
        .readAloudAction(appLabel)
        // "Open App Entry in Browser" (the generic action every kind gets)
        // opens the Drupal directory page, not the actual App Store listing
        // — reaching the real App Store link previously required opening
        // the detail screen first. Explicit like every other action here
        // (rather than left to the unhidden Link below alone) so a
        // VoiceOver user gets it reliably instead of depending on
        // .contextMenu's own — separate, untested — custom-action bridging.
        .modifier(ConditionalAccessibilityAction(
            isActive: appStoreURL != nil,
            name: "Open in App Store"
        ) {
            guard let appStoreURL else { return }
            UIApplication.shared.open(appStoreURL)
        })
        .contentActions(
            id: app.id, entityId: app.nid ?? 0, kind: .appListing, title: app.name, lastActivityAt: app.lastActivityAt, url: app.url,
            currentCommentCount: app.reviewCount, onContentDeleted: onDelete
        ) {
            // Matches the explicit .accessibilityAction above — hidden so
            // VoiceOver doesn't announce "Open in App Store" a second time.
            // Plain Link, not WebLink — an apps.apple.com URL is a
            // Universal Link that only hands off to the native App Store
            // app when opened externally; SFSafariViewController won't do
            // that handoff, so this needs to stay outside the in-app-
            // browser preference. Matches AppDetailView's own App Store
            // buttons.
            if let appStoreURL {
                Link(destination: appStoreURL) {
                    Label("Open in App Store", systemImage: "arrow.up.forward.app")
                }
                .accessibilityHidden(true)
            }
        }
        .cardDensityPadding()
        .task(id: ContentTranslation.taskId(title: app.name, targetLanguage: preferences.effectiveContentLanguage)) {
            translatedTitle = await ContentTranslation.resolvedTitle(
                kind: "appListing", id: app.id, originalTitle: app.name, targetLanguage: preferences.effectiveContentLanguage
            )
        }
    }

    private var appStoreURL: URL? {
        app.appStoreUrl.flatMap(URL.init)
    }

    private var newCount: Int {
        PersistenceStore.shared.newReplyCount(kind: .appListing, id: app.id, currentCount: app.reviewCount)
    }

    private var appLabel: String {
        let newLabel = newCount > 0 ? ". \(newCount) new comment\(newCount == 1 ? "" : "s")" : ""
        return detailLevelLabel(
            title: ContentTranslation.accessibilityTitle(original: app.name, translated: translatedTitle),
            // Previously just the category ("Games"), with nothing in the
            // label saying this was an app listing at all — see the same
            // fix on ForumTopicRow's contentType for the full reasoning.
            contentType: "\(app.category) app entry",
            // Despite the "reviewCount" field name, list-level counts come
            // from Drupal's comment_count (Mappers.swift), not the separate
            // Reviews feature on the app detail page — "review(s)" here was
            // simply the wrong word. Every other row kind already says
            // "comment(s)"; matched for consistency, reported directly.
            authorAndCount: byAuthorAndCount(app.developer, "\(app.reviewCount) comment\(app.reviewCount == 1 ? "" : "s")"),
            newActivityLabel: newLabel,
            date: app.lastActivityAt.formatted(.relative(presentation: .named)),
            alwaysAppend: app.isSaved ? ". Saved." : ""
        )
    }
}

// MARK: - Resource Row

struct ResourceRow: View {
    let resource: Resource
    var isNew: Bool = false
    var onDelete: (() -> Void)? = nil
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var translatedTitle: String?

    var body: some View {
        NavigationLink(value: resource) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label(resource.kind.displayName, systemImage: resource.kind.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if newCount > 0 {
                        NewCountBadge(count: newCount)
                    } else if isNew {
                        NewBadge()
                    }
                    if resource.isSaved {
                        Image(systemName: "bookmark.fill").font(.caption2).foregroundStyle(.secondary).accessibilityHidden(true)
                    }
                    RelativeDateLabel(date: resource.updatedAt)
                }
                HStack(spacing: 4) {
                    Text(translatedTitle ?? resource.title)
                        .font(.body)
                        .lineLimit(2)
                    if translatedTitle != nil { TranslatedTitleBadge() }
                }
                if !resource.authorName.isEmpty {
                    Text("by \(resource.authorName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .overlay(alignment: .leading) {
            Rectangle().fill(ContentKind.resource.accentColor).frame(width: 4).clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(.leading, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(resourceLabel)
        .readAloudAction(resourceLabel)
        .contentActions(
            id: resource.id, entityId: resource.nid ?? 0, kind: .resource, title: resource.title, lastActivityAt: resource.updatedAt, url: resource.url,
            currentCommentCount: resource.commentCount, onContentDeleted: onDelete
        )
        .cardDensityPadding()
        .task(id: ContentTranslation.taskId(title: resource.title, targetLanguage: preferences.effectiveContentLanguage)) {
            translatedTitle = await ContentTranslation.resolvedTitle(
                kind: "resource", id: resource.id, originalTitle: resource.title, targetLanguage: preferences.effectiveContentLanguage
            )
        }
    }

    private var newCount: Int {
        PersistenceStore.shared.newReplyCount(kind: .resource, id: resource.id, currentCount: resource.commentCount)
    }

    private var resourceLabel: String {
        let newLabel = newCount > 0 ? ". \(newCount) new comment\(newCount == 1 ? "" : "s")" : ""
        return detailLevelLabel(
            title: ContentTranslation.accessibilityTitle(original: resource.title, translated: translatedTitle),
            contentType: resource.kind.displayName,
            authorAndCount: byAuthorAndCount(resource.authorName, "\(resource.commentCount) comment\(resource.commentCount == 1 ? "" : "s")"),
            newActivityLabel: newLabel,
            date: resource.updatedAt.formatted(.relative(presentation: .named)),
            alwaysAppend: resource.isSaved ? ". Saved." : ""
        )
    }
}

// MARK: - Blog Post Row

struct BlogPostRow: View {
    let post: BlogPost
    var isNew: Bool = false
    var onDelete: (() -> Void)? = nil
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var translatedTitle: String?

    var body: some View {
        NavigationLink(value: post) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("Blog", systemImage: "newspaper")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if newCount > 0 {
                        NewCountBadge(count: newCount)
                    } else if isNew {
                        NewBadge()
                    }
                    if post.isSaved {
                        Image(systemName: "bookmark.fill").font(.caption2).foregroundStyle(.secondary).accessibilityHidden(true)
                    }
                    RelativeDateLabel(date: post.lastActivityAt)
                }
                HStack(spacing: 4) {
                    Text(translatedTitle ?? post.title)
                        .font(.body)
                        .lineLimit(2)
                    if translatedTitle != nil { TranslatedTitleBadge() }
                }
                HStack {
                    if !post.authorName.isEmpty {
                        Text("by \(post.authorName)")
                    }
                    Spacer()
                    ActivityCountLabel(count: post.commentCount, noun: "comment")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .overlay(alignment: .leading) {
            Rectangle().fill(ContentKind.blogPost.accentColor).frame(width: 4).clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(.leading, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(postLabel)
        .readAloudAction(postLabel)
        .contentActions(
            id: post.id, entityId: post.nid ?? 0, kind: .blogPost, title: post.title, lastActivityAt: post.lastActivityAt, url: post.url,
            currentCommentCount: post.commentCount, onContentDeleted: onDelete
        )
        .cardDensityPadding()
        .task(id: ContentTranslation.taskId(title: post.title, targetLanguage: preferences.effectiveContentLanguage)) {
            translatedTitle = await ContentTranslation.resolvedTitle(
                kind: "blogPost", id: post.id, originalTitle: post.title, targetLanguage: preferences.effectiveContentLanguage
            )
        }
    }

    private var newCount: Int {
        PersistenceStore.shared.newReplyCount(kind: .blogPost, id: post.id, currentCount: post.commentCount)
    }

    private var postLabel: String {
        let newLabel = newCount > 0 ? ". \(newCount) new comment\(newCount == 1 ? "" : "s")" : ""
        return detailLevelLabel(
            title: ContentTranslation.accessibilityTitle(original: post.title, translated: translatedTitle),
            contentType: "Blog post",
            authorAndCount: byAuthorAndCount(post.authorName, "\(post.commentCount) comment\(post.commentCount == 1 ? "" : "s")"),
            newActivityLabel: newLabel,
            date: post.lastActivityAt.formatted(.relative(presentation: .named)),
            alwaysAppend: post.isSaved ? ". Saved." : ""
        )
    }
}
