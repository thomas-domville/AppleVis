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
        ("Off", 0), ("10 seconds", 10), ("15 seconds", 15), ("30 seconds", 30)
    ]

    var body: some View {
        Form {
            Section("Playback") {
                Picker("Speed", selection: $preferences.playbackSpeed) {
                    ForEach(speedOptions, id: \.self) { speed in
                        Text(speedLabel(speed)).tag(speed)
                    }
                }
                .accessibilityHint(String(localized: "Controls how fast episodes play. 1× is normal speed."))

                Picker("Skip Back", selection: $preferences.skipBackInterval) {
                    ForEach(skipBackOptions, id: \.self) { s in
                        Text("\(Int(s)) seconds").tag(s)
                    }
                }
                .accessibilityHint(String(localized: "How many seconds the skip-back button jumps."))

                Picker("Skip Forward", selection: $preferences.skipForwardInterval) {
                    ForEach(skipForwardOptions, id: \.self) { s in
                        Text("\(Int(s)) seconds").tag(s)
                    }
                }
                .accessibilityHint(String(localized: "How many seconds the skip-forward button jumps."))

                Toggle("Auto-Play Next", isOn: $preferences.autoPlayNext)
                    .accessibilityHint(String(localized: "Automatically starts the next episode when the current one ends."))
            }

            Section("Audio Enhancement") {
                Toggle("Trim Silence", isOn: $preferences.trimSilence)
                    .accessibilityHint(String(localized: "Speeds up playback by shortening quiet pauses between words."))
                Toggle("Voice Boost", isOn: $preferences.voiceBoost)
                    .accessibilityHint(String(localized: "Applies processing to make voices clearer and more prominent."))
                Picker("Equaliser", selection: $preferences.podcastEQ) {
                    ForEach(PodcastEQ.allCases) { eq in
                        Text(eq.displayName).tag(eq)
                    }
                }
                .accessibilityHint(String(localized: "Adjusts the audio frequency balance."))
            }

            Section("Smart Controls") {
                Picker("Sleep Timer", selection: $preferences.sleepTimerMinutes) {
                    ForEach(sleepTimerOptions, id: \.minutes) { opt in
                        Text(opt.label).tag(opt.minutes)
                    }
                }
                .accessibilityHint(String(localized: "Automatically pauses playback after the chosen period. Useful for falling asleep while listening."))

                Picker("Resume Rewind", selection: $preferences.resumeRewindSeconds) {
                    ForEach(resumeRewindOptions, id: \.seconds) { opt in
                        Text(opt.label).tag(opt.seconds)
                    }
                }
                .accessibilityHint(String(localized: "When you resume a paused episode, the player rewinds by this many seconds to give you context."))
            }

            Section("Downloads") {
                Picker("Auto-Download", selection: $preferences.autoDownload) {
                    ForEach(PodcastAutoDownload.allCases) { opt in
                        Text(opt.displayName).tag(opt)
                    }
                }
                .accessibilityHint(String(localized: "Automatically downloads new episodes for offline listening."))

                Picker("Auto-Delete", selection: $preferences.autoDelete) {
                    ForEach(PodcastAutoDelete.allCases) { opt in
                        Text(opt.displayName).tag(opt)
                    }
                }
                .accessibilityHint(String(localized: "Automatically removes played episodes to free up storage."))
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Podcasts")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func speedLabel(_ speed: Double) -> String {
        speed == 1.0 ? "1× (Normal)" : "\(speed)×"
    }
}
