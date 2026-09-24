import SwiftUI

/// Shared edit sheet for any user-authored comment/reply/review body text.
struct EditContentSheet: View {
    let title: String
    let initialText: String
    let onSave: (String) async throws -> Void
    /// See `GuidelinesChecker.check(_:isReply:)`'s doc comment. Defaults to
    /// true since every call site but one (the admin Guideline Violation
    /// Check screen, which can also be editing a flagged root item) is
    /// editing an existing comment/reply/review.
    let isReply: Bool

    @State private var text: String
    @State private var isSaving = false
    @State private var error: String?
    @State private var justRewrote = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var toast: ToastStore
    @StateObject private var guidelines = GuidelinesCheckState()
    @StateObject private var intelligence = ComposeIntelligenceState()
    /// Now focuses the header below, not the text editor — matches how
    /// every other wizard-style screen in the app (Setup, the Welcome Tour,
    /// Submit/Contact) focuses its heading first, not straight into a
    /// field. Previously had no focus management at all and silently
    /// defaulted to the back button; this is a further refinement of that
    /// original fix, not a reversal of it.
    @AccessibilityFocusState private var isHeaderFocused: Bool

    init(title: String, initialText: String, isReply: Bool = true, onSave: @escaping (String) async throws -> Void) {
        self.title = title
        self.initialText = initialText
        self.isReply = isReply
        self.onSave = onSave
        _text = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    WizardStepHeader(
                        title: title, icon: "text.bubble",
                        stepIndex: 1, stepTotal: 1, headerFocus: $isHeaderFocused
                    )
                    Text("Update your message below, then tap Save.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 24)

                    if intelligence.showTranslatePrompt {
                        TranslatePromptView(isProcessing: intelligence.isProcessing) {
                            Task {
                                if let result = await intelligence.translate(subject: nil, body: text, isTopic: false) {
                                    text = result.body
                                    justRewrote = true
                                } else {
                                    toast.error(String(localized: "Couldn't translate this. Try again."))
                                }
                            }
                        } onDismiss: {
                            intelligence.dismissTranslatePrompt()
                        }
                        .padding(.horizontal)
                    }
                    if let warning = guidelines.topWarning {
                        GuidelinesReminderView(
                            warning: warning,
                            draftText: text,
                            context: title,
                            onDismiss: { guidelines.dismiss() },
                            onRewriteRespectfully: {
                                Task {
                                    if let result = await intelligence.rewriteRespectfully(subject: nil, body: text, isTopic: false) {
                                        text = result.body
                                        justRewrote = true
                                    } else {
                                        toast.error(String(localized: "Couldn't rewrite this. Try again."))
                                    }
                                }
                            }
                        )
                        .padding(.horizontal)
                        .transition(UIAccessibility.isReduceMotionEnabled ? .identity : .opacity.combined(with: .move(edge: .top)))
                    }
                    TextEditor(text: $text)
                        .frame(minHeight: 160)
                        .padding(.horizontal)
                        .rewriteFlash($justRewrote)
                        .onChange(of: text) { _, newValue in
                            guidelines.textChanged(newValue, isReply: isReply)
                            intelligence.textChanged(
                                newValue,
                                translationEnabled: preferences.composeTranslationEnabled,
                                detectionEnabled: preferences.nonEnglishDetectionEnabled
                            )
                        }
                    rewriteButton
                        .padding(.horizontal)
                    if let error {
                        Text(error).foregroundStyle(.red).padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { SoundPlayer.shared.play(.screenClose); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving || text == initialText)
                }
            }
            .animation(UIAccessibility.isReduceMotionEnabled ? nil : .easeInOut, value: guidelines.topWarning?.id)
            .task { await retryAccessibilityFocus(into: $isHeaderFocused) }
        }
    }

    @ViewBuilder
    private var rewriteButton: some View {
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
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || intelligence.isProcessing)
            .accessibilityHint(String(localized: "Uses Apple Intelligence to suggest a clearer rewrite of this text."))
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
            self.error = String(localized: "Couldn't save changes.")
        }
        isSaving = false
    }
}
