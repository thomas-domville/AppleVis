import SwiftUI

// MARK: - Quick confirmation for VoiceOver (2026-10-07)
//
// When an action removes something from the screen (marking an item read,
// unsaving, removing a download), VoiceOver moves straight on to what's
// next, and a short sound and tap say it worked. Speaking a confirmation
// first meant waiting for it to finish, which felt slow even on the newest
// iPhone. If Confirmation Sounds and Haptic Feedback are both off, the words
// are still spoken, queued after the move, so nobody is left without a
// confirmation. Requested directly: "my users want instant in any
// situation." First used for Fetch's Mark This Group as Read.

enum ActionCue {
    /// True when someone has turned off both Confirmation Sounds and Haptic
    /// Feedback, so a sound and tap would say nothing.
    static var cuesAreOff: Bool {
        guard let preferences = PreferencesStore.current else { return false }
        return !preferences.confirmationSoundsEnabled && !preferences.hapticsEnabled
    }

    /// Plays `sound` (and its tap). Returns `message` only when cues are
    /// off, for the caller to speak after moving focus.
    static func play(_ sound: AppSound, orSay message: String) -> String? {
        SoundPlayer.shared.play(sound)
        return cuesAreOff ? message : nil
    }

    /// Spoken after whatever VoiceOver is saying, never over it.
    static func sayQueued(_ message: String) {
        UIAccessibility.post(
            notification: .announcement,
            argument: NSAttributedString(string: message, attributes: [.accessibilitySpeechQueueAnnouncement: true]))
    }

    /// The item to land on after `id` leaves `ids`: the next one, else the
    /// one before, else nil (the list is now empty).
    static func neighbor<ID: Equatable>(of id: ID, in ids: [ID]) -> ID? {
        guard let index = ids.firstIndex(of: id) else { return nil }
        if index + 1 < ids.count { return ids[index + 1] }
        if index > 0 { return ids[index - 1] }
        return nil
    }
}

/// Moves VoiceOver to `target` right away, once the removed row has left
/// the list. A row that slides into the removed one's place can claim focus
/// first, so this asks a few more times over about a second, and stops as
/// soon as focus holds, so VoiceOver doesn't read the new item twice.
/// `message`, if any, is spoken after the item is read.
@MainActor
func moveAccessibilityFocusPromptly<T: Hashable>(
    to target: T,
    into binding: AccessibilityFocusState<T?>.Binding,
    saying message: String? = nil
) async {
    guard UIAccessibility.isVoiceOverRunning else { return }
    try? await Task.sleep(for: .milliseconds(50))
    var attempted = false
    for delayMs in [80, 200, 350, 600] {
        try? await Task.sleep(for: .milliseconds(delayMs))
        if attempted, binding.wrappedValue == target { break }
        binding.wrappedValue = nil
        binding.wrappedValue = target
        if !attempted, let message { ActionCue.sayQueued(message) }
        attempted = true
    }
}

/// The same, for a single element such as a list's summary.
@MainActor
func moveAccessibilityFocusPromptly(
    into binding: AccessibilityFocusState<Bool>.Binding,
    saying message: String? = nil
) async {
    guard UIAccessibility.isVoiceOverRunning else { return }
    try? await Task.sleep(for: .milliseconds(50))
    var attempted = false
    for delayMs in [80, 200, 350, 600] {
        try? await Task.sleep(for: .milliseconds(delayMs))
        if attempted, binding.wrappedValue { break }
        binding.wrappedValue = false
        binding.wrappedValue = true
        if !attempted, let message { ActionCue.sayQueued(message) }
        attempted = true
    }
}

// MARK: - Mark as Read from a row's actions

/// Offered by a list that wants to handle Mark as Read itself (Home moves
/// VoiceOver to the next item in New). Called by the row's shared Mark as
/// Read action before the item is marked, while it's still in the list.
struct MarkedReadFeedbackAction {
    let handle: (ContentKind, String) -> Void
    func callAsFunction(kind: ContentKind, id: String) { handle(kind, id) }
}

private struct MarkedReadFeedbackKey: EnvironmentKey {
    static let defaultValue: MarkedReadFeedbackAction? = nil
}

extension EnvironmentValues {
    var markedReadFeedback: MarkedReadFeedbackAction? {
        get { self[MarkedReadFeedbackKey.self] }
        set { self[MarkedReadFeedbackKey.self] = newValue }
    }
}
