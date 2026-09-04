import SwiftUI

/// Shared edit sheet for any user-authored comment/reply/review body text.
struct EditContentSheet: View {
    let title: String
    let initialText: String
    let onSave: (String) async throws -> Void

    @State private var text: String
    @State private var isSaving = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var toast: ToastStore
    @StateObject private var guidelines = GuidelinesCheckState()
    @StateObject private var intelligence = ComposeIntelligenceState()
    /// Had no focus management at all — focuses the text editor itself
    /// rather than a separate heading, matching ComposeTopicView's identical
    /// reasoning for a single-field edit form: otherwise it silently
    /// defaults to the back button. Full app-wide focus audit, requested
    /// directly.
    @AccessibilityFocusState private var isTextEditorFocused: Bool

    init(title: String, initialText: String, onSave: @escaping (String) async throws -> Void) {
        self.title = title
        self.initialText = initialText
        self.onSave = onSave
        _text = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                if intelligence.showTranslatePrompt {
                    TranslatePromptView(isProcessing: intelligence.isProcessing) {
                        Task {
                            if let result = await intelligence.translate(subject: nil, body: text, isTopic: false) {
                                text = result.body
                            } else {
                                toast.error(String(localized: "Couldn't translate this. Try again."))
                            }
                        }
                    } onDismiss: {
                        intelligence.dismissTranslatePrompt()
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                if let warning = guidelines.topWarning {
                    GuidelinesReminderView(
                        warning: warning,
                        onDismiss: { guidelines.dismiss() },
                        onRewriteRespectfully: {
                            Task {
                                if let result = await intelligence.rewriteRespectfully(subject: nil, body: text, isTopic: false) {
                                    text = result.body
                                } else {
                                    toast.error(String(localized: "Couldn't rewrite this. Try again."))
                                }
                            }
                        }
                    )
                        .padding(.horizontal)
                        .padding(.top)
                }
                TextEditor(text: $text)
                    .padding()
                    .accessibilityFocused($isTextEditorFocused)
                    .onChange(of: text) { _, newValue in
                        guidelines.textChanged(newValue)
                        intelligence.textChanged(
                            newValue,
                            translationEnabled: preferences.composeTranslationEnabled,
                            detectionEnabled: preferences.nonEnglishDetectionEnabled
                        )
                    }
                if let error {
                    Text(error).foregroundStyle(.red).padding(.horizontal)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { SoundPlayer.shared.play(.screenClose); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving || text == initialText)
                }
            }
            .task { await retryAccessibilityFocus(into: $isTextEditorFocused) }
        }
    }

    private func save() async {
        if let message = ContentSubmissionPolicy.blockingMessage(
            body: text
        ) {
            error = message
            return
        }
        isSaving = true; error = nil
        do {
            try await onSave(text)
            dismiss()
        } catch let e as APIError {
            error = e.localizedDescription
        } catch {
            self.error = "Couldn't save changes."
        }
        isSaving = false
    }
}
