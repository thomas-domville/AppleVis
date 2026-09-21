import SwiftUI

struct EpisodeDetailView: View {
    let episodeId: String
    /// Set when opened via a card's "Jump to First New Comment" action —
    /// see the same property on ForumTopicDetailView for the full
    /// reasoning; routed the same way through DeepLinkRouter.pendingContentIntent.
    var focusFirstNewCommentOnAppear: Bool = false
    @State private var hasAppliedFirstNewCommentFocus = false
    /// Set when opened from the admin Guideline Violation Check screen for a
    /// flagged comment — see `ForumTopicDetailView.targetCommentId` for the
    /// full reasoning.
    var targetCommentId: String? = nil
    @State private var hasAppliedTargetCommentFocus = false
    @State private var episode: PodcastEpisode?
    @State private var comments: [PodcastComment] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var showCompose = false
    @State private var quotedComment: PodcastComment?
    // A single Identifiable item instead of a bool flag + a separate
    // `embeddedTranscript` string — `.sheet(isPresented:)` with sibling
    // state set in the same action is a known SwiftUI race (same one just
    // fixed on the App Entry page's Refresh App Details sheet): the sheet's
    // content closure can capture the sibling state's *previous* value
    // rather than what was just assigned, since presentation and data
    // aren't tied to the same value. Here that meant TranscriptView could
    // open with `embeddedTranscript` still nil even though it was set the
    // same instant — which sent it down the fallback path to the old
    // id-based transcript endpoint that 404s for an ordinary embedded
    // transcript, surfacing "This item is no longer available" even though
    // a transcript was right there in the show notes the whole time.
    // Reported directly: not tied to any particular transcription tool —
    // a live-data comparison of a Google Gemini-transcribed episode against
    // a VoicePen-transcribed one found both format the embedded transcript
    // identically; this was a presentation-timing bug, not a parsing one.
    @State private var transcriptRequest: TranscriptRequest?
    @State private var showFullPlayer = false
    @State private var showAudioEnhancements = false
    @State private var isLoadingMoreComments = false
    @State private var hasMoreComments = true
    // Mirrors ForumTopicDetailView.loadAllRepliesTask — load() kicks off
    // loadMoreComments()'s drain-everything loop in the background, and
    // "Jump to First New Comment"/"Jump to Last Comment" previously called
    // it again themselves if that background load hadn't finished, racing
    // two loops that both read comments.count before either appended and
    // so both fetched (and appended) the same page twice. Tracking the
    // in-flight Task lets every caller await the one already running.
    // Reported directly: "jump to newest/first new comment" not landing on
    // the right comment.
    @State private var loadAllCommentsTask: Task<Void, Never>?
    @State private var newCommentCount = 0
    @State private var pendingFocusCommentId: String?
    @State private var artworkDescription: String?
    // Episode-level moderation — mirrors ForumTopicDetailView's own
    // Edit/Unpublish/Delete via DetailActionsMenu. No regular member ever
    // "owns" an episode (PodcastEpisode carries no authorId), so this is
    // effectively admin/editor-only in practice, but built the same way as
    // every other content kind for consistency.
    @State private var editingEpisodeNode: EditableNode?
    @Environment(\.dismiss) private var dismiss
    @AccessibilityFocusState private var isTitleFocused: Bool
    @AccessibilityFocusState private var focusedCommentId: String?
    /// Dismissing the Transcript sheet otherwise left VoiceOver focus on
    /// whatever this screen's default landing point is (the title), instead
    /// of back on the button that opened it — reported directly.
    @AccessibilityFocusState private var isTranscriptButtonFocused: Bool
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var tips: TipStore
    @EnvironmentObject private var preferences: PreferencesStore
    @ObservedObject private var downloads = DownloadManager.shared

    private var speedOptions: [Float] { PodcastSpeedOptions.all.map(Float.init) }

    private func isQueued(_ episode: PodcastEpisode) -> Bool {
        player.queue.contains { $0.id == episode.id }
    }

