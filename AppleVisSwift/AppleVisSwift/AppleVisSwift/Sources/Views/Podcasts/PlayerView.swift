import SwiftUI

// MARK: - Mini Player (shown above the tab bar in ContentView)

struct MiniPlayerView: View {
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var preferences: PreferencesStore
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
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

                Button {
                    Task { await player.skip(by: preferences.skipForwardInterval) }
                } label: {
                    Image(systemName: "goforward.\(Int(preferences.skipForwardInterval))")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip forward \(Int(preferences.skipForwardInterval)) seconds")

                Button {
                    player.stop()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop and dismiss player")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .onTapGesture { showFullPlayer = true }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(
                "\(episode.title) by \(episode.showTitle). " +
                "\(player.isPlaying ? "Playing" : "Paused"). Double-tap to open player."
            )
            .sheet(isPresented: $showFullPlayer) {
                FullPlayerView()
            }
        }
    }
}

// MARK: - Full Player (sheet)

struct FullPlayerView: View {
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss

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
                            Text(formatTime(player.position))
                            Spacer()
                            Text("-\(formatTime(max(0, player.duration - player.position)))")
                        }
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 24)
                        .accessibilityHidden(true)

                        // Transport controls
                        transportControls
                            .padding(.horizontal, 24)
                            .padding(.bottom, 28)

                        // Speed + Sleep Timer + AirPlay
                        GlassEffectContainer(spacing: 12) {
                            HStack(spacing: 12) {
                                speedButton
                                sleepTimerButton
                                RoutePickerView()
                                    .frame(width: 22, height: 22)
                                    .padding(11)
                                    .contentShape(Rectangle())
                                    .accessibilityLabel("Audio output")
                            }
                        }
                        .padding(.bottom, 32)
                    }
                }
                .navigationTitle("Now Playing")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { SoundPlayer.shared.play(.screenClose); dismiss() }
                    }
                }
            }
        }
        // Keyboard shortcuts — useful with a hardware keyboard (iPad/Mac Catalyst).
        .background {
            Button("") { player.togglePlayPause() }
                .keyboardShortcut(.space, modifiers: [])
                .opacity(0)
            Button("") { Task { await player.skip(by: -preferences.skipBackInterval) } }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .opacity(0)
            Button("") { Task { await player.skip(by: preferences.skipForwardInterval) } }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .opacity(0)
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
            .accessibilityLabel("Skip back \(Int(preferences.skipBackInterval)) seconds")
            .frame(maxWidth: .infinity)

            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 76))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            .frame(maxWidth: .infinity)

            Button {
                Task { await player.skip(by: preferences.skipForwardInterval) }
            } label: {
                Image(systemName: "goforward.\(Int(preferences.skipForwardInterval))")
                    .font(.system(size: 34))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip forward \(Int(preferences.skipForwardInterval)) seconds")
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
                .glassEffect(in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Playback speed: \(speedLabel(current))×")
        .accessibilityHint("Double-tap to increase. Swipe up or down to adjust.")
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
                Button("Turn Off", role: .destructive) { player.cancelSleepTimer() }
            }
        } label: {
            Label(sleepTimerLabel, systemImage: "moon.zzz")
                .font(.subheadline).fontWeight(.bold)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .glassEffect(in: Capsule())
        }
        .accessibilityLabel("Sleep timer\(sleepTimerLabel.isEmpty ? "" : ": \(sleepTimerLabel)")")
    }

    private var sleepTimerLabel: String {
        if player.sleepAtEndOfEpisode { return "End" }
        if let remaining = player.sleepTimerRemaining { return formatTime(remaining) }
        return ""
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%d:%02d", m, sec)
    }

    private func speedLabel(_ speed: Float) -> String {
        speed.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", speed)
            : String(format: "%.2g", speed)
    }
}

/// Shared by ScrubberView's VoiceOver value and FullPlayerView's visible time
/// labels — the scrubber previously announced only a bare percentage since
/// the visible time labels are `.accessibilityHidden`, giving VoiceOver
/// users no spoken elapsed/remaining time at all.
private func formatScrubberTime(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds))
    let h = s / 3600
    let m = (s % 3600) / 60
    let sec = s % 60
    return h > 0
        ? String(format: "%d:%02d:%02d", h, m, sec)
        : String(format: "%d:%02d", m, sec)
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
        .accessibilityLabel("Playback position")
        .accessibilityValue(player.duration > 0
            ? "\(formatScrubberTime(player.position)) of \(formatScrubberTime(player.duration)), \(Int(player.position / player.duration * 100))%"
            : "0%"
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
