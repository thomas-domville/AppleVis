import SwiftUI

struct IntelligenceSettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var tips: TipStore

    var body: some View {
        Form {
            Section {
                Text("Smart features powered by Apple Intelligence run entirely on your device. Nothing is sent to external servers.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Apple Intelligence Features") {
                Toggle("Non-English Content Detection", isOn: $preferences.nonEnglishDetectionEnabled)
                    .accessibilityHint("Detects when you're viewing content in a language other than English and offers to translate it.")

                Toggle("Compose Rewrite", isOn: $preferences.composeRewriteEnabled)
                    .accessibilityHint("When writing a forum post or message, AI can suggest rewrites to improve clarity or tone.")

                Toggle("Compose Translation", isOn: $preferences.composeTranslationEnabled)
                    .accessibilityHint("Translates your draft text so you can communicate in other languages.")

                Toggle("Search Translation", isOn: $preferences.searchTranslationEnabled)
                    .accessibilityHint("When you search for terms in non-English, AI translates your query to find relevant results.")

                Toggle("AI Summaries", isOn: $preferences.aiSummariesEnabled)
                    .accessibilityHint("Generates concise summaries for long forum threads and articles so you can quickly decide whether to read more.")
            }

            Section("Live System Features") {
                FeatureInfoRow(
                    icon: "speaker.wave.3",
                    title: "Read Aloud",
                    subtitle: "iOS system feature",
                    detail: "Reads any text on screen. Available via the Share sheet or accessibility shortcut.",
                    isSystemFeature: true
                )

                FeatureInfoRow(
                    icon: "character.bubble",
                    title: "Translate",
                    subtitle: "iOS system feature",
                    detail: "Translate selected text using the iOS Translate system. Long-press any text to access.",
                    isSystemFeature: true
                )
            }

            Section("Native Integration") {
                FeatureInfoRow(
                    icon: "waveform",
                    title: "Siri",
                    subtitle: "Supports Siri voice commands",
                    detail: "You can ask Siri to open AppleVis and navigate to specific content.",
                    isSystemFeature: true
                )

                FeatureInfoRow(
                    icon: "app.badge",
                    title: "Live Activities",
                    subtitle: "Now-playing controls on Lock Screen",
                    detail: "Control podcast playback from the Lock Screen, Dynamic Island, and Control Center.",
                    isSystemFeature: true
                )

                FeatureInfoRow(
                    icon: "magnifyingglass",
                    title: "Spotlight",
                    subtitle: "Search saved items from Spotlight",
                    detail: "Your bookmarked content is indexed and searchable from iOS Spotlight Search.",
                    isSystemFeature: true
                )

                FeatureInfoRow(
                    icon: "square.grid.2x2",
                    title: "Home Screen Widgets",
                    subtitle: "Quick-glance widgets",
                    detail: "Add AppleVis widgets to see recent content and your podcast queue at a glance.",
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
        }
        .navigationTitle("Intelligence & Siri")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { tips.show(.settingsIntelligence) }
    }
}

private struct FeatureInfoRow: View {
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
        .accessibilityLabel("\(title). \(subtitle). \(detail)")
    }
}
