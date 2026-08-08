import SwiftUI

struct EpisodeDetailView: View {
    let episodeId: String
    @State private var episode: PodcastEpisode?
    @State private var comments: [PodcastComment] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showCompose = false
    @State private var quotedComment: PodcastComment?
    @State private var showTranscript = false
    @State private var isLoadingMoreComments = false
    @State private var hasMoreComments = true
    @State private var artworkDescription: String?
    @AccessibilityFocusState private var isTitleFocused: Bool
    @AccessibilityFocusState private var focusedCommentId: String?
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var tips: TipStore
    @EnvironmentObject private var preferences: PreferencesStore
    @ObservedObject private var downloads = DownloadManager.shared

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
        .handoff(title: episode?.title, url: episode?.url)
        .task {
            SoundPlayer.shared.play(.articleOpen)
            await load()
        }
        .task(id: episode?.artworkUrl) {
            guard let artworkUrl = episode?.artworkUrl, let url = URL(string: artworkUrl) else { return }
            artworkDescription = await ImageDescriber.describe(imageAt: url)
        }
        .onChange(of: downloads.lastFailure) { _, failure in
            guard let failure, failure.episodeId == episode?.id else { return }
            toast.error("Couldn't download \"\(failure.episodeTitle)\". Try again.")
        }
    }

    @ViewBuilder
    private func content(_ episode: PodcastEpisode) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero
                    heroCard(episode).padding()

                    // Chapters
                    if !episode.chapters.isEmpty {
                        sectionHeading("Chapters")
                            .onAppear { tips.show(.episodeChapters) }
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
                        SegmentedHTMLView(html: episode.description)
                            .padding(.horizontal).padding(.bottom, 16)
                    }

                    Divider()

                    // Comments
                    commentsSection(episode: episode, proxy: proxy)

                    Color.clear.frame(height: 40)
                }
            }
            .background(preferences.colors.background)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    if player.currentEpisode?.id == episode.id {
                        player.togglePlayPause()
                    } else {
                        Task { await player.load(episode) }
                    }
                } label: {
                    Image(systemName: player.currentEpisode?.id == episode.id && player.isPlaying
                          ? "pause.circle" : "play.circle")
                }
                .accessibilityLabel(
                    player.currentEpisode?.id == episode.id && player.isPlaying
                    ? "Pause" : "Play \(episode.title)"
                )

                downloadButton(episode)

                if let transcriptUrl = episode.transcriptUrl, !transcriptUrl.isEmpty {
                    Button { showTranscript = true } label: {
                        Image(systemName: "text.quote")
                    }
                    .accessibilityLabel(String(localized: "View Transcript"))
                }

                if auth.isSignedIn {
                    Button { showCompose = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel(String(localized: "Add comment"))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            ContentDetailActions(id: episode.id, kind: .podcastEpisode, title: episode.title, lastActivityAt: episode.lastActivityAt, url: episode.url)
        }
        .sheet(isPresented: $showCompose) {
            ComposePodcastCommentView(episodeId: episode.id, title: episode.title) { comment in
                comments.append(comment)
            }
        }
        .sheet(item: $quotedComment) { target in
            ComposePodcastCommentView(episodeId: episode.id, title: episode.title, quotedComment: target) { comment in
                comments.append(comment)
            }
        }
        .sheet(isPresented: $showTranscript) {
            TranscriptView(episodeId: episode.id, episodeTitle: episode.title)
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
        .accessibilityLabel(
            "\(episode.title) by \(episode.showTitle)" +
            (artworkDescription.map { ". Artwork \($0)" } ?? "")
        )
        .accessibilityAddTraits(.isHeader)
        .accessibilityFocused($isTitleFocused)
    }

    @ViewBuilder
    private func downloadButton(_ episode: PodcastEpisode) -> some View {
        if downloads.isDownloaded(episode.id) {
            Button {
                downloads.delete(episode.id)
            } label: {
                Image(systemName: "arrow.down.circle.fill")
            }
            .accessibilityLabel(String(localized: "Downloaded"))
            .accessibilityHint(String(localized: "Double-tap to remove download."))
        } else if downloads.activeDownloads.contains(episode.id) {
            ProgressView(value: downloads.progress[episode.id] ?? 0)
                .progressViewStyle(.circular)
                .accessibilityLabel("Downloading, \(Int((downloads.progress[episode.id] ?? 0) * 100)) percent")
        } else {
            Button {
                downloads.download(episode)
            } label: {
                Image(systemName: "arrow.down.circle")
            }
            .accessibilityLabel(String(localized: "Download for offline playback"))
        }
    }

    private func sectionHeading(_ text: String) -> some View {
        Text(text).font(.headline)
            .padding(.horizontal)
            .padding(.top, 16).padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func commentsSection(episode: PodcastEpisode, proxy: ScrollViewProxy) -> some View {
        CommunityDiscussionHeading(
            count: episode.commentCount,
            onThreadOverview: { announceThreadOverview() },
            onJumpToLast: { Task { await jumpToLastComment(proxy: proxy) } }
        )

        if comments.isEmpty {
            Text("No comments yet.")
                .font(.subheadline).foregroundStyle(.secondary)
                .padding(.horizontal).padding(.vertical, 8)
        } else {
            ForEach(Array(comments.enumerated()), id: \.element.id) { index, comment in
                CommentRow(
                    authorName: comment.authorName, text: comment.body, date: comment.createdAt,
                    index: index, total: comments.count,
                    subject: comment.subject, parentTitle: episode.title,
                    commentId: comment.id, authorId: comment.authorId, commentType: "comment_node_podcast",
                    onDelete: {
                        comments.removeAll { $0.id == comment.id }
                    },
                    onEdit: { newText in
                        guard let idx = comments.firstIndex(where: { $0.id == comment.id }) else { return }
                        comments[idx] = PodcastComment(id: comment.id, authorName: comment.authorName, authorId: comment.authorId, subject: comment.subject, body: newText, createdAt: comment.createdAt)
                    },
                    onReplyTo: {
                        guard auth.isSignedIn else {
                            toast.warning(String(localized: "Sign in to reply to comments."))
                            return
                        }
                        quotedComment = comment
                    },
                    focusBinding: $focusedCommentId
                )
                .id(comment.id)
                Divider().padding(.leading)
            }

            if hasMoreComments {
                if isLoadingMoreComments {
                    ProgressView().frame(maxWidth: .infinity).padding()
                } else {
                    let remaining = episode.commentCount - comments.count
                    Button(remaining > 0 ? "Load \(remaining) More Comments" : "Load More Comments") {
                        Task { await loadMoreComments() }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
        }
    }

    /// VoiceOver "Thread overview" custom action on the comments heading —
    /// a spoken summary in place of manually reading through every comment.
    private func announceThreadOverview() {
        let mostRecent = comments.max { $0.createdAt < $1.createdAt }
        var summary = "Thread has \(comments.count) comment\(comments.count == 1 ? "" : "s")."
        if let mostRecent {
            summary += " Most recent comment by \(mostRecent.authorName), \(mostRecent.createdAt.formatted(.relative(presentation: .named)))."
        }
        if let episode {
            summary += " Original post by \(episode.authorName)."
        }
        UIAccessibility.post(notification: .announcement, argument: summary)
    }

    private func load() async {
        isLoading = true; error = nil
        do {
            async let ep = APIClient.shared.podcasts.episode(id: episodeId)
            async let cms = APIClient.shared.podcasts.comments(episodeId: episodeId)
            let (fetchedEp, fetchedComments) = try await (ep, cms)
            episode = fetchedEp
            comments = fetchedComments
            // Was `>= 100` (the page size requested, not what the server
            // actually returns — Drupal JSON:API commonly clamps a
            // requested page[limit] down to a lower site-configured max).
            // Comparing against the episode's own known commentCount is
            // correct regardless of the server's actual page size.
            hasMoreComments = fetchedComments.count < fetchedEp.commentCount
            PersistenceStore.shared.stampItemVisit(
                id: FeedItem.visitKey(kind: .podcastEpisode, contentId: fetchedEp.id),
                commentCount: fetchedEp.commentCount
            )
            // Fetch every remaining page automatically instead of waiting for
            // a "Load More" tap — the heading already shows the true total
            // (commentCount), so leaving the rest behind a manual tap just
            // contradicted what the count said was there.
            if hasMoreComments {
                Task { await loadMoreComments() }
            }
            SpotlightIndexer.index(fetchedEp)
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Couldn't load episode." }
        isLoading = false
    }

    /// Loads every remaining page in one go instead of requiring a tap per
    /// page — the server clamps each request to its own max page size, so
    /// an episode with many comments could otherwise take several manual
    /// "Load More" taps to fully unroll.
    private func loadMoreComments() async {
        isLoadingMoreComments = true
        do {
            while comments.count < (episode?.commentCount ?? 0) {
                let more = try await APIClient.shared.podcasts.moreComments(episodeId: episodeId, offset: comments.count)
                guard !more.isEmpty else { break }
                comments.append(contentsOf: more)
            }
        } catch {
            toast.error(String(localized: "Couldn't load more comments."))
        }
        hasMoreComments = comments.count < (episode?.commentCount ?? 0)
        isLoadingMoreComments = false
    }

    /// "Jump to Last Comment" custom action on the Community Discussion
    /// heading — loads any not-yet-fetched comments first so it always
    /// lands on the true last one, then moves VoiceOver focus there.
    private func jumpToLastComment(proxy: ScrollViewProxy) async {
        if hasMoreComments { await loadMoreComments() }
        guard let lastId = comments.last?.id else { return }
        withReduceMotionAwareAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
        try? await Task.sleep(for: .milliseconds(400))
        focusedCommentId = lastId
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
                Image(systemName: "play.circle").foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(chapter.title), starts at \(formatTime(chapter.startTime))")
        .accessibilityHint(String(localized: "Double-tap to seek."))
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
    var quotedComment: PodcastComment? = nil
    let onPosted: (PodcastComment) -> Void

    @State private var commentText: String
    @State private var isSubmitting = false
    @State private var submitError: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore

    init(episodeId: String, title: String, quotedComment: PodcastComment? = nil, onPosted: @escaping (PodcastComment) -> Void) {
        self.episodeId = episodeId
        self.title = title
        self.quotedComment = quotedComment
        self.onPosted = onPosted
        if let quotedComment {
            _commentText = State(initialValue: QuotedReply.prefix(authorName: quotedComment.authorName, body: quotedComment.body))
        } else {
            _commentText = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(quotedComment != nil ? "Replying to \(quotedComment!.authorName) — Re: \(title)" : "Re: \(title)")
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
            toast.success(String(localized: "Comment posted"))
            SoundPlayer.shared.play(.reply)
            onPosted(comment)
            dismiss()
        } catch let e as APIError { submitError = e.localizedDescription
        } catch { submitError = "Failed to post comment." }
        isSubmitting = false
    }
}
