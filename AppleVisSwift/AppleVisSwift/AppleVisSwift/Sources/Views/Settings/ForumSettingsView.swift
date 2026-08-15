import SwiftUI

struct ForumSettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore

    var body: some View {
        Form {
            Section {
                Text("Controls which content appears in the Home feed by default when you open the app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Home Feed Default Filter") {
                ForEach(ForumFilter.allCases) { filter in
                    Button {
                        preferences.forumsDefaultFilter = filter
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(filter.displayName)
                                    .foregroundStyle(.primary)
                                Text(filterSubtitle(filter))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if preferences.forumsDefaultFilter == filter {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .accessibilityAddTraits(preferences.forumsDefaultFilter == filter ? [.isSelected] : [])
                }
            }

            Section("Home Feed Content") {
                Toggle("Forum Topics", isOn: $preferences.showForums)
                    .accessibilityHint(String(localized: "Include forum topics in the Home feed."))
                Toggle("Podcast Episodes", isOn: $preferences.showPodcasts)
                    .accessibilityHint(String(localized: "Include podcast episodes in the Home feed."))
                Toggle("App Listings", isOn: $preferences.showApps)
                    .accessibilityHint(String(localized: "Include app directory entries in the Home feed."))
                Toggle("Guides & Tutorials", isOn: $preferences.showGuides)
                    .accessibilityHint(String(localized: "Include how-to guides and tutorials in the Home feed."))
                Toggle("Blog Posts", isOn: $preferences.showBlogs)
                    .accessibilityHint(String(localized: "Include blog posts and opinion pieces in the Home feed."))
                Toggle("Apple Topics Only", isOn: $preferences.appleOnlyForums)
                    .accessibilityHint(String(localized: "Limits the Home feed to topics directly related to Apple products and platforms."))
            }

            Section {
                ResetToDefaultsButton {
                    preferences.forumsDefaultFilter = .recent
                    preferences.showForums = true
                    preferences.showPodcasts = true
                    preferences.showApps = true
                    preferences.showGuides = true
                    preferences.showBlogs = true
                    preferences.appleOnlyForums = false
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Forums")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func filterSubtitle(_ filter: ForumFilter) -> String {
        switch filter {
        case .recent:         return "Shows the most recently updated topics from all categories."
        case .new:             return "Shows only topics created since your last visit."
        case .unread:          return "Shows only topics you haven't opened yet."
        case .sinceLastVisit: return "Shows topics with new replies since your last visit."
        case .following:       return "Shows only forum topics you're following."
        case .saved:           return "Shows only forum topics you've saved."
        }
    }
}
