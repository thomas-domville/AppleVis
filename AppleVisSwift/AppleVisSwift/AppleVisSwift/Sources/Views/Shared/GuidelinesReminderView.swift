import SwiftUI
import Combine

/// Dismissible advisory banner shown while composing, when the draft text
/// trips one of the AppleVis posting-guideline checks. Never blocks posting.
struct GuidelinesReminderView: View {
    let warning: GuidelineWarning
    let onDismiss: () -> Void

    private static let guidelinesURL = URL(string: "https://www.applevis.com/help/guidelines")!

    private var config: (bg: Color, border: Color, text: Color, button: Color, label: String) {
        switch warning.severity {
        case .high:
            return (Color(red: 1.0, green: 0.941, blue: 0.941), Color(red: 0.988, green: 0.647, blue: 0.647),
                    Color(red: 0.600, green: 0.106, blue: 0.106), Color(red: 0.725, green: 0.110, blue: 0.110), "Guideline reminder")
        case .medium:
            return (Color(red: 1.0, green: 0.984, blue: 0.922), Color(red: 0.988, green: 0.827, blue: 0.302),
                    Color(red: 0.573, green: 0.251, blue: 0.055), Color(red: 0.706, green: 0.325, blue: 0.035), "Guideline reminder")
        case .low:
            return (Color(red: 0.941, green: 0.976, blue: 1.0), Color(red: 0.729, green: 0.902, blue: 0.992),
                    Color(red: 0.047, green: 0.290, blue: 0.431), Color(red: 0.020, green: 0.412, blue: 0.631), "Friendly tip")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(config.label): \(warning.rule)")
                    .font(.caption).fontWeight(.bold)
                    .foregroundStyle(config.text)
                Text(warning.message)
                    .font(.subheadline)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(config.label): \(warning.rule). \(warning.message)")

            HStack(spacing: 10) {
                Button(action: onDismiss) {
                    Text("Got It")
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(config.button, in: RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityHint("Dismisses this reminder.")

                Link(destination: Self.guidelinesURL) {
                    Text("View Guidelines")
                        .fontWeight(.semibold)
                        .foregroundStyle(config.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(config.border, lineWidth: 1.5))
                }
                .accessibilityHint("Opens the AppleVis guidelines page in Safari.")
            }
        }
        .padding(14)
        .background(config.bg, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(config.border, lineWidth: 1.5))
    }
}

/// Debounced guideline-check state for a compose screen. Rule-based checks
/// fire ~1.5s after the user stops typing; dismissed warnings won't reappear
/// this session.
@MainActor
final class GuidelinesCheckState: ObservableObject {
    @Published private(set) var topWarning: GuidelineWarning?

    private var dismissedIds: Set<String> = []
    private var lastAnnouncedId: String?
    private var checkTask: Task<Void, Never>?

    func textChanged(_ text: String) {
        checkTask?.cancel()
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 else {
            topWarning = nil
            return
        }
        checkTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled, let self else { return }
            let visible = GuidelinesChecker.check(text).filter { !self.dismissedIds.contains($0.id) }
            self.topWarning = visible.first
            if let top = visible.first, top.id != self.lastAnnouncedId {
                self.lastAnnouncedId = top.id
                UIAccessibility.post(notification: .announcement, argument: "Guideline reminder: \(top.rule). \(top.message)")
            }
        }
    }

    func dismiss() {
        guard let top = topWarning else { return }
        dismissedIds.insert(top.id)
        topWarning = nil
    }
}
