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
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @EnvironmentObject private var communityAgreement: CommunityAgreementStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var guidelines = GuidelinesCheckState()
    @StateObject private var intelligence = ComposeIntelligenceState()
    @StateObject private var domainChecker = EmailDomainChecker()
    @AccessibilityFocusState private var isStepFocused: Bool
    @AccessibilityFocusState private var isErrorFocused: Bool

    @State private var step: Step = .details
    @State private var showSignIn = false
    /// Gates `showSignIn` above via `.communityAgreementGate(...)` below —
    /// see `CommunityAgreementStore`.
    @State private var showCommunityAgreement = false
    @State private var title = ""
    @State private var category = ""
    /// The live webform's actual required "Message" field — its own
    /// description reads "Tell us a little about your blog post and why
    /// you think it would be of interest and value to the AppleVis
    /// community." Previously named `coverNote`, optional, and never
    /// actually sent to that field at all — the real "Message" field was
    /// silently filled with a mechanical "Blog Title: X\nCategory: Y"
    /// summary instead of ever asking the submitter for this. Verified
    /// live against the real form. Reported directly.
    @State private var pitchMessage = ""
    @State private var blogDraft = ""
    /// The live webform's `email` field is genuinely `required="required"`
    /// — confirmed live, and confirmed pre-filled with the signed-in
    /// user's real account email in a browser (a Drupal default-value
    /// token, not something a raw POST inherits automatically). This was
    /// previously hardcoded to an empty string at submit time, which a
    /// server-required field would very likely reject outright. Reported
    /// directly; the same fix is needed for Bug and Podcast submission,
    /// which share the identical hardcoded-empty pattern.
    @State private var email = ""
    @State private var isSubmitting = false
    @State private var error: String?
    @State private var showFileImporter = false
    @State private var showDiscardConfirm = false
    @State private var submitted = false
    @State private var blogDraftMinimumAnnounced = false
    @State private var showAccountEmailChange = false
    @State private var emailSuggestionDismissed = false
    @State private var justRewrote = false

    /// Set when opened from the Share Extension with shared text.
    init(prefillText: String? = nil) {
        _blogDraft = State(initialValue: prefillText ?? "")
    }

    private var detailsValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !category.isEmpty
    }

    private var blogDraftLength: Int { blogDraft.trimmingCharacters(in: .whitespacesAndNewlines).count }

    /// 50-char minimum matches legacy's `submit-blog/content.tsx`
    /// `canContinue`, dropped in the native port (SUBMIT-012). Now also
    /// requires Email and the pitch message — both genuinely required on
    /// the live form, previously not asked for (email) or not actually
    /// sent to the field asking for it (pitch). Reported directly.
    private var contentValid: Bool {
        blogDraftLength >= 50 && emailValid && !pitchMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var contentBlockingReasons: [String] {
        var reasons: [String] = []
        if !emailValid {
            reasons.append(String(localized: "Enter a valid email address to continue."))
        }
        if pitchMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            reasons.append(String(localized: "Tell us why this post would interest AppleVis readers to continue."))
        }
        if blogDraftLength < 50 {
            reasons.append(String(localized: "Write at least \(50 - blogDraftLength) more character\(50 - blogDraftLength == 1 ? "" : "s") to continue."))
        }
        return reasons
    }

    // Moved to String.isValidEmailFormat (EmailValidation.swift) so Contact
    // Us, Submit Bug Report, and Report a Comment can share the same check
    // instead of each having their own weaker "contains @" test.
    private var emailValid: Bool { email.isValidEmailFormat }

    /// Mirrors Contact's crossing-the-threshold announcement so VoiceOver
    /// users learn the moment they can continue, not just via Next's
    /// disabled state.
    private func handleBlogDraftChange(_ newValue: String) {
        let length = newValue.trimmingCharacters(in: .whitespacesAndNewlines).count
        if !blogDraftMinimumAnnounced && length >= 50 {
            blogDraftMinimumAnnounced = true
            UIAccessibility.post(notification: .announcement, argument: String(localized: "Minimum length reached. You can now continue."))
        } else if blogDraftMinimumAnnounced && length < 50 {
            blogDraftMinimumAnnounced = false
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if submitted {
                    ThankYouView(
                        icon: "doc.text",
                        heading: "You did it — thanks!",
                        message: "Your draft is now in front of our editorial team. We genuinely appreciate you taking the time to write for AppleVis, and we'll be in touch soon with our decision.",
                        doneLabel: "Done",
                        onDone: { dismiss() }
                    ) {
                        if !emailSuggestionDismissed,
                           AccountEmailUpdateSuggestion.applies(usedEmail: email, accountEmail: auth.user?.email) {
                            AccountEmailUpdateSuggestion(isDismissed: $emailSuggestionDismissed, showEmailChangeWizard: $showAccountEmailChange)
                        }
                    }
                } else if !auth.isSignedIn {
                    signInRequiredView
                } else {
                    Form {
                        switch step {
                        case .details: detailsSection
                        case .content: contentSection
                        case .review:  reviewSection
                        }
                        if let error {
                            Section {
                                Text(error)
                                    .foregroundStyle(.red)
                                    .accessibilityAddTraits(.isHeader)
                                    .accessibilityFocused($isErrorFocused)
                            }
                        }
                    }
                    .themedList(preferences.colors)
                }
            }
            .navigationTitle("Submit a Blog Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !submitted {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { requestCancel() }
                }
                if auth.isSignedIn {
                    ToolbarItem(placement: .confirmationAction) {
                        if step == .review {
                            Button("Submit") { Task { await submit() } }
                                .disabled(isSubmitting || !networkMonitor.isConnected)
                                .accessibilityHint(networkMonitor.isConnected ? "" : String(localized: "You're offline. Reconnect to submit this."))
                        } else {
                            Button("Next") { goNext() }
                                .disabled(step == .details ? !detailsValid : !contentValid)
                        }
                    }
                }
                }
            }
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
        .communityAgreementGate(showCommunityAgreement: $showCommunityAgreement, showSignIn: $showSignIn)
        .sheet(isPresented: $showAccountEmailChange) {
            AccountSecurityWizard(mode: .email, initialEmail: email)
        }
        // Step 1 previously got no explicit focus at all — only
        // goNext()/goBack() ever called focusStepAfterTransition(), so
        // opening this wizard left VoiceOver focus on system default
        // (typically Cancel). Full app-wide focus audit, requested directly.
        .task {
            // The live website pre-fills this same field with the signed-in
            // user's real account email (see the `email` property comment
            // above) — AuthUser.email now lets the app match that instead of
            // making a signed-in user retype it. Reported directly.
            if email.isEmpty, let acctEmail = auth.user?.email {
                email = acctEmail
            }
            focusStepAfterTransition()
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
                .accessibilityFocused($isStepFocused)
            Text("You need to be signed in to your AppleVis account to submit a blog post.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Sign In") {
                communityAgreement.requestSignIn(showCommunityAgreement: $showCommunityAgreement, showSignIn: $showSignIn)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var detailsSection: some View {
        Group {
            Section {
                WizardStepHeader(title: "Title & Category", stepIndex: 1, stepTotal: 3, headerFocus: $isStepFocused)
                Text("Submit a blog post draft for the AppleVis editorial team to review. This does not publish immediately — an editor will follow up.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Blog Post") {
                TextField("Blog title", text: $title)
                    .accessibilityHint(String(localized: "Required."))
                Picker("Category", selection: $category) {
                    Text("Choose a category").tag("")
                    ForEach(Self.categories, id: \.self) { Text(LocalizedStringKey($0)).tag($0) }
                }
                .accessibilityHint(String(localized: "Required."))
            }
            Section {
                WizardBlockingNote(reasons: detailsBlockingReasons)
                WizardBottomButton(String(localized: "Next"), isEnabled: detailsValid, action: goNext)
            }
        }
    }

    private var detailsBlockingReasons: [String] {
        var reasons: [String] = []
        if title.trimmingCharacters(in: .whitespaces).isEmpty {
            reasons.append(String(localized: "Enter a blog title to continue."))
        }
        if category.isEmpty {
            reasons.append(String(localized: "Choose a category to continue."))
        }
        return reasons
    }

    private var contentSection: some View {
        Group {
            Section {
                WizardStepHeader(title: "Your Content", stepIndex: 2, stepTotal: 3, onBack: goBack, headerFocus: $isStepFocused)
                Text("Add your email so our editorial team can reply, then tell us about your post and write or import your draft.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section {
                TextField("Your Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .accessibilityHint(String(localized: "Required. The AppleVis editorial team may reply to follow up on your submission."))
                    .onChange(of: email) { _, newValue in domainChecker.check(email: newValue) }
            } header: {
                Text("Your Email")
            } footer: {
                if !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !emailValid {
                    Text("Enter a valid email address.")
                        .foregroundStyle(.red)
                } else {
                    EmailDomainWarning(checker: domainChecker)
                }
            }
            if intelligence.showTranslatePrompt {
                Section {
                    TranslatePromptView(isProcessing: intelligence.isProcessing) {
                        Task {
                            // The pitch can set off the prompt too, so translate
                            // whichever box isn't in English. Reported directly.
                            if await intelligence.translateEach([$pitchMessage, $blogDraft]) {
                                justRewrote = true
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
                    GuidelinesReminderView(
                        warning: warning,
                        draftText: blogDraft,
                        context: "Submit Blog Post",
                        onDismiss: { guidelines.dismiss() },
                        onRewriteRespectfully: {
                            Task {
                                if let result = await intelligence.rewriteRespectfully(subject: title, body: blogDraft, isTopic: true) {
                                    title = result.subject ?? title
                                    blogDraft = result.body
                                    justRewrote = true
                                } else {
                                    toast.error(String(localized: "Couldn't rewrite this. Try again."))
                                }
                            }
                        }
                    )
                }
                .transition(UIAccessibility.isReduceMotionEnabled ? .identity : .opacity.combined(with: .move(edge: .top)))
            }
            // The live webform's actual required "Message" field — see the
            // `pitchMessage` property's doc comment. Now gets the same
            // live guideline/language checking as the draft itself, which
            // the old optional "Note to Editors" never had at all.
            Section {
                TextEditor(text: $pitchMessage)
                    .frame(minHeight: 80)
                    .accessibilityLabel(String(localized: "Why this post would interest AppleVis readers"))
                    .accessibilityHint(String(localized: "Required. Tell us a little about your blog post and why you think it would be of interest and value to the AppleVis community."))
                    .rewriteFlash($justRewrote)
                    .onChange(of: pitchMessage) { _, newValue in
                        guidelines.textChanged(newValue)
                        intelligence.textChanged(
                            newValue,
                            translationEnabled: preferences.composeTranslationEnabled,
                            detectionEnabled: preferences.nonEnglishDetectionEnabled
                        )
                    }
                // The draft had Rewrite; this required pitch never did.
                DraftRewriteButton(intelligence: intelligence, text: $pitchMessage, justRewrote: $justRewrote)
            } header: {
                Text("Why This Post Would Interest AppleVis Readers")
            } footer: {
                Text("Tell us a little about your blog post and why you think it would be of interest and value to the AppleVis community.")
            }
            Section {
                // Combined label+counter into one live-updating swipe-stop
                // instead of two. Same fix applied to every minimum-length
                // field across every wizard. Reported directly.
                HStack {
                    Text("Blog Post Draft").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(blogDraftLength < 50 ? "\(blogDraftLength) / 50 min" : "\(blogDraftLength) chars")
                        .font(.caption)
                        .fontWeight(blogDraftLength < 50 ? .bold : .regular)
                        .foregroundStyle(blogDraftLength < 50 ? .red : .secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(blogDraftLength < 50 ? String(localized: "Blog Post Draft: \(blogDraftLength) of 50 minimum characters") : String(localized: "Blog Post Draft: \(blogDraftLength) characters"))
                .accessibilityAddTraits(.updatesFrequently)
                TextEditor(text: $blogDraft)
                    .frame(minHeight: 200)
                    .accessibilityLabel(String(localized: "Blog Post Draft"))
                    .accessibilityHint(String(localized: "Required. Minimum 50 characters."))
                    .rewriteFlash($justRewrote)
                    .onChange(of: blogDraft) { _, newValue in
                        handleBlogDraftChange(newValue)
                        guidelines.textChanged(newValue)
                        intelligence.textChanged(
                            newValue,
                            translationEnabled: preferences.composeTranslationEnabled,
                            detectionEnabled: preferences.nonEnglishDetectionEnabled
                        )
                    }
                rewriteButton
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
            Section {
                WizardBlockingNote(reasons: contentBlockingReasons)
                WizardBottomButton(String(localized: "Next"), isEnabled: contentValid, action: goNext)
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
            || !pitchMessage.trimmingCharacters(in: .whitespaces).isEmpty
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
            guard let text = Self.decodeTextFile(at: url) else {
                toast.error(String(localized: "Couldn't read that file."))
                return
            }
            blogDraft = text
            UIAccessibility.post(notification: .announcement, argument: String(localized: "Imported \(text.count) characters."))
        case .failure:
            toast.error(String(localized: "Couldn't import that file."))
        }
    }

    /// `allowedContentTypes` on the file importer includes `.rtf`, but a
    /// plain `String(contentsOf:encoding:.utf8)` read — which RTF's own
    /// text-based markup doesn't fail on — produces raw `{\rtf1\ansi...}`
    /// control-code text instead of the actual document content. Decodes
    /// through `NSAttributedString` for `.rtf` specifically; every other
    /// allowed type keeps the plain UTF-8 read. Reported directly.
    static func decodeTextFile(at url: URL) -> String? {
        if url.pathExtension.lowercased() == "rtf" {
            guard let data = try? Data(contentsOf: url),
                  let attributed = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
            else { return nil }
            return attributed.string
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private func pasteFromClipboard() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            UIAccessibility.post(notification: .announcement, argument: String(localized: "Clipboard is empty."))
            return
        }
        blogDraft = text
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Pasted \(text.count) characters."))
    }

    private var reviewSection: some View {
        Group {
            Section {
                WizardStepHeader(title: "Review & Submit", stepIndex: 3, stepTotal: 3, onBack: goBack, headerFocus: $isStepFocused)
                Text("Check your details, then tap Submit.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Blog Post") {
                WizardReviewRow(label: "Title", value: title)
                WizardReviewRow(label: "Category", value: category)
            }
            Section("Content") {
                WizardReviewRow(label: "Why This Post Would Interest AppleVis Readers", value: pitchMessage)
                WizardReviewRow(label: "Blog Post Draft", value: blogDraft)
            }
            Section("From") {
                WizardReviewRow(label: "Posting As", value: auth.user?.name ?? "")
                WizardReviewRow(label: "Email", value: email)
            }
            if !networkMonitor.isConnected {
                Section {
                    OfflineComposeNotice()
                }
                .listRowSeparator(.hidden)
            }
            Section {
                WizardBottomButton(
                    String(localized: "Submit"),
                    isEnabled: !isSubmitting && networkMonitor.isConnected, isLoading: isSubmitting
                ) { Task { await submit() } }
            }
        }
    }

    @ViewBuilder
    private var rewriteButton: some View {
        if preferences.composeRewriteEnabled && IntelligenceService.isAvailable {
            Button {
                Task {
                    if let result = await intelligence.rewrite(subject: title, body: blogDraft, isTopic: true) {
                        title = result.subject ?? title
                        blogDraft = result.body
                        justRewrote = true
                    } else {
                        toast.error(String(localized: "Couldn't rewrite this. Try again."))
                    }
                }
            } label: {
                Label("Rewrite", systemImage: "wand.and.stars")
                    .symbolEffect(.bounce, value: justRewrote)
            }
            .disabled(blogDraft.trimmingCharacters(in: .whitespaces).isEmpty || intelligence.isProcessing)
            .accessibilityHint(String(localized: "Uses Apple Intelligence to suggest a clearer rewrite of this text."))
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

    /// Was a single guessed 300ms delay — see SubmitAppView's identical fix
    /// for the full reasoning (this pattern was independently copy-pasted
    /// across every multi-step wizard). Full app-wide focus audit,
    /// requested directly.
    private func focusStepAfterTransition() {
        Task { await retryAccessibilityFocus(into: $isStepFocused) }
    }

    private func submit() async {
        guard let user = auth.user else { return }
        if let policyMessage = ContentSubmissionPolicy.blockingMessage(
            subject: title,
            body: [pitchMessage, blogDraft].joined(separator: "\n\n")
        ) {
            error = policyMessage
            await announceWizardFailure(policyMessage, focus: $isErrorFocused)
            return
        }
        isSubmitting = true; error = nil
        // The live "Message" field is what editors actually read as the
        // submitter's pitch — sends the real pitch text now, with the
        // category folded in as supplementary context rather than
        // crowding it out, matching what the field is genuinely for
        // (previously this field received a mechanical "Blog Title: X
        // \nCategory: Y" summary instead, and the real pitch was never
        // asked for at all). Reported directly.
        let message = category.isEmpty
            ? pitchMessage
            : "\(pitchMessage)\n\n(Suggested category: \(category))"
        // The live "Blog Post" field's own description says "Include your
        // proposed title for the post" — there's no separate title field
        // on the real form at all, so the title this wizard collects for
        // a nicer editing experience is folded into the draft content
        // itself at submit time, not just mentioned in a side field the
        // real form doesn't read as the actual draft. Reported directly.
        let draftWithTitle = "\(title)\n\n\(blogDraft)"
        let result = await DrupalFormClient.submitBlog(
            name: user.name,
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            message: message,
            blogDraft: draftWithTitle
        )
        switch result {
        case .ok:
            SoundPlayer.shared.play(.success)
            submitted = true
        case .failure(let message):
            error = message
            await announceWizardFailure(message, focus: $isErrorFocused)
        }
        isSubmitting = false
    }
}
