import SwiftUI

// MARK: - Mini Player (shown above the tab bar in ContentView)

struct MiniPlayerView: View {
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var toast: ToastStore
    @State private var showFullPlayer = false

    var body: some View {
        if let episode = player.currentEpisode {
            HStack(spacing: 12) {
                AsyncImage(url: episode.artworkUrl.flatMap(URL.init)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "mic.fill").foregroundStyle(.secondary)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(episode.title)
                        .font(.subheadline).fontWeight(.medium)
                        .lineLimit(1)
                    Text(episode.showTitle)
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    player.togglePlayPause()
                    // See EpisodeDetailView.playOrPause's identical fix —
                    // the label updates reactively, but VoiceOver needs an
                    // explicit announcement to actually speak the new state
                    // right after the tap.
                    UIAccessibility.post(notification: .announcement, argument: player.isPlaying ? String(localized: "Pause") : String(localized: "Play"))
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.isPlaying ? String(localized: "Pause") : String(localized: "Play"))

                Button {
                    Task { await player.skip(by: preferences.skipForwardInterval) }
                } label: {
                    Image(systemName: "goforward.\(Int(preferences.skipForwardInterval))")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Skip forward \(PodcastDuration.accessibilityLabel(preferences.skipForwardInterval))"))

                Button {
                    player.stop()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Stop and dismiss player"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .adaptiveGlass(in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .onTapGesture { showFullPlayer = true }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(
                String(localized: "\(episode.title) by \(episode.showTitle). ") +
                String(localized: "\(player.isPlaying ? "Playing" : "Paused"). Double-tap to open player.")
            )
            .sheet(isPresented: $showFullPlayer) {
                FullPlayerView()
            }
            // Previously `errorMessage` was set on a stream failure but
            // nothing in the UI ever read it — a dropped connection just
            // left playback silently stalled with no explanation anywhere.
            .onChange(of: player.errorMessage) { _, message in
                guard let message else { return }
                toast.error(message)
            }
        }
    }
}

// MARK: - Full Player (sheet)

struct FullPlayerView: View {
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss
    @State private var showQueue = false

    private let speedOptions: [Float] = PodcastSpeedOptions.all.map(Float.init)

