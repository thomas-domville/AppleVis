import SwiftUI

struct AccessibilitySettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        Form {
            Section {
                Text("AppleVis-specific accessibility controls. iOS system settings like VoiceOver, Dynamic Type, Reduce Motion, and Bold Text are followed automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityFocused($isTitleFocused)
            }

            // AppleVis Tips, Welcome Summary, Auto-Focus Search Field, Home
            // Startup Behavior, and Web Links all moved to a new General
            // settings screen — none of them are actually about VoiceOver,
            // Dynamic Type, or anything else accessibility-specific; they'd
            // accumulated here by historical accident. Requested directly.
            Section("VoiceOver Detail Level") {
                ForEach(AnnouncementLevel.allCases) { level in
                    Button {
                        preferences.announcementLevel = level
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(level.displayName)
                                    .foregroundStyle(.primary)
                                    .fontWeight(preferences.announcementLevel == level ? .semibold : .regular)
                                Spacer()
                                if preferences.announcementLevel == level {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                        .accessibilityHidden(true)
                                }
                            }
                            // Was spoken twice — once here as part of the
                            // button's own auto-combined label, then again
                            // via the accessibilityHint below repeating the
                            // same text right after "Example of what
                            // VoiceOver reads." Hidden here so the hint is
                            // the one and only place it's spoken, in the
                            // right order (framed by the explanation, not
                            // duplicated ahead of it). Reported directly.
                            Text(level.preview)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .italic()
                                .accessibilityHidden(true)
                        }
                        .padding(.vertical, 2)
                    }
                    .accessibilityAddTraits(preferences.announcementLevel == level ? [.isSelected] : [])
                    .accessibilityHint(String(localized: "Example of what VoiceOver reads: \(level.preview)"))
                }
            }

            Section("iOS Accessibility (Read-Only)") {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("VoiceOver, Dynamic Type, Reduce Motion")
                        Text("Change these in iOS Settings → Accessibility. AppleVis detects and respects them automatically.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Label("Open iOS Settings", systemImage: "gear")
                        ExternalLinkIndicator()
                    }
                }
                .accessibilityHint(String(localized: "Opens the Settings app, outside AppleVis."))
            }

            Section {
                ResetToDefaultsButton {
                    preferences.announcementLevel = .normal
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Accessibility")
        .navigationBarTitleDisplayMode(.inline)
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
    }
}
