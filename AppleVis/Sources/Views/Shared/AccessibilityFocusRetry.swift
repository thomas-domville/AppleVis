import SwiftUI
import UIKit

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
    // No-op with VoiceOver off: an AccessibilityFocusState reassignment has
    // no visible effect for sighted/mouse interaction, but the repeated
    // state mutation still forces SwiftUI to re-diff the screen — which, in
    // testing, was found to race with a concurrent tap/gesture landing in
    // that same ~850ms window. Skipping entirely when there's no assistive
    // tech to benefit removes that race with zero accessibility regression.
    guard UIAccessibility.isVoiceOverRunning else { return }
    for delayMs in delaysMs {
        try? await Task.sleep(for: .milliseconds(delayMs))
        // If VoiceOver focus is already on something other than our target,
        // the user has moved on and is exploring elsewhere — forcing focus
        // back mid-interaction is exactly what let a double-tap gesture
        // land on a stale target instead of whatever the user was actually
        // on (the reported "double-stacked"/wrong-item navigation). Once
        // that happens, stop fighting the user for it.
        if let current = binding.wrappedValue, current != target { return }
        binding.wrappedValue = nil
        binding.wrappedValue = target
    }
}

/// Same retry rationale as the generic version above, for the plain-`Bool`
/// `@AccessibilityFocusState` every content detail page (topic, episode,
/// app, blog, resource, bug) uses for its title — those previously each set
/// focus once after a single guessed delay (e.g. `Task.sleep(300ms)`), which
/// is exactly the unreliable-on-slower-devices pattern this file's doc
/// comment already describes; only Home had been upgraded to retry.
/// Reported directly: topic detail's title focus sometimes went silent.
@MainActor
func retryAccessibilityFocus(
    into binding: AccessibilityFocusState<Bool>.Binding,
    delaysMs: [Int] = [300, 550, 850]
) async {
    // See the generic overload above: skipped entirely without VoiceOver,
    // since the repeated state mutation has no benefit for sighted/mouse
    // interaction but can race with a concurrent tap.
    guard UIAccessibility.isVoiceOverRunning else { return }
    // Clear any leftover `true` first. The same binding is often shared by
    // a row that has just gone away (a wizard's old step heading, or the
    // Guideline Violation Check's "Scanning…" row, replaced by its results
    // summary when the scan ends). A leftover `true` from that old row
    // would look like "already focused" below, and focus would never move.
    binding.wrappedValue = false
    for delayMs in delaysMs {
        try? await Task.sleep(for: .milliseconds(delayMs))
        // Focus is on the element: done. Leaving it alone from here means a
        // user who swipes on is never pulled back (see the generic overload
        // above for why that's disruptive).
        if binding.wrappedValue { return }
        // Not there yet: try again. This used to stop after the first
        // attempt whether or not focus had actually landed, treating a
        // failed attempt as the user moving away. When the first try came
        // too early (a closing keyboard, a new step still loading),
        // VoiceOver stayed on Cancel or the top of the screen. Reported
        // directly: wizard step headings not getting focus.
        binding.wrappedValue = false
        binding.wrappedValue = true
    }
}

/// Restores focus to the specific row a hub/list screen (Settings, Profile,
/// Discover, About) was left from, instead of the system's default landing
/// spot after a back-button pop. Call from `.onDisappear` on the *pushed
/// destination* itself, not `.task`/`.onAppear` on the hub — a hub that is
/// its own `NavigationStack` root (or reached only once per tab lifetime)
/// never re-runs `.task`/`.onAppear` when a child it pushed is popped back
/// to it, since the root view is never actually torn down (confirmed via
/// `DiscoverView`'s own `.task`, which already documents running only once).
/// The pushed child's `.onDisappear`, by contrast, fires reliably on every
/// pop, since that instance really is being destroyed. Reported directly:
/// back-navigation from Settings (and similar hub screens) left VoiceOver
/// focus wherever iOS defaulted to, rather than on the row you'd tapped.
@MainActor
func retryAccessibilityFocus<T: Hashable>(
    into binding: AccessibilityFocusState<T?>.Binding,
    returningTo rowTarget: T,
    delaysMs: [Int] = [300, 550, 850]
) async {
    // See the generic overload above: skipped entirely without VoiceOver,
    // since the repeated state mutation has no benefit for sighted/mouse
    // interaction but can race with a concurrent tap.
    guard UIAccessibility.isVoiceOverRunning else { return }
    for delayMs in delaysMs {
        try? await Task.sleep(for: .milliseconds(delayMs))
        // See the generic overload above: back off once the user has
        // moved focus elsewhere on their own instead of re-forcing it.
        if let current = binding.wrappedValue, current != rowTarget { return }
        binding.wrappedValue = nil
        binding.wrappedValue = rowTarget
    }
}

/// Moves VoiceOver to a wizard's new step heading, fast. Every wizard used
/// its own copy of this with fixed waits of 0.5, 0.85, and 1.25 seconds,
/// which added up to a 2 to 3 second pause before focus landed. VoiceOver
/// users expect it to be near instant. Reported directly.
///
/// Closes the keyboard first, because VoiceOver grabs whatever is under a
/// closing keyboard. If a keyboard was open, the first try waits for its
/// close animation (about a third of a second); otherwise it tries almost
/// at once. Either way it stops as soon as focus lands.
@MainActor
func focusWizardStepHeading(_ binding: AccessibilityFocusState<Bool>.Binding) async {
    let keyboardWasOpen = UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    await retryAccessibilityFocus(into: binding, delaysMs: keyboardWasOpen ? [350, 150, 250, 400] : [100, 150, 250, 400])
}
