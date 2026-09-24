import SwiftUI

/// Brief background tint that fades in then out to confirm an AI rewrite or
/// translation just changed this field's text — otherwise the text silently
/// swaps with no visual signal anything happened, easy to miss entirely for
/// a low-vision user who isn't rereading every word. Flip `trigger` to
/// `true` right after applying the new text; it resets itself.
struct RewriteFlash: ViewModifier {
    @Binding var trigger: Bool

    func body(content: Content) -> some View {
        content
            .background(trigger ? Color.accentColor.opacity(0.15) : Color.clear)
            .animation(UIAccessibility.isReduceMotionEnabled ? nil : .easeOut(duration: 0.6), value: trigger)
            .onChange(of: trigger) { _, newValue in
                guard newValue else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    trigger = false
                }
            }
    }
}

extension View {
    func rewriteFlash(_ trigger: Binding<Bool>) -> some View {
        modifier(RewriteFlash(trigger: trigger))
    }
}

/// Not private so other screens with the same "focus this heading after a
/// transition" need (e.g. OnboardingView's step headers) can reuse it.
struct OptionalAccessibilityFocus: ViewModifier {
    let isFocused: AccessibilityFocusState<Bool>.Binding?

    func body(content: Content) -> some View {
        if let isFocused {
            content.accessibilityFocused(isFocused)
        } else {
            content
        }
    }
}

/// Post-submit confirmation screen shown by a wizard after a successful send,
/// matching RN's shared `ThankYouScreen` (`app/submit-blog/review.tsx`) —
/// previously wizards just toasted and dismissed immediately, giving VoiceOver
/// users no confirmation focus point and sighted users no visual payoff.
struct ThankYouView<Footer: View>: View {
    let icon: String
    let heading: String
    let message: String
    let doneLabel: String
    let onDone: () -> Void
    /// Optional extra content below the Done button — e.g. a dismissible,
    /// opt-in suggestion to also update the account's email when a
    /// signed-in user sent this message from a different address. Kept
    /// secondary to Done both in position and emphasis, since it's a
    /// suggestion, never something the wizard should push.
    @ViewBuilder var footer: () -> Footer
    @AccessibilityFocusState private var isHeadingFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)
                .frame(width: 88, height: 88)
                .background(Color.accentColor.opacity(0.15), in: Circle())
                .accessibilityHidden(true)
                // A small, non-celebratory flourish — reaches every wizard
                // that completes through this shared view (Contact Us,
                // Submit Bug Report, Submit Blog, Submit an App, Submit a
                // Podcast, Report a Comment, Account Security), including
                // ones where actual confetti would be the wrong tone (e.g.
                // Report a Comment). No `value:` needed — for a discrete
                // effect like `.bounce`, that plays it once the moment this
                // view appears, which for a one-shot completion screen like
                // this is exactly "on appear." System symbol effects
                // already respect Reduce Motion on their own.
                .symbolEffect(.bounce)

            // `Text(String)`/`Button(String)` resolve to the verbatim
            // initializer, not the LocalizedStringKey one, so a plain
            // `Text(heading)` here would silently skip the string catalog
            // no matter how the caller wrote its literal — wrapping in
            // LocalizedStringKey restores the lookup by content.
            Text(LocalizedStringKey(heading))
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($isHeadingFocused)

            Text(LocalizedStringKey(message))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(LocalizedStringKey(doneLabel), action: onDone)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            footer()

            Spacer()
        }
        .padding(32)
        .task {
            try? await Task.sleep(for: .milliseconds(350))
            isHeadingFocused = true
        }
    }
}

extension ThankYouView where Footer == EmptyView {
    init(icon: String, heading: String, message: String, doneLabel: String, onDone: @escaping () -> Void) {
        self.init(icon: icon, heading: heading, message: message, doneLabel: doneLabel, onDone: onDone, footer: { EmptyView() })
    }
}

/// Announces a submission failure to VoiceOver and moves accessibility focus
/// to the error message — call from a wizard's `submit()` failure branch.
/// Previously only `ContactView` gave any VoiceOver feedback at all on
/// failure; the other four wizards just set `error` and left focus wherever
/// it was, so a VoiceOver user got silence after tapping Submit with no
/// indication anything had gone wrong. The delay mirrors the wizards'
/// existing `focusStepAfterTransition()` pattern — SwiftUI needs a beat after
/// a body-changing state write before the focus target actually exists.
@MainActor
func announceWizardFailure(_ message: String, focus: AccessibilityFocusState<Bool>.Binding) async {
    UIAccessibility.post(notification: .announcement, argument: message)
    try? await Task.sleep(for: .milliseconds(300))
    focus.wrappedValue = true
}

/// A single label/value row on a wizard's final review screen.
struct WizardReviewRow: View {
    let label: String
    let value: String

    private var localizedLabel: String { String(localized: String.LocalizationValue(label)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(label))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "—" : value)
                .font(.body)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(localizedLabel): \(value.isEmpty ? "none" : value)"))
    }
}

/// Lists what's still needed before a wizard step's Next/Submit button will
/// enable — shown just above that button so a VoiceOver user swiping toward
/// it hears exactly why it's disabled, instead of landing on a silently
/// dimmed control. Generalizes the one-off "Confirm both checkboxes to
/// continue" note SubmitAppView's Before You Begin screen already had,
/// itemized so a step with more than one unmet requirement lists all of
/// them at once. Empty when nothing's blocking — callers pass whichever
/// reason strings currently apply, already filtered.
struct WizardBlockingNote: View {
    let reasons: [String]

    var body: some View {
        if !reasons.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(reasons, id: \.self) { reason in
                    Label(reason, systemImage: "exclamationmark.circle")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)
        }
    }
}

/// A step's bottom action button — mirrors the identical action already in
/// the navigation bar's toolbar. Onboarding trained every user to expect
/// the way forward at the bottom of a step's content; these seven Form-
/// based wizards only ever offered it in the top-right corner instead. A
/// beta tester's Contact Us "type" step — a list of tappable choices —
/// demonstrated the gap directly: swiping to the end of the list, as
/// VoiceOver naturally does, landed on nothing actionable. This button adds
/// that second path without removing the first, so anyone already used to
/// reaching for the toolbar loses nothing.
struct WizardBottomButton: View {
    let title: String
    var isEnabled: Bool = true
    var isProminent: Bool = true
    /// Swaps the label for a spinner while true — matches the toolbar
    /// Next/Submit action's own text-swap ("Sending…" etc.) with an actual
    /// visual indicator alongside it, and matches the same spinner treatment
    /// Edit/Compose screens' Save/Post buttons already use.
    var isLoading: Bool = false
    let action: () -> Void

    init(_ title: String, isEnabled: Bool = true, isProminent: Bool = true, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.isProminent = isProminent
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        let label = Group {
            if isLoading {
                ProgressView()
            } else {
                Text(title)
            }
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        Group {
            if isProminent {
                Button(action: action) { label }
                    .buttonStyle(.borderedProminent)
            } else {
                Button(action: action) { label }
                    .buttonStyle(.bordered)
            }
        }
        .disabled(!isEnabled || isLoading)
        // Without this, VoiceOver's label while `isLoading` would come from
        // the bare ProgressView instead of `title` — losing the "Sending…"
        // (or equivalent) announcement right when it matters most.
        .accessibilityLabel(title)
    }
}
