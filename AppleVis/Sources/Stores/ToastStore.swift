import SwiftUI
import Combine
import UIKit

@MainActor
final class ToastStore: ObservableObject {
    @Published var current: Toast?

    struct Toast: Identifiable {
        let id = UUID()
        let message: String
        let kind: Kind

        enum Kind { case success, error, warning }

        var systemImage: String {
            switch kind {
            case .success: return "checkmark.circle.fill"
            case .error:   return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }

        var color: Color {
            switch kind {
            case .success: return .green
            case .error:   return .red
            case .warning: return .orange
            }
        }
    }

    /// `quiet`: shown on screen only. For a list that already confirmed
    /// the action with its own sound and moved VoiceOver on (2026-10-07).
    /// `sound`: the action's own sound (posting, saving) in place of the
    /// generic success chime, so the two don't play on top of each other.
    /// The message is still spoken (2026-10-07).
    func show(_ message: String, kind: Toast.Kind = .success, quiet: Bool = false, sound: AppSound? = nil) {
        let toast = Toast(message: message, kind: kind)
        current = toast
        if quiet {
            Task {
                try? await Task.sleep(for: .seconds(3))
                if current?.id == toast.id { current = nil }
            }
            return
        }
        SoundPlayer.shared.play(sound ?? (kind == .success ? .success : .error))
        // The toast itself renders on screen with its own distinct text,
        // but the sound alone doesn't tell a VoiceOver user *which*
        // toast fired ("Saved" vs. "Removed from Saved" vs. "Couldn't
        // update follow status" all just played the same chime otherwise).
        //
        // Spoken a moment later and queued behind whatever VoiceOver is
        // saying. Most success messages come just as a screen closes
        // ("Topic posted", "Reply posted"), and an announcement made at
        // that instant was cut off by the screen change, so a tester heard
        // nothing and couldn't tell whether posting had worked. Reported
        // directly (2026-10-05).
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            UIAccessibility.post(
                notification: .announcement,
                argument: NSAttributedString(string: message, attributes: [.accessibilitySpeechQueueAnnouncement: true])
            )
        }
        Task {
            try? await Task.sleep(for: .seconds(3))
            // CONC-02: previously nilled `current` unconditionally — two
            // toasts within 3 seconds (e.g. Save immediately followed by
            // Follow) meant the first toast's timer cleared the *second*
            // toast early, cutting its on-screen/VoiceOver-announced
            // duration short. Only clear if `current` is still this exact
            // toast.
            if current?.id == toast.id {
                current = nil
            }
        }
    }

    func success(_ message: String, quiet: Bool = false, sound: AppSound? = nil) { show(message, kind: .success, quiet: quiet, sound: sound) }
    func error(_ message: String)   { show(message, kind: .error) }
    func warning(_ message: String) { show(message, kind: .warning) }
}
