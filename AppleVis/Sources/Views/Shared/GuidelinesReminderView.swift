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

    // The rule name and message stay English in GuidelineWarning (the
    // false-positive report sends them to the editorial team as written)
    // and are translated here, only for display. They used to be shown as
    // written, so these reminders were English in every language.
    // AI-generated reminders have no catalog entry and show as they are.
    private var localizedLabel: String { String(localized: String.LocalizationValue(config.label)) }
    private var localizedRule: String { String(localized: String.LocalizationValue(warning.rule)) }
    private var localizedMessage: String { String(localized: String.LocalizationValue(warning.message)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "\(localizedLabel): \(localizedRule)")
                    .font(.caption).fontWeight(.bold)
                    .foregroundStyle(config.text)
                Text(verbatim: localizedMessage)
                    .font(.subheadline)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "\(localizedLabel): \(localizedRule). \(localizedMessage)"))

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
    /// Second opinions already asked for, so typing on after a reminder
    /// doesn't re-ask about the same draft.
    private var opinionCache: [String: IntelligenceService.GuidelineSecondOpinion] = [:]

    /// The conversation a reply is being written in, set by the comment box.
    /// A reminder Apple Intelligence still thinks fits after reading the
    /// draft alone gets a second look with the thread around it, so a
    /// developer answering in their own thread, for example, isn't nudged
    /// about self-promotion. Requested directly (2026-10-06).
    var conversation: ConversationSource?
    /// Loaded once per draft, and only if a reminder needs it.
    private var loadedConversation: ConversationContext??

    /// Settings > Intelligence > Smarter Guideline Reminders. On by default.
    private static var secondOpinionEnabled: Bool {
        UserDefaults.standard.object(forKey: "intel.guidelineSecondOpinion") as? Bool ?? true
    }

    /// The latest draft, for checking when dictation ends or at Submit.
    private var lastDraft: (text: String, isReply: Bool)?
    /// Dictation was in progress at the last change. Reminders wait until
    /// it ends: a pause between dictated sentences isn't a pause in
    /// writing, and a reminder spoken mid-dictation was talked over or
    /// distracting. Many VoiceOver users dictate. Requested directly
    /// (2026-10-06).
    private var isDictating = false
    private var inputModeObserver: AnyCancellable?
    /// Reminders already asked about at Submit, so it's only once per draft.
    private var askedAtSubmit: Set<String> = []

    init() {
        inputModeObserver = NotificationCenter.default
            .publisher(for: UITextInputMode.currentInputModeDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.inputModeChanged() }
    }

    /// `isReply` — see `GuidelinesChecker.check(_:isReply:)`'s doc comment;
    /// forwarded as-is, defaulting to false (a new topic/post/entry).
    func textChanged(_ text: String, isReply: Bool = false) {
        checkTask?.cancel()
        lastDraft = (text, isReply)
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 else {
            topWarning = nil
            return
        }
        // Checked once dictation ends instead (inputModeChanged).
        if Self.isDictationActive {
            isDictating = true
            return
        }
        checkTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled, let self else { return }
            await self.runCheck(text, isReply: isReply)
            if !Task.isCancelled { self.checkTask = nil }
        }
    }

    /// Dictation just ended: check now, with no wait, since this is when
    /// someone listens back to what they dictated.
    private func inputModeChanged() {
        let dictating = Self.isDictationActive
        let wasDictating = isDictating
        isDictating = dictating
        guard wasDictating, !dictating, let draft = lastDraft,
              draft.text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 else { return }
        checkTask?.cancel()
        checkTask = Task { [weak self] in
            await self?.runCheck(draft.text, isReply: draft.isReply)
            if !Task.isCancelled { self?.checkTask = nil }
        }
    }

    /// The keyboard reports "dictation" as its language while dictating.
    /// Widely used, though not a documented promise; if it ever stops
    /// working, reminders behave as before and the Submit question still
    /// catches a missed one.
    private static var isDictationActive: Bool {
        FirstResponderFinder.current()?.textInputMode?.primaryLanguage == "dictation"
    }

    private func runCheck(_ text: String, isReply: Bool, announce: Bool = true) async {
        var visible = GuidelinesChecker.check(text, isReply: isReply).filter { !self.dismissedIds.contains($0.id) }
        // Apple Intelligence second opinion (2026-09-27): the rules spot
        // a possible issue, then the on-device model reads the whole
        // draft and skips a reminder that clearly doesn't fit ("thanks
        // for explaining it clearly!"). It can't add reminders, and the
        // clear-cut rules (strong language, images, and so on) never get
        // one. Used to ask the model to find problems on its own when
        // the rules found none, which could invent reminders in
        // untranslated wording. Requested directly.
        if Self.secondOpinionEnabled && IntelligenceService.isAvailable && !visible.isEmpty {
            var top: GuidelineWarning?
            for warning in visible {
                guard !Task.isCancelled else { return }
                // Medium reminders only. A low one is just a soft ding, so
                // it isn't worth an Apple Intelligence check while typing:
                // fewer model runs, less battery (2026-10-06).
                if warning.allowsSecondOpinion, warning.severity == .medium,
                   let opinion = await self.opinion(on: warning, in: text, isReply: isReply),
                   !opinion.isRealConcern {
                    continue
                }
                top = warning
                break
            }
            guard !Task.isCancelled else { return }
            visible = top.map { [$0] } ?? []
        }
        self.topWarning = visible.first
        if announce, let top = visible.first, top.id != self.lastAnnouncedId {
            self.lastAnnouncedId = top.id
            Self.cue(top)
        }
    }

    /// Called first thing on Submit, after the hard checks. When a medium
    /// reminder is still showing (not dismissed with Got It), asks once:
    /// Post Anyway or Keep Editing. True means it asked, and `post` runs if
    /// they choose Post Anyway. Never for low reminders, never twice for
    /// the same reminder, and never blocks. For anyone who missed it while
    /// writing, such as a VoiceOver user who dictated and went straight to
    /// Submit. Requested directly (2026-10-06).
    func confirmBeforePosting(_ post: @escaping () -> Void) async -> Bool {
        // A check still waiting (typed or dictated just before Submit)
        // runs now, quietly, so the question reflects the final text.
        if let draft = lastDraft, checkTask != nil {
            checkTask?.cancel()
            checkTask = nil
            if draft.text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 {
                await runCheck(draft.text, isReply: draft.isReply, announce: false)
            }
        }
        guard let top = topWarning, top.severity == .medium, !askedAtSubmit.contains(top.id) else { return false }
        askedAtSubmit.insert(top.id)
        let rule = String(localized: String.LocalizationValue(top.rule))
        let message = String(localized: String.LocalizationValue(top.message))
        let alert = UIAlertController(
            title: String(localized: "Before You Post"),
            message: "\(rule). \(message)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "Keep Editing"), style: .cancel))
        alert.addAction(UIAlertAction(title: String(localized: "Post Anyway"), style: .default) { _ in post() })
        guard let presenter = FirstResponderFinder.topViewController() else { return false }
        presenter.present(alert, animated: true)
        return true
    }

    private func opinion(on warning: GuidelineWarning, in text: String, isReply: Bool) async -> IntelligenceService.GuidelineSecondOpinion? {
        let key = "\(warning.id)|\(text.hashValue)"
        if let cached = opinionCache[key] { return cached }
        let load: (() async -> ConversationContext?)? = (isReply && conversation != nil) ? { [weak self] in
            await self?.conversationContext()
        } : nil
        let opinion = await IntelligenceService.reviewFlag(
            warning, in: text, context: IntelligenceService.FlagContext(isReply: isReply), loadConversation: load
        )
        if let opinion { opinionCache[key] = opinion }
        return opinion
    }

    private func conversationContext() async -> ConversationContext? {
        if let loadedConversation { return loadedConversation }
        guard let conversation else { return nil }
        var loaded = await GuidelineConversation.load(conversation)
        // Replying in a thread you started yourself.
        if let me = AuthStore.current?.user?.uuid, !me.isEmpty, loaded?.startedById == me {
            loaded?.flaggedAuthorStartedThread = true
        }
        loadedConversation = .some(loaded)
        return loaded
    }

    /// The "ding": a soft chime and a light tap when a reminder appears,
    /// like a misspelling ding in a word processor. You can stop and check
    /// it from the Actions rotor, or keep writing. It's only read aloud
    /// with Settings > Sounds & Haptics > Speak Guideline Reminders on,
    /// since speech while typing or dictating got in the way. Requested
    /// directly (2026-10-06).
    private static func cue(_ warning: GuidelineWarning) {
        SoundPlayer.shared.play(.guidelineDing)
        if PreferencesStore.current?.speakGuidelineReminders == true {
            speak(warning)
        }
    }

    /// Queued behind what VoiceOver is already saying. It used to interrupt,
    /// so typing echo could cut it off after a word or two.
    private static func speak(_ warning: GuidelineWarning) {
        let text = String(localized: "Guideline reminder: \(String(localized: String.LocalizationValue(warning.rule))). \(String(localized: String.LocalizationValue(warning.message)))")
        UIAccessibility.post(
            notification: .announcement,
            argument: NSAttributedString(string: text, attributes: [.accessibilitySpeechQueueAnnouncement: true])
        )
    }

    /// The text field's "Read Guideline Reminder" action.
    func readAgain() {
        guard let top = topWarning else { return }
        Self.speak(top)
    }

    func dismiss() {
        guard let top = topWarning else { return }
        dismissedIds.insert(top.id)
        topWarning = nil
    }
}

