import SwiftUI

/// docs/APPLEVIS_2026_1_MASTER_SPEC.md's "Settings Model" lists "Siri &
/// Shortcuts" as its own settings item. Siri support is real (see
/// Services/AppleVisShortcuts.swift) but was previously surfaced only as a
/// single description card inside "Intelligence & Siri" — this lists the
/// actual shortcuts so users know what's available, rather than a vague
/// "you can ask Siri to open AppleVis" line.
struct SiriShortcutsSettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        Form {
            Section {
                Text("These AppleVis actions are available to Siri and the Shortcuts app. Add your own phrases for any of them from the Shortcuts app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityFocused($isTitleFocused)
            }

            Section("Available Shortcuts") {
                FeatureInfoRow(
                    icon: "house",
                    title: "Open AppleVis",
                    subtitle: "\"Hey Siri, open AppleVis\"",
                    detail: "Opens AppleVis to the Home tab.",
                    isSystemFeature: true
                )
                FeatureInfoRow(
                    icon: "bubble.left.and.bubble.right",
                    title: "Open AppleVis Forums",
                    subtitle: "\"Hey Siri, open AppleVis Forums\"",
                    detail: "Opens the Forums browser.",
                    isSystemFeature: true
                )
                FeatureInfoRow(
                    icon: "circle.badge",
                    title: "Show Unread AppleVis Topics",
                    subtitle: "\"Hey Siri, show unread AppleVis topics\"",
                    detail: "Opens Forums filtered to unread topics.",
                    isSystemFeature: true
                )
                FeatureInfoRow(
                    icon: "play.circle",
                    title: "Resume AppleVis Podcast",
                    subtitle: "\"Hey Siri, resume AppleVis podcast\"",
                    detail: "Resumes the last-played episode from where you left off.",
                    isSystemFeature: true
                )
                FeatureInfoRow(
                    icon: "play.circle.fill",
                    title: "Play Latest AppleVis Podcast",
                    subtitle: "\"Hey Siri, play latest AppleVis podcast\"",
                    detail: "Plays the newest AppleVis podcast episode.",
                    isSystemFeature: true
                )
                FeatureInfoRow(
                    icon: "magnifyingglass",
                    title: "Search AppleVis",
                    subtitle: "\"Hey Siri, search AppleVis\"",
                    detail: "Searches forum topics, apps, podcast episodes, and guides.",
                    isSystemFeature: true
                )
                FeatureInfoRow(
                    icon: "bookmark",
                    title: "Open AppleVis Saved Items",
                    subtitle: "\"Hey Siri, open AppleVis saved items\"",
                    detail: "Opens your saved items.",
                    isSystemFeature: true
                )
                FeatureInfoRow(
                    icon: "sparkles",
                    title: "What's New on AppleVis",
                    subtitle: "\"Hey Siri, what's new on AppleVis\"",
                    detail: "Speaks a summary of what's new since your last visit.",
                    isSystemFeature: true
                )
                FeatureInfoRow(
                    icon: "ant",
                    title: "Report an AppleVis Bug",
                    subtitle: "\"Hey Siri, report a bug to AppleVis\"",
                    detail: "Opens straight to the accessibility bug report form.",
                    isSystemFeature: true
                )
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Siri & Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
    }
}
