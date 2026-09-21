import SwiftUI

/// In-app contact form — replaces linking out to Safari. Ported against the
/// live, verified `/contact` Drupal webform (see DrupalFormClient).
///
/// Matches RN's `app/contact/{index,details,compose,review}.tsx` flow: a
/// contact-type picker, an optional guest-only details step, a message step,
/// and review + send. Signed-in users skip the details step (3 steps total);
/// guests see all four.
struct ContactView: View {
    enum ContactType: String, CaseIterable, Identifiable {
        case bug, feedback, suggestion, general
        var id: String { rawValue }

        var label: String {
            switch self {
            case .bug: return "Bug Report"
            case .feedback: return "Feedback"
            case .suggestion: return "Suggestion"
            case .general: return "General Enquiry"
            }
        }

        var subject: String {
            switch self {
            case .bug: return "App Bug Report"
            case .feedback: return "App Feedback"
            case .suggestion: return "App Suggestion"
            case .general: return "App Enquiry"
            }
        }

        var description: String {
            switch self {
            case .bug: return "Something in the app is broken or not working as expected."
            case .feedback: return "Share your thoughts, reactions, or general impressions about the app."
            case .suggestion: return "An idea to make the app better — a feature, improvement, or change."
            case .general: return "Ask a question, raise a concern, or get in touch about anything else."
            }
        }

        var hint: String {
            switch self {
            case .bug: return "Report a technical problem with the AppleVis app."
            case .feedback: return "Tell us what you think about the app."
            case .suggestion: return "Suggest a new feature or improvement."
            case .general: return "Ask a general question or share a concern about AppleVis."
            }
        }

        var messagePlaceholder: String {
            switch self {
            case .bug: return "Describe what happened, what you expected, and the steps to reproduce it…"
            case .feedback: return "Share your thoughts about the AppleVis app…"
            case .suggestion: return "Describe your idea and why it would improve the app…"
            case .general: return "Tell us what's on your mind…"
            }
        }

        var icon: String {
            switch self {
            case .bug: return "ladybug"
            case .feedback: return "ellipsis.bubble"
            case .suggestion: return "lightbulb"
            case .general: return "questionmark.circle"
            }
        }

        var color: Color {
            switch self {
            case .bug: return Color(red: 0.937, green: 0.267, blue: 0.267)
            case .feedback: return Color(red: 0.039, green: 0.518, blue: 1.0)
            case .suggestion: return Color(red: 0.063, green: 0.725, blue: 0.506)
            case .general: return Color(red: 0.961, green: 0.620, blue: 0.043)
            }
        }
    }

    private enum Step: Int { case type, details, message, review }

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var guidelines = GuidelinesCheckState()
    @StateObject private var intelligence = ComposeIntelligenceState()
    @StateObject private var domainChecker = EmailDomainChecker()
    @AccessibilityFocusState private var isStepFocused: Bool
    @AccessibilityFocusState private var isErrorFocused: Bool

    /// Lets callers outside RN's own flow (About's "Report a Bug"/"Send
    /// Feedback", which RN just opened in Safari) preselect a type — the
    /// picker still shows so the user can change their mind.
    var initialType: ContactType? = nil

    @State private var step: Step = .type
    @State private var contactType: ContactType?
    @State private var name = ""
    @State private var email = ""
    @State private var message = ""
    @State private var includeSysInfo = false
    @State private var declarationAgreed = false
    @State private var isSubmitting = false
    @State private var submitted = false
    @State private var error: String?
    @State private var showDiscardConfirm = false
    @State private var messageMinimumAnnounced = false
    @State private var showAccountEmailChange = false
    @State private var emailSuggestionDismissed = false

    private var isSignedIn: Bool { auth.isSignedIn }
    private var totalSteps: Int { isSignedIn ? 3 : 4 }
    private var effectiveType: ContactType { contactType ?? .feedback }
    private var displayName: String { isSignedIn ? (auth.user?.name ?? "") : name }