    var body: some View {
        NavigationStack {
            if let episode = player.currentEpisode {
                ScrollView {
                    VStack(spacing: 0) {
                        // Artwork
                        AsyncImage(url: episode.artworkUrl.flatMap(URL.init)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.secondary.opacity(0.2))
                                .overlay(
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 60))
                                        .foregroundStyle(.secondary)
                                )
                        }
                        .frame(width: 220, height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(radius: 20, y: 8)
                        .padding(.top, 24)
                        .padding(.bottom, 28)
                        .accessibilityHidden(true)

                        // Episode info
                        VStack(spacing: 6) {
                            Text(episode.title)
                                .font(.title3).fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                            Text(episode.showTitle)
                                .font(.subheadline).foregroundStyle(.secondary)
                            if let chapter = player.currentChapter, let index = episode.chapters.firstIndex(where: { $0.id == chapter.id }) {
                                Text("Chapter \(index + 1) of \(episode.chapters.count): \(chapter.title)")
                                    .font(.caption).foregroundStyle(Color.accentColor)
                                    .padding(.top, 2)
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 28)

                        // Scrubber
                        ScrubberView()
                            .padding(.horizontal, 28)
                            .padding(.bottom, 4)

                        // Time labels
                        HStack {
                            Text(PodcastDuration.colon(player.position))
                            Spacer()
                            Text("-\(PodcastDuration.colon(max(0, player.duration - player.position)))")
                        }
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 24)
                        .accessibilityHidden(true)

                        // Transport controls
                        transportControls
                            .padding(.horizontal, 24)
                            .padding(.bottom, 28)

                        // Speed + Sleep Timer + AirPlay. GlassEffectContainer
                        // (iOS 26+) coalesces the individual .adaptiveGlass
                        // shapes' rendering; below iOS 26 there's no
                        // equivalent to imitate, so the content just renders
                        // directly — each button's own .adaptiveGlass
                        // fallback still applies.
                        Group {
                            let buttons = HStack(spacing: 12) {
                                speedButton
                                sleepTimerButton
                                RoutePickerView()
                                    .frame(width: 22, height: 22)
                                    .padding(11)
                                    .contentShape(Rectangle())
                                    .accessibilityLabel(String(localized: "Audio output"))
                            }
                            if #available(iOS 26.0, *) {
                                GlassEffectContainer(spacing: 12) { buttons }
                            } else {
                                buttons
                            }
                        }
                        .padding(.bottom, 32)
                    }
                }
                .background(preferences.colors.background)
                .navigationTitle("Now Playing")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // No way to reach Up Next from Now Playing (PODCAST-13) —
                    // users had to dismiss the full player and navigate
                    // elsewhere to see or reorder the queue.
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showQueue = true
                        } label: {
                            Image(systemName: "list.number")
                        }
                        .accessibilityLabel(String(localized: "Queue"))
                        .accessibilityHint(String(localized: "Shows what's playing next."))
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { SoundPlayer.shared.play(.screenClose); dismiss() }
                    }
                }
                .sheet(isPresented: $showQueue) {
                    QueueView(isModal: true)
                }
            }
        }
        // Keyboard shortcuts — useful with a hardware keyboard (iPad/Mac Catalyst).
        // `.opacity(0)` only hides these visually; `.accessibilityHidden(true)`
        // is what actually keeps three unlabeled "Button" stops off the
        // VoiceOver/Switch Control/Voice Control navigation order. Applied
        // to this Group specifically, not the outer chain, so it doesn't
        // hide the actual player content behind it.
        .background {
            Group {
                Button("") { player.togglePlayPause() }
                    .keyboardShortcut(.space, modifiers: [])
                Button("") { Task { await player.skip(by: -preferences.skipBackInterval) } }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button("") { Task { await player.skip(by: preferences.skipForwardInterval) } }
                    .keyboardShortcut(.rightArrow, modifiers: [])
            }
            .opacity(0)
            .accessibilityHidden(true)
        }
    }

    private var transportControls: some View {
        HStack(spacing: 0) {
            Button {
                Task { await player.skip(by: -preferences.skipBackInterval) }
            } label: {
                Image(systemName: "gobackward.\(Int(preferences.skipBackInterval))")
                    .font(.system(size: 34))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Skip back \(PodcastDuration.accessibilityLabel(preferences.skipBackInterval))"))
            .frame(maxWidth: .infinity)

            Button {
                player.togglePlayPause()
                // See EpisodeDetailView.playOrPause's identical fix — the
                // label updates reactively, but VoiceOver needs an explicit
                // announcement to actually speak the new state right after
                // the tap.
                UIAccessibility.post(notification: .announcement, argument: player.isPlaying ? String(localized: "Pause") : String(localized: "Play"))
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 76))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? String(localized: "Pause") : String(localized: "Play"))
            .frame(maxWidth: .infinity)

            Button {
                Task { await player.skip(by: preferences.skipForwardInterval) }
            } label: {
                Image(systemName: "goforward.\(Int(preferences.skipForwardInterval))")
                    .font(.system(size: 34))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Skip forward \(PodcastDuration.accessibilityLabel(preferences.skipForwardInterval))"))
            .frame(maxWidth: .infinity)
        }
    }

    private var speedButton: some View {
        let current = player.playbackSpeed
        let currentIndex = speedOptions.firstIndex(of: current) ?? 2
        let nextIndex = (currentIndex + 1) % speedOptions.count
        let next = speedOptions[nextIndex]

        return Button {
            player.playbackSpeed = next
        } label: {
            Text("\(speedLabel(current))×")
                .font(.subheadline).fontWeight(.bold)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .adaptiveGlass(in: Capsule())
        }
        .buttonStyle(.plain)
        // Split into a static label + dynamic value (PODCAST-06) — VoiceOver's
        // automatic post-adjustment announcement speaks accessibilityValue,
        // not the label, so baking the current speed only into the label
        // risked no audible confirmation after swiping to change it.
        .accessibilityLabel(String(localized: "Playback speed"))
        .accessibilityValue(String(localized: "\(speedLabel(current))×"))
        .accessibilityHint(String(localized: "Double-tap to increase. Swipe up or down to adjust."))
        // Was double-tap-to-increase only, wrapping 3.0x back to 0.5x — a
        // VoiceOver user who overshot their target speed had to tap through
        // the entire list again (up to 9 taps) instead of swiping down once.
        .accessibilityAdjustableAction { direction in
            let idx = speedOptions.firstIndex(of: player.playbackSpeed) ?? 2
            switch direction {
            case .increment:
                player.playbackSpeed = speedOptions[(idx + 1) % speedOptions.count]
            case .decrement:
                player.playbackSpeed = speedOptions[(idx - 1 + speedOptions.count) % speedOptions.count]
            @unknown default: break
            }
        }
    }

    private var sleepTimerButton: some View {
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
            Label(sleepTimerLabel, systemImage: "moon.zzz")
                .font(.subheadline).fontWeight(.bold)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .adaptiveGlass(in: Capsule())
        }
        .accessibilityLabel(sleepTimerAccessibilityLabel)
    }

    private var sleepTimerAccessibilityLabel: String {
        if player.sleepAtEndOfEpisode {
            return String(localized: "Sleep Timer, end of episode")
        }
        if let remaining = player.sleepTimerRemaining {
            return String(localized: "Sleep Timer, \(PodcastDuration.accessibilityRemaining(remaining))")
        }
        return String(localized: "Sleep Timer")
    }

    private var sleepTimerLabel: String {
        if player.sleepAtEndOfEpisode { return "End" }
        if let remaining = player.sleepTimerRemaining { return PodcastDuration.colon(remaining) }
        return ""
    }

    private func speedLabel(_ speed: Float) -> String {
        speed.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", speed)
            : String(format: "%.2g", speed)
    }
}

