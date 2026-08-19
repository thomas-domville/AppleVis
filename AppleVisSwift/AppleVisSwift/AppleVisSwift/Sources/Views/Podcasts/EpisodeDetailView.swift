import SwiftUI

struct EpisodeDetailView: View {
    let episodeId: String
    /// Set when opened via a card's "Jump to First New Comment" action —
    /// see the same property on ForumTopicDetailView for the full
    /// reasoning; routed the same way through DeepLinkRouter.pendingContentIntent.
    var focusFirstNewCommentOnAppear: Bool = false
    @State private var hasAppliedFirstNewCommentFocus = false
    @State private var episode: PodcastEpisode?
    @State private var comments: [PodcastComment] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showCompose = false
    @State private var quotedComment: PodcastComment?
    @State private var showTranscript = false
    @State private var showFullPlayer = false
    @State private var isLoadingMoreComments = false
    @State private var hasMoreComments = true
    @State private var newCommentCount = 0
    @State private var pendingFocusCommentId: String?
    @State private var artworkDescription: String?
    @AccessibilityFocusState private var isTitleFocused: Bool
    @AccessibilityFocusState private var focusedCommentId: String?
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var tips: TipStore
    @EnvironmentObject private var preferences: PreferencesStore
    @ObservedObject private var downloads = DownloadManager.shared

