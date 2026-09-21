import SwiftUI
import Combine

/// Dismissible advisory banner shown while composing, when the draft text
/// trips one of the AppleVis posting-guideline checks. Never blocks posting.
struct GuidelinesReminderView: View {
    let warning: GuidelineWarning
    /// The actual draft text this warning fired on — included in a false-
    /// positive report so the editorial team can see exactly what tripped
    /// the rule, not just which rule it was.
    let draftText: String
    /// Short, human-readable label for where this banner is showing (e.g.
    /// "Forum Topic", "Contact Us") — included in a false-positive report
    /// for the same reason.
    let context: String
    let onDismiss: () -> Void
    let onRewriteRespectfully: (() -> Void)?

    init(warning: GuidelineWarning, draftText: String, context: String, onDismiss: @escaping () -> Void) {
        self.warning = warning
        self.draftText = draftText
        self.context = context
        self.onDismiss = onDismiss
        self.onRewriteRespectfully = nil
    }

    init(warning: GuidelineWarning, draftText: String, context: String, onDismiss: @escaping () -> Void, onRewriteRespectfully: @escaping () -> Void) {
        self.warning = warning
        self.draftText = draftText
        self.context = context
        self.onDismiss = onDismiss
        self.onRewriteRespectfully = onRewriteRespectfully
    }

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @State private var isReportingFalsePositive = false
    @State private var hasReportedFalsePositive = false

    private static let guidelinesURL = URL(string: "https://www.applevis.com/help/guidelines")!

    private var config: (bg: Color, border: Color, text: Color, button: Color, label: String) {
        switch warning.severity {
        case .high:
            return (Color(red: 1.0, green: 0.941, blue: 0.941), Color(red: 0.988, green: 0.647, blue: 0.647),
                    Color(red: 0.600, green: 0.106, blue: 0.106), Color(red: 0.725, green: 0.110, blue: 0.110), "Guideline reminder")
        case .medium:
            return (Color(red: 1.0, green: 0.984, blue: 0.922), Color(red: 0.988, green: 0.827, blue: 0.302),
                    Color(red: 0.573, green: 0.251, blue: 0.055), Color(red: 0.706, green: 0.325, blue: 0.035), "Guideline reminder")
        case .low:
            return (Color(red: 0.941, green: 0.976, blue: 1.0), Color(red: 0.729, green: 0.902, blue: 0.992),
                    Color(red: 0.047, green: 0.290, blue: 0.431), Color(red: 0.020, green: 0.412, blue: 0.631), "Friendly tip")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(config.label): \(warning.rule)")
                    .font(.caption).fontWeight(.bold)
                    .foregroundStyle(config.text)
                Text(warning.message)
                    .font(.subheadline)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "\(config.label): \(warning.rule). \(warning.message)"))

            HStack(spacing: 10) {
                if warning.isToneConcern, let onRewriteRespectfully, IntelligenceService.isAvailable {
                    Button(action: onRewriteRespectfully) {
                        Text("Rewrite Respectfully")
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(config.button, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityHint(String(localized: "Rewrites this draft in a more respectful tone."))
                }

                Button(action: onDismiss) {
                    Text("Got It")
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(config.button, in: RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityHint(String(localized: "Dismisses this reminder."))

                WebLink(destination: Self.guidelinesURL) {
                    Text("View Guidelines")
                        .fontWeight(.semibold)
                        .foregroundStyle(config.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(config.border, lineWidth: 1.5))
                }
                .accessibilityHint(String(localized: "Opens the AppleVis guidelines page in Safari."))
            }

            // Guest composers (Contact Us) have no account email to attach
            // a report to, so this stays signed-in only rather than adding
            // a whole extra guest-details capture just for this. A visible,
            // persistent confirmation replaces the button after a
            // successful report — not just a toast — so it's still clear
            // something happened to anyone who missed it. Requested
            // directly.
            if auth.isSignedIn {
                if hasReportedFalsePositive {
                    Label("Reported — thanks for the feedback.", systemImage: "checkmark.circle.fill")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(config.text)
                        .accessibilityElement(children: .combine)
                } else {
                    Button(action: reportFalsePositive) {
                        if isReportingFalsePositive {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Reporting…")
                            }
                        } else {
                            Text("This Doesn't Seem Right")
                        }
                    }
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(config.text)
                    .disabled(isReportingFalsePositive)
                    .accessibilityHint(String(localized: "Reports this warning to the AppleVis editorial team as a possible false positive."))
                }
            }
        }
        .padding(14)
        .background(config.bg, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(config.border, lineWidth: 1.5))
    }

    private func reportFalsePositive() {
        guard let user = auth.user, let email = user.email, !isReportingFalsePositive else { return }
        isReportingFalsePositive = true
        Task {
            let ok = await GuidelineFalsePositiveReporter.report(
                warning: warning, draftText: draftText, context: context,
                reporterName: user.name, reporterEmail: email
            )
            isReportingFalsePositive = false
            if ok {
                hasReportedFalsePositive = true
                SoundPlayer.shared.play(.success)
                toast.success(String(localized: "Thanks — reported to our editorial team."))
                UIAccessibility.post(notification: .announcement, argument: "Thanks — reported to our editorial team.")
            } else {
                toast.error(String(localized: "Couldn't send that report. Try again."))
            }
        }
    }
}

/// Debounced guideline-check state for a compose screen. Rule-based checks
/// fire ~1.5s after the user stops typing; dismissed warnings won't reappear
/// this session.
@MainActor
final class GuidelinesCheckState: ObservableObject {
    @Published private(set) var topWarning: GuidelineWarning?

    private var dismissedIds: Set<String> = []
    private var lastAnnouncedId: String?
    private var checkTask: Task<Void, Never>?

    /// `isReply` — see `GuidelinesChecker.check(_:isReply:)`'s doc comment;
    /// forwarded as-is, defaulting to false (a new topic/post/entry).
    func textChanged(_ text: String, isReply: Bool = false) {
        checkTask?.cancel()
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 else {
            topWarning = nil
            return
        }
        checkTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled, let self else { return }
            var visible = GuidelinesChecker.check(text, isReply: isReply).filter { !self.dismissedIds.contains($0.id) }
            // AI-assisted second pass — existed but was never called
            // anywhere. Only runs when the rule-based check found nothing,
            // matching its own doc comment ("only flags obvious violations
            // the rules missed"), so a rule hit isn't delayed by an extra
            // on-device model round-trip.
            if visible.isEmpty && IntelligenceService.isAvailable {
                let aiWarnings = await IntelligenceService.checkAgainstGuidelinesAI(text)
                guard !Task.isCancelled else { return }
                visible = aiWarnings.filter { !self.dismissedIds.contains($0.id) }
            }
            self.topWarning = visible.first
            if let top = visible.first, top.id != self.lastAnnouncedId {
                self.lastAnnouncedId = top.id
                UIAccessibility.post(notification: .announcement, argument: "Guideline reminder: \(top.rule). \(top.message)")
            }
        }
    }

    func dismiss() {
        guard let top = topWarning else { return }
        dismissedIds.insert(top.id)
        topWarning = nil
    }
}