    private func isEpisodePlayed(_ episode: PodcastEpisode) -> Bool {
        PersistenceStore.shared.isEpisodePlayed(episode.id)
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

                    playbackSection(episode)

                    audioEnhancementsButton

                    episodeToolsSection(episode)

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
                        SegmentedHTMLView(html: notesWithoutTranscript(episode), contentKind: "podcastEpisode", contentId: episode.id, field: "body")
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
            .task {
                guard let targetCommentId, !hasAppliedTargetCommentFocus else { return }
                hasAppliedTargetCommentFocus = true
                if hasMoreComments { await ensureAllCommentsLoaded() }
                pendingFocusCommentId = targetCommentId
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
            ToolbarItem(placement: .navigationBarTrailing) {
                DetailActionsMenu(
                    id: episode.id, entityId: episode.nid, kind: .podcastEpisode, title: episode.title, lastActivityAt: episode.lastActivityAt, url: episode.url,
                    excerpt: .excerpt(from: episode.description),
                    onAddComment: { showCompose = true },
                    onEdit: { startEditEpisode(episode) },
                    onUnpublish: { await unpublishEpisode(episode) },
                    onDelete: { await deleteEpisode(episode) }
                )
            }
        }
        .sheet(item: $editingEpisodeNode) { node in
            EditNodeSheet(initialTitle: node.title, initialBody: node.body) { newTitle, newBody in
                try await saveEpisodeEdit(nodeTypeSuffix: node.nodeTypeSuffix, title: newTitle, body: newBody)
            }
        }
        .safeAreaInset(edge: .bottom) {
            ContentDetailActions(
                id: episode.id, entityId: episode.nid, kind: .podcastEpisode, title: episode.title, lastActivityAt: episode.lastActivityAt, url: episode.url,
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
        .sheet(item: $transcriptRequest, onDismiss: {
            Task { await retryAccessibilityFocus(into: $isTranscriptButtonFocused) }
        }) { request in
            TranscriptView(episodeId: episode.id, episodeTitle: episode.title, episodeURL: episode.url, embeddedTranscript: request.transcript)
        }
        .sheet(isPresented: $showFullPlayer) {
            FullPlayerView()
        }
        .sheet(isPresented: $showAudioEnhancements) {
            AudioEnhancementsSheet()
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

    private func playbackSection(_ episode: PodcastEpisode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Playback")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 10) {
                Button {
                    Task { await player.skip(by: -preferences.skipBackInterval) }
                } label: {
                    episodeControlLabel(systemImage: "gobackward.\(Int(preferences.skipBackInterval))", title: "Back", subtitle: "\(Int(preferences.skipBackInterval)) sec")
                }
                .accessibilityLabel(String(localized: "Skip back \(PodcastDuration.accessibilityLabel(preferences.skipBackInterval))"))

                Button {
                    playOrPause(episode)
                } label: {
                    episodeControlLabel(
                        systemImage: isPlayingThisEpisode(episode) ? "pause.circle.fill" : "play.circle.fill",
                        title: isPlayingThisEpisode(episode) ? "Pause" : resumeTitle(for: episode),
                        subtitle: playbackStatus(for: episode)
                    )
                }
                .accessibilityLabel(playAccessibilityLabel(for: episode))

                Button {
                    Task { await player.skip(by: preferences.skipForwardInterval) }
                } label: {
                    episodeControlLabel(systemImage: "goforward.\(Int(preferences.skipForwardInterval))", title: "Forward", subtitle: "\(Int(preferences.skipForwardInterval)) sec")
                }
                .accessibilityLabel(String(localized: "Skip forward \(PodcastDuration.accessibilityLabel(preferences.skipForwardInterval))"))
            }

            HStack(spacing: 10) {
                speedButton
                sleepTimerMenu
                routePickerTile
            }
        }
        .buttonStyle(.plain)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func episodeToolsSection(_ episode: PodcastEpisode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Episode Tools")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                downloadTool(episode)

                if hasTranscript(for: episode) {
                    episodeToolButton(title: "Transcript", subtitle: "Read", systemImage: "text.quote") {
                        transcriptRequest = TranscriptRequest(transcript: extractedTranscript(from: episode))
                    }
                    .accessibilityLabel(String(localized: "Read Transcript"))
                    .accessibilityFocused($isTranscriptButtonFocused)
                }

                episodeToolButton(
                    title: isQueued(episode) ? "Queued" : "Queue",
                    subtitle: isQueued(episode) ? "Remove" : "Add",
                    systemImage: isQueued(episode) ? "text.badge.minus" : "text.badge.plus"
                ) {
                    if isQueued(episode) {
                        player.removeFromQueue(id: episode.id)
                        toast.success(String(localized: "Removed from queue"))
                    } else {
                        player.enqueue(episode)
                        toast.success(String(localized: "Added to queue"))
                    }
                }
                .accessibilityLabel(String(localized: isQueued(episode) ? "Remove from Queue" : "Add to Queue"))

                episodeToolButton(title: "Play Next", subtitle: "Up next", systemImage: "text.line.first.and.arrowtriangle.forward") {
                    player.playNext(episode)
                    toast.success(String(localized: "Playing next"))
                }
                .accessibilityLabel(String(localized: "Play Next"))

                // Toggle, not a one-way "Mark Played" → static "Played" —
                // matches the Queue button's own toggle pattern just above.
                // Previously there was no way back once marked, whether you
                // tapped it by mistake or a synced iCloud state set it.
                // "Listened" (not "Played") to avoid reading as ambiguous
                // for audio content. Requested directly.
                episodeToolButton(
                    title: isEpisodePlayed(episode) ? "Listened" : "Mark Listened",
                    subtitle: isEpisodePlayed(episode) ? "Marked" : "Complete",
                    systemImage: isEpisodePlayed(episode) ? "checkmark.circle.fill" : "checkmark.circle"
                ) {
                    if isEpisodePlayed(episode) {
                        PersistenceStore.shared.unmarkEpisodePlayed(episode.id)
                        toast.success(String(localized: "Marked as not listened"))
                    } else {
                        PersistenceStore.shared.markEpisodePlayed(episode.id)
                        // Marking listened while a resume point is still on
                        // file would otherwise offer to "Resume from 12:34"
                        // for an episode you just said you're done with.
                        player.clearSavedPosition(for: episode.id)
                        toast.success(String(localized: "Marked as listened"))
                    }
                }
                .accessibilityLabel(String(localized: isEpisodePlayed(episode) ? "Listened" : "Mark as Listened"))

                episodeToolButton(title: "Now Playing", subtitle: "Open", systemImage: "slider.horizontal.3") {
                    openFullPlayer(for: episode)
                }
                .accessibilityLabel(String(localized: "Open Now Playing"))
            }
        }
        .buttonStyle(.plain)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func isPlayingThisEpisode(_ episode: PodcastEpisode) -> Bool {
        player.currentEpisode?.id == episode.id && player.isPlaying
    }

    private func isCurrentEpisode(_ episode: PodcastEpisode) -> Bool {
        player.currentEpisode?.id == episode.id
    }

    private func playOrPause(_ episode: PodcastEpisode) {
        if isCurrentEpisode(episode) {
            player.togglePlayPause()
            // The button's own accessibilityLabel already updates reactively
            // (playAccessibilityLabel(for:) reads player.isPlaying), but
            // VoiceOver doesn't reliably re-speak a focused element's label
            // just because it changed underneath — an explicit announcement
            // is what actually makes the new "Pause"/"Resume" state audible
            // right after the double-tap, not just discoverable on the next
            // swipe past it. Reported directly.
            UIAccessibility.post(notification: .announcement, argument: playAccessibilityLabel(for: episode))
        } else {
            Task { await player.load(episode) }
        }
    }

    private func openFullPlayer(for episode: PodcastEpisode) {
        Task {
            if player.currentEpisode?.id != episode.id {
                await player.load(episode)
            }
            showFullPlayer = true
        }
    }

    private func resumeTitle(for episode: PodcastEpisode) -> String {
        isCurrentEpisode(episode) && player.position > 0 ? "Resume" : "Play"
    }

    private func playbackStatus(for episode: PodcastEpisode) -> String {
        guard isCurrentEpisode(episode), player.position > 0 else {
            return validDuration(episode).map(PodcastDuration.abbreviated) ?? "Episode"
        }
        let total = player.duration > 0 ? " of \(PodcastDuration.colon(player.duration))" : ""
        return "\(PodcastDuration.colon(player.position))\(total)"
    }

    private func playAccessibilityLabel(for episode: PodcastEpisode) -> String {
        if isPlayingThisEpisode(episode) { return String(localized: "Pause") }
        if isCurrentEpisode(episode), player.position > 0 {
            return String(localized: "Resume at \(PodcastDuration.accessibilityLabel(player.position))")
        }
        return String(localized: "Play \(episode.title)")
    }

    private var speedButton: some View {
        let current = player.playbackSpeed
        let currentIndex = speedOptions.firstIndex(of: current) ?? 2
        let next = speedOptions[(currentIndex + 1) % speedOptions.count]

        return Button {
            player.playbackSpeed = next
        } label: {
            episodeControlLabel(systemImage: "speedometer", title: "Speed", subtitle: "\(speedLabel(current))x")
        }
        .accessibilityLabel(String(localized: "Playback speed"))
        .accessibilityValue(String(localized: "\(speedLabel(current)) times"))
        .accessibilityHint(String(localized: "Double-tap to increase. Swipe up or down to adjust."))
        .accessibilityAdjustableAction { direction in
            let idx = speedOptions.firstIndex(of: player.playbackSpeed) ?? 2
            switch direction {
            case .increment:
                player.playbackSpeed = speedOptions[(idx + 1) % speedOptions.count]
            case .decrement:
                player.playbackSpeed = speedOptions[(idx - 1 + speedOptions.count) % speedOptions.count]
            @unknown default:
                break
            }
        }
    }

    private var sleepTimerMenu: some View {
        Menu {
            ForEach([15, 30, 45, 60], id: \.self) { minutes in
                Button {
                    player.startSleepTimer(minutes: minutes)
                } label: {
                    if preferences.sleepTimerMinutes == minutes {
                        Label("\(minutes) minutes (Default)", systemImage: "checkmark")
                    } else {
                        Text("\(minutes) minutes")
                    }
                }
            }
            Button("End of Episode") { player.startSleepTimerAtEndOfEpisode() }
            if player.sleepTimerRemaining != nil || player.sleepAtEndOfEpisode {
                Button("Turn Off", role: .destructive) { player.userCancelSleepTimer() }
            }
        } label: {
            episodeControlLabel(systemImage: "moon.zzz", title: "Sleep", subtitle: sleepTimerStatus)
        }
        .accessibilityLabel(String(localized: "Sleep Timer"))
        .accessibilityValue(sleepTimerAccessibilityStatus)
    }

    /// Previously three separate, uncombined VoiceOver stops (the route
    /// picker button's own "Audio Output" label, then the visible "Output"
    /// caption, then a hardcoded "AirPlay" subtitle read as its own
    /// element) — confusing to swipe through with no indication they were
    /// one control. Matches the Sleep Timer/Speed tiles right next to it:
    /// one combined element with a single clear label, backed by the live
    /// output name (see `PlayerStore.currentOutputName`) instead of a
    /// hardcoded "AirPlay" that was wrong whenever playback was actually
    /// going through the speaker, headphones, or Bluetooth. Reported
    /// directly.
    private var routePickerTile: some View {
        VStack(spacing: 5) {
            RoutePickerView()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            Text("Output")
                .font(.caption2)
                .fontWeight(.semibold)
            Text(player.currentOutputName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(String(localized: "Audio Output"))
        .accessibilityValue(player.currentOutputName)
        .accessibilityHint(String(localized: "Double-tap to choose a different output."))
    }

    private var sleepTimerStatus: String {
        if player.sleepAtEndOfEpisode { return "End" }
        if let remaining = player.sleepTimerRemaining { return PodcastDuration.colon(remaining) }
        return "Off"
    }

    private var sleepTimerAccessibilityStatus: String {
        if player.sleepAtEndOfEpisode { return String(localized: "End of episode") }
        if let remaining = player.sleepTimerRemaining {
            return PodcastDuration.accessibilityRemaining(remaining)
        }
        return String(localized: "Off")
    }

    private func downloadTool(_ episode: PodcastEpisode) -> some View {
        if downloads.isDownloaded(episode.id) {
            return AnyView(episodeToolButton(title: "Downloaded", subtitle: "Remove", systemImage: "arrow.down.circle.fill") {
                downloads.delete(episode.id)
            }
            .accessibilityLabel(String(localized: "Downloaded. Double-tap to remove download.")))
        } else if downloads.activeDownloads.contains(episode.id) {
            let percent = Int((downloads.progress[episode.id] ?? 0) * 100)
            return AnyView(episodeToolButton(title: "Downloading", subtitle: "\(percent)%", systemImage: "xmark.circle") {
                downloads.cancelDownload(episode.id)
            }
            .accessibilityLabel(String(localized: "Downloading, \(percent) percent. Double-tap to cancel.")))
        } else {
            return AnyView(episodeToolButton(title: "Download", subtitle: "Offline", systemImage: "arrow.down.circle") {
                downloads.download(episode)
            }
            .accessibilityLabel(String(localized: "Download for offline playback")))
        }
    }

    private func episodeControlLabel(systemImage: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .lineLimit(1)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private func episodeToolButton(title: String, subtitle: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            episodeToolLabel(title: title, subtitle: subtitle, systemImage: systemImage)
        }
    }

    private func episodeToolLabel(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private func speedLabel(_ speed: Float) -> String {
        speed.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", speed)
            : String(format: "%.2g", speed)
    }

    private var audioEnhancementsSummary: String {
        var parts: [String] = []
        parts.append(preferences.voiceBoost ? "Voice Boost on" : "Voice Boost off")
        parts.append(preferences.trimSilence ? "Trim Silence on" : "Trim Silence off")
        parts.append("EQ \(preferences.podcastEQ.displayName)")
        parts.append("Pitch correction on")
        return parts.joined(separator: ", ")
    }

    private var audioEnhancementsButton: some View {
        Button {
            showAudioEnhancements = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "waveform.path.ecg")
                    .font(.title3)
                    .frame(width: 32)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Audio Enhancements")
                        .font(.subheadline).fontWeight(.semibold)
                    Text(audioEnhancementsSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .accessibilityLabel(String(localized: "Audio Enhancements"))
        .accessibilityValue(audioEnhancementsSummary)
        .accessibilityHint(String(localized: "Double-tap to adjust Voice Boost, Trim Silence, and equaliser settings."))
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

    // Same stacked title/byline/posted-and-last-comment shape Blog/Forum/
    // Guide headers use (BlogDetailView.content, ForumTopicDetailView.content),
    // adapted for a podcast: showTitle stands in for the byline (there's no
    // per-episode author profile to link the way Blog's AuthorProfileButton
    // does), and a final line covers total length plus remaining time when
    // this episode is the one currently loaded and in progress — neither of
    // which the other content types have an equivalent for.
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
                Text(episode.title)
                    .font(.body).fontWeight(.semibold).lineLimit(3)
                Text(episode.showTitle)
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(postedAndLastCommentText(episode))
                    .font(.caption).foregroundStyle(.secondary)
                if let duration = resolvedDuration(episode) {
                    Text(lengthAndRemainingText(duration: duration, remaining: remainingDuration(episode)))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(heroAccessibilityLabel(episode))
        .accessibilityAddTraits(.isHeader)
        .accessibilityFocused($isTitleFocused)
    }

    private func postedAndLastCommentText(_ episode: PodcastEpisode) -> String {
        let posted = String(localized: "Posted \(episode.publishedAt.formatted(.relative(presentation: .named)))")
        guard episode.commentCount > 0 else { return posted }
        return String(localized: "\(posted), last comment \(episode.lastActivityAt.formatted(.relative(presentation: .named)))")
    }

    /// Prefers the live player's duration over `episode.duration` when this
    /// episode is loaded — Drupal hardcodes `episode.duration` to 0
    /// server-side (see `validDuration`), so once AVPlayer has actually
    /// opened the file its real duration is the only trustworthy source.
    private func resolvedDuration(_ episode: PodcastEpisode) -> TimeInterval? {
        if isCurrentEpisode(episode), player.duration > 0 { return player.duration }
        return validDuration(episode)
    }

    private func remainingDuration(_ episode: PodcastEpisode) -> TimeInterval? {
        guard isCurrentEpisode(episode), player.position > 0, player.duration > 0 else { return nil }
        let remaining = player.duration - player.position
        return remaining > 0 ? remaining : nil
    }

    private func lengthAndRemainingText(duration: TimeInterval, remaining: TimeInterval?) -> String {
        let total = PodcastDuration.abbreviated(duration)
        guard let remaining else { return total }
        return String(localized: "\(total) · \(PodcastDuration.abbreviated(remaining)) remaining")
    }

    private func heroAccessibilityLabel(_ episode: PodcastEpisode) -> String {
        let duration = resolvedDuration(episode)
        let remaining = remainingDuration(episode)
        return String(localized: "\(episode.title) by \(episode.showTitle), posted \(episode.publishedAt.formatted(.relative(presentation: .named)))") +
            (episode.commentCount > 0 ? String(localized: ", last comment \(episode.lastActivityAt.formatted(.relative(presentation: .named)))") : "") +
            (duration.map { String(localized: ", \(PodcastDuration.accessibilityLabel($0))") } ?? "") +
            (remaining.map { String(localized: ", \(PodcastDuration.accessibilityRemaining($0))") } ?? "") +
            (artworkDescription.map { String(localized: ". Artwork \($0)") } ?? "")
    }

    private func sectionHeading(_ text: String) -> some View {
        Text(text).font(.headline)
            .padding(.horizontal)
            .padding(.top, 16).padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }

    /// Strips AppleVis's own "Transcript" block off the end of show notes —
    /// confirmed against real episodes (via the public podcast RSS feed): a
    /// "Transcript" heading, an AI-transcription disclaimer, then the full
    /// transcript, running straight to the end of the body with nothing
    /// after it. `APIClient.podcasts.transcript(id:)`'s dedicated endpoint
    /// turns out not to be the real source for this content — it 404s for
    /// ordinary episodes — so this embedded block, extracted the same way
    /// `extractedTranscript`/`hasTranscript` above already do via
    /// `transcriptHeadingIndex`, is what `TranscriptView` actually shows.
    /// Using that same shared check here means notes are only ever stripped
    /// when the Transcript button is actually there to show what got
    /// removed — never silently dropped with nothing to replace it.
    private func notesWithoutTranscript(_ episode: PodcastEpisode) -> String {
        let segments = HTMLSegmenter.segment(episode.description)
        guard let transcriptIndex = transcriptHeadingIndex(in: segments) else { return episode.description }
        return segments[..<transcriptIndex].map(\.html).joined()
    }

    /// Previously also returned true whenever `episode.transcriptUrl` was
    /// set, regardless of whether `extractedTranscript` actually found
    /// anything — but `TranscriptView` never uses that URL for anything, so
    /// an episode with a `transcriptUrl` but no matching heading in the show
    /// notes showed the button, then dead-ended on "This item is no longer
    /// available" once the id-based fetch 404'd with nothing to fall back
    /// to. The button should only ever appear when there's something this
    /// screen can actually show. Reported directly.
    private func hasTranscript(for episode: PodcastEpisode) -> Bool {
        extractedTranscript(from: episode) != nil
    }

    private func extractedTranscript(from episode: PodcastEpisode) -> String? {
        let segments = HTMLSegmenter.segment(episode.description)
        guard let transcriptIndex = transcriptHeadingIndex(in: segments) else { return nil }
        let transcript = segments[transcriptIndex...].map(\.plainText)
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return transcript.isEmpty ? nil : transcript
    }

    /// Checked against live episodes (AppleVis Extra 114/115/117, Deyesfree)
    /// via the public podcast RSS feed: all of them use a real `<h3>
    /// Transcript</h3>` heading, which the `segment.isHeading` check below
    /// already matches — so requiring a real heading isn't the live bug.
    /// This still also matches a short standalone paragraph whose entire
    /// text is just the label (still an exact match, not a substring one,
    /// so an ordinary sentence that happens to mention "transcript" can't
    /// false-positive) — a host who bolds "Transcript:" in Drupal's WYSIWYG
    /// editor instead of using a real heading style produces exactly that,
    /// and it costs nothing to also accept it. The label itself never
    /// depends on which transcription tool was used (VoicePen today, maybe
    /// something else later) — only on the fixed "Transcript"-style wording
    /// a host writes by hand, so a future tool change doesn't affect this.
    private func transcriptHeadingIndex(in segments: [HTMLSegment]) -> Int? {
        segments.firstIndex { Self.isTranscriptHeading($0.plainText) }
    }

    static func isTranscriptHeading(_ text: String) -> Bool {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ":.-"))
            .lowercased()

        return normalized == "transcript"
            || normalized == "transcription"
            || normalized == "episode transcript"
            || normalized == "episode transcription"
            || normalized == "podcast transcript"
            || normalized == "podcast transcription"
            || normalized == "audio transcript"
            || normalized == "audio transcription"
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
                    subject: comment.subject, parentTitle: episode.title, parentURL: episode.url,
                    commentId: comment.id, authorId: comment.authorId, commentType: "comment_node_podcast",
                    onDelete: {
                        comments.removeAll { $0.id == comment.id }
                    },
                    onUnpublish: {
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
                        Task { await ensureAllCommentsLoaded() }
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

    private func startEditEpisode(_ episode: PodcastEpisode) {
        editingEpisodeNode = EditableNode(title: episode.title, body: episode.description, nodeTypeSuffix: "podcast")
    }

    private func saveEpisodeEdit(nodeTypeSuffix: String, title: String, body: String) async throws {
        guard let user = auth.user, let episode else { return }
        try await APIClient.shared.content.editNode(nodeId: episode.id, nodeType: nodeTypeSuffix, title: title, body: body, csrfToken: user.csrfToken)
        toast.success(String(localized: "Episode updated"))
        await load()
    }

    private func unpublishEpisode(_ episode: PodcastEpisode) async {
        guard let user = auth.user else { return }
        do {
            try await APIClient.shared.content.unpublishNode(nodeId: episode.id, nodeType: "podcast", csrfToken: user.csrfToken)
            toast.success(String(localized: "Episode unpublished"))
        } catch {
            toast.error(String(localized: "Couldn't unpublish."))
        }
    }

    /// Deletes the episode currently being viewed — unlike row-level
    /// deletion elsewhere, there's no list to prune; the only sensible next
    /// step is leaving the screen, matching ForumTopicDetailView.deleteTopic().
    private func deleteEpisode(_ episode: PodcastEpisode) async {
        guard let user = auth.user else { return }
        do {
            try await APIClient.shared.content.deleteNode(nodeId: episode.id, nodeType: "podcast", csrfToken: user.csrfToken)
            toast.success(String(localized: "Episode deleted"))
            dismiss()
        } catch {
            toast.error(String(localized: "Couldn't delete."))
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
                Task { await ensureAllCommentsLoaded() }
            }
            SpotlightIndexer.index(fetchedEp)
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Couldn't load episode." }
        isLoading = false
        // isTitleFocused was declared and bound to the hero card but never
        // actually set anywhere — VoiceOver focus was left wherever it was
        // before navigating in, instead of landing on the episode title.
        // Retries at each delay rather than a single guessed one — a single
        // attempt could silently go nowhere on a slower device or slower
        // load. Reported directly.
        if episode != nil {
            Task {
                await retryAccessibilityFocus(into: $isTitleFocused)
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

    /// Single-flight wrapper around loadMoreComments() — see
    /// loadAllCommentsTask's doc comment for why this exists.
    private func ensureAllCommentsLoaded() async {
        if let existing = loadAllCommentsTask {
            await existing.value
            return
        }
        let task = Task { await loadMoreComments() }
        loadAllCommentsTask = task
        await task.value
        loadAllCommentsTask = nil
    }

    /// "Jump to Last Comment" custom action on the Community Discussion
    /// heading — loads any not-yet-fetched comments first so it always
    /// lands on the true last one, then moves VoiceOver focus there.
    private func jumpToLastComment(proxy: ScrollViewProxy) async {
        if hasMoreComments { await ensureAllCommentsLoaded() }
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
        if hasMoreComments { await ensureAllCommentsLoaded() }
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
        .accessibilityLabel(String(localized: "\(chapter.title), starts at \(PodcastDuration.accessibilityLabel(chapter.startTime))"))
        .accessibilityHint(String(localized: "Double-tap to seek."))
    }
}

// MARK: - Audio enhancements

private struct AudioEnhancementsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var preferences: PreferencesStore

    private var stateSummary: String {
        [
            preferences.voiceBoost ? "Voice Boost on" : "Voice Boost off",
            preferences.trimSilence ? "Trim Silence on" : "Trim Silence off",
            "EQ \(preferences.podcastEQ.displayName)",
            "Pitch correction on"
        ].joined(separator: ", ")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Audio Enhancements") {
                    Toggle("Voice Boost", isOn: $preferences.voiceBoost)
                        .accessibilityHint(String(localized: "Makes voices clearer and more prominent."))

                    Toggle("Trim Silence", isOn: $preferences.trimSilence)
                        .accessibilityHint(String(localized: "Shortens quiet pauses between words."))

                    Picker("Equaliser", selection: $preferences.podcastEQ) {
                        ForEach(PodcastEQ.allCases) { eq in
                            Text(eq.displayName).tag(eq)
                        }
                    }
                    .accessibilityHint(String(localized: "Adjusts the audio frequency balance. Speech Clarity is usually best for spoken-word podcasts."))
                    // Explicit value — without it, swiping up/down only
                    // played the "value changed" tone with no spoken EQ
                    // name. Same fix as PlayerView's playback-speed control
                    // (PODCAST-06). Reported directly.
                    .accessibilityValue(Text(preferences.podcastEQ.displayName))
                    .accessibilityAdjustableAction { direction in
                        guard let idx = PodcastEQ.allCases.firstIndex(of: preferences.podcastEQ) else { return }
                        switch direction {
                        case .increment:
                            preferences.podcastEQ = PodcastEQ.allCases[(idx + 1) % PodcastEQ.allCases.count]
                        case .decrement:
                            preferences.podcastEQ = PodcastEQ.allCases[(idx - 1 + PodcastEQ.allCases.count) % PodcastEQ.allCases.count]
                        @unknown default: break
                        }
                    }
                }

                Section("Pitch Correction") {
                    LabeledContent("Status", value: "On automatically")
                    Text("AppleVis keeps voices sounding natural at faster playback speeds.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "Pitch Correction. On automatically. AppleVis keeps voices sounding natural at faster playback speeds."))
            }
            .themedList(preferences.colors)
            .navigationTitle("Audio Enhancements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .accessibilityValue(stateSummary)
        }
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
    @EnvironmentObject private var preferences: PreferencesStore
    @StateObject private var guidelines = GuidelinesCheckState()
    @StateObject private var intelligence = ComposeIntelligenceState()

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
                if intelligence.showTranslatePrompt {
                    TranslatePromptView(isProcessing: intelligence.isProcessing) {
                        Task {
                            if let result = await intelligence.translate(subject: nil, body: commentText, isTopic: false) {
                                commentText = result.body
                            } else {
                                toast.error(String(localized: "Couldn't translate this. Try again."))
                            }
                        }
                    } onDismiss: {
                        intelligence.dismissTranslatePrompt()
                    }
                    .padding(.horizontal)
                }
                if let warning = guidelines.topWarning {
                    GuidelinesReminderView(
                        warning: warning,
                        draftText: commentText,
                        context: "Podcast Episode Comment",
                        onDismiss: { guidelines.dismiss() },
                        onRewriteRespectfully: {
                            Task {
                                if let result = await intelligence.rewriteRespectfully(subject: nil, body: commentText, isTopic: false) {
                                    commentText = result.body
                                } else {
                                    toast.error(String(localized: "Couldn't rewrite this. Try again."))
                                }
                            }
                        }
                    )
                        .padding(.horizontal)
                }
                TextEditor(text: $commentText)
                    .padding()
                    .onChange(of: commentText) { _, newValue in
                        guidelines.textChanged(newValue, isReply: true)
                        intelligence.textChanged(
                            newValue,
                            translationEnabled: preferences.composeTranslationEnabled,
                            detectionEnabled: preferences.nonEnglishDetectionEnabled
                        )
                    }
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
        if let message = ContentSubmissionPolicy.blockingMessage(
            body: commentText
        ) {
            submitError = message
            return
        }
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
        } catch { submitError = "Couldn't post comment. Try again." }
        isSubmitting = false
    }
}
