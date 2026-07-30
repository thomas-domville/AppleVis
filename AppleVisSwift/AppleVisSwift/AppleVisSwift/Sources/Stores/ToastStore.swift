import SwiftUI
import Combine

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
        current = Toast(message: message, kind: kind)
        SoundPlayer.shared.play(kind == .success ? .success : .error)
        Task {
            try? await Task.sleep(for: .seconds(3))
            current = nil
        }
    }

    func success(_ message: String) { show(message, kind: .success) }
    func error(_ message: String)   { show(message, kind: .error) }
    func warning(_ message: String) { show(message, kind: .warning) }
}