    private func isQueued(_ episode: PodcastEpisode) -> Bool {
        player.queue.contains { $0.id == episode.id }
    }

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
            toast.error(String(localized: "Couldn't download \"\(failure.episodeTitle)\". Try again."))
        }
    }

    @ViewBuilder
    private func content(_ episode: PodcastEpisode) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero
                    heroCard(episode).padding()

                    // Same shortcut the App Entry page has — a second,
                    // earlier entry point to the same "Jump to First New
                    // Comment" the Community Discussion heading offers
                    // further down, for anyone who just wants to see what's
                    // new without scrolling past Chapters/Episode Notes.
                    newCommentShortcut(proxy: proxy)

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
                    if !notesWithoutTranscript(episode).isEmpty {
                        sectionHeading("Episode Notes")
                        SegmentedHTMLView(html: notesWithoutTranscript(episode))
                            .padding(.horizontal).padding(.bottom, 16)
                    }

                    Divider()

                    // Comments
                    commentsSection(episode: episode, proxy: proxy)

                    Color.clear.frame(height: 40)
                }
            }
            .background(preferences.colors.background)
            // None of the four Apps/Guides/Blogs/Bugs compose flows (nor
            // this one) set focus after a successful post, unlike Forums'
            // well-implemented pendingFocusReplyId pattern — a VoiceOver
            // user wasn't confirmed, without extra swiping, that their
            // comment posted or where it landed (ALL-04).
            .onChange(of: pendingFocusCommentId) { _, newId in
                guard let newId else { return }
                withReduceMotionAwareAnimation { proxy.scrollTo(newId, anchor: .bottom) }
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    focusedCommentId = newId
                    pendingFocusCommentId = nil
                }
            }
            .task {
                guard focusFirstNewCommentOnAppear, !hasAppliedFirstNewCommentFocus else { return }
                hasAppliedFirstNewCommentFocus = true
                await jumpToFirstNewComment(proxy: proxy)
            }
            // See ForumTopicDetailView's identical pair for the full
            // reasoning; PodcastComment has no per-item "isNew" flag, so
            // this is the newest `newCommentCount` comments by position.
            .accessibilityRotor("New Comments") {
                ForEach(comments.newestSuffix(count: newCommentCount)) { comment in
                    AccessibilityRotorEntry(comment.authorName, id: comment.id)
                }
            }
            .accessibilityRotor("Replies to Me") {
                ForEach(comments.filter { comment in
                    guard let name = auth.user?.name else { return false }
                    return QuotedReply.isDirectedAt(name, body: comment.body)
                }) { comment in
                    AccessibilityRotorEntry(comment.authorName, id: comment.id)
                }
            }
            // Chapters exist specifically as navigation waypoints — the
            // rotor is arguably a more natural fit here than anywhere else
            // it's used in the app.
            .accessibilityRotor("Chapters") {
                ForEach(episode.chapters) { chapter in
                    AccessibilityRotorEntry(chapter.title, id: chapter.id)
                }
            }
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
                    ? String(localized: "Pause") : String(localized: "Play \(episode.title)")
                )

                downloadButton(episode)

                if let transcriptUrl = episode.transcriptUrl, !transcriptUrl.isEmpty {
                    Button { showTranscript = true } label: {
                        Image(systemName: "text.quote")
                    }
                    .accessibilityLabel(String(localized: "View Transcript"))
                }

                // Every other podcast surface (browse row, queue screen)
                // supports queueing; the single most detailed view of an
                // episode had no way to queue it without leaving the screen
                // (PODCAST-14). Play Next and Mark as Played were both
                // entirely absent natively despite What's New advertising
                // "Mark as Played actions" as already shipped.
                Menu {
                    // Speed, Sleep Timer, Voice Boost, Trim Silence, and
                    // AirPlay all exist already — on FullPlayerView (speed/
                    // sleep timer/AirPlay) and in Settings → Podcasts (all
                    // of them) — but this detail page had no path to either
                    // one at all unless something was already playing,
                    // since the only way to reach FullPlayerView anywhere
                    // in the app was tapping the mini-player bar, which
                    // doesn't exist until playback has started. Loads this
                    // episode first if it isn't already the current one, so
                    // the controls that open always have something to act on.
                    Button {
                        // `load()` does real async setup (audio session,
                        // AVPlayerItem construction) before it sets
                        // `currentEpisode` — presenting the sheet before
                        // that finishes would show FullPlayerView with
                        // `player.currentEpisode` still nil, which renders
                        // as a blank sheet (there's no "nothing playing"
                        // fallback there). Awaiting inside the same Task
                        // guarantees the episode is already current by the
                        // time the sheet appears.
                        Task {
                            if player.currentEpisode?.id != episode.id {
                                await player.load(episode)
                            }
                            showFullPlayer = true
                        }
                    } label: {
                        Label("Player Controls", systemImage: "slider.horizontal.3")
                    }
                    Button {
                        if isQueued(episode) {
                            player.removeFromQueue(id: episode.id)
                        } else {
                            player.enqueue(episode)
                        }
                    } label: {
                        Label(isQueued(episode) ? "Remove from Queue" : "Add to Queue", systemImage: isQueued(episode) ? "text.badge.minus" : "text.badge.plus")
                    }
                    Button {
                        player.playNext(episode)
                        toast.success(String(localized: "Playing next"))
                    } label: {
                        Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                    }
                    if PersistenceStore.shared.isEpisodePlayed(episode.id) {
                        Label("Played", systemImage: "checkmark.circle.fill")
                    } else {
                        Button {
                            PersistenceStore.shared.markEpisodePlayed(episode.id)
                            toast.success(String(localized: "Marked as played"))
                        } label: {
                            Label("Mark as Played", systemImage: "checkmark.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(String(localized: "More episode actions"))
            }
        }
        .safeAreaInset(edge: .bottom) {
            ContentDetailActions(
                id: episode.id, kind: .podcastEpisode, title: episode.title, lastActivityAt: episode.lastActivityAt, url: episode.url,
                onAddComment: { showCompose = true }
            )
        }
        .sheet(isPresented: $showCompose) {
            ComposePodcastCommentView(episodeId: episode.id, title: episode.title) { comment in
                comments.append(comment)
                pendingFocusCommentId = comment.id
            }
        }
        .sheet(item: $quotedComment) { target in
            ComposePodcastCommentView(episodeId: episode.id, title: episode.title, quotedComment: target) { comment in
                comments.append(comment)
                pendingFocusCommentId = comment.id
            }
        }
        .sheet(isPresented: $showTranscript) {
            TranscriptView(episodeId: episode.id, episodeTitle: episode.title)
        }
        .sheet(isPresented: $showFullPlayer) {
            FullPlayerView()
        }
    }

    /// Drupal's `duration` is hardcoded to 0, never nil — see
    /// `PodcastAudioMetadataProbe` — so `> 0` guards against ever showing
    /// or speaking "0 min" during the brief window before that probe (or
    /// its cache) resolves a real value in place.
    private func validDuration(_ episode: PodcastEpisode) -> TimeInterval? {
        guard let duration = episode.duration, duration > 0 else { return nil }
        return duration
    }

    @ViewBuilder
    private func newCommentShortcut(proxy: ScrollViewProxy) -> some View {
        if newCommentCount > 0 {
            Button {
                Task { await jumpToFirstNewComment(proxy: proxy) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.to.line.compact")
                    Text("\(newCommentCount) new comment\(newCommentCount == 1 ? "" : "s") — Jump to First New Comment")
                        .font(.subheadline).fontWeight(.medium)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Color.accentColor)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .tintedBackground(Color.accentColor, opacity: 0.1, cornerRadius: 10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .accessibilityLabel(String(localized: "\(newCommentCount) new comment\(newCommentCount == 1 ? "" : "s")"))
            .accessibilityHint(String(localized: "Double-tap to jump to the first new comment."))
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
                    if let duration = validDuration(episode) {
                        Text(PodcastDuration.abbreviated(duration))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    RelativeDateLabel(date: episode.publishedAt)
                }
                if episode.commentCount > 0 {
                    Text("Last comment \(episode.lastActivityAt.formatted(.relative(presentation: .named)))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "\(episode.title) by \(episode.showTitle), published \(episode.publishedAt.formatted(.relative(presentation: .named)))") +
            (validDuration(episode).map { String(localized: ", \(PodcastDuration.abbreviated($0))") } ?? "") +
            (episode.commentCount > 0 ? String(localized: ", last comment \(episode.lastActivityAt.formatted(.relative(presentation: .named)))") : "") +
            (artworkDescription.map { String(localized: ". Artwork \($0)") } ?? "")
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
            // Previously a bare, non-interactive ProgressView — DownloadManager.
            // cancelDownload(_:) existed but nothing in the app ever called
            // it, so no one (sighted or VoiceOver) had any way to stop an
            // unwanted or mistaken download (PODCAST-03).
            Button {
                downloads.cancelDownload(episode.id)
            } label: {
                ProgressView(value: downloads.progress[episode.id] ?? 0)
                    .progressViewStyle(.circular)
            }
            .accessibilityLabel(String(localized: "Downloading, \(Int((downloads.progress[episode.id] ?? 0) * 100)) percent"))
            .accessibilityHint(String(localized: "Double-tap to cancel."))
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

    /// Strips AppleVis's own "Transcript" block off the end of show notes —
    /// confirmed against a real episode: a "Transcript" heading, an AI-
    /// transcription disclaimer, then the full transcript, running straight
    /// to the end of the body with nothing after it. `TranscriptView`
    /// already fetches the real transcript from its own dedicated endpoint
    /// (`APIClient.podcasts.transcript(id:)`), entirely independent of this
    /// HTML — so it was never a source of truth, just a second, unformatted
    /// copy of the same text sitting where the notes should end. Reuses
    /// `HTMLSegmenter` (already splitting this exact body for rendering)
    /// instead of a fresh regex: finds the first heading segment whose text
    /// is exactly "Transcript" and drops it and everything after.
    /// Only applied when `transcriptUrl` is set — otherwise the dedicated
    /// button/modal won't be there to replace what got removed, and this
    /// text is the only copy that would exist.
    private func notesWithoutTranscript(_ episode: PodcastEpisode) -> String {
        guard let transcriptUrl = episode.transcriptUrl, !transcriptUrl.isEmpty else {
            return episode.description
        }
        let segments = HTMLSegmenter.segment(episode.description)
        guard let transcriptIndex = segments.firstIndex(where: {
            $0.isHeading && $0.plainText.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("Transcript") == .orderedSame
        }) else {
            return episode.description
        }
        return segments[..<transcriptIndex].map(\.html).joined()
    }

    @ViewBuilder
    private func commentsSection(episode: PodcastEpisode, proxy: ScrollViewProxy) -> some View {
        CommunityDiscussionHeading(
            count: episode.commentCount,
            onThreadOverview: { announceThreadOverview() },
            onJumpToLast: { Task { await jumpToLastComment(proxy: proxy) } },
            newCount: newCommentCount,
            onJumpToFirstNew: { Task { await jumpToFirstNewComment(proxy: proxy) } }
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
                    ProgressView().frame(maxWidth: .infinity).accessibilityLabel(String(localized: "Loading more…")).padding()
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
            resolveAudioMetadataIfNeeded(for: fetchedEp)
            // Was `>= 100` (the page size requested, not what the server
            // actually returns — Drupal JSON:API commonly clamps a
            // requested page[limit] down to a lower site-configured max).
            // Comparing against the episode's own known commentCount is
            // correct regardless of the server's actual page size.
            hasMoreComments = fetchedComments.count < fetchedEp.commentCount
            // Captured from the PREVIOUS visit snapshot before stampItemVisit
            // below overwrites it — reading newReplyCount AFTER the stamp
            // would always return 0, the same class of bug fixed for
            // ForumTopicDetailView's isNew wiring earlier.
            newCommentCount = PersistenceStore.shared.newReplyCount(
                kind: .podcastEpisode, id: fetchedEp.id, currentCount: fetchedEp.commentCount
            )
            PersistenceStore.shared.stampItemVisit(
                id: FeedItem.visitKey(kind: .podcastEpisode, contentId: fetchedEp.id),
                commentCount: fetchedEp.commentCount
            )
            // Keeps the website's own "read" state (Drupal core's History
            // module) in sync with what's viewed in the app — signed-out
            // users still rely on the local stamp above only.
            if let csrfToken = auth.user?.csrfToken {
                Task { await APIClient.shared.history.markRead(nid: fetchedEp.nid, csrfToken: csrfToken) }
            }
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
        // isTitleFocused was declared and bound to the hero card but never
        // actually set anywhere — VoiceOver focus was left wherever it was
        // before navigating in, instead of landing on the episode title.
        if episode != nil {
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                isTitleFocused = true
            }
        }
    }

    /// Fire-and-forget — doesn't block the page's own loading spinner, since
    /// a live probe means a network round-trip on top of the episode fetch
    /// that already happened. Checks PersistenceStore's cache first (no
    /// network at all); only reaches for `PodcastAudioMetadataProbe` if
    /// nothing's cached yet for this episode, and caches whatever it finds
    /// so this episode is never probed twice. See `PodcastAudioMetadataProbe`
    /// for why Drupal alone can't supply either value.
    private func resolveAudioMetadataIfNeeded(for fetchedEpisode: PodcastEpisode) {
        Task {
            let cached = PersistenceStore.shared.cachedAudioMetadata(episodeId: fetchedEpisode.id)

            if let cachedDuration = cached?.duration {
                episode?.duration = cachedDuration
            } else if fetchedEpisode.duration == nil || fetchedEpisode.duration == 0 {
                if let probed = await PodcastAudioMetadataProbe.resolveDuration(audioUrl: fetchedEpisode.audioUrl) {
                    PersistenceStore.shared.cacheProbedDuration(episodeId: fetchedEpisode.id, duration: probed)
                    episode?.duration = probed
                }
            }

            if let cachedChapters = cached?.chapters, !cachedChapters.isEmpty {
                episode?.chapters = cachedChapters
            } else if fetchedEpisode.chapters.isEmpty {
                let probed = await PodcastAudioMetadataProbe.resolveChapters(audioUrl: fetchedEpisode.audioUrl)
                if !probed.isEmpty {
                    PersistenceStore.shared.cacheProbedChapters(episodeId: fetchedEpisode.id, chapters: probed)
                    episode?.chapters = probed
                }
            }
        }
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

    /// "Jump to First New Comment" — comments arrive chronologically
    /// oldest-first (matches "Jump to Last Comment" scrolling to `.last`
    /// for the most recent), so the first of the `newCommentCount` most
    /// recently posted comments sits at `comments.count - newCommentCount`.
    private func jumpToFirstNewComment(proxy: ScrollViewProxy) async {
        if hasMoreComments { await loadMoreComments() }
        let targetIndex = comments.count - newCommentCount
        guard newCommentCount > 0, targetIndex >= 0, targetIndex < comments.count else { return }
        let targetId = comments[targetIndex].id
        withReduceMotionAwareAnimation { proxy.scrollTo(targetId, anchor: .top) }
        try? await Task.sleep(for: .milliseconds(400))
        focusedCommentId = targetId
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
                    Text(PodcastDuration.colon(chapter.startTime))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "play.circle").foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "\(chapter.title), starts at \(PodcastDuration.colon(chapter.startTime))"))
        .accessibilityHint(String(localized: "Double-tap to seek."))
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
