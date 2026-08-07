import SwiftUI

/// Visual "N NEW" pill shown when a browse-list row has new replies/comments
/// since it was last visited — same signal Home already surfaces via
/// HomeViewModel.newReplyCount, now available to every row type via
/// PersistenceStore.newReplyCount so it isn't Home-exclusive. Purely visual;
/// the accompanying text lives in each row's accessibility label instead of
/// duplicating it here.
struct NewCountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count) NEW")
            .font(.caption2).fontWeight(.bold)
            .foregroundStyle(.white)
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
                    Text("by \(topic.authorName)")
                    Spacer()
                    ActivityCountLabel(count: topic.replyCount, noun: "reply")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
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
        return "\(topic.title), \(topic.category), \(topic.replyCount) replies, \(topic.lastActivityAt.formatted(.relative(presentation: .named)))\(savedFollowingLabel)\(newLabel)"
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
                        if let duration = episode.duration {
                            Text(Duration.seconds(duration).formatted(.units(allowed: [.hours, .minutes])))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if newCount > 0 {
                            NewCountBadge(count: newCount)
                        }
                        RelativeDateLabel(date: episode.publishedAt)
                    }
                }

                Button {
                    Task { await player.load(episode) }
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
            Task { await player.load(episode) }
        }
        .contentActions(
            id: episode.id, kind: .podcastEpisode, title: episode.title, lastActivityAt: episode.lastActivityAt, url: episode.url,
            currentCommentCount: episode.commentCount,
            onAddComment: { showComposeComment = true },
            onContentDeleted: onDelete
        )
        .cardDensityPadding()
        .sheet(isPresented: $showComposeComment) {
            ComposePodcastCommentView(episodeId: episode.id, title: episode.title) { _ in }
        }
    }

    private var isCurrentlyPlaying: Bool {
        player.currentEpisode?.id == episode.id && player.isPlaying
    }

    private var newCount: Int {
        PersistenceStore.shared.newReplyCount(kind: .podcastEpisode, id: episode.id, currentCount: episode.commentCount)
    }

    private var episodeLabel: String {
        let newLabel = newCount > 0 ? ". \(newCount) new comment\(newCount == 1 ? "" : "s")" : ""
        return "\(episode.title), \(episode.showTitle) podcast" +
        (episode.duration.map { ", \(Duration.seconds($0).formatted(.units(allowed: [.hours, .minutes])))" } ?? "") +
        ", \(episode.publishedAt.formatted(.relative(presentation: .named)))\(newLabel)"
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
                    Text(app.developer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text(app.category)
                        Spacer()
                        if newCount > 0 {
                            NewCountBadge(count: newCount)
                        }
                        RelativeDateLabel(date: app.lastActivityAt)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(appLabel)
        .readAloudAction(appLabel)
        .contentActions(
            id: app.id, kind: .appListing, title: app.name, lastActivityAt: app.lastActivityAt, url: app.url,
            currentCommentCount: app.reviewCount, onContentDeleted: onDelete
        )
        .cardDensityPadding()
    }

    private var newCount: Int {
        PersistenceStore.shared.newReplyCount(kind: .appListing, id: app.id, currentCount: app.reviewCount)
    }

    private var appLabel: String {
        let newLabel = newCount > 0 ? ". \(newCount) new review\(newCount == 1 ? "" : "s")" : ""
        return "\(app.name) by \(app.developer), \(app.category), \(app.lastActivityAt.formatted(.relative(presentation: .named)))\(newLabel)"
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
                    RelativeDateLabel(date: resource.updatedAt)
                }
                Text(resource.title)
                    .font(.body)
                    .lineLimit(2)
                Text("by \(resource.authorName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
        return "\(resource.title), \(resource.kind.displayName), by \(resource.authorName), " +
        "\(resource.updatedAt.formatted(.relative(presentation: .named)))\(newLabel)"
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
                    RelativeDateLabel(date: post.lastActivityAt)
                }
                Text(post.title)
                    .font(.body)
                    .lineLimit(2)
                HStack {
                    Text("by \(post.authorName)")
                    Spacer()
                    ActivityCountLabel(count: post.commentCount, noun: "comment")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
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
        return "\(post.title), Blog post, by \(post.authorName), \(post.commentCount) comment\(post.commentCount == 1 ? "" : "s"), " +
        "\(post.lastActivityAt.formatted(.relative(presentation: .named)))\(newLabel)"
    }
}
