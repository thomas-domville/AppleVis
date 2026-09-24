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
                    title: String(localized: "Open AppleVis"),
                    subtitle: String(localized: "\"Hey Siri, open AppleVis\""),
                    detail: String(localized: "Opens AppleVis to the Home tab."),
                    isSystemFeature: true
                )
                FeatureInfoRow(
                    icon: "bubble.left.and.bubble.right",
                    title: String(localized: "Open AppleVis Forums"),
                    subtitle: String(localized: "\"Hey Siri, open AppleVis Forums\""),
                    detail: String(localized: "Opens the Forums browser."),
                    isSystemFeature: true
                )
                FeatureInfoRow(
                    icon: "circle.badge",
                    title: String(localized: "Show Unread AppleVis Topics"),
                    subtitle: String(localized: "\"Hey Siri, show unread AppleVis topics\""),
                    detail: String(localized: "Opens Forums filtered to unread topics."),
                    isSystemFeature: true
                )
                FeatureInfoRow(
                    icon: "play.circle",
                    title: String(localized: "Resume AppleVis Podcast"),
                    subtitle: String(localized: "\"Hey Siri, resume AppleVis podcast\""),
                    detail: String(localized: "Resumes the last-played episode from where you left off."),
                    isSystemFeature: true
                )
                FeatureInfoRow(
                    icon: "play.circle.fill",
                    title: String(localized: "Play Latest AppleVis Podcast"),
                    subtitle: String(localized: "\"Hey Siri, play latest AppleVis podcast\""),
                    detail: String(localized: "Plays the newest AppleVis podcast episode."),
                    isSystemFeature: true
                )
                FeatureInfoRow(
                    icon: "magnifyingglass",
                    title: String(localized: "Search AppleVis"),
                    subtitle: String(localized: "\"Hey Siri, search AppleVis\""),
                    detail: String(localized: "Searches forum topics, apps, podcast episodes, and guides."),
                    isSystemFeature: true
                )
                FeatureInfoRow(
                    icon: "bookmark",
                    title: String(localized: "Open AppleVis Saved Items"),
                    subtitle: String(localized: "\"Hey Siri, open AppleVis saved items\""),
                    detail: String(localized: "Opens your saved items."),
                    isSystemFeature: true
                )
                FeatureInfoRow(
                    icon: "sparkles",
                    title: String(localized: "What's New on AppleVis"),
                    subtitle: String(localized: "\"Hey Siri, what's new on AppleVis\""),
                    detail: String(localized: "Speaks a summary of what's new since your last visit."),
                    isSystemFeature: true
                )
                FeatureInfoRow(
                    icon: "ant",
                    title: String(localized: "Report an AppleVis Bug"),
                    subtitle: String(localized: "\"Hey Siri, report a bug to AppleVis\""),
                    detail: String(localized: "Opens straight to the accessibility bug report form."),
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
