import SwiftUI

/// Shared step header for every multi-step wizard in the app (Setup, the
/// Welcome Tour, and the Submit/Contact/Report/Change-Password family) —
/// one canonical header shape instead of three independently hand-rolled
/// ones. Back button, an optional section/chapter caption, a visible
/// "Step X of Y", decorative progress dots, an optional icon, and a title
/// whose accessibility label folds the section+step info in so it's
/// announced exactly once, not twice (the section caption and the dots are
/// both `.accessibilityHidden` for that reason — this is the same
/// no-double-announcement pattern the Welcome Tour already proved out).
///
/// Deliberately does not render a wizard's step *body* (form fields, choice
/// grids, prose) — only the chrome above it. Each wizard keeps rendering
/// its own content directly below this header.
struct WizardStepHeader: View {
    /// e.g. a Welcome Tour chapter ("Home"). `nil` for wizards with no
    /// grouping (Setup, Submit/Contact/etc.), which just show the step count.
    var sectionLabel: String? = nil
    let title: String
    /// SF Symbol name; `nil` omits the icon badge entirely (the
    /// Submit/Contact family has no icon in its step header today).
    var icon: String? = nil
    /// When non-nil, the icon plays a `.bounce` symbol effect whenever this
    /// value changes — the Welcome Tour uses it to mark checkpoint steps
    /// (`stepIndex`, only passed on checkpoints) without bouncing on every
    /// plain content step too. `nil` (the default) never bounces.
    var iconBounceTrigger: Int? = nil
    /// Shown beside the icon, the same height, so it adds no extra height
    /// to the header. The Welcome Tour puts its narrator, the Mouse, here;
    /// every other wizard leaves it nil.
    var artwork: AnyView? = nil
    /// 1-based, within `sectionLabel`'s own run if grouped.
    let stepIndex: Int
    let stepTotal: Int
    var accentColor: Color = .accentColor
    /// `nil` hides the Back button (first step of the wizard).
    var onBack: (() -> Void)? = nil
    var headerFocus: AccessibilityFocusState<Bool>.Binding? = nil

    // `title`/`sectionLabel` are runtime String values, not string literals —
    // Text(_ content: String) and String(localized: "\(title)...") both skip
    // catalog lookup entirely for a String argument, the same bug already
    // fixed for OnboardingHeader/WizardStepIndicator. LocalizedStringKey for
    // display, String.LocalizationValue for the accessibility label.
    private var localizedTitle: String { String(localized: String.LocalizationValue(title)) }
    private var localizedSectionLabel: String? { sectionLabel.map { String(localized: String.LocalizationValue($0)) } }

    private var combinedAccessibilityLabel: String {
        switch (localizedSectionLabel, stepTotal > 1) {
        case let (section?, true):
            return String(localized: "\(localizedTitle). \(section), step \(stepIndex) of \(stepTotal).")
        case let (section?, false):
            return String(localized: "\(localizedTitle). \(section).")
        case (nil, true):
            return String(localized: "\(localizedTitle). Step \(stepIndex) of \(stepTotal).")
        case (nil, false):
            return localizedTitle
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            if let onBack {
                HStack {
                    Button(action: onBack) {
                        Label("Back", systemImage: "chevron.backward")
                    }
                    .accessibilityHint(String(localized: "Returns to the previous step."))
                    Spacer()
                }
            }

            VStack(spacing: 2) {
                if let sectionLabel {
                    Text(LocalizedStringKey(sectionLabel))
                        .font(.caption).fontWeight(.semibold)
                        .textCase(.uppercase)
                }
                if stepTotal > 1 {
                    Text("Step \(stepIndex) of \(stepTotal)")
                        .font(.caption)
                }
            }
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)

            if stepTotal > 1 {
                HStack(spacing: 8) {
                    ForEach(1...stepTotal, id: \.self) { i in
                        Capsule()
                            .fill(i == stepIndex ? accentColor : Color.secondary.opacity(0.3))
                            .frame(width: i == stepIndex ? 22 : 8, height: 8)
                    }
                }
                .accessibilityHidden(true)
            }

            if icon != nil || artwork != nil {
                HStack(spacing: 16) {
                    if let artwork {
                        artwork
                    }
                    if let icon {
                        let iconView = Image(systemName: icon)
                            .font(.system(size: 34))
                            .foregroundStyle(accentColor)
                            .frame(width: 72, height: 72)
                            .background(accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
                            .accessibilityHidden(true)
                        if let iconBounceTrigger {
                            iconView.symbolEffect(.bounce, value: iconBounceTrigger)
                        } else {
                            iconView
                        }
                    }
                }
            }

            Text(LocalizedStringKey(title))
                .font(.title2).fontWeight(.bold)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel(combinedAccessibilityLabel)
                .modifier(OptionalAccessibilityFocus(isFocused: headerFocus))
        }
        .padding(.horizontal, 24)
    }
}

/// Cancel and Back together at the top left, for the wizards shown in a
/// sheet with a navigation bar (Contact, every Submit form, Report a
/// Comment, Account Security). Back used to sit in the step header just
/// under Cancel, but VoiceOver reads the whole navigation bar first, so
/// swiping went Cancel, title, Next, and only then Back. In one group the
/// swipe order matches what's on screen: Cancel, Back, title, Next.
/// Cancel stays in the same spot on every step; Back appears from step 2.
/// Onboarding and the Welcome Tour have no navigation bar, so they keep
/// the header's own Back button. Reported directly.
struct WizardLeadingToolbar: ToolbarContent {
    var cancelHint: String = String(localized: "Cancels and closes this form.")
    let onCancel: () -> Void
    /// `nil` on the first step.
    let onBack: (() -> Void)?

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
                .accessibilityHint(cancelHint)
            if let onBack {
                Button(action: onBack) {
                    Label("Back", systemImage: "chevron.backward")
                        .labelStyle(.titleAndIcon)
                }
                .accessibilityLabel(String(localized: "Back"))
                .accessibilityHint(String(localized: "Returns to the previous step."))
            }
        }
    }
}
