import SwiftUI

/// Everything the wizard needs to know about the comment being reported —
/// gathered by the caller (AppReviewRow/ReplyView/CommentRow) from data it
/// already has, since none of those rows carry a reliable comment permalink
/// (their `id` is a JSON:API UUID, not the integer cid Drupal's `/comment/
/// {cid}` URLs need). The parent content's own URL plus an excerpt/author/
/// date let a human find the comment quickly without a guessed-and-possibly-
/// wrong deep link.
struct ReportCommentContext {
    /// What's being reported, used to build "Reporting a comment by X" /
    /// "Reporting a topic by X" and the navigation title/email subject —
    /// singular, lowercase (e.g. "comment", "topic", "app entry", "episode",
    /// "blog post", "guide", "bug report"). Defaults to "comment" so every
    /// existing call site (reporting a comment/reply/review) keeps working
    /// unchanged; `DetailActionsMenu` passes the primary content's own kind
    /// when reporting a topic/entry itself rather than a comment on it.
    var subjectKind: String = "comment"
    /// Empty when there's no reliable author to show (e.g. a Podcast
    /// Episode has no author identity) — the preview then reads "Reporting
    /// this episode" instead of "... by X".
    let authorName: String
    let commentExcerpt: String
    let commentDate: Date
    let contentTitle: String
    let contentURL: String
}

extension String {
    /// Strips HTML and truncates a raw comment body down to something
    /// short enough to quote in a report without dumping the whole thread
    /// post into an email.
    static func excerpt(from html: String, limit: Int = 300) -> String {
        let stripped = html.strippingHTMLTags().trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.count > limit ? String(stripped.prefix(limit)) + "…" : stripped
    }
}

/// "Report this comment," for now, routes through the same `/contact`
/// Drupal webform every other in-app contact flow uses (see
/// `DrupalFormClient.submitContact`) — there's no dedicated Flags-based
/// report API yet (see the "Reporting is coming once the Drupal Flags API
/// is confirmed" placeholder this wizard replaces). Once that API exists,
/// only `submit()` needs to change; the wizard UI stays the same.
struct ReportCommentWizard: View {
    enum Reason: String, CaseIterable, Identifiable {
        case spam, harassment, inappropriate, offTopic, misinformation, other
        var id: Self { self }

        var label: String {
            switch self {
            case .spam: return "Spam or Advertising"
            case .harassment: return "Harassment or Abuse"
            case .inappropriate: return "Inappropriate or Offensive Content"
            case .offTopic: return "Off-Topic"
            case .misinformation: return "Misinformation"
            case .other: return "Something Else"
            }
        }

        var description: String {
            switch self {
            case .spam: return "Unsolicited advertising, links, or repeated promotional content."
            case .harassment: return "Targets, threatens, or demeans a specific person."
            case .inappropriate: return "Contains offensive, explicit, or otherwise inappropriate content."
            case .offTopic: return "Doesn't relate to the discussion it was posted in."
            case .misinformation: return "States something false or misleading as fact."
            case .other: return "Doesn't fit the categories above."
            }
        }

        var icon: String {
            switch self {
            case .spam: return "exclamationmark.triangle"
            case .harassment: return "hand.raised.slash"
            case .inappropriate: return "eye.slash"
            case .offTopic: return "arrow.triangle.branch"
            case .misinformation: return "questionmark.circle"
            case .other: return "ellipsis.circle"
            }
        }

        /// `label`/`description` above are plain String, so Text(_:String)
        /// and Label(_:S, systemImage:) both display them verbatim, skipping
        /// catalog lookup entirely — same bug as WizardStepIndicator/
        /// WizardReviewRow. These resolve them explicitly for call sites
        /// (accessibility labels, the composed report body) that need the
        /// actual localized text rather than a SwiftUI view.
        var localizedLabel: String { String(localized: String.LocalizationValue(label)) }
        var localizedDescription: String { String(localized: String.LocalizationValue(description)) }
    }

    private enum Step: Int { case reason, details, review }

    let context: ReportCommentContext

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var domainChecker = EmailDomainChecker()
    @AccessibilityFocusState private var isStepFocused: Bool
    @AccessibilityFocusState private var isErrorFocused: Bool

    @State private var step: Step = .reason
    @State private var reason: Reason?
    @State private var name = ""
    @State private var email = ""
    @State private var details = ""
    @State private var isSubmitting = false
    @State private var submitted = false
    @State private var error: String?
    @State private var showDiscardConfirm = false
    @State private var showAccountEmailChange = false
    @State private var emailSuggestionDismissed = false

    private let totalSteps = 3
    private var isSignedIn: Bool { auth.isSignedIn }
    private var effectiveReason: Reason { reason ?? .other }
    private var displayName: String { isSignedIn ? (auth.user?.name ?? "") : name }
    private var navigationTitleText: String { String(localized: "Report \(context.subjectKind.capitalized)") }
    private var reportedSubjectText: String {
        context.authorName.isEmpty
            ? String(localized: "Reporting this \(context.subjectKind)")
            : String(localized: "Reporting a \(context.subjectKind) by \(context.authorName)")
    }

