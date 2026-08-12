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

func detailLevelLabel(
    title: String,
    contentType: String,
    authorAndCount: String,
    date: String,
    alwaysAppend: String
) -> String {
    let level = PreferencesStore.current?.announcementLevel ?? .normal
    var parts = "\(title), \(contentType)"
    if level != .simple, !authorAndCount.isEmpty {
        parts += ", \(authorAndCount)"
    }
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
            .background(Color.accentColor, in: Capsule())
            .accessibilityHidden(true)
    }
}

// MARK: - Forum Topic Row

struct ForumTopicRow: View {
    let topic: ForumTopic
    var onDelete: (() -> Void)? = nil
    @State private var showComposeReply = false

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
                    }
                    if topic.isSaved {
                        Image(systemName: "bookmark.fill").font(.caption2).foregroundStyle(.secondary).accessibilityHidden(true)
                    }
                    if topic.isFollowing {
                        Image(systemName: "bell.fill").font(.caption2).foregroundStyle(.secondary).accessibilityHidden(true)
                    }
                    RelativeDateLabel(date: topic.lastActivityAt)
                }
                Text(topic.title)
                    .font(.body)
                    .lineLimit(2)
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
            id: topic.id, kind: .forumTopic, title: topic.title, lastActivityAt: topic.lastActivityAt, url: topic.url,
            currentCommentCount: topic.replyCount,
            onAddComment: { showComposeReply = true },
            authorId: topic.authorId, onContentDeleted: onDelete
        )
        .cardDensityPadding()
        .sheet(isPresented: $showComposeReply) {
            ComposeReplyView(topicId: topic.id, topicTitle: topic.title) { _ in }
        }
    }

    private var topicLabel: String {
        let newLabel = newCount > 0 ? ". \(newCount) new repl\(newCount == 1 ? "y" : "ies")" : ""
        return detailLevelLabel(
            title: topic.title,
            // Previously just the category ("iOS/iPadOS Gaming"), with
            // nothing anywhere in the label saying this was a forum topic
            // at all — inconsistent with Podcast rows, which always say
            // "<show> podcast". Reported by a VoiceOver user: different
            // content kinds on Home read structurally differently with no
            // way to tell them apart by ear.
            // categoryFromForumURL falls back to "" when a topic's url
            // doesn't match /forum/{category}/{slug} (e.g. an unaliased
            // /node/{nid} path) — omit the leading space rather than
            // reading as a bare, uninformative "topic".
            contentType: topic.category.isEmpty ? "topic" : "\(topic.category) topic",
            authorAndCount: byAuthorAndCount(topic.authorName, "\(topic.replyCount) comment\(topic.replyCount == 1 ? "" : "s")"),
            date: topic.lastActivityAt.formatted(.relative(presentation: .named)),
            alwaysAppend: "\(savedFollowingLabel)\(newLabel)"
        )
    }
}

// MARK: - Podcast Episode Row

struct PodcastEpisodeRow: View {
    let episode: PodcastEpisode
    var onDelete: (() -> Void)? = nil
    @EnvironmentObject private var player: PlayerStore
    @State private var showComposeComment = false

