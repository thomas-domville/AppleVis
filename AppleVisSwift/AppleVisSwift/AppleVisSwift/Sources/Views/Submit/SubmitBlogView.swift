import SwiftUI
import UniformTypeIdentifiers

/// Ported against src/services/drupalForm.ts's `/form/blog-submission` webform
/// and src/contexts/BlogWizardContext.tsx.
///
/// RN requires sign-in (submission silently no-ops without a user, and posts
/// under the account's name with no email field at all — verified via
/// `app/submit-blog/review.tsx`'s `if (!user) return` + `name: user.name,
/// email: ''`) and collects Title + Category as step 1, not editable name/
/// email fields — Swift previously fabricated a "Your Details" step asking
/// for free-text name/email with no sign-in gate, and never collected Title
/// or Category at all.
///
/// Three-step wizard: Title & Category → Content → Review, matching RN's
/// index → content → review.
struct SubmitBlogView: View {
    private enum Step: Int { case details, content, review }

    static let categories = [
        "Accessories", "Advocacy", "Apple", "Apple TV", "Apple Vision Pro",
        "Apple Watch", "AppleVis", "Assistive Technology", "Braille", "Gaming",
        "iOS", "iOS and iPadOS Apps", "iPad", "iPadOS", "iPhone",
        "Mac Apps", "macOS", "News", "Opinion", "Reviews", "Rumors",
    ]

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var guidelines = GuidelinesCheckState()
    @StateObject private var intelligence = ComposeIntelligenceState()
    @AccessibilityFocusState private var isStepFocused: Bool

    @State private var step: Step = .details
    @State private var showSignIn = false
    @State private var title = ""
    @State private var category = ""
    @State private var coverNote = ""
    @State private var blogDraft = ""
    @State private var isSubmitting = false
    @State private var error: String?
    @State private var showFileImporter = false
    @State private var showDiscardConfirm = false

    /// Set when opened from the Share Extension with shared text.
    init(prefillText: String? = nil) {
        _blogDraft = State(initialValue: prefillText ?? "")
    }

    private var detailsValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !category.isEmpty
    }

    private var contentValid: Bool {
        !blogDraft.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if !auth.isSignedIn {
                    signInRequiredView
                } else {
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
                    .themedList(preferences.colors)
                }
            }
            .navigationTitle("Submit a Blog Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == .details ? "Cancel" : "Back") {
                        if step == .details {
                            requestCancel()
                        } else {
                            goBack()
                        }
                    }
                }
                if auth.isSignedIn {
                    if step == .content && preferences.composeRewriteEnabled && IntelligenceService.isAvailable {
                        ToolbarItem(placement: .secondaryAction) {
                            Button("Rewrite") {
                                Task {
                                    if let result = await intelligence.rewrite(subject: nil, body: blogDraft, isTopic: false) {
                                        blogDraft = result.body
                                    } else {
                                        toast.error(String(localized: "Couldn't rewrite this. Try again."))
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
            }
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
    }

    private var signInRequiredView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Sign In Required")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text("You need to be signed in to your AppleVis account to submit a blog post.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Sign In") { showSignIn = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var detailsSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: 1, total: 3, title: "Title & Category", isFocused: $isStepFocused)
                Text("Submit a blog post draft for the AppleVis editorial team to review. This does not publish immediately — an editor will follow up.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Blog Post") {
                TextField("Blog title", text: $title)
                Picker("Category", selection: $category) {
                    Text("Choose a category").tag("")
                    ForEach(Self.categories, id: \.self) { Text($0).tag($0) }
                }
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
                                toast.error(String(localized: "Couldn't translate this. Try again."))
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
            Section("Note to Editors") {
                TextEditor(text: $coverNote)
                    .frame(minHeight: 80)
                    .accessibilityHint(String(localized: "A private note to the editorial team, not published."))
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
                    .accessibilityHint(String(localized: "Replaces the draft with the contents of a text file."))

                    Spacer()

                    Button {
                        pasteFromClipboard()
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }
                    .accessibilityHint(String(localized: "Replaces the draft with the contents of the clipboard."))
                }
                .buttonStyle(.borderless)
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.plainText, .text, .rtf], onCompletion: handleFileImport)
        .confirmationDialog(
            "Discard this submission?",
            isPresented: $showDiscardConfirm, titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { SoundPlayer.shared.play(.screenClose); dismiss() }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Your progress will be discarded.")
        }
    }

    /// RN confirmed before discarding a filled-out form; Cancel here
    /// previously dismissed immediately with no warning, silently losing a
    /// written blog post draft with one accidental tap — same regression
    /// already fixed for Submit App, now matched here.
    private func requestCancel() {
        let hasProgress = !title.trimmingCharacters(in: .whitespaces).isEmpty
            || !coverNote.trimmingCharacters(in: .whitespaces).isEmpty
            || !blogDraft.trimmingCharacters(in: .whitespaces).isEmpty
        if hasProgress {
            showDiscardConfirm = true
        } else {
            SoundPlayer.shared.play(.screenClose)
            dismiss()
        }
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
                toast.error(String(localized: "Couldn't read that file."))
                return
            }
            blogDraft = text
            UIAccessibility.post(notification: .announcement, argument: "Imported \(text.count) characters.")
        case .failure:
            toast.error(String(localized: "Couldn't import that file."))
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
            Section("Blog Post") {
                WizardReviewRow(label: "Title", value: title)
                WizardReviewRow(label: "Category", value: category)
            }
            Section("Content") {
                WizardReviewRow(label: "Note to Editors", value: coverNote)
                WizardReviewRow(label: "Blog Post Draft", value: blogDraft)
            }
            Section("From") {
                WizardReviewRow(label: "Posting As", value: auth.user?.name ?? "")
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
        guard let user = auth.user else { return }
        isSubmitting = true; error = nil
        var message = "Blog Title: \(title)\nCategory: \(category)"
        if !coverNote.trimmingCharacters(in: .whitespaces).isEmpty {
            message += "\n\nNote to editors:\n\(coverNote)"
        }
        let result = await DrupalFormClient.submitBlog(name: user.name, email: "", message: message, blogDraft: blogDraft)
        switch result {
        case .ok:
            toast.success(String(localized: "Blog post submitted for review"))
            dismiss()
        case .failure(let message):
            error = message
        }
        isSubmitting = false
    }
}