    private func stepNumber(_ s: Step) -> Int {
        switch s {
        case .type: return 1
        case .details: return 2
        case .message: return isSignedIn ? 2 : 3
        case .review: return isSignedIn ? 3 : 4
        }
    }

    private var messageLength: Int { message.trimmingCharacters(in: .whitespacesAndNewlines).count }
    private var detailsValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && email.isValidEmailFormat
    }
    private var messageValid: Bool { messageLength >= 20 }
    private var canSend: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        email.isValidEmailFormat && declarationAgreed && !isSubmitting && networkMonitor.isConnected
    }

    var body: some View {
        NavigationStack {
            Group {
                if submitted {
                    ThankYouView(
                        icon: "envelope",
                        heading: "Message sent!",
                        message: "Thanks for reaching out — we've received your message. We typically reply to urgent issues as soon as possible and routine enquiries within one business day.",
                        doneLabel: "Back to Profile",
                        onDone: { dismiss() }
                    ) {
                        if isSignedIn, !emailSuggestionDismissed,
                           AccountEmailUpdateSuggestion.applies(usedEmail: email, accountEmail: auth.user?.email) {
                            AccountEmailUpdateSuggestion(isDismissed: $emailSuggestionDismissed, showEmailChangeWizard: $showAccountEmailChange)
                        }
                    }
                } else {
                    Form {
                        switch step {
                        case .type:    typeSection
                        case .details: detailsSection
                        case .message: messageSection
                        case .review:  reviewSection
                        }
                        if let error {
                            Section { Text(error).foregroundStyle(.red) }
                        }
                    }
                    .themedList(preferences.colors)
                }
            }
            .navigationTitle("Contact AppleVis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !submitted {
                    // Previously showed "Back" (not "Cancel") on every step
                    // past Contact Type, leaving no way to actually leave
                    // the form from Details, Message, or Review without
                    // stepping backward through every screen first. Cancel
                    // now stays put regardless of step; step-backward
                    // navigation moved to its own in-content button below,
                    // matching Submit App/Blog/Bug/Podcast's existing
                    // convention. Reported directly.
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { requestCancel() }
                            .accessibilityHint(String(localized: "Cancels and closes this form."))
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if step == .review {
                            Button(isSubmitting ? "Sending…" : "Send Message") { Task { await submit() } }
                                .disabled(!canSend)
                                .accessibilityHint(networkMonitor.isConnected ? "" : String(localized: "You're offline. Reconnect to send this."))
                        } else {
                            Button("Next") { goNext() }
                                .disabled(!canGoNext)
                        }
                    }
                }
            }
            .confirmationDialog(
                step == .type ? "Cancel contact?" : "Discard this message?",
                isPresented: $showDiscardConfirm,
                titleVisibility: .visible
            ) {
                Button("Discard", role: .destructive) {
                    SoundPlayer.shared.play(.screenClose)
                    dismiss()
                }
                Button(step == .type ? "Keep Going" : "Keep Editing", role: .cancel) {}
            } message: {
                Text(step == .type ? "Your selections will be discarded." : "Your contact support message will be discarded.")
            }
            .sheet(isPresented: $showAccountEmailChange) {
                AccountSecurityWizard(mode: .email, initialEmail: email)
            }
            .onAppear {
                if name.isEmpty { name = auth.user?.name ?? "" }
                // A signed-in user's account email is already known
                // (AuthUser.email) — no reason to make them retype it. A
                // signed-out guest gets their last-typed email back instead,
                // saved in submit() below, so returning guests don't have to
                // retype it either. Reported directly.
                if email.isEmpty {
                    if isSignedIn {
                        email = auth.user?.email ?? ""
                    } else {
                        email = preferences.lastGuestEmail
                    }
                }
                if contactType == nil { contactType = initialType }
                // Step 1 previously got no explicit focus at all — only
                // goNext()/goBack() ever called focusStepAfterTransition(),
                // so opening this wizard left VoiceOver focus on system
                // default (typically Cancel). Full app-wide focus audit,
                // requested directly.
                focusStepAfterTransition()
            }
        }
    }

    private var canGoNext: Bool {
        switch step {
        case .type: return contactType != nil
        case .details: return detailsValid
        case .message: return messageValid
        case .review: return true
        }
    }

    // MARK: - Step 1: Contact type

    private var typeSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: 1, total: totalSteps, title: "Contact AppleVis", isFocused: $isStepFocused, accentColor: contactType?.color)
                Text("Choose the type of message you'd like to send. This helps us get it to the right team.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section {
                Label("To report an Apple accessibility bug, use Discover → Contribute → Submit a Bug Report.", systemImage: "info.circle")
                    .font(.footnote)
                    .accessibilityLabel(String(localized: "Note: This form contacts the AppleVis team about the app itself. To report an accessibility bug in Apple software, use Discover, then Contribute, then Submit a Bug Report."))
            }
            Section {
                ForEach(ContactType.allCases) { type in
                    typeCard(type)
                }
            }
            Section {
                WizardBlockingNote(reasons: contactType == nil ? [String(localized: "Choose a contact type to continue.")] : [])
                WizardBottomButton(String(localized: "Next"), isEnabled: contactType != nil, action: goNext)
            }
        }
    }

    private func typeCard(_ type: ContactType) -> some View {
        let isSelected = contactType == type
        return Button {
            contactType = type
            SoundPlayer.shared.play(.pickerTick)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: type.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : type.color)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? type.color : type.color.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(type.label).font(.subheadline.bold())
                    Text(type.description).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? type.color : .secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(String(localized: "\(type.label). \(type.description)"))
        .accessibilityHint(type.hint)
    }

    // MARK: - Step 2 (guests only): Your Details

    private var detailsSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: stepNumber(.details), total: totalSteps, title: "Your Details", isFocused: $isStepFocused, accentColor: effectiveType.color)
                backButton
                Text("We need your name and email address so we can reply to you.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section {
                TextField("Full Name or Username", text: $name)
                    .accessibilityHint(String(localized: "Required. Used to address our reply."))
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .accessibilityHint(String(localized: "Required. Used to send you a reply."))
                    .onChange(of: email) { _, newValue in domainChecker.check(email: newValue) }
            } header: {
                Text("Your Details")
            } footer: {
                if !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !email.isValidEmailFormat {
                    Text("Enter a valid email address.")
                } else {
                    EmailDomainWarning(checker: domainChecker)
                }
            }
            Section {
                Text("We only use your email to reply to this message and will not add you to any mailing list.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Your details are only used to reply to this message. AppleVis does not sell or share your personal information.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                WizardBlockingNote(reasons: detailsBlockingReasons)
                WizardBottomButton(String(localized: "Next"), isEnabled: detailsValid, action: goNext)
            }
        }
    }

    private var detailsBlockingReasons: [String] {
        var reasons: [String] = []
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            reasons.append(String(localized: "Enter your name to continue."))
        }
        if !email.isValidEmailFormat {
            reasons.append(String(localized: "Enter a valid email address to continue."))
        }
        return reasons
    }

    // MARK: - Step 2/3: Write your message

    private var messageSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: stepNumber(.message), total: totalSteps, title: "Write your message", isFocused: $isStepFocused, accentColor: effectiveType.color)
                backButton
                Text("You're sending a \(effectiveType.label). Write as much detail as you like.")
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    Label(effectiveType.label, systemImage: effectiveType.icon)
                        .foregroundStyle(effectiveType.color)
                        .font(.subheadline.bold())
                    // Signed-in users skip straight from Type to Message, so
                    // Back already lands on Type — this button would be an
                    // exact duplicate there. Guests have a Details step in
                    // between, where Back only goes one step at a time; this
                    // is the only way to reach Type without a second tap.
                    // Reported directly.
                    if !isSignedIn {
                        Spacer()
                        Button("Change") { step = .type }
                            .font(.caption)
                            .accessibilityLabel(String(localized: "Change contact type"))
                            .accessibilityHint(String(localized: "Goes back to step 1 to change your selection."))
                    }
                }
            }
            if intelligence.showTranslatePrompt {
                Section {
                    TranslatePromptView(isProcessing: intelligence.isProcessing) {
                        Task {
                            if let result = await intelligence.translate(subject: effectiveType.subject, body: message, isTopic: false) {
                                message = result.body
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
                        draftText: message,
                        context: "Contact Us",
                        onDismiss: { guidelines.dismiss() },
                        onRewriteRespectfully: {
                            Task {
                                if let result = await intelligence.rewriteRespectfully(subject: effectiveType.subject, body: message, isTopic: false) {
                                    message = result.body
                                } else {
                                    toast.error(String(localized: "Couldn't rewrite this. Try again."))
                                }
                            }
                        }
                    )
                }
            }
            Section {
                // Previously two separate swipe-stops ("Message", then the
                // counter) ahead of the field itself, on top of the same
                // "minimum 20 characters" already spoken as part of the
                // field's own hint below — three announcements for one
                // fact. Combined into a single live-updating stop here;
                // same fix applied to every other minimum-length field
                // (Description, Blog Draft, Accessibility Comments, etc.)
                // across every wizard. Reported directly.
                HStack {
                    Text("Message").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(messageLength < 20 ? "\(messageLength) / 20 min" : "\(messageLength) chars")
                        .font(.caption)
                        .fontWeight(messageLength < 20 ? .bold : .regular)
                        .foregroundStyle(messageLength < 20 ? .red : .secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(messageLength < 20 ? String(localized: "Message: \(messageLength) of 20 minimum characters") : String(localized: "Message: \(messageLength) characters"))
                .accessibilityAddTraits(.updatesFrequently)
                TextEditor(text: $message)
                    .frame(minHeight: 160)
                    .accessibilityLabel(String(localized: "Message"))
                    .accessibilityHint(String(localized: "Required. Minimum 20 characters. \(effectiveType.messagePlaceholder)"))
                    .onChange(of: message) { _, newValue in
                        handleMessageChange(newValue)
                        guidelines.textChanged(newValue)
                        intelligence.textChanged(
                            newValue,
                            translationEnabled: preferences.composeTranslationEnabled,
                            detectionEnabled: preferences.nonEnglishDetectionEnabled
                        )
                    }
                rewriteButton
            }
            if effectiveType == .bug {
                Section {
                    // Previously appended just two lines (app version, iOS
                    // version) despite the toggle's own label promising
                    // "device info" it never actually sent. Now shares
                    // DiagnosticInfo with About's "Copy Support Info" —
                    // device model, build number, theme, locale, network,
                    // and every accessibility setting (VoiceOver, Reduce
                    // Motion, Dynamic Type, etc.), which matters more here
                    // than almost anywhere else in the app given how many
                    // real bugs are specific to an assistive technology
                    // being on or off. Requested directly.
                    Toggle(isOn: $includeSysInfo) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Include app and device info").font(.subheadline.bold())
                            Text("Appends your app version, device, and accessibility settings (like VoiceOver) to help diagnose the issue.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityHint(String(localized: "Automatically appends your app version, device, and accessibility settings to help diagnose the issue."))
                }
                Section {
                    Label("Tips for a helpful bug report", systemImage: "lightbulb")
                        .font(.caption.bold())
                        .foregroundStyle(effectiveType.color)
                    Text("• Describe the exact steps to reproduce the issue.\n• State what you expected versus what actually happened.\n• Turn on \"Include app and device info\" above to attach your version details.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "Tips for a helpful bug report: describe the exact steps to reproduce the issue, what you expected to happen, and what actually happened. Turn on Include app and device info above to automatically attach your version details."))
            }
            Section {
                WizardBlockingNote(reasons: messageValid ? [] : [String(localized: "Write at least \(20 - messageLength) more character\(20 - messageLength == 1 ? "" : "s") to continue.")])
                WizardBottomButton(String(localized: "Next"), isEnabled: messageValid, action: goNext)
            }
        }
    }

    /// Mirrors RN's crossing-the-threshold announcement so VoiceOver users
    /// learn the moment they can continue, not just via the Next button's
    /// disabled state.
    /// Was a toolbar button under the overflow "More" menu — easy to miss,
    /// and its scope wasn't obvious from a generic toolbar label. Now sits
    /// directly under the field it rewrites, matching Submit App/Blog's
    /// existing pattern. Reported directly.
    @ViewBuilder
    private var rewriteButton: some View {
        if preferences.composeRewriteEnabled && IntelligenceService.isAvailable {
            Button {
                Task {
                    if let result = await intelligence.rewrite(subject: effectiveType.subject, body: message, isTopic: false) {
                        message = result.body
                    } else {
                        toast.error(String(localized: "Couldn't rewrite this. Try again."))
                    }
                }
            } label: {
                Label("Rewrite", systemImage: "wand.and.stars")
            }
            .disabled(message.trimmingCharacters(in: .whitespaces).isEmpty || intelligence.isProcessing)
            .accessibilityHint(String(localized: "Uses Apple Intelligence to suggest a clearer rewrite of this text."))
        }
    }

    private func handleMessageChange(_ newValue: String) {
        let length = newValue.trimmingCharacters(in: .whitespacesAndNewlines).count
        if !messageMinimumAnnounced && length >= 20 {
            messageMinimumAnnounced = true
            UIAccessibility.post(notification: .announcement, argument: "Minimum length reached. You can now continue.")
        } else if messageMinimumAnnounced && length < 20 {
            messageMinimumAnnounced = false
        }
    }

    // MARK: - Final step: Review + Send

    private var reviewSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: stepNumber(.review), total: totalSteps, title: "Review and send", isFocused: $isStepFocused, accentColor: effectiveType.color)
                backButton
                Text("Check your message, then tap Send Message.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if !networkMonitor.isConnected {
                Section {
                    OfflineComposeNotice()
                }
                .listRowSeparator(.hidden)
            }
            Section {
                HStack {
                    Label(effectiveType.label, systemImage: effectiveType.icon)
                        .foregroundStyle(effectiveType.color)
                    Spacer()
                    Button {
                        step = .type
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel(String(localized: "Edit message"))
                    .accessibilityHint(String(localized: "Goes back to edit your message."))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "Contact type: \(effectiveType.label)"))

                WizardReviewRow(label: "Subject", value: effectiveType.subject)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Message preview").font(.caption).foregroundStyle(.secondary)
                    Text(previewMessage)
                    if message.count > 200 {
                        Text("\(message.count) characters total").font(.caption).foregroundStyle(.secondary)
                    }
                    if includeSysInfo && effectiveType == .bug {
                        Text("+ App and device info will be appended")
                            .font(.caption).fontWeight(.semibold).foregroundStyle(effectiveType.color)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            Section("From") {
                if isSignedIn {
                    WizardReviewRow(label: "Name", value: displayName + " (from account)")
                    // Prefilled from AuthUser.email in onAppear above, but
                    // kept editable unlike Name above — a reply email is far
                    // more likely than a display name to be something
                    // someone wants to swap (a personal address instead of
                    // the account's), so locking it read-only the way Name
                    // is would remove a choice with no real benefit. Matches
                    // the same editable-after-prefill pattern already used
                    // in Submit Bug Report, Submit Blog, and Report a
                    // Comment. Reported directly.
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .accessibilityLabel(String(localized: "Email address"))
                        .accessibilityHint(String(localized: "Required. We will use this address to reply to you."))
                        .onChange(of: email) { _, newValue in domainChecker.check(email: newValue) }
                    EmailDomainWarning(checker: domainChecker)
                } else {
                    WizardReviewRow(label: "Name", value: name.isEmpty ? "No name entered" : name)
                    WizardReviewRow(label: "Email", value: email.isEmpty ? "No email entered" : email)
                }
            }

            Section {
                Button {
                    declarationAgreed.toggle()
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: declarationAgreed ? "checkmark.square.fill" : "square")
                            .foregroundStyle(declarationAgreed ? effectiveType.color : .secondary)
                        Text("I confirm this is a genuine message — not sponsored content, advertising, an SEO submission, or any other paid proposal.")
                            .font(.footnote)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(String(localized: "Declaration"))
                .accessibilityHint(String(localized: "I confirm this is a genuine message, not sponsored content, advertising, an SEO submission, or any other paid proposal."))
                .accessibilityValue(declarationAgreed ? "Checked" : "Unchecked")
            }
            Section {
                WizardBlockingNote(reasons: reviewBlockingReasons)
                WizardBottomButton(
                    isSubmitting ? String(localized: "Sending…") : String(localized: "Send Message"),
                    isEnabled: canSend
                ) { Task { await submit() } }
            }
        }
    }

    private var reviewBlockingReasons: [String] {
        var reasons: [String] = []
        if !email.isValidEmailFormat {
            reasons.append(String(localized: "Enter a valid email address to continue."))
        }
        if !declarationAgreed {
            reasons.append(String(localized: "Confirm the declaration above to continue."))
        }
        return reasons
    }

    private var previewMessage: String {
        message.count > 200 ? String(message.prefix(200)) + "…" : message
    }

    // MARK: - Navigation

    private func goNext() {
        SoundPlayer.shared.play(.pickerTick)
        switch step {
        case .type:    step = isSignedIn ? .message : .details
        case .details: step = .message
        case .message: step = .review
        case .review:  break
        }
        focusStepAfterTransition()
    }

    private func goBack() {
        SoundPlayer.shared.play(.pickerTick)
        switch step {
        case .type:    break
        case .details: step = .type
        case .message: step = isSignedIn ? .type : .details
        case .review:  step = .message
        }
        focusStepAfterTransition()
    }

    private func requestCancel() {
        if contactType == nil && message.trimmingCharacters(in: .whitespaces).isEmpty {
            SoundPlayer.shared.play(.screenClose)
            dismiss()
        } else {
            showDiscardConfirm = true
        }
    }

    /// Moves VoiceOver focus to the new step's heading — previously Next/Back
    /// only played a sound, leaving focus on the previous step's now-gone
    /// controls with nothing announcing the step actually changed. Delayed
    /// since setting focus before the new section has laid out is a common
    /// way for it to silently fail.
    /// Was a single guessed 300ms delay — see SubmitAppView's identical fix
    /// for the full reasoning. Full app-wide focus audit, requested
    /// directly.
    private func focusStepAfterTransition() {
        Task { await retryAccessibilityFocus(into: $isStepFocused) }
    }

    /// Step-backward navigation, separated from the toolbar's Cancel button
    /// so a user can discard the message from any step.
    private var backButton: some View {
        Button {
            goBack()
        } label: {
            Label("Back", systemImage: "chevron.backward")
        }
    }

    private func submit() async {
        guard canSend else { return }
        if let policyMessage = ContentSubmissionPolicy.blockingMessage(
            subject: effectiveType.subject,
            body: message
        ) {
            error = policyMessage
            await announceWizardFailure(policyMessage, focus: $isErrorFocused)
            return
        }
        isSubmitting = true; error = nil
        UIAccessibility.post(notification: .announcement, argument: "Sending your message…")

        var finalMessage = message
        if includeSysInfo && effectiveType == .bug {
            finalMessage += "\n\n" + DiagnosticInfo.report(
                themeDisplayName: preferences.theme.displayName,
                isConnected: networkMonitor.isConnected,
                dynamicTypeSize: dynamicTypeSize,
                isSignedIn: auth.isSignedIn,
                isEditor: auth.user?.isAdmin ?? false
            )
        }

        let result = await DrupalFormClient.submitContact(
            name: displayName.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces),
            subject: effectiveType.subject,
            message: finalMessage
        )
        switch result {
        case .ok:
            SoundPlayer.shared.play(.success)
            UIAccessibility.post(notification: .announcement, argument: "Message sent successfully.")
            if !isSignedIn {
                preferences.lastGuestEmail = email.trimmingCharacters(in: .whitespaces)
            }
            submitted = true
        case .failure(let message):
            error = message + "\n\nYou can also contact us at applevis.com/contact."
        }
        isSubmitting = false
    }
}