    var body: some View {
        NavigationLink(value: episode) {
            HStack(spacing: 12) {
                AsyncImage(url: episode.artworkUrl.flatMap(URL.init)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.secondary)
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.showTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(episode.title)
                        .font(.body)
                        .lineLimit(2)
                    HStack {
                        if isCurrentlyPlaying {
                            NowPlayingWaveform()
                        }
                        if let duration = episode.duration {
                            Text(Duration.seconds(duration).formatted(.units(allowed: [.hours, .minutes])))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if newCount > 0 {
                            NewCountBadge(count: newCount)
                        }
                        if episode.isSaved {
                            Image(systemName: "bookmark.fill").font(.caption2).foregroundStyle(.secondary).accessibilityHidden(true)
                        }
                        if isQueued {
                            Image(systemName: "text.badge.plus").font(.caption2).foregroundStyle(.secondary).accessibilityHidden(true)
                        }
                        RelativeDateLabel(date: episode.publishedAt)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(episodeLabel)
        .readAloudAction(episodeLabel)
        .accessibilityAction(named: Text(isCurrentlyPlaying ? "Pause" : "Play")) {
            Task { await playOrToggle() }
        }
        .accessibilityAction(named: Text(isQueued ? "Remove from Queue" : "Add to queue")) {
            if isQueued { player.removeFromQueue(id: episode.id) } else { player.enqueue(episode) }
        }
        .contentActions(
            id: episode.id, kind: .podcastEpisode, title: episode.title, lastActivityAt: episode.lastActivityAt, url: episode.url,
            currentCommentCount: episode.commentCount,
            onAddComment: { showComposeComment = true },
            onContentDeleted: onDelete
        ) {
            // These already exist as VoiceOver-only .accessibilityActions
            // above — .accessibilityHidden here keeps this purely a visual
            // addition for sighted long-press users, not a second
            // VoiceOver-announced "Play"/"Add to Queue".
            Button {
                Task { await playOrToggle() }
            } label: {
                Label(isCurrentlyPlaying ? "Pause" : "Play", systemImage: isCurrentlyPlaying ? "pause.circle" : "play.circle")
            }
            .accessibilityHidden(true)
            Button {
                if isQueued { player.removeFromQueue(id: episode.id) } else { player.enqueue(episode) }
            } label: {
                Label(isQueued ? "Remove from Queue" : "Add to Queue", systemImage: isQueued ? "text.badge.minus" : "text.badge.plus")
            }
            .accessibilityHidden(true)
        }
        .cardDensityPadding()
        .sheet(isPresented: $showComposeComment) {
            ComposePodcastCommentView(episodeId: episode.id, title: episode.title) { _ in }
        }
    }

    private var isCurrentlyPlaying: Bool {
        player.currentEpisode?.id == episode.id && player.isPlaying
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

    private var newCount: Int {
        PersistenceStore.shared.newReplyCount(kind: .podcastEpisode, id: episode.id, currentCount: episode.commentCount)
    }

    private var episodeLabel: String {
        let newLabel = newCount > 0 ? ". \(newCount) new comment\(newCount == 1 ? "" : "s")" : ""
        let durationText = episode.duration.map { Duration.seconds($0).formatted(.units(allowed: [.hours, .minutes])) } ?? ""
        let countText = episode.commentCount > 0 ? "\(episode.commentCount) comment\(episode.commentCount == 1 ? "" : "s")" : ""
        let authorAndCount = [durationText, countText].filter { !$0.isEmpty }.joined(separator: ", ")
        return detailLevelLabel(
            title: episode.title,
            // Some show titles already end in "Podcast" (e.g. "AppleVis
            // Podcast") — appending " podcast" unconditionally read as
            // "AppleVis Podcast podcast". Reported via a live transcript.
            contentType: episode.showTitle.localizedCaseInsensitiveContains("podcast")
                ? episode.showTitle : "\(episode.showTitle) podcast",
            authorAndCount: authorAndCount,
            date: episode.publishedAt.formatted(.relative(presentation: .named)),
            alwaysAppend: "\(savedQueuedLabel)\(newLabel)"
        )
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
    var onDelete: (() -> Void)? = nil

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
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name)
                        .font(.body)
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
        .contentActions(
            id: app.id, kind: .appListing, title: app.name, lastActivityAt: app.lastActivityAt, url: app.url,
            currentCommentCount: app.reviewCount, onContentDeleted: onDelete
        ) {
            // "Open App Entry in Browser" (the generic action every kind
            // gets) opens the Drupal directory page, not the actual App
            // Store listing — previously reaching the real App Store link
            // required opening the detail screen first, which already has
            // this exact action. Long-pressing straight from the row now
            // reaches it directly.
            if let appStoreUrl = app.appStoreUrl, let storeURL = URL(string: appStoreUrl) {
                Link(destination: storeURL) {
                    Label("Open in App Store", systemImage: "arrow.up.forward.app")
                }
            }
        }
        .cardDensityPadding()
    }

    private var newCount: Int {
        PersistenceStore.shared.newReplyCount(kind: .appListing, id: app.id, currentCount: app.reviewCount)
    }

    private var appLabel: String {
        let newLabel = newCount > 0 ? ". \(newCount) new comment\(newCount == 1 ? "" : "s")" : ""
        return detailLevelLabel(
            title: app.name,
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
            date: app.lastActivityAt.formatted(.relative(presentation: .named)),
            alwaysAppend: "\(app.isSaved ? ". Saved." : "")\(newLabel)"
        )
    }
}

// MARK: - Resource Row

struct ResourceRow: View {
    let resource: Resource
    var onDelete: (() -> Void)? = nil

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
                    }
                    if resource.isSaved {
                        Image(systemName: "bookmark.fill").font(.caption2).foregroundStyle(.secondary).accessibilityHidden(true)
                    }
                    RelativeDateLabel(date: resource.updatedAt)
                }
                Text(resource.title)
                    .font(.body)
                    .lineLimit(2)
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
            id: resource.id, kind: .resource, title: resource.title, lastActivityAt: resource.updatedAt, url: resource.url,
            currentCommentCount: resource.commentCount, onContentDeleted: onDelete
        )
        .cardDensityPadding()
    }

    private var newCount: Int {
        PersistenceStore.shared.newReplyCount(kind: .resource, id: resource.id, currentCount: resource.commentCount)
    }

    private var resourceLabel: String {
        let newLabel = newCount > 0 ? ". \(newCount) new comment\(newCount == 1 ? "" : "s")" : ""
        return detailLevelLabel(
            title: resource.title,
            contentType: resource.kind.displayName,
            authorAndCount: byAuthorAndCount(resource.authorName, "\(resource.commentCount) comment\(resource.commentCount == 1 ? "" : "s")"),
            date: resource.updatedAt.formatted(.relative(presentation: .named)),
            alwaysAppend: "\(resource.isSaved ? ". Saved." : "")\(newLabel)"
        )
    }
}

// MARK: - Blog Post Row

struct BlogPostRow: View {
    let post: BlogPost
    var onDelete: (() -> Void)? = nil

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
                    }
                    if post.isSaved {
                        Image(systemName: "bookmark.fill").font(.caption2).foregroundStyle(.secondary).accessibilityHidden(true)
                    }
                    RelativeDateLabel(date: post.lastActivityAt)
                }
                Text(post.title)
                    .font(.body)
                    .lineLimit(2)
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
            id: post.id, kind: .blogPost, title: post.title, lastActivityAt: post.lastActivityAt, url: post.url,
            currentCommentCount: post.commentCount, onContentDeleted: onDelete
        )
        .cardDensityPadding()
    }

    private var newCount: Int {
        PersistenceStore.shared.newReplyCount(kind: .blogPost, id: post.id, currentCount: post.commentCount)
    }

    private var postLabel: String {
        let newLabel = newCount > 0 ? ". \(newCount) new comment\(newCount == 1 ? "" : "s")" : ""
        return detailLevelLabel(
            title: post.title,
            contentType: "Blog post",
            authorAndCount: byAuthorAndCount(post.authorName, "\(post.commentCount) comment\(post.commentCount == 1 ? "" : "s")"),
            date: post.lastActivityAt.formatted(.relative(presentation: .named)),
            alwaysAppend: "\(post.isSaved ? ". Saved." : "")\(newLabel)"
        )
    }
}
