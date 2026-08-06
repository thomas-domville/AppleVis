import SwiftUI
import UniformTypeIdentifiers

/// Ported against src/services/drupalForm.ts's `/form/blog-submission` webform.
/// Requires an authenticated session to reach the real form — could not be
/// end-to-end verified live (see DrupalFormClient's header comment).
///
/// Three-step wizard: Your Details → Content → Review, matching the original
/// step-by-step design (index → content → review).
struct SubmitBlogView: View {
    private enum Step: Int { case details, content, review }

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var guidelines = GuidelinesCheckState()
    @StateObject private var intelligence = ComposeIntelligenceState()
    @AccessibilityFocusState private var isStepFocused: Bool

    @State private var step: Step = .details
    @State private var name = ""
    @State private var email = ""
    @State private var coverNote = ""
    @State private var blogDraft = ""
    @State private var isSubmitting = false
    @State private var error: String?
    @State private var showFileImporter = false

    /// Set when opened from the Share Extension with shared text.
    init(prefillText: String? = nil) {
        _blogDraft = State(initialValue: prefillText ?? "")
    }

    private var detailsValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var contentValid: Bool {
        !blogDraft.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                switch step {
                case .details: detailsSection
                case .content: contentSection
                case .review:  reviewSection
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Submit a Blog Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == .details ? "Cancel" : "Back") {
                        if step == .details {
                            SoundPlayer.shared.play(.screenClose)
                            dismiss()
                        } else {
                            goBack()
                        }
                    }
                }
                if step == .content && preferences.composeRewriteEnabled && IntelligenceService.isAvailable {
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Rewrite") {
                            Task {
                                if let result = await intelligence.rewrite(subject: nil, body: blogDraft, isTopic: false) {
                                    blogDraft = result.body
                                } else {
                                    toast.error("Couldn't rewrite this. Try again.")
                                }
                            }
                        }
                        .disabled(blogDraft.trimmingCharacters(in: .whitespaces).isEmpty || intelligence.isProcessing)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if step == .review {
                        Button("Submit") { Task { await submit() } }
                            .disabled(isSubmitting)
                    } else {
                        Button("Next") { goNext() }
                            .disabled(step == .details ? !detailsValid : !contentValid)
                    }
                }
            }
            .onAppear {
                if name.isEmpty { name = auth.user?.name ?? "" }
            }
        }
    }

    private var detailsSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: 1, total: 3, title: "Your Details", isFocused: $isStepFocused)
                Text("Submit a blog post draft for the AppleVis editorial team to review. This does not publish immediately — an editor will follow up.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Your Details") {
                TextField("Name", text: $name)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .accessibilityHint("The editorial team will follow up at this address.")
            }
        }
    }

    private var contentSection: some View {
        Group {
            Section { WizardStepIndicator(step: 2, total: 3, title: "Your Content", isFocused: $isStepFocused) }
            if intelligence.showTranslatePrompt {
                Section {
                    TranslatePromptView(isProcessing: intelligence.isProcessing) {
                        Task {
                            if let result = await intelligence.translate(subject: nil, body: blogDraft, isTopic: false) {
                                blogDraft = result.body
                            } else {
                                toast.error("Couldn't translate this. Try again.")
                            }
                        }
                    } onDismiss: {
                        intelligence.dismissTranslatePrompt()
                    }
                }
            }
            if let warning = guidelines.topWarning {
                Section {
                    GuidelinesReminderView(warning: warning) { guidelines.dismiss() }
                }
            }
            Section("Cover Note") {
                TextEditor(text: $coverNote)
                    .frame(minHeight: 80)
                    .accessibilityHint("A private note to the editorial team, not published.")
            }
            Section("Blog Post Draft") {
                TextEditor(text: $blogDraft)
                    .frame(minHeight: 200)
                    .onChange(of: blogDraft) { _, newValue in
                        guidelines.textChanged(newValue)
                        intelligence.textChanged(
                            newValue,
                            translationEnabled: preferences.composeTranslationEnabled,
                            detectionEnabled: preferences.nonEnglishDetectionEnabled
                        )
                    }
                HStack {
                    Button {
                        showFileImporter = true
                    } label: {
                        Label("Import File", systemImage: "doc.text")
                    }
                    .accessibilityHint("Replaces the draft with the contents of a text file.")

                    Spacer()

                    Button {
                        pasteFromClipboard()
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }
                    .accessibilityHint("Replaces the draft with the contents of the clipboard.")
                }
                .buttonStyle(.borderless)
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.plainText, .text, .rtf], onCompletion: handleFileImport)
    }

    /// Matches the old app's Write/Import/Paste content step, minus the
    /// mode-switching UI — Import and Paste both just fill the same draft
    /// editor, which keeps the Write mode always visible instead of hiding
    /// it behind a segmented picker.
    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                toast.error("Couldn't read that file.")
                return
            }
            blogDraft = text
            UIAccessibility.post(notification: .announcement, argument: "Imported \(text.count) characters.")
        case .failure:
            toast.error("Couldn't import that file.")
        }
    }

    private func pasteFromClipboard() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            UIAccessibility.post(notification: .announcement, argument: "Clipboard is empty.")
            return
        }
        blogDraft = text
        UIAccessibility.post(notification: .announcement, argument: "Pasted \(text.count) characters.")
    }

    private var reviewSection: some View {
        Group {
            Section { WizardStepIndicator(step: 3, total: 3, title: "Review & Submit", isFocused: $isStepFocused) }
            Section("Your Details") {
                WizardReviewRow(label: "Name", value: name)
                WizardReviewRow(label: "Email", value: email)
            }
            Section("Content") {
                WizardReviewRow(label: "Cover Note", value: coverNote)
                WizardReviewRow(label: "Blog Post Draft", value: blogDraft)
            }
        }
    }

    private func goNext() {
        SoundPlayer.shared.play(.pickerTick)
        step = Step(rawValue: step.rawValue + 1) ?? .review
        focusStepAfterTransition()
    }

    private func goBack() {
        SoundPlayer.shared.play(.pickerTick)
        step = Step(rawValue: step.rawValue - 1) ?? .details
        focusStepAfterTransition()
    }

    private func focusStepAfterTransition() {
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            isStepFocused = true
        }
    }

    private func submit() async {
        isSubmitting = true; error = nil
        let result = await DrupalFormClient.submitBlog(name: name, email: email, message: coverNote, blogDraft: blogDraft)
        switch result {
        case .ok:
            toast.success("Blog post submitted for review")
            dismiss()
        case .failure(let message):
            error = message
        }
        isSubmitting = false
    }
}
