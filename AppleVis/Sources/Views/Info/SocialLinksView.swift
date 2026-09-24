import SwiftUI

/// Consolidates the three "Follow AppleVis on X/Facebook/Mastodon" rows that
/// used to sit directly in About's "Connect With Us" section into their own
/// screen, matching the same one-button-to-a-dedicated-list pattern RSS
/// Feeds already uses. Requested directly.
struct SocialLinksView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    /// Had no focus management at all. Full app-wide focus audit,
    /// requested directly.
    @AccessibilityFocusState private var isIntroFocused: Bool

    var body: some View {
        Form {
            Section {
                Text("Follow AppleVis wherever you already hang out online, for updates outside the app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityFocused($isIntroFocused)
            }
            Section {
                ForEach(AppleVisSocial.platforms) { platform in
                    WebLink(destination: platform.url) {
                        Label("Follow AppleVis on \(platform.name)", systemImage: platform.icon)
                    }
                    .accessibilityLabel(String(localized: "Follow AppleVis on \(platform.name)"))
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Social Media")
        .navigationBarTitleDisplayMode(.inline)
        .task { await retryAccessibilityFocus(into: $isIntroFocused) }
    }
}
