import SwiftUI

struct PodcastSettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore

    private let speedOptions: [Double] = PodcastSpeedOptions.all
    private let skipBackOptions: [Double] = [5, 10, 15, 30]
    private let skipForwardOptions: [Double] = [15, 30, 45, 60]
    private let sleepTimerOptions: [(label: String, minutes: Int)] = [
        ("Off", 0), ("15 minutes", 15), ("30 minutes", 30), ("45 minutes", 45), ("60 minutes", 60)
    ]
    private let resumeRewindOptions: [(label: String, seconds: Int)] = [
        ("Off", 0), ("5 seconds", 5), ("10 seconds", 10), ("15 seconds", 15), ("30 seconds", 30)
    ]
    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        Form {
            Section("Playback") {
                Picker("Speed", selection: $preferences.playbackSpeed) {
                    ForEach(speedOptions, id: \.self) { speed in
                        Text(speedLabel(speed)).tag(speed)
                    }
                }
                .accessibilityHint(String(localized: "Controls how fast episodes play. 1× is normal speed."))
                .accessibilityAdjustableAction { direction in
                    guard let idx = speedOptions.firstIndex(of: preferences.playbackSpeed) else { return }
                    switch direction {
                    case .increment:
                        preferences.playbackSpeed = speedOptions[(idx + 1) % speedOptions.count]
                    case .decrement:
                        preferences.playbackSpeed = speedOptions[(idx - 1 + speedOptions.count) % speedOptions.count]
                    @unknown default: break
                    }
                }
                // Was focused on the Speed picker control itself — the
                // literal "jump straight to a control" pattern this app's
                // focus convention exists to avoid; every sibling Settings
                // screen focuses descriptive text instead. Full app-wide
                // focus audit, requested directly.
                Text("Controls how fast episodes play — higher gets through more in less time, lower gives you more breathing room.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityFocused($isTitleFocused)

                Picker("Skip Back", selection: $preferences.skipBackInterval) {
                    ForEach(skipBackOptions, id: \.self) { s in
                        Text("\(Int(s)) seconds").tag(s)
                    }
                }
                .accessibilityHint(String(localized: "How many seconds the skip-back button jumps."))
                .accessibilityAdjustableAction { direction in
                    guard let idx = skipBackOptions.firstIndex(of: preferences.skipBackInterval) else { return }
                    switch direction {
                    case .increment:
                        preferences.skipBackInterval = skipBackOptions[(idx + 1) % skipBackOptions.count]
                    case .decrement:
                        preferences.skipBackInterval = skipBackOptions[(idx - 1 + skipBackOptions.count) % skipBackOptions.count]
                    @unknown default: break
                    }
                }

                Picker("Skip Forward", selection: $preferences.skipForwardInterval) {
                    ForEach(skipForwardOptions, id: \.self) { s in
                        Text("\(Int(s)) seconds").tag(s)
                    }
                }
                .accessibilityHint(String(localized: "How many seconds the skip-forward button jumps."))
                .accessibilityAdjustableAction { direction in
                    guard let idx = skipForwardOptions.firstIndex(of: preferences.skipForwardInterval) else { return }
                    switch direction {
                    case .increment:
                        preferences.skipForwardInterval = skipForwardOptions[(idx + 1) % skipForwardOptions.count]
                    case .decrement:
                        preferences.skipForwardInterval = skipForwardOptions[(idx - 1 + skipForwardOptions.count) % skipForwardOptions.count]
                    @unknown default: break
                    }
                }

                Toggle("Auto-Play Next", isOn: $preferences.autoPlayNext)
                    .accessibilityHint(String(localized: "Automatically starts the next episode when the current one ends."))
            }

            Section("Audio Enhancement") {
                Toggle("Trim Silence", isOn: $preferences.trimSilence)
                    .accessibilityHint(String(localized: "Speeds up playback by shortening quiet pauses between words."))
                Text("Shortens the quiet pauses between words, so episodes move along a little faster without changing the speed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Voice Boost", isOn: $preferences.voiceBoost)
                    .accessibilityHint(String(localized: "Applies processing to make voices clearer and more prominent."))
                Text("Processes the audio to make voices stand out more clearly against music or background noise.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Equaliser", selection: $preferences.podcastEQ) {
                    ForEach(PodcastEQ.allCases) { eq in
                        Text(eq.displayName).tag(eq)
                    }
                }
                .accessibilityHint(String(localized: "Adjusts the audio frequency balance."))
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
                Text("Shapes the tone of playback — Speech Clarity favours voices, Bass Boost and Treble Boost lean into low or high frequencies, Flat leaves it untouched.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Smart Controls") {
                Picker("Sleep Timer", selection: $preferences.sleepTimerMinutes) {
                    ForEach(sleepTimerOptions, id: \.minutes) { opt in
                        Text(opt.label).tag(opt.minutes)
                    }
                }
                .accessibilityHint(String(localized: "Automatically pauses playback after the chosen period. Useful for falling asleep while listening."))
                .accessibilityAdjustableAction { direction in
                    guard let idx = sleepTimerOptions.firstIndex(where: { $0.minutes == preferences.sleepTimerMinutes }) else { return }
                    switch direction {
                    case .increment:
                        preferences.sleepTimerMinutes = sleepTimerOptions[(idx + 1) % sleepTimerOptions.count].minutes
                    case .decrement:
                        preferences.sleepTimerMinutes = sleepTimerOptions[(idx - 1 + sleepTimerOptions.count) % sleepTimerOptions.count].minutes
                    @unknown default: break
                    }
                }
                Text("Pauses playback on its own after the time you pick — handy for drifting off without an episode playing all night.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Resume Rewind", selection: $preferences.resumeRewindSeconds) {
                    ForEach(resumeRewindOptions, id: \.seconds) { opt in
                        Text(opt.label).tag(opt.seconds)
                    }
                }
                .accessibilityHint(String(localized: "When you resume a paused episode, the player rewinds by this many seconds to give you context."))
                .accessibilityAdjustableAction { direction in
                    guard let idx = resumeRewindOptions.firstIndex(where: { $0.seconds == preferences.resumeRewindSeconds }) else { return }
                    switch direction {
                    case .increment:
                        preferences.resumeRewindSeconds = resumeRewindOptions[(idx + 1) % resumeRewindOptions.count].seconds
                    case .decrement:
                        preferences.resumeRewindSeconds = resumeRewindOptions[(idx - 1 + resumeRewindOptions.count) % resumeRewindOptions.count].seconds
                    @unknown default: break
                    }
                }
                Text("Rewinds a few seconds when you resume a paused episode, so you get context instead of picking up mid-sentence.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Downloads") {
                Picker("Auto-Download", selection: $preferences.autoDownload) {
                    ForEach(PodcastAutoDownload.allCases) { opt in
                        Text(opt.displayName).tag(opt)
                    }
                }
                .accessibilityHint(String(localized: "Automatically downloads new episodes for offline listening."))
                .accessibilityAdjustableAction { direction in
                    guard let idx = PodcastAutoDownload.allCases.firstIndex(of: preferences.autoDownload) else { return }
                    switch direction {
                    case .increment:
                        preferences.autoDownload = PodcastAutoDownload.allCases[(idx + 1) % PodcastAutoDownload.allCases.count]
                    case .decrement:
                        preferences.autoDownload = PodcastAutoDownload.allCases[(idx - 1 + PodcastAutoDownload.allCases.count) % PodcastAutoDownload.allCases.count]
                    @unknown default: break
                    }
                }
                Text("Downloads new episodes on their own, so they're ready to play offline before you even open them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Auto-Delete", selection: $preferences.autoDelete) {
                    ForEach(PodcastAutoDelete.allCases) { opt in
                        Text(opt.displayName).tag(opt)
                    }
                }
                .accessibilityHint(String(localized: "Automatically removes played episodes to free up storage."))
                .accessibilityAdjustableAction { direction in
                    guard let idx = PodcastAutoDelete.allCases.firstIndex(of: preferences.autoDelete) else { return }
                    switch direction {
                    case .increment:
                        preferences.autoDelete = PodcastAutoDelete.allCases[(idx + 1) % PodcastAutoDelete.allCases.count]
                    case .decrement:
                        preferences.autoDelete = PodcastAutoDelete.allCases[(idx - 1 + PodcastAutoDelete.allCases.count) % PodcastAutoDelete.allCases.count]
                    @unknown default: break
                    }
                }
                Text("Removes downloaded episodes once you've finished them, to keep them from piling up and using storage.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                ResetToDefaultsButton {
                    preferences.playbackSpeed = 1.0
                    preferences.skipBackInterval = 10
                    preferences.skipForwardInterval = 30
                    preferences.autoPlayNext = true
                    preferences.sleepTimerMinutes = 0
                    preferences.resumeRewindSeconds = 15
                    preferences.trimSilence = false
                    preferences.voiceBoost = false
                    preferences.podcastEQ = .flat
                    preferences.autoDownload = .off
                    preferences.autoDelete = .off
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Podcasts")
        .navigationBarTitleDisplayMode(.inline)
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
    }

    private func speedLabel(_ speed: Double) -> String {
        speed == 1.0 ? "1× (Normal)" : "\(speed)×"
    }
}
