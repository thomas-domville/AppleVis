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
        case bug, feedback, suggestion, recommendation
        var id: String { rawValue }

        var label: String {
            switch self {
            case .bug: return "Bug Report"
            case .feedback: return "Feedback"
            case .suggestion: return "Suggestion"
            case .recommendation: return "Recommendation"
            }
        }

        var subject: String {
            switch self {
            case .bug: return "App Bug Report"
            case .feedback: return "App Feedback"
            case .suggestion: return "App Suggestion"
            case .recommendation: return "App Recommendation"
            }
        }

        var description: String {
            switch self {
            case .bug: return "Something in the app is broken or not working as expected."
            case .feedback: return "Share your thoughts, reactions, or general impressions about the app."
            case .suggestion: return "An idea to make the app better — a feature, improvement, or change."
            case .recommendation: return "Suggest a resource, podcast, app entry, blog topic, or piece of content."
            }
        }

        var hint: String {
            switch self {
            case .bug: return "Report a technical problem with the AppleVis app."
            case .feedback: return "Tell us what you think about the app."
            case .suggestion: return "Suggest a new feature or improvement."
            case .recommendation: return "Recommend content or resources for the AppleVis community."
            }
        }

        var messagePlaceholder: String {
            switch self {
            case .bug: return "Describe what happened, what you expected, and the steps to reproduce it…"
            case .feedback: return "Share your thoughts about the AppleVis app…"
            case .suggestion: return "Describe your idea and why it would improve the app…"
            case .recommendation: return "Tell us what you would like to see in AppleVis…"
            }
        }

        var icon: String {
            switch self {
            case .bug: return "ladybug"
            case .feedback: return "ellipsis.bubble"
            case .suggestion: return "lightbulb"
            case .recommendation: return "star"
            }
        }

        var color: Color {
            switch self {
            case .bug: return Color(red: 0.937, green: 0.267, blue: 0.267)
            case .feedback: return Color(red: 0.039, green: 0.518, blue: 1.0)
            case .suggestion: return Color(red: 0.063, green: 0.725, blue: 0.506)
            case .recommendation: return Color(red: 0.961, green: 0.620, blue: 0.043)
            }
        }
    }

    private enum Step: Int { case type, details, message, review }

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var guidelines = GuidelinesCheckState()
    @StateObject private var intelligence = ComposeIntelligenceState()
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
        !name.trimmingCharacters(in: .whitespaces).isEmpty && email.contains("@")
    }
    private var messageValid: Bool { messageLength >= 20 }
    private var canSend: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        email.contains("@") && declarationAgreed && !isSubmitting
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
                    )
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
                    if step == .message && preferences.composeRewriteEnabled && IntelligenceService.isAvailable {
                        ToolbarItem(placement: .secondaryAction) {
                            Button("Rewrite") {
                                Task {
                                    if let result = await intelligence.rewrite(subject: effectiveType.subject, body: message, isTopic: false) {
                                        message = result.body
                                    } else {
                                        toast.error(String(localized: "Couldn't rewrite this. Try again."))
                                    }
                                }
                            }
                            .disabled(message.trimmingCharacters(in: .whitespaces).isEmpty || intelligence.isProcessing)
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if step == .review {
                            Button(isSubmitting ? "Sending…" : "Send Message") { Task { await submit() } }
                                .disabled(!canSend)
                        } else {
                            Button(step == .message ? "Continue to Review" : "Next") { goNext() }
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
            .onAppear {
                if name.isEmpty { name = auth.user?.name ?? "" }
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
            Section("Your Details") {
                TextField("Full Name or Username", text: $name)
                    .accessibilityHint(String(localized: "Required. Used to address our reply."))
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .accessibilityHint(String(localized: "Required. Used to send you a reply."))
            }
            Section {
                Text("We only use your email to reply to this message and will not add you to any mailing list.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Your details are only used to reply to this message. AppleVis does not sell or share your personal information.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
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
                    Spacer()
                    Button("Change") { step = .type }
                        .font(.caption)
                        .accessibilityLabel(String(localized: "Change contact type"))
                        .accessibilityHint(String(localized: "Goes back to step 1 to change your selection."))
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
                HStack {
                    Text("Message").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(messageLength < 20 ? "\(messageLength) / 20 min" : "\(messageLength) chars")
                        .font(.caption)
                        .fontWeight(messageLength < 20 ? .bold : .regular)
                        .foregroundStyle(messageLength < 20 ? .red : .secondary)
                        .accessibilityLabel(messageLength < 20 ? String(localized: "\(messageLength) of 20 minimum characters") : String(localized: "\(messageLength) characters"))
                }
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
            }
            if effectiveType == .bug {
                Section {
                    Toggle(isOn: $includeSysInfo) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Include app and device info").font(.subheadline.bold())
                            Text("Appends your app version and iOS version to help diagnose the issue.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityHint(String(localized: "Automatically appends your app version and iOS version to help diagnose the issue."))
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
        }
    }

    /// Mirrors RN's crossing-the-threshold announcement so VoiceOver users
    /// learn the moment they can continue, not just via the Next button's
    /// disabled state.
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
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .accessibilityLabel(String(localized: "Email address"))
                        .accessibilityHint(String(localized: "Required. We will use this address to reply to you."))
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
                        Text("I understand that AppleVis does not accept sponsored posts/content, advertising, SEO, or any other type of paid proposals.")
                            .font(.footnote)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(String(localized: "Declaration"))
                .accessibilityHint(String(localized: "I understand that AppleVis does not accept sponsored posts or content, advertising, SEO, or any other type of paid proposals."))
                .accessibilityValue(declarationAgreed ? "Checked" : "Unchecked")
            }
        }
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
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
            finalMessage += "\n\n--- App Info ---\nApp Version: AppleVis \(version)\nPlatform: iOS \(UIDevice.current.systemVersion)"
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
            submitted = true
        case .failure(let message):
            error = message + "\n\nYou can also contact us at applevis.com/contact."
        }
        isSubmitting = false
    }
}