/// "Read Guideline Reminder" and "Dismiss Guideline Reminder" in the text
/// field's own Actions rotor while a reminder is showing, so a VoiceOver
/// user can hear it again or dismiss it without leaving the field to find
/// the reminder above it. Requested directly (2026-10-06).
struct GuidelineReminderActions: ViewModifier {
    @ObservedObject var guidelines: GuidelinesCheckState

    func body(content: Content) -> some View {
        content
            .modifier(ConditionalAccessibilityAction(isActive: guidelines.topWarning != nil, name: "Read Guideline Reminder") {
                guidelines.readAgain()
            })
            .modifier(ConditionalAccessibilityAction(isActive: guidelines.topWarning != nil, name: "Dismiss Guideline Reminder") {
                guidelines.dismiss()
                UIAccessibility.post(notification: .announcement, argument: String(localized: "Reminder dismissed."))
            })
    }
}

extension View {
    func guidelineReminderActions(_ guidelines: GuidelinesCheckState) -> some View {
        modifier(GuidelineReminderActions(guidelines: guidelines))
    }
}

/// Finds the focused text field (to read its input mode) and the screen
/// on top (to present the Submit question from anywhere).
@MainActor
enum FirstResponderFinder {
    private static weak var found: UIResponder?

    static func current() -> UIResponder? {
        found = nil
        UIApplication.shared.sendAction(#selector(UIResponder.appleVisCaptureFirstResponder(_:)), to: nil, from: nil, for: nil)
        return found
    }

    fileprivate static func capture(_ responder: UIResponder) { found = responder }

    static func topViewController() -> UIViewController? {
        var top = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed { top = presented }
        return top
    }
}

extension UIResponder {
    @objc fileprivate func appleVisCaptureFirstResponder(_ sender: Any?) {
        FirstResponderFinder.capture(self)
    }
}
