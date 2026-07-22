import SwiftUI

struct AccessibilitySettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore

    var body: some View {
        Form {
            Section {
                Text("AppleVis-specific accessibility controls. iOS system settings like VoiceOver, Dynamic Type, Reduce Motion, and Bold Text are followed automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("AppleVis Controls") {
                Toggle("AppleVis Tips", isOn: $preferences.helpfulTipsEnabled)
                    .accessibilityHint("Shows short contextual tips and friendly reminders where they can save time.")

                Toggle("Welcome Summary", isOn: $preferences.welcomeSummaryEnabled)
                    .accessibilityHint("Shows a brief Home update with new AppleVis activity since your last visit.")

                Toggle("Auto-Focus Search Field", isOn: $preferences.searchAutoFocusEnabled)
                    .accessibilityHint("Automatically focuses and raises the keyboard when you open Search.")

                Picker("Home Startup Behavior", selection: $preferences.homeStartupBehavior) {
                    ForEach(HomeStartupBehavior.allCases) { behavior in
                        Text(behavior.displayName).tag(behavior)
                    }
                }
                .accessibilityHint("Controls how much spoken announcement Home produces when you open or return to it.")
            }

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
                            Text(level.preview)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .italic()
                        }
                        .padding(.vertical, 2)
                    }
                    .accessibilityAddTraits(preferences.announcementLevel == level ? [.isSelected] : [])
                    .accessibilityHint("Example of what VoiceOver reads: \(level.preview)")
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
                    Label("Open iOS Settings", systemImage: "gear")
                }
            }
        }
        .navigationTitle("Accessibility")
        .navigationBarTitleDisplayMode(.inline)
    }
}
