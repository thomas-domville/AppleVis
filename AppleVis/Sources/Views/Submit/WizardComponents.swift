import SwiftUI

/// "Step X of N" indicator shown at the top of each multi-step submission
/// wizard. Optionally bound to an `@AccessibilityFocusState` so the wizard
/// can move VoiceOver focus here after Next/Back — previously goNext()/
/// goBack() only played a sound, leaving focus wherever it was on the
/// previous step with nothing announcing the step actually changed.
struct WizardStepIndicator: View {
    let step: Int
    let total: Int
    let title: String
    var isFocused: AccessibilityFocusState<Bool>.Binding? = nil
    /// RN's `WizardLayout` shows an animated top progress *stripe* colored
    /// per-wizard-type in addition to the step dots — this text-only
    /// indicator had no visual progress cue at all, which is meaningfully
    /// less informative for low-vision users who don't run VoiceOver.
    var accentColor: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if total > 0 {
                GeometryReader { geo in
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(accentColor ?? Color.accentColor)
                                .frame(width: geo.size.width * CGFloat(step) / CGFloat(total))
                        }
                }
                .frame(height: 4)
                .accessibilityHidden(true)
            }
            Text("Step \(step) of \(total)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(LocalizedStringKey(title))
                .font(.headline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Step \(step) of \(total): \(String(localized: String.LocalizationValue(title)))"))
        .accessibilityAddTraits(.isHeader)
        .modifier(OptionalAccessibilityFocus(isFocused: isFocused))
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
    let action: () -> Void

    init(_ title: String, isEnabled: Bool = true, isProminent: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.isProminent = isProminent
        self.action = action
    }

    var body: some View {
        let label = Text(title)
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
        .disabled(!isEnabled)
    }
}
