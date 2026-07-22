import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                // Header
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

                Section("Customisation") {
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        SettingsRow(icon: "paintbrush", label: "Appearance", subtitle: "Theme", color: .purple)
                    }

                    NavigationLink {
                        AccessibilitySettingsView()
                    } label: {
                        SettingsRow(icon: "accessibility", label: "Accessibility", subtitle: "VoiceOver and low vision controls", color: .blue)
                    }
                }

                Section("Alerts") {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        SettingsRow(icon: "bell", label: "Notifications", subtitle: "Alerts, sounds, and activity", color: .orange)
                    }
                }

                Section("Content") {
                    NavigationLink {
                        ForumSettingsView()
                    } label: {
                        SettingsRow(icon: "bubble.left.and.bubble.right", label: "Forums", subtitle: "Home feed filter defaults", color: .green)
                    }

                    NavigationLink {
                        PodcastSettingsView()
                    } label: {
                        SettingsRow(icon: "headphones", label: "Podcasts", subtitle: "Playback and download defaults", color: .pink)
                    }
                }

                Section("Data & Privacy") {
                    NavigationLink {
                        SavedSyncSettingsView()
                    } label: {
                        SettingsRow(icon: "icloud", label: "Saved & Sync", subtitle: "Saved items and iCloud sync", color: .blue)
                    }

                    NavigationLink {
                        PrivacySettingsView()
                    } label: {
                        SettingsRow(icon: "hand.raised", label: "Privacy", subtitle: "Privacy and data handling", color: .teal)
                    }

                    NavigationLink {
                        IntelligenceSettingsView()
                    } label: {
                        SettingsRow(icon: "sparkles", label: "Intelligence & Siri", subtitle: "Smart features and AI controls", color: .indigo)
                    }

                    NavigationLink {
                        StorageView()
                    } label: {
                        SettingsRow(icon: "internaldrive", label: "Storage & Cache", subtitle: "Manage downloads and cached content", color: Color(.systemGray))
                    }
                }

                Section("Support") {
                    NavigationLink {
                        HelpView()
                    } label: {
                        SettingsRow(icon: "questionmark.circle", label: "Help", subtitle: "Guides and support", color: .purple)
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        SettingsRow(icon: "info.circle", label: "About AppleVis", subtitle: "Version info and credits", color: .gray)
                    }
                }
            }
            .navigationTitle("Settings")
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
