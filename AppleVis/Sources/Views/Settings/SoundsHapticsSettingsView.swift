import SwiftUI

/// docs/APPLEVIS_2026_1_MASTER_SPEC.md's "Settings Model" lists "Sounds &
/// Haptics" as its own settings item. Haptics used to be entirely
/// unimplemented (no UIImpactFeedbackGenerator/UINotificationFeedback
/// Generator usage anywhere), so this screen previously only covered the
/// sound toggles that were actually real. `SoundPlayer.haptic` now pairs a
/// real haptic with the same "confirmation" tier of sounds (save, follow,
/// submit success, sign in, errors) — never the "interface" chrome tier
/// (refresh, tab switching, picker ticks), matching that tier's own
/// off-by-default sound treatment. This toggle is separate from the sound
/// ones so a user can keep one channel without the other.
struct SoundsHapticsSettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        Form {
            Section("Sounds") {
                Toggle("Confirmation Sounds", isOn: $preferences.confirmationSoundsEnabled)
                    .accessibilityHint(String(localized: "Plays a sound for notifications, saving, downloads finishing, and podcast play and pause."))
                    .accessibilityFocused($isTitleFocused)
                Text("Plays a sound for moments worth noticing — saving, downloads finishing, notifications, and podcast play and pause.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Interface Sounds", isOn: $preferences.interfaceSoundsEnabled)
                    .accessibilityHint(String(localized: "Plays a sound for tab switching, picker changes, opening screens, and list refreshes."))
                Text("Plays a sound for everyday navigation — tab switching, picker changes, opening screens, and list refreshes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Haptics") {
                Toggle("Haptic Feedback", isOn: $preferences.hapticsEnabled)
                    .accessibilityHint(String(localized: "Vibrates for the same moments Confirmation Sounds covers, such as saving, signing in, and errors."))
                Text("Adds a vibration for the same moments Confirmation Sounds covers, like saving, signing in, and errors.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("Sounds and haptics for errors and connectivity changes always play, since they're important to notice rather than decorative.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                ResetToDefaultsButton {
                    preferences.confirmationSoundsEnabled = true
                    preferences.interfaceSoundsEnabled = false
                    preferences.hapticsEnabled = true
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Sounds & Haptics")
        .navigationBarTitleDisplayMode(.inline)
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
    }
}