// MARK: - Scrubber (extracted so it can read geometry)

private struct ScrubberView: View {
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var preferences: PreferencesStore

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(height: 4)
                Capsule()
                    .fill(Color.accentColor)
                    .frame(
                        width: player.duration > 0
                            ? geo.size.width * CGFloat(min(1, player.position / player.duration))
                            : 0,
                        height: 4
                    )
            }
            .frame(height: 28)
            .contentShape(Rectangle())
            .onTapGesture { location in
                guard player.duration > 0 else { return }
                let ratio = location.x / geo.size.width
                Task { await player.seek(to: ratio * player.duration) }
            }
        }
        .frame(height: 28)
        .accessibilityElement()
        .accessibilityLabel(String(localized: "Playback position"))
        // Standardized on elapsed-of-total phrasing (PODCAST-11) — percent
        // was redundant alongside the time and made repeated Braille reads
        // during a seek gesture more verbose than necessary.
        .accessibilityValue(player.duration > 0
            ? PodcastDuration.accessibilityPosition(current: player.position, duration: player.duration)
            : PodcastDuration.accessibilityLabel(0)
        )
        .accessibilityAdjustableAction { direction in
            // Was hardcoded to 30s/15s regardless of the user's configured
            // skip intervals — every other skip control on this screen
            // (transport buttons, mini-player) already reads these
            // preferences, so swiping the scrubber behaved inconsistently
            // with double-tapping the actual skip buttons.
            switch direction {
            case .increment: Task { await player.skip(by: preferences.skipForwardInterval) }
            case .decrement: Task { await player.skip(by: -preferences.skipBackInterval) }
            @unknown default: break
            }
        }
    }
}
