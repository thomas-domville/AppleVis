import SwiftUI

/// A single row's identity, kept as data (rather than inline NavigationLinks)
/// so the search field below can filter by label/subtitle without a parallel
/// hand-maintained filter switch — docs/APPLEVIS_2026_1_MASTER_SPEC.md calls
/// for "a Settings search field in production."
private struct SettingsEntry: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let subtitle: String
    let color: Color
    let destination: AnyView

    var matches: String { "\(label) \(subtitle)".lowercased() }
}

private struct SettingsSection: Identifiable {
    let id = UUID()
    let title: String
    let entries: [SettingsEntry]
}

struct SettingsView: View {
    @State private var searchText = ""

    private var sections: [SettingsSection] {
        [
            SettingsSection(title: "Customisation", entries: [
                SettingsEntry(icon: "paintbrush", label: "Appearance", subtitle: "Theme", color: .purple,
                              destination: AnyView(AppearanceSettingsView())),
                SettingsEntry(icon: "accessibility", label: "Accessibility", subtitle: "VoiceOver and low vision controls", color: .blue,
                              destination: AnyView(AccessibilitySettingsView())),
            ]),
            SettingsSection(title: "Alerts", entries: [
                SettingsEntry(icon: "bell", label: "Notifications", subtitle: "Alerts, sounds, and activity", color: .orange,
                              destination: AnyView(NotificationSettingsView())),
                SettingsEntry(icon: "speaker.wave.2", label: "Sounds & Haptics", subtitle: "Interface and confirmation sounds", color: .pink,
                              destination: AnyView(SoundsHapticsSettingsView())),
            ]),
            SettingsSection(title: "Content", entries: [
                SettingsEntry(icon: "bubble.left.and.bubble.right", label: "Forums", subtitle: "Home feed filter defaults", color: .green,
                              destination: AnyView(ForumSettingsView())),
                SettingsEntry(icon: "headphones", label: "Podcasts", subtitle: "Playback and download defaults", color: .pink,
                              destination: AnyView(PodcastSettingsView())),
            ]),
            SettingsSection(title: "Data & Privacy", entries: [
                SettingsEntry(icon: "icloud", label: "Saved & Sync", subtitle: "Saved items and iCloud sync", color: .blue,
                              destination: AnyView(SavedSyncSettingsView())),
                SettingsEntry(icon: "hand.raised", label: "Privacy", subtitle: "Privacy and data handling", color: .teal,
                              destination: AnyView(PrivacySettingsView())),
                SettingsEntry(icon: "sparkles", label: "Intelligence", subtitle: "Smart features and AI controls", color: .indigo,
                              destination: AnyView(IntelligenceSettingsView())),
                SettingsEntry(icon: "waveform", label: "Siri & Shortcuts", subtitle: "Voice commands and Shortcuts app actions", color: .indigo,
                              destination: AnyView(SiriShortcutsSettingsView())),
                SettingsEntry(icon: "internaldrive", label: "Storage & Cache", subtitle: "Manage downloads and cached content", color: Color(.systemGray),
                              destination: AnyView(StorageView())),
            ]),
            SettingsSection(title: "Support", entries: [
                SettingsEntry(icon: "questionmark.circle", label: "Help", subtitle: "Guides and support", color: .purple,
                              destination: AnyView(HelpView())),
                SettingsEntry(icon: "info.circle", label: "About AppleVis", subtitle: "Version info and credits", color: .gray,
                              destination: AnyView(AboutView())),
            ]),
        ]
    }

    private var filteredSections: [SettingsSection] {
        guard !searchText.isEmpty else { return sections }
        let query = searchText.lowercased()
        return sections.compactMap { section in
            let matching = section.entries.filter { $0.matches.contains(query) }
            return matching.isEmpty ? nil : SettingsSection(title: section.title, entries: matching)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Settings Center")
                                .font(.headline)
                            Text("Tune AppleVis for VoiceOver, Braille, low vision, podcasts, notifications, and sync.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Account and sign-in tools live in Profile.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                    }
                }

                if filteredSections.isEmpty {
                    EmptyStateView(title: "No Results", message: "No settings match \"\(searchText)\".", systemImage: "magnifyingglass")
                }

                ForEach(filteredSections) { section in
                    Section(section.title) {
                        ForEach(section.entries) { entry in
                            NavigationLink {
                                entry.destination
                            } label: {
                                SettingsRow(icon: entry.icon, label: entry.label, subtitle: entry.subtitle, color: entry.color)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .searchable(text: $searchText, prompt: "Search Settings")
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let label: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
