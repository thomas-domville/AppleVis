import SwiftUI

/// docs/APPLEVIS_2026_1_MASTER_SPEC.md's "Settings Model" lists "Sounds &
/// Haptics" as its own settings item — this app has no haptic feedback
/// implemented anywhere (no UIImpactFeedbackGenerator/UINotificationFeedback
/// Generator usage), so this screen only covers the sound toggles that are
/// actually real, rather than claiming a haptics feature that isn't there.
struct SoundsHapticsSettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore

    var body: some View {
        Form {
            Section("Sounds") {
                Toggle("Confirmation Sounds", isOn: $preferences.confirmationSoundsEnabled)
                    .accessibilityHint(String(localized: "Plays a sound for notifications, saving, downloads finishing, and podcast play and pause."))

                Toggle("Interface Sounds", isOn: $preferences.interfaceSoundsEnabled)
                    .accessibilityHint(String(localized: "Plays a sound for tab switching, picker changes, opening screens, and list refreshes."))
            }

            Section {
                Text("Sounds for errors and connectivity changes always play, since they're important to notice rather than decorative.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                ResetToDefaultsButton {
                    preferences.confirmationSoundsEnabled = true
                    preferences.interfaceSoundsEnabled = false
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Sounds & Haptics")
        .navigationBarTitleDisplayMode(.inline)
    }
}
