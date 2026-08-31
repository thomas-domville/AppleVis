import SwiftUI

/// Consolidates the three "Follow AppleVis on X/Facebook/Mastodon" rows that
/// used to sit directly in About's "Connect With Us" section into their own
/// screen, matching the same one-button-to-a-dedicated-list pattern RSS
/// Feeds already uses. Requested directly.
struct SocialLinksView: View {
    @EnvironmentObject private var preferences: PreferencesStore

    private struct SocialPlatform: Identifiable {
        let id: String
        let name: String
        let icon: String
        let url: URL
    }

    private let platforms: [SocialPlatform] = [
        SocialPlatform(id: "x", name: "X", icon: "at", url: URL(string: "https://x.com/AppleVis")!),
        SocialPlatform(id: "facebook", name: "Facebook", icon: "f.circle", url: URL(string: "https://www.facebook.com/AppleVis")!),
        SocialPlatform(id: "mastodon", name: "Mastodon", icon: "network", url: URL(string: "https://mastodon.online/@AppleVis")!),
    ]

    var body: some View {
        Form {
            Section {
                Text("Follow AppleVis wherever you already hang out online, for updates outside the app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Section {
                ForEach(platforms) { platform in
                    WebLink(destination: platform.url) {
                        Label("Follow AppleVis on \(platform.name)", systemImage: platform.icon)
                    }
                    .accessibilityLabel(String(localized: "Follow AppleVis on \(platform.name)"))
                    .accessibilityHint(String(localized: "Opens in Safari."))
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Social Media")
        .navigationBarTitleDisplayMode(.inline)
    }
}
