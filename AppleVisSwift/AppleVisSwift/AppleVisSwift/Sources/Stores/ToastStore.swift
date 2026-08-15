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

    func show(_ message: String, kind: Toast.Kind = .success) {
        let toast = Toast(message: message, kind: kind)
        current = toast
        SoundPlayer.shared.play(kind == .success ? .success : .error)
        // The toast itself renders on screen with its own distinct text,
        // but the sound alone doesn't tell a VoiceOver user *which*
        // toast fired ("Saved" vs. "Removed from Saved" vs. "Couldn't
        // update follow status" all just played the same chime otherwise).
        UIAccessibility.post(notification: .announcement, argument: message)
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

    func success(_ message: String) { show(message, kind: .success) }
    func error(_ message: String)   { show(message, kind: .error) }
    func warning(_ message: String) { show(message, kind: .warning) }
}
