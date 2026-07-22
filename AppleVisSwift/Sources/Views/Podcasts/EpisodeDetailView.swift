import SwiftUI

struct EpisodeDetailView: View {
    let episodeId: String
    @State private var episode: PodcastEpisode?
    @State private var comments: [PodcastComment] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showCompose = false
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore

    var body: some View {
        Group {
            if isLoading && episode == nil {
                LoadingView()
            } else if let err = error, episode == nil {
                ErrorView(message: err) { await load() }
            } else if let episode {
                content(episode)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func content(_ episode: PodcastEpisode) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero
                heroCard(episode).padding()

                // Chapters
                if !episode.chapters.isEmpty {
                    sectionHeading("Chapters")
                    ForEach(episode.chapters) { chapter in
                        ChapterRow(chapter: chapter) {
                            Task { await player.seek(to: chapter.startTime) }
                        }
                        Divider().padding(.leading)
                    }
                }

                // Description
                if !episode.description.isEmpty {
                    sectionHeading("Episode Notes")
                    HTMLTextView(html: episode.description)
                        .padding(.horizontal).padding(.bottom, 16)
                }

                Divider()

                // Comments
                commentsSection

                Color.clear.frame(height: 40)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    Task { await player.load(episode) }
                } label: {
                    Image(systemName: player.currentEpisode?.id == episode.id && player.isPlaying
                          ? "pause.circle" : "play.circle")
                }
                .accessibilityLabel(
                    player.currentEpisode?.id == episode.id && player.isPlaying
                    ? "Pause" : "Play \(episode.title)"
                )

                if auth.isSignedIn {
                    Button { showCompose = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Add comment")
                }
            }
        }
        .sheet(isPresented: $showCompose) {
            if let ep = episode {
                ComposePodcastCommentView(episodeId: ep.id, title: ep.title) { comment in
                    comments.append(comment)
                }
            }
        }
    }

    private func heroCard(_ episode: PodcastEpisode) -> some View {
        HStack(alignment: .top, spacing: 14) {
            AsyncImage(url: episode.artworkUrl.flatMap(URL.init)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.2))
                    .overlay(Image(systemName: "mic.fill").foregroundStyle(.secondary))
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(episode.showTitle)
                    .font(.caption).foregroundStyle(.secondary)
                Text(episode.title)
                    .font(.body).fontWeight(.semibold).lineLimit(3)
                HStack {
                    if let duration = episode.duration {
                        Text(Duration.seconds(duration).formatted(.units(allowed: [.hours, .minutes])))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    RelativeDateLabel(date: episode.publishedAt)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(episode.title) by \(episode.showTitle)")
    }

    private func sectionHeading(_ text: String) -> some View {
        Text(text).font(.headline)
            .padding(.horizontal)
            .padding(.top, 16).padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var commentsSection: some View {
        HStack {
            Text("\(comments.count) Comment\(comments.count == 1 ? "" : "s")")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 4)
        .accessibilityAddTraits(.isHeader)

        if comments.isEmpty {
            Text("No comments yet.")
                .font(.subheadline).foregroundStyle(.secondary)
                .padding(.horizontal).padding(.vertical, 8)
        } else {
            ForEach(comments) { comment in
                CommentRow(authorName: comment.authorName, body: comment.body, date: comment.createdAt)
                Divider().padding(.leading)
            }
        }
    }

    private func load() async {
        isLoading = true; error = nil
        do {
            async let ep = APIClient.shared.podcasts.episode(id: episodeId)
            async let cms = APIClient.shared.podcasts.comments(episodeId: episodeId)
            let (fetchedEp, fetchedComments) = try await (ep, cms)
            episode = fetchedEp
            comments = fetchedComments
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Couldn't load episode." }
        isLoading = false
    }
}

// MARK: - Chapter row

struct ChapterRow: View {
    let chapter: Chapter
    let onSeek: () -> Void

    var body: some View {
        Button(action: onSeek) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(chapter.title).font(.subheadline)
                    Text(formatTime(chapter.startTime))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "play.circle").foregroundStyle(.accent)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(chapter.title), starts at \(formatTime(chapter.startTime)). Double-tap to seek.")
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%d:%02d", m, sec)
    }
}

// MARK: - Compose podcast comment

struct ComposePodcastCommentView: View {
    let episodeId: String
    let title: String
    let onPosted: (PodcastComment) -> Void

    @State private var commentText = ""
    @State private var isSubmitting = false
    @State private var submitError: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Re: \(title)")
                    .font(.subheadline).foregroundStyle(.secondary).padding()
                TextEditor(text: $commentText).padding()
                if let err = submitError {
                    Text(err).foregroundStyle(.red).padding()
                }
            }
            .navigationTitle("Add Comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { Task { await submit() } }
                        .disabled(commentText.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                }
            }
        }
    }

    private func submit() async {
        guard let user = auth.user else { return }
        isSubmitting = true; submitError = nil
        do {
            let comment = try await APIClient.shared.podcasts.submitComment(
                episodeId: episodeId, body: commentText, csrfToken: user.csrfToken
            )
            toast.success("Comment posted")
            onPosted(comment)
            dismiss()
        } catch let e as APIError { submitError = e.localizedDescription
        } catch { submitError = "Failed to post comment." }
        isSubmitting = false
    }
}