    private func stepNumber(_ s: Step) -> Int { s.rawValue + 1 }

    private var detailsValid: Bool {
        let nameOK = isSignedIn || !name.trimmingCharacters(in: .whitespaces).isEmpty
        return nameOK && email.isValidEmailFormat
    }
    private var canSend: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty && email.isValidEmailFormat && !isSubmitting
    }
    private var canGoNext: Bool {
        switch step {
        case .reason: return reason != nil
        case .details: return detailsValid
        case .review: return true
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if submitted {
                    ThankYouView(
                        icon: "flag",
                        heading: "Report sent!",
                        message: String(localized: "Thanks for helping keep AppleVis welcoming. The editorial team will review this \(context.subjectKind) and follow up by email if needed."),
                        doneLabel: "Done",
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
                        case .reason:  reasonSection
                        case .details: detailsSection
                        case .review:  reviewSection
                        }
                        if let error {
                            Section { Text(error).foregroundStyle(.red) }
                        }
                    }
                    .themedList(preferences.colors)
                }
            }
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !submitted {
                    // Previously showed "Back" (not "Cancel") on every step
                    // past Reason, leaving no way to actually leave the
                    // wizard from Details or Review without stepping
                    // backward first. Cancel now stays put regardless of
                    // step; step-backward navigation moved to its own
                    // in-content button below, matching every other
                    // wizard's convention. Reported directly.
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { requestCancel() }
                            .accessibilityHint(String(localized: "Cancels and closes this report."))
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if step == .review {
                            Button(isSubmitting ? "Sending…" : "Send Report") { Task { await submit() } }
                                .disabled(!canSend)
                        } else {
                            Button("Next") { goNext() }
                                .disabled(!canGoNext)
                        }
                    }
                }
            }
            .disabled(isSubmitting)
            .confirmationDialog(
                "Discard this report?", isPresented: $showDiscardConfirm, titleVisibility: .visible
            ) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Going", role: .cancel) {}
            } message: {
                Text("Your report will not be sent.")
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
                // retype it either. Matches the same fix in ContactView.
                if email.isEmpty {
                    if isSignedIn {
                        email = auth.user?.email ?? ""
                    } else {
                        email = preferences.lastGuestEmail
                    }
                }
                // Step 1 previously got no explicit focus at all — only
                // goNext()/goBack() ever called focusStepAfterTransition(),
                // so opening this wizard left VoiceOver focus on system
                // default (typically Cancel). Full app-wide focus audit,
                // requested directly.
                focusStepAfterTransition()
            }
        }
    }

    // MARK: - Step 1: Reason

    private var reasonSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: 1, total: totalSteps, title: "Why are you reporting this?", isFocused: $isStepFocused, accentColor: .red)
                Text("Choose the option that best describes the problem.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section {
                reportedCommentPreview
            }
            Section {
                ForEach(Reason.allCases) { r in
                    reasonCard(r)
                }
            }
            Section {
                WizardBlockingNote(reasons: reason == nil ? [String(localized: "Choose a reason to continue.")] : [])
                WizardBottomButton(String(localized: "Next"), isEnabled: reason != nil, action: goNext)
            }
        }
    }

    private var reportedCommentPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(reportedSubjectText)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if !context.commentExcerpt.isEmpty {
                Text(context.commentExcerpt)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func reasonCard(_ r: Reason) -> some View {
        let isSelected = reason == r
        return Button {
            reason = r
            SoundPlayer.shared.play(.pickerTick)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: r.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : .red)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Color.red : Color.red.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey(r.label)).font(.subheadline.bold())
                    Text(LocalizedStringKey(r.description)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.red : .secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(String(localized: "\(r.localizedLabel). \(r.localizedDescription)"))
    }

    // MARK: - Step 2: Details + contact info

    private var detailsSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: stepNumber(.details), total: totalSteps, title: "Add any details", isFocused: $isStepFocused, accentColor: .red)
                backButton
                Text("Anything else that would help the editorial team review this is optional but appreciated.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Additional Details") {
                TextEditor(text: $details)
                    .frame(minHeight: 120)
                    .accessibilityLabel(String(localized: "Additional details"))
                    .accessibilityHint(String(localized: "Optional. Anything that would help our editorial team understand what's wrong here — extra context is always appreciated, but never required."))
            }
            if !isSignedIn {
                Section("Your Name") {
                    TextField("Full Name or Username", text: $name)
                        .accessibilityHint(String(localized: "Required."))
                }
            }
            Section {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .accessibilityHint(String(localized: "Required. Used only if the editorial team needs to follow up."))
                    .onChange(of: email) { _, newValue in domainChecker.check(email: newValue) }
            } header: {
                Text("Your Email")
            } footer: {
                if !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !email.isValidEmailFormat {
                    Text("Enter a valid email address.")
                } else {
                    EmailDomainWarning(checker: domainChecker)
                }
            }
            Section {
                WizardBlockingNote(reasons: detailsBlockingReasons)
                WizardBottomButton(String(localized: "Next"), isEnabled: detailsValid, action: goNext)
            }
        }
    }

    private var detailsBlockingReasons: [String] {
        var reasons: [String] = []
        if !isSignedIn && name.trimmingCharacters(in: .whitespaces).isEmpty {
            reasons.append(String(localized: "Enter your name to continue."))
        }
        if !email.isValidEmailFormat {
            reasons.append(String(localized: "Enter a valid email address to continue."))
        }
        return reasons
    }

    // MARK: - Step 3: Review + Send

    private var reviewSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: stepNumber(.review), total: totalSteps, title: "Review and send", isFocused: $isStepFocused, accentColor: .red)
                backButton
                Text("Check your report, then tap Send Report.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    Label(LocalizedStringKey(effectiveReason.label), systemImage: effectiveReason.icon)
                        .foregroundStyle(.red)
                    Spacer()
                    Button { step = .reason } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel(String(localized: "Edit reason"))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "Reason: \(effectiveReason.localizedLabel)"))

                WizardReviewRow(label: "Comment by", value: context.authorName)
                WizardReviewRow(label: "On", value: context.contentTitle)
                if !details.trimmingCharacters(in: .whitespaces).isEmpty {
                    WizardReviewRow(label: "Additional details", value: details)
                }
            }
            Section("From") {
                WizardReviewRow(label: "Name", value: isSignedIn ? displayName + " (from account)" : name)
                WizardReviewRow(label: "Email", value: email)
            }
            Section {
                WizardBlockingNote(reasons: email.isValidEmailFormat ? [] : [String(localized: "Enter a valid email address to continue.")])
                WizardBottomButton(
                    isSubmitting ? String(localized: "Sending…") : String(localized: "Send Report"),
                    isEnabled: canSend
                ) { Task { await submit() } }
            }
        }
    }

    // MARK: - Navigation

    private func goNext() {
        SoundPlayer.shared.play(.pickerTick)
        switch step {
        case .reason:  step = .details
        case .details: step = .review
        case .review:  break
        }
        focusStepAfterTransition()
    }

    private func goBack() {
        SoundPlayer.shared.play(.pickerTick)
        switch step {
        case .reason:  break
        case .details: step = .reason
        case .review:  step = .details
        }
        focusStepAfterTransition()
    }

    private func requestCancel() {
        if reason == nil && details.trimmingCharacters(in: .whitespaces).isEmpty {
            SoundPlayer.shared.play(.screenClose)
            dismiss()
        } else {
            showDiscardConfirm = true
        }
    }

    /// Was a single guessed 300ms delay — see SubmitAppView's identical fix
    /// for the full reasoning. Full app-wide focus audit, requested
    /// directly.
    private func focusStepAfterTransition() {
        Task { await retryAccessibilityFocus(into: $isStepFocused) }
    }

    /// Step-backward navigation, separated from the toolbar's Cancel button
    /// so a user can discard the report from any step.
    private var backButton: some View {
        Button {
            goBack()
        } label: {
            Label("Back", systemImage: "chevron.backward")
        }
    }

    private var composedMessage: String {
        var lines = [
            "Reason: \(effectiveReason.label)",
            "",
            context.authorName.isEmpty
                ? "Reported \(context.subjectKind): \(context.contentTitle)"
                : "Reported \(context.subjectKind) by: \(context.authorName)",
            "Posted: \(context.commentDate.formatted(date: .abbreviated, time: .shortened))",
            "On: \(context.contentTitle)",
        ]
        if !context.contentURL.isEmpty { lines.append("Link: \(context.contentURL)") }
        if !context.commentExcerpt.isEmpty {
            lines.append("")
            lines.append("Excerpt:")
            lines.append("\"\(context.commentExcerpt)\"")
        }
        lines.append("")
        lines.append("Reporter's additional details:")
        lines.append(details.trimmingCharacters(in: .whitespaces).isEmpty ? "(none provided)" : details)
        lines.append("")
        lines.append("— Sent via the AppleVis app's Report feature.")
        return lines.joined(separator: "\n")
    }

    private func submit() async {
        guard canSend else { return }
        isSubmitting = true; error = nil
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Sending your report…"))

        let result = await DrupalFormClient.submitContact(
            name: displayName.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces),
            subject: "\(context.subjectKind.capitalized) Report: \(effectiveReason.label)",
            message: composedMessage
        )
        switch result {
        case .ok:
            SoundPlayer.shared.play(.success)
            UIAccessibility.post(notification: .announcement, argument: String(localized: "Report sent successfully."))
            if !isSignedIn {
                preferences.lastGuestEmail = email.trimmingCharacters(in: .whitespaces)
            }
            submitted = true
        case .failure(let message):
            let fullMessage = message + "\n\nYou can also report this at applevis.com/contact."
            error = fullMessage
            await announceWizardFailure(fullMessage, focus: $isErrorFocused)
        }
        isSubmitting = false
    }
}
