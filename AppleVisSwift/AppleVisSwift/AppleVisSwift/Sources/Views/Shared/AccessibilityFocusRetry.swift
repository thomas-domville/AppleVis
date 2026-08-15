import SwiftUI

/// Reusable "Reset to Defaults" action for a settings screen — scoped to
/// only that screen's own settings, per screen (SETTINGS-04: no reset
/// control existed anywhere across 11 Settings screens, despite
/// `PreferencesStore` already centralizing the default values such a
/// control could target). A light, non-catastrophic confirmation is enough
/// here — unlike Delete Account, this is fully reversible by re-adjusting
/// the affected toggles.
struct ResetToDefaultsButton: View {
    let action: () -> Void
    @State private var showConfirm = false

    var body: some View {
        Button("Reset to Defaults", role: .destructive) {
            showConfirm = true
        }
        .confirmationDialog(
            "Reset these settings to their defaults?",
            isPresented: $showConfirm, titleVisibility: .visible
        ) {
            Button("Reset to Defaults", role: .destructive) {
                action()
                SoundPlayer.shared.play(.refresh)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This only affects the settings on this screen.")
        }
    }
}

/// Reassigns accessibility focus at each delay in `delaysMs`, not just once —
/// works around two real constraints: `@AccessibilityFocusState` needs an
/// actual value change to re-trigger (setting the same target twice in a row
/// is a no-op), and a `List` only instantiates a row once scroll actually
/// reaches it, so a single guessed delay isn't reliable across devices —
/// slower devices may still be laying out at the first retry, and retrying
/// again after the target already exists is harmless (the reassignment is
/// idempotent from the user's perspective once focus is already there).
///
/// Previously duplicated as two independently-tuned copies in `HomeView.swift`
/// (`announceWelcomeIfNeeded()` and `WhatsNewCard`'s tap handler) with
/// slightly different delay schedules — consolidated here so the delay
/// schedule and this rationale live in one place instead of two copies that
/// could silently drift apart (CARD-12).
@MainActor
func retryAccessibilityFocus<T: Hashable>(
    _ target: T,
    into binding: AccessibilityFocusState<T?>.Binding,
    delaysMs: [Int] = [300, 550, 850]
) async {
    for delayMs in delaysMs {
        try? await Task.sleep(for: .milliseconds(delayMs))
        binding.wrappedValue = nil
        binding.wrappedValue = target
    }
}
