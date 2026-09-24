import SwiftUI

struct IntelligenceSettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var tips: TipStore
    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        Form {
            Section {
                Text("Smart features powered by Apple Intelligence run entirely on your device. Nothing is sent to external servers.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityFocused($isTitleFocused)
            }

            Section("Apple Intelligence Features") {
                // Previously described as noticing non-English content you're
                // *reading* and offering to translate it — but AppleVis
                // guidelines require posts to be in English, so nothing
                // non-English should ever be sitting there to read in the
                // first place. What this actually does is detect your OWN
                // draft while you're writing a post, reply, or comment, and
                // offer a live nudge to translate it before you submit —
                // separate from and in addition to the always-on English-only
                // check applied at submission itself (see
                // `ContentSubmissionPolicy.blockingMessage`), which this
                // toggle cannot turn off. Reported directly.
                Toggle("Non-English Draft Detection", isOn: $preferences.nonEnglishDetectionEnabled)
                    .accessibilityHint(String(localized: "While you write a post, reply, or comment, offers to translate your draft if it isn't in English."))
                Text("AppleVis posts must be in English — that's always checked when you submit, no matter how this is set. This only controls whether you get a proactive nudge to translate while you're still typing, instead of finding out at submission.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Compose Rewrite", isOn: $preferences.composeRewriteEnabled)
                    .accessibilityHint(String(localized: "When writing a forum post or message, AI can suggest rewrites to improve clarity or tone."))
                Text("Offers a polished rewrite while you're writing a post or message, without changing what you're trying to say.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Compose Translation", isOn: $preferences.composeTranslationEnabled)
                    .accessibilityHint(String(localized: "Translates your draft text so you can communicate in other languages."))
                Text("Translates your own draft, so you can write in another language and still post it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Search Translation", isOn: $preferences.searchTranslationEnabled)
                    .accessibilityHint(String(localized: "When you search for terms in non-English, AI translates your query to find relevant results."))
                Text("Translates a search typed in another language so you still find the right results.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("AI Summaries", isOn: $preferences.aiSummariesEnabled)
                    .accessibilityHint(String(localized: "Creates short summaries of long forum threads and articles, so you can decide whether to read more."))
                Text("Boils down long threads and articles into a quick summary, so you can decide whether it's worth reading in full.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                FeatureInfoRow(
                    icon: "checkmark.bubble",
                    title: String(localized: "Accessibility Consensus"),
                    subtitle: String(localized: "On an app's page, under comments"),
                    detail: String(localized: "Aggregates an app's comments into one sentence about how well it works with VoiceOver — an instant overview instead of reading every comment yourself."),
                    isSystemFeature: false
                )
            }

            Section("Live System Features") {
                FeatureInfoRow(
                    icon: "speaker.wave.3",
                    title: String(localized: "Read Aloud"),
                    subtitle: String(localized: "iOS system feature"),
                    detail: String(localized: "Reads any text on screen. Available via the Share sheet or accessibility shortcut."),
                    isSystemFeature: true
                )

                FeatureInfoRow(
                    icon: "character.bubble",
                    title: String(localized: "Translate"),
                    subtitle: String(localized: "iOS system feature"),
                    detail: String(localized: "Translate selected text using the iOS Translate system. Long-press any text to access."),
                    isSystemFeature: true
                )
            }

            Section("Native Integration") {
                FeatureInfoRow(
                    icon: "magnifyingglass",
                    title: "Spotlight",
                    subtitle: String(localized: "Search saved items from Spotlight"),
                    detail: String(localized: "Your bookmarked content is indexed and searchable from iOS Spotlight Search."),
                    isSystemFeature: true
                )

                FeatureInfoRow(
                    icon: "lock.fill",
                    title: String(localized: "Lock Screen & Control Center"),
                    subtitle: String(localized: "Playback controls while podcasts are playing"),
                    detail: String(localized: "Play, pause, and skip from the Lock Screen and Control Center while a podcast episode is playing."),
                    isSystemFeature: true
                )
            }

            Section {
                Label {
                    Text("Apple Intelligence is available on iPhone 15 Pro and later, and all iPhone 16 models, running iOS 18.1 or later.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "cpu")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }

            Section {
                ResetToDefaultsButton {
                    preferences.nonEnglishDetectionEnabled = true
                    preferences.composeRewriteEnabled = true
                    preferences.composeTranslationEnabled = true
                    preferences.searchTranslationEnabled = true
                    preferences.aiSummariesEnabled = true
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Intelligence")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { tips.show(.settingsIntelligence) }
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
    }
}

struct FeatureInfoRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let detail: String
    let isSystemFeature: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isSystemFeature {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                            .accessibilityHidden(true)
                    }
                }
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(Color.accentColor)
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 32)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(title). \(subtitle). \(detail)"))
    }
}
