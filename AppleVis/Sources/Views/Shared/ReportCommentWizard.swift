import SwiftUI

/// Everything the wizard needs to know about the comment being reported —
/// gathered by the caller (AppReviewRow/ReplyView/CommentRow) from data it
/// already has, since none of those rows carry a reliable comment permalink
/// (their `id` is a JSON:API UUID, not the integer cid Drupal's `/comment/
/// {cid}` URLs need). The parent content's own URL plus an excerpt/author/
/// date let a human find the comment quickly without a guessed-and-possibly-
/// wrong deep link.
struct ReportCommentContext {
    let authorName: String
    let commentExcerpt: String
    let commentDate: Date
    let contentTitle: String
    let contentURL: String
}

extension ReportCommentContext {
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
    }

    private enum Step: Int { case reason, details, review }

    let context: ReportCommentContext

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss
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

    private let totalSteps = 3
    private var isSignedIn: Bool { auth.isSignedIn }
    private var effectiveReason: Reason { reason ?? .other }
    private var displayName: String { isSignedIn ? (auth.user?.name ?? "") : name }

    private func stepNumber(_ s: Step) -> Int { s.rawValue + 1 }

    private var detailsValid: Bool {
        let nameOK = isSignedIn || !name.trimmingCharacters(in: .whitespaces).isEmpty
        return nameOK && email.contains("@")
    }
    private var canSend: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty && email.contains("@") && !isSubmitting
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
                        message: "Thanks for helping keep AppleVis welcoming. The editorial team will review this comment and follow up by email if needed.",
                        doneLabel: "Done",
                        onDone: { dismiss() }
                    )
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
            .navigationTitle("Report Comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !submitted {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(step == .reason ? "Cancel" : "Back") {
                            if step == .reason { requestCancel() } else { goBack() }
                        }
                        .accessibilityHint(step == .reason
                            ? String(localized: "Cancels and closes this report.")
                            : String(localized: "Returns to the previous step."))
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
            .onAppear {
                if name.isEmpty { name = auth.user?.name ?? "" }
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
        }
    }

    private var reportedCommentPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Reporting a comment by \(context.authorName)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(context.commentExcerpt)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(3)
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
                    Text(r.label).font(.subheadline.bold())
                    Text(r.description).font(.caption).foregroundStyle(.secondary)
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
        .accessibilityLabel(String(localized: "\(r.label). \(r.description)"))
    }

    // MARK: - Step 2: Details + contact info

    private var detailsSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: stepNumber(.details), total: totalSteps, title: "Add any details", isFocused: $isStepFocused, accentColor: .red)
                Text("Anything else that would help the editorial team review this is optional but appreciated.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Additional Details") {
                TextEditor(text: $details)
                    .frame(minHeight: 120)
                    .accessibilityLabel(String(localized: "Additional details"))
                    .accessibilityHint(String(localized: "Optional."))
            }
            if !isSignedIn {
                Section("Your Name") {
                    TextField("Full Name or Username", text: $name)
                        .accessibilityHint(String(localized: "Required."))
                }
            }
            Section("Your Email") {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .accessibilityHint(String(localized: "Required. Used only if the editorial team needs to follow up."))
            }
        }
    }

    // MARK: - Step 3: Review + Send

    private var reviewSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: stepNumber(.review), total: totalSteps, title: "Review and send", isFocused: $isStepFocused, accentColor: .red)
                Text("Check your report, then tap Send Report.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    Label(effectiveReason.label, systemImage: effectiveReason.icon)
                        .foregroundStyle(.red)
                    Spacer()
                    Button { step = .reason } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel(String(localized: "Edit reason"))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "Reason: \(effectiveReason.label)"))

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

    private func focusStepAfterTransition() {
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            isStepFocused = true
        }
    }

    private var composedMessage: String {
        var lines = [
            "Reason: \(effectiveReason.label)",
            "",
            "Reported comment by: \(context.authorName)",
            "Posted: \(context.commentDate.formatted(date: .abbreviated, time: .shortened))",
            "On: \(context.contentTitle)",
        ]
        if !context.contentURL.isEmpty { lines.append("Link: \(context.contentURL)") }
        lines.append("")
        lines.append("Comment excerpt:")
        lines.append("\"\(context.commentExcerpt)\"")
        lines.append("")
        lines.append("Reporter's additional details:")
        lines.append(details.trimmingCharacters(in: .whitespaces).isEmpty ? "(none provided)" : details)
        lines.append("")
        lines.append("— Sent via the AppleVis app's Report Comment feature.")
        return lines.joined(separator: "\n")
    }

    private func submit() async {
        guard canSend else { return }
        isSubmitting = true; error = nil
        UIAccessibility.post(notification: .announcement, argument: "Sending your report…")

        let result = await DrupalFormClient.submitContact(
            name: displayName.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces),
            subject: "Comment Report: \(effectiveReason.label)",
            message: composedMessage
        )
        switch result {
        case .ok:
            SoundPlayer.shared.play(.success)
            UIAccessibility.post(notification: .announcement, argument: "Report sent successfully.")
            submitted = true
        case .failure(let message):
            let fullMessage = message + "\n\nYou can also report this at applevis.com/contact."
            error = fullMessage
            await announceWizardFailure(fullMessage, focus: $isErrorFocused)
        }
        isSubmitting = false
    }
}
