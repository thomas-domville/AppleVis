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

    /// Translates every field that isn't in English, for screens with more
    /// than one text box. The prompt can be set off by any of them, but
    /// Translate used to act on one fixed box only — so non-English text in
    /// the other box stayed as it was. Reported directly.
    /// Returns false if any translation failed.
    func translateEach(_ fields: [Binding<String>]) async -> Bool {
        var succeeded = true
        for field in fields where IntelligenceService.detectNonEnglish(field.wrappedValue) {
            if let result = await translate(subject: nil, body: field.wrappedValue, isTopic: false) {
                field.wrappedValue = result.body
            } else {
                succeeded = false
            }
        }
        if succeeded { showTranslatePrompt = false }
        return succeeded
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

/// A Rewrite button for a single compose field, for screens that don't
/// build their own — same look, wording and hint as every wizard's.
struct DraftRewriteButton: View {
    @ObservedObject var intelligence: ComposeIntelligenceState
    @Binding var text: String
    @Binding var justRewrote: Bool

    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var toast: ToastStore

    var body: some View {
        if preferences.composeRewriteEnabled && IntelligenceService.isAvailable {
            Button {
                Task {
                    if let result = await intelligence.rewrite(subject: nil, body: text, isTopic: false) {
                        text = result.body
                        justRewrote = true
                    } else {
                        toast.error(String(localized: "Couldn't rewrite this. Try again."))
                    }
                }
            } label: {
                Label("Rewrite", systemImage: "wand.and.stars")
                    .symbolEffect(.bounce, value: justRewrote)
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || intelligence.isProcessing)
            .accessibilityHint(String(localized: "Uses Apple Intelligence to suggest a clearer rewrite of this text."))
        }
    }
}
