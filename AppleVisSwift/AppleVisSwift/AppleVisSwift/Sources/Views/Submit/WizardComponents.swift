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
            Text(title)
                .font(.headline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(step) of \(total): \(title)")
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

/// Injects "Step X of Y." between a header's title and subtitle in its
/// combined accessibility label — used by OnboardingView so VoiceOver users
/// get a sense of progress through the flow (RN did this on every step),
/// without dropping the subtitle that `.accessibilityElement(children:
/// .combine)` would otherwise speak automatically.
struct OptionalStepAnnouncement: ViewModifier {
    let title: String
    let subtitle: String
    let stepInfo: (current: Int, total: Int)?

    func body(content: Content) -> some View {
        if let stepInfo {
            content.accessibilityLabel("\(title). Step \(stepInfo.current) of \(stepInfo.total). \(subtitle)")
        } else {
            content
        }
    }
}

/// Post-submit confirmation screen shown by a wizard after a successful send,
/// matching RN's shared `ThankYouScreen` (`app/submit-blog/review.tsx`) —
/// previously wizards just toasted and dismissed immediately, giving VoiceOver
/// users no confirmation focus point and sighted users no visual payoff.
struct ThankYouView: View {
    let icon: String
    let heading: String
    let message: String
    let doneLabel: String
    let onDone: () -> Void
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

            Text(heading)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($isHeadingFocused)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(doneLabel, action: onDone)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            Spacer()
        }
        .padding(32)
        .task {
            try? await Task.sleep(for: .milliseconds(350))
            isHeadingFocused = true
        }
    }
}

/// A single label/value row on a wizard's final review screen.
struct WizardReviewRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "—" : value)
                .font(.body)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value.isEmpty ? "none" : value)")
    }
}
