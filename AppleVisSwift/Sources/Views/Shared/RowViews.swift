import SwiftUI

// MARK: - Forum Topic Row

struct ForumTopicRow: View {
    let topic: ForumTopic

    var body: some View {
        NavigationLink(value: topic) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label(topic.category, systemImage: "bubble.left.and.bubble.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
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
        .accessibilityLabel("\(topic.title), \(topic.category), \(topic.replyCount) replies, \(topic.lastActivityAt.formatted(.relative(presentation: .named)))")
    }
}

// MARK: - Podcast Episode Row

struct PodcastEpisodeRow: View {
    let episode: PodcastEpisode
    @EnvironmentObject private var player: PlayerStore

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
                        RelativeDateLabel(date: episode.publishedAt)
                    }
                }

                Button {
                    Task { await player.load(episode) }
                } label: {
                    Image(systemName: player.currentEpisode?.id == episode.id && player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.currentEpisode?.id == episode.id && player.isPlaying ? "Pause" : "Play \(episode.title)")
            }
        }
    }
}

// MARK: - App Listing Row

struct AppListingRow: View {
    let app: AppListing

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
                        RelativeDateLabel(date: app.lastActivityAt)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(app.name) by \(app.developer), \(app.category)")
    }
}

// MARK: - Resource Row

struct ResourceRow: View {
    let resource: Resource

    var body: some View {
        NavigationLink(value: resource) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label(resource.kind.displayName, systemImage: resource.kind.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
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
    }
}

// MARK: - Blog Post Row

struct BlogPostRow: View {
    let post: BlogPost

    var body: some View {
        NavigationLink(value: post) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("Blog", systemImage: "newspaper")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
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
    }
}
