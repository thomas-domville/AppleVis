import SwiftUI
import UIKit

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
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var searchText = ""
    @AccessibilityFocusState private var focusTarget: AnyHashable?
    private static let titleFocusID = AnyHashable("settings.title")

    private var sections: [SettingsSection] {
        [
            // New home for AppleVis Tips, Welcome Summary, Auto-Focus
            // Search Field, Home Startup Behavior, and Web Links — all
            // moved out of Accessibility, where they'd accumulated despite
            // none of them being accessibility-specific. Requested
            // directly.
            SettingsSection(title: "General", entries: [
                SettingsEntry(icon: "slider.horizontal.3", label: "General", subtitle: "Home behavior, tips, and web links", color: .mint,
                              destination: AnyView(GeneralSettingsView())),
            ]),
            SettingsSection(title: "Customisation", entries: [
                SettingsEntry(icon: "paintbrush", label: "Appearance", subtitle: "Theme, colour, and card density", color: .purple,
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
                SettingsEntry(icon: "bubble.left.and.bubble.right", label: "Home Feed", subtitle: "What shows up in your Home feed", color: .green,
                              destination: AnyView(HomeFeedSettingsView())),
                SettingsEntry(icon: "headphones", label: "Podcasts", subtitle: "Playback and download defaults", color: .pink,
                              destination: AnyView(PodcastSettingsView())),
            ]),
            SettingsSection(title: "Data & Privacy", entries: [
                SettingsEntry(icon: "icloud", label: "Saved & Sync", subtitle: "Saved items and iCloud sync", color: .blue,
                              destination: AnyView(SavedSyncSettingsView())),
                SettingsEntry(icon: "hand.raised", label: "Privacy", subtitle: "What we collect, and how to clear your local data", color: .teal,
                              destination: AnyView(PrivacySettingsView())),
                SettingsEntry(icon: "sparkles", label: "Intelligence", subtitle: "Smart features and AI controls", color: .indigo,
                              destination: AnyView(IntelligenceSettingsView())),
                // Deliberately not nested inside Intelligence above — unlike
                // every toggle there, this has no Apple Intelligence
                // hardware/OS-26 gate, and grouping it in would misleadingly
                // imply the same requirement.
                SettingsEntry(icon: "globe", label: "Content Translation", subtitle: "Read AppleVis in your own language", color: .cyan,
                              destination: AnyView(ContentTranslationSettingsView())),
                SettingsEntry(icon: "waveform", label: "Siri & Shortcuts", subtitle: "Voice commands and Shortcuts app actions", color: .indigo,
                              destination: AnyView(SiriShortcutsSettingsView())),
            ]),
            // Kept out of "Data & Privacy" — RN gave this its own visually
            // distinct framing at the bottom of the list specifically
            // because it holds destructive actions (delete downloads,
            // clear cache), not because it's a content-vs-privacy
            // distinction like the rest of that section.
            SettingsSection(title: "Storage & Cache", entries: [
                SettingsEntry(icon: "internaldrive", label: "Storage & Cache", subtitle: "Manage downloads and cached content", color: Color(.systemGray),
                              destination: AnyView(StorageView())),
            ]),
            SettingsSection(title: "Support", entries: [
                SettingsEntry(icon: "questionmark.circle", label: "Help", subtitle: "Guides and support", color: .purple,
                              destination: AnyView(HelpView())),
                SettingsEntry(icon: "info.circle", label: "About", subtitle: "Version info and credits", color: .gray,
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

    /// RN's header had its own "Read Settings Summary" VoiceOver action
    /// announcing this exact breakdown — Swift's version was plain text
    /// with no equivalent.
    private func announceSettingsSummary() {
        let sectionCount = sections.count
        let entryCount = sections.reduce(0) { $0 + $1.entries.count }
        UIAccessibility.post(
            notification: .announcement,
            argument: "\(sectionCount) sections and \(entryCount) settings areas."
        )
    }

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    Section {
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor)
                                    .frame(width: 36, height: 36)
                                Image(systemName: "gearshape")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                            .accessibilityHidden(true)
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
                        }
                        .padding(.vertical, 4)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(Color.accentColor).frame(width: 3).clipShape(RoundedRectangle(cornerRadius: 1.5))
                        }
                        .padding(.leading, 4)
                        .accessibilityElement(children: .combine)
                        .accessibilityAction(named: Text("Read Settings Summary")) { announceSettingsSummary() }
                        .accessibilityFocused($focusTarget, equals: Self.titleFocusID)
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
                                    .onDisappear {
                                        Task { await retryAccessibilityFocus(into: $focusTarget, returningTo: AnyHashable(entry.id)) }
                                    }
                            } label: {
                                SettingsRow(icon: entry.icon, label: entry.label, subtitle: entry.subtitle, color: entry.color)
                            }
                            .accessibilityFocused($focusTarget, equals: AnyHashable(entry.id))
                        }
                    }
                }
            }
            .themedList(preferences.colors)
            .navigationTitle("Settings")
            .searchable(text: $searchText, prompt: "Search Settings")
            .task { await retryAccessibilityFocus(into: $focusTarget, returningTo: Self.titleFocusID) }
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
