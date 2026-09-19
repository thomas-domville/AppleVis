import SwiftUI

struct HomeFeedSettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        Form {
            Section {
                Text("Controls which content appears in the Home feed by default when you open the app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityFocused($isTitleFocused)
            }

            Section("Home Feed Content") {
                Toggle("Forum Topics", isOn: $preferences.showForums)
                    .accessibilityHint(String(localized: "Include forum topics in the Home feed."))
                Text("Forum discussions show up in your Home feed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Podcast Episodes", isOn: $preferences.showPodcasts)
                    .accessibilityHint(String(localized: "Include podcast episodes in the Home feed."))
                Text("New podcast episodes show up in your Home feed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("App Listings", isOn: $preferences.showApps)
                    .accessibilityHint(String(localized: "Include app directory entries in the Home feed."))
                Text("New and updated App Directory entries show up in your Home feed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Guides & Tutorials", isOn: $preferences.showGuides)
                    .accessibilityHint(String(localized: "Include how-to guides and tutorials in the Home feed."))
                Text("New guides and tutorials show up in your Home feed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Blog Posts", isOn: $preferences.showBlogs)
                    .accessibilityHint(String(localized: "Include blog posts and opinion pieces in the Home feed."))
                Text("New AppleVis Blog posts show up in your Home feed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Apple Topics Only", isOn: $preferences.appleOnlyForums)
                    .accessibilityHint(String(localized: "Limits the Home feed to topics directly related to Apple products and platforms."))
                Text("Narrows the feed down to just topics about Apple products and platforms — everything else stays hidden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                ResetToDefaultsButton {
                    preferences.showForums = true
                    preferences.showPodcasts = true
                    preferences.showApps = true
                    preferences.showGuides = true
                    preferences.showBlogs = true
                    preferences.appleOnlyForums = true
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Home Feed")
        .navigationBarTitleDisplayMode(.inline)
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
    }
}
