import SwiftUI
import Combine

/// Drives the "Translate to English?" prompt and "Rewrite" action available
/// while composing a forum topic/reply, gated by the Intelligence settings
/// toggles. Everything runs on-device via `IntelligenceService`.
@MainActor
final class ComposeIntelligenceState: ObservableObject {
    @Published private(set) var showTranslatePrompt = false
    @Published private(set) var isProcessing = false

    private var detectTask: Task<Void, Never>?

    func textChanged(_ text: String, translationEnabled: Bool, detectionEnabled: Bool) {
        detectTask?.cancel()
        guard translationEnabled, detectionEnabled else {
            showTranslatePrompt = false
            return
        }
        detectTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled, let self else { return }
            showTranslatePrompt = IntelligenceService.detectNonEnglish(text)
        }
    }

    func dismissTranslatePrompt() {
        detectTask?.cancel()
        showTranslatePrompt = false
    }

    func translate(subject: String?, body: String, isTopic: Bool) async -> IntelligenceService.DraftRewriteResult? {
        isProcessing = true
        defer { isProcessing = false }
        let result = await IntelligenceService.translateToEnglish(subject: subject, body: body, isTopic: isTopic)
        if result != nil { showTranslatePrompt = false }
        return result
    }

    func rewrite(subject: String?, body: String, isTopic: Bool) async -> IntelligenceService.DraftRewriteResult? {
        isProcessing = true
        defer { isProcessing = false }
        return await IntelligenceService.rewriteFriendly(subject: subject, body: body, isTopic: isTopic)
    }

    func rewriteRespectfully(subject: String?, body: String, isTopic: Bool) async -> IntelligenceService.DraftRewriteResult? {
        isProcessing = true
        defer { isProcessing = false }
        return await IntelligenceService.rewriteRespectfully(subject: subject, body: body, isTopic: isTopic)
    }
}

/// "This looks like it's not in English — translate to English?" prompt.
struct TranslatePromptView: View {
    let isProcessing: Bool
    let onTranslate: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "character.bubble")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Not in English?")
                    .font(.subheadline).fontWeight(.semibold)
                Text("AppleVis posts should be in English. Translate your draft?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isProcessing {
                ProgressView()
            } else {
                Button("Translate", action: onTranslate)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.plain)
                    .font(.caption)
            }
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}
