import SwiftUI

/// Shown before someone can sign in — never before using AppleVis itself,
/// which stays fully browsable while signed out regardless of what happens
/// here. One reusable implementation from two entry points so behavior
/// can't drift between them: `OnboardingView`'s Community Agreement step
/// (inline, shares the wizard's own header-focus binding via `headerFocus`)
/// and `ProfileView`'s signed-out "Sign in to AppleVis" button (a
/// standalone sheet, manages its own focus). See `CommunityAgreementStore`
/// for the versioned acceptance state this gates on.
struct CommunityAgreementView: View {
    /// Passed by `OnboardingView` so this step's title joins the wizard's
    /// shared focus-retry mechanism, same as every other step's header.
    /// Left nil when presented standalone (Profile), in which case this
    /// view manages its own focus via `ownTitleFocus` below.
    var headerFocus: AccessibilityFocusState<Bool>.Binding? = nil
    /// Differs by entry point: onboarding continues setup, Profile returns
    /// there — same as `COPY.md`'s two suggested hint variants.
    let declineHint: String
    let onAgree: () -> Void
    let onDecline: () -> Void
    /// Set only by `OnboardingView`'s Community Agreement step — Setup's
    /// other 8 steps each show a Back button via `WizardStepHeader`, but
    /// this view predates that and builds its own header, so it needs its
    /// own small Back affordance to match rather than losing one. `nil`
    /// (the Profile sheet's standalone use) omits it entirely — there's
    /// nothing to go "back" to there, just Cancel/Decline.
    var onBack: (() -> Void)? = nil

    @AccessibilityFocusState private var ownTitleFocus: Bool
    private static let guidelinesURL = URL(string: "https://www.applevis.com/help/guidelines")!

    private var effectiveFocus: AccessibilityFocusState<Bool>.Binding {
        headerFocus ?? $ownTitleFocus
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let onBack {
                    HStack {
                        Button(action: onBack) {
                            Label("Back", systemImage: "chevron.backward")
                        }
                        .accessibilityHint(String(localized: "Returns to the previous step."))
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
                VStack(spacing: 12) {
                    Image(systemName: "person.2.circle")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                    Text("Our Community Agreement")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                        .modifier(OptionalAccessibilityFocus(isFocused: effectiveFocus))
                }
                .padding(.top, 48)

                // Reading order matches the spec exactly: title -> body ->
                // guidelines link -> Agree -> Decline. Deliberately not
                // wrapped in .accessibilityElement(children: .combine) —
                // that would swallow the link and both buttons into one
                // static stop, leaving VoiceOver/Switch Control with no way
                // to reach or activate any of them independently.
                VStack(alignment: .leading, spacing: 14) {
                    Text("AppleVis is at its best when everyone feels welcome to join the conversation. Our Community Guidelines help make that possible.")
                    Text("When you write a topic, reply, comment, review, or other community content in the AppleVis app, we may automatically check your draft against our Community Guidelines as you write.")
                    Text("Most of the time, we'll show a friendly note if something might need another look. For content that isn't allowed on AppleVis, we'll ask you to change it before posting.")
                    Text("Some guideline checks can use Apple's on-device intelligence when it's available. These checks happen on your device rather than sending your draft to an outside AI service.")
                    Text("By choosing Agree and Continue, you're agreeing to follow the AppleVis Community Guidelines when participating in the community.")
                    // Previously the only explanation of what "I Don't Agree"
                    // actually does lived in its VoiceOver-only
                    // accessibilityHint below — a sighted user swiping
                    // through on screen saw two buttons with no stated
                    // consequence for the second one. Requested directly.
                    Text("If you'd rather not agree now, that's fine. You can still browse all of AppleVis without signing in, and we'll ask again the next time you sign in.")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)

                WebLink(destination: Self.guidelinesURL, hint: String(localized: "Opens the complete AppleVis Community Guidelines.")) {
                    Text("Read the Community Guidelines")
                        .fontWeight(.semibold)
                }

                VStack(spacing: 12) {
                    Button(action: onAgree) {
                        Text("Agree and Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint(String(localized: "Accepts the Community Agreement and continues to sign in."))

                    // Not scroll-gated — the spec is explicit that Agree
                    // shouldn't require scrolling to the bottom first, and
                    // the same goes for Decline being reachable immediately.
                    Button("I Don't Agree", action: onDecline)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .accessibilityHint(declineHint)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .task {
            // Onboarding drives focus itself (nextStep()/previousStep()
            // already retry into the shared headerFocus binding); only
            // self-drive it here when presented standalone.
            if headerFocus == nil {
                await retryAccessibilityFocus(into: $ownTitleFocus)
            }
        }
    }
}

/// Pairs with `CommunityAgreementStore.requestSignIn(showCommunityAgreement:
/// showSignIn:)` — attach alongside an existing `.sheet(isPresented:
/// $showSignIn) { SignInView() }` on any screen that offers its own
/// sign-in prompt (Compose/Submit flows, Profile), and call `requestSignIn`
/// from that screen's "Sign In" button instead of setting `showSignIn`
/// directly. One implementation shared by every entry point, per the
/// Community Agreement's actual requirement: sign-in gated, not app access.
private struct CommunityAgreementGate: ViewModifier {
    @EnvironmentObject private var communityAgreement: CommunityAgreementStore
    @Binding var showCommunityAgreement: Bool
    @Binding var showSignIn: Bool
    var declineHint: String

    func body(content: Content) -> some View {
        content.sheet(isPresented: $showCommunityAgreement, onDismiss: {
            // Only opens Sign In if Agree actually ran — Decline leaves
            // showSignIn untouched, so the user stays exactly where they
            // were, signed out.
            if communityAgreement.hasAcceptedCurrentVersion {
                showSignIn = true
            }
        }) {
            CommunityAgreementView(
                declineHint: declineHint,
                onAgree: {
                    communityAgreement.acceptCurrentVersion()
                    showCommunityAgreement = false
                },
                onDecline: { showCommunityAgreement = false }
            )
        }
    }
}

extension View {
    func communityAgreementGate(
        showCommunityAgreement: Binding<Bool>,
        showSignIn: Binding<Bool>,
        declineHint: String = String(localized: "Closes this without signing in. You can review the agreement again later.")
    ) -> some View {
        modifier(CommunityAgreementGate(showCommunityAgreement: showCommunityAgreement, showSignIn: showSignIn, declineHint: declineHint))
    }
}
