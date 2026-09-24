import SwiftUI
import UserNotifications
import UIKit

struct OnboardingView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var communityAgreement: CommunityAgreementStore

    @State private var step = 0
    @State private var showSkipConfirm = false
    private let totalSteps = 9
    /// Every step's header binds to this so VoiceOver focus moves there after
    /// Next/Skip — previously each step was a distinct pushed screen in the
    /// old RN app, which got an automatic focus/announcement from React
    /// Navigation's screen transition for free; collapsing all 6 steps into
    /// one ZStack + switch here lost that for free, and nothing was added to
    /// compensate, so every step change was completely silent for VoiceOver.
    @AccessibilityFocusState private var isStepHeaderFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Group {
                    switch step {
                    case 0: WelcomeStep(onNext: nextStep, headerFocus: $isStepHeaderFocused)
                    case 1: CommunityAgreementStep(onAgree: agreeToCommunityAgreement, onDecline: declineCommunityAgreementAndSkipSignIn, onBack: previousStep, headerFocus: $isStepHeaderFocused)
                    case 2: SignInStep(onNext: nextStep, onSkip: nextStep, onBack: previousStep, headerFocus: $isStepHeaderFocused)
                    case 3: NewActivityDisplayStep(onNext: nextStep, onBack: previousStep, headerFocus: $isStepHeaderFocused)
                    case 4: ThemeStep(onNext: nextStep, onBack: previousStep, headerFocus: $isStepHeaderFocused)
                    case 5: AppleTopicsStep(onNext: nextStep, onBack: previousStep, headerFocus: $isStepHeaderFocused)
                    case 6: LanguageFilterStep(onNext: nextStep, onBack: previousStep, headerFocus: $isStepHeaderFocused)
                    case 7: NotificationsStep(onNext: nextStep, onBack: previousStep, headerFocus: $isStepHeaderFocused)
                    case 8: ReadyStep(onFinish: finish, onBack: previousStep, headerFocus: $isStepHeaderFocused)
                    default: EmptyView()
                    }
                }
                // Cancel used to live in the top chrome row, but it didn't
                // discard anything — it just accepted whatever hadn't been set
                // yet and finished, exactly like Skip Setup below, just labeled
                // and placed like a "get me out of here" affordance on someone's
                // very first screen. Demoted to a plain text link after each
                // step's own content instead, next to a plain-language reason
                // it's safe to tap. Hidden on the last step: by then there's
                // nothing left to skip. Also hidden on Welcome (step 0): Skip
                // Setup still finishes onboarding and lets someone use the app,
                // so it's a form of "continuing" too — it shouldn't be reachable
                // before the Terms of Service/Privacy Policy agreement on that
                // step has actually been made via Accept and Get Started.
                if step > 0 && step < totalSteps - 1 {
                    VStack(spacing: 4) {
                        Button("Skip Setup") { showSkipConfirm = true }
                            .font(.subheadline)
                            .accessibilityHint(String(localized: "Skips the rest of setup."))
                        Text("You can change any of this later in Settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 12)
                }
            }
            .animation(UIAccessibility.isReduceMotionEnabled ? nil : .easeInOut(duration: 0.3), value: step)
            .background(preferences.colors.background)
            // nextStep()/previousStep() already retry-focus the header after a
            // transition, but nothing did that for the initial appearance, so
            // VoiceOver defaulted to the chrome row's first focusable element
            // instead of the Welcome heading on first launch.
            .task { await retryAccessibilityFocus(into: $isStepHeaderFocused) }
            .confirmationDialog(
                "Skip the rest of setup?",
                isPresented: $showSkipConfirm, titleVisibility: .visible
            ) {
                Button("Skip Setup", role: .destructive) { finish() }
                Button("Continue Setup", role: .cancel) {}
            } message: {
                Text("You can change these settings anytime later in Settings.")
            }
            .navigationTitle("Setup")
        }
    }

    private func nextStep() {
        let next = min(step + 1, totalSteps - 1)
        withReduceMotionAwareAnimation { step = next }
        // A single fixed-delay focus attempt is unreliable on slower
        // devices/transitions — the shared retryAccessibilityFocus helper
        // (AccessibilityFocusRetry.swift) exists specifically because of
        // that, but this step-change path had never been switched over to
        // it. Reported directly: after "Get Started," VoiceOver focus
        // didn't move at all — swiping did nothing until the user found
        // the new step by touch.
        Task { await retryAccessibilityFocus(into: $isStepHeaderFocused) }
    }

    private func previousStep() {
        // Can't land back on step 2 (SignIn): SignInStep's own onAppear
        // immediately calls onNext() whenever already signed in, which
        // just bounces straight back to step 3 — Back would silently do
        // nothing. Welcome is the nearest step that's actually a valid
        // destination for a signed-in user going back from New Activity
        // Display (step 3) — Community Agreement (step 1) is skipped too,
        // since CommunityAgreementStep's own onAppear bounces past itself
        // for the same already-signed-in reason SignInStep does.
        let previous = step == 3 && auth.isSignedIn ? 0 : max(step - 1, 0)
        withReduceMotionAwareAnimation { step = previous }
        Task { await retryAccessibilityFocus(into: $isStepHeaderFocused) }
    }

    private func agreeToCommunityAgreement() {
        communityAgreement.acceptCurrentVersion()
        nextStep()
    }

    /// Declining only means "don't sign in right now" — browsing stays
    /// fully available, matching Skip Setup elsewhere in this wizard.
    /// Skips past the Sign In step too: without agreement there's nothing
    /// for it to do here, and landing on it would just show a sign-in form
    /// for something the user just said no to. Also used by
    /// `CommunityAgreementStep` itself to bypass this step silently for an
    /// already-signed-in user, without recording a fresh acceptance they
    /// were never actually asked for.
    private func declineCommunityAgreementAndSkipSignIn() {
        let next = min(step + 2, totalSteps - 1)
        withReduceMotionAwareAnimation { step = next }
        Task { await retryAccessibilityFocus(into: $isStepHeaderFocused) }
    }

    private func finish() {
        auth.completeOnboarding()
    }
}

// MARK: - Step 1: Welcome

private struct WelcomeStep: View {
    let onNext: () -> Void
    let headerFocus: AccessibilityFocusState<Bool>.Binding
    // Grows with Dynamic Type instead of staying pinned at 32pt while the
    // adjacent title/description wraps across several lines at the largest
    // accessibility text sizes.
    @ScaledMetric(relativeTo: .body) private var featureIconWidth: CGFloat = 32

    private let features: [(icon: String, title: String, desc: String)] = [
        // A prior pass replaced "Built for VoiceOver" with "Tested, Not
        // Just Labeled" to sound like less of a generic accessibility
        // slogan — a beta tester flagged that the replacement read as AI-
        // generated boilerplate instead ("this is one of the first
        // giveaways that AI was used to generate wording"), the exact
        // thing it was trying to avoid. Removed outright rather than
        // reworded again: the app's actual VoiceOver support should speak
        // for itself through the experience, not through a claim about it
        // here. Reported directly.
        ("person.3",        "Community-Driven",             "Tips, reviews, and guides contributed by blind and low-vision users."),
        ("newspaper",       "All the Content You Need",     "Forums, app comments, podcasts, tutorials, and news in one place."),
        // RN's welcome copy is concrete about how many themes and which
        // ones — Swift's was generic ("High-contrast and low-vision-
        // friendly themes built in") despite having the same 15 themes
        // available (PreferencesStore's AppTheme enum).
        ("paintbrush",      "Accessible Themes",            "15 themes including High Contrast, Mouse, and Midnight — choose yours in the next few steps."),
        ("bell.badge",      "Smart Notifications",          "Stay informed about the content that matters to you."),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    WizardStepHeader(
                        title: "Welcome to AppleVis", icon: "eye.circle.fill",
                        stepIndex: 1, stepTotal: 9, headerFocus: headerFocus
                    )

                    Text("The community for blind and low-vision Apple users.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 48)

                // This app has no way to detect an upgrade from the previous
                // AppleVis app (a deliberate choice — see Phase D of the
                // release audit: no Expo→native migration code, full local
                // reset accepted as a one-time cost), so this note is shown
                // to everyone rather than guessed at. It's a no-op for a
                // genuinely new user and the one explanation a returning
                // user gets for why they need to sign in and reconfigure
                // preferences again.
                VStack(alignment: .leading, spacing: 6) {
                    Label("Used AppleVis before?", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    Text("This is a rebuilt version of the app. Your forum posts, comments, and account are all still there on the website — just sign back in. Local settings like your saved episodes and preferences were reset and will need to be set up again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "Used AppleVis before? This is a rebuilt version of the app. Your forum posts, reviews, and account are all still there on the website — just sign back in. Local settings like your saved episodes and preferences were reset and will need to be set up again."))

                VStack(spacing: 20) {
                    ForEach(features, id: \.title) { feature in
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: feature.icon)
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: featureIconWidth)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(feature.title)
                                    .font(.headline)
                                Text(feature.desc)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, 24)

                // The app's own Terms of Service/Privacy Policy were only
                // ever reachable as a buried, optional link in About and
                // Settings — nobody had to see or acknowledge them to use
                // the app. Placed here, on the very first screen everyone
                // sees before any other choice (including signing in),
                // this becomes the one moment that reaches every user, not
                // just the ones who sign in — matching how the Community
                // Agreement step later covers sign-in specifically.
                // Requested directly, alongside an in-package NOTICE.txt
                // and Info.plist copyright string covering the same ground
                // for anyone inspecting the app outside of actually running
                // it.
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("By continuing, you agree to our")
                            .foregroundStyle(.secondary)
                        WebLink(destination: URL(string: "https://www.applevis.com/terms")!) {
                            Text("Terms of Service")
                        }
                        .fontWeight(.semibold)
                    }
                    HStack(spacing: 4) {
                        Text("and")
                            .foregroundStyle(.secondary)
                        WebLink(destination: URL(string: "https://www.applevis.com/privacy")!) {
                            Text("Privacy Policy")
                        }
                        .fontWeight(.semibold)
                        Text(".")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

                Button(action: onNext) {
                    Text("Accept and Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .accessibilityHint(String(localized: "Agrees to our Terms of Service and Privacy Policy, and advances to the next setup step."))
            }
        }
    }
}

// MARK: - Step 2: Community Agreement

private struct CommunityAgreementStep: View {
    @EnvironmentObject private var auth: AuthStore
    let onAgree: () -> Void
    let onDecline: () -> Void
    let onBack: () -> Void
    let headerFocus: AccessibilityFocusState<Bool>.Binding

    var body: some View {
        CommunityAgreementView(
            headerFocus: headerFocus,
            declineHint: String(localized: "Continues using AppleVis without signing in. You can review the agreement again later."),
            onAgree: onAgree,
            onDecline: onDecline,
            onBack: onBack
        )
        .onAppear {
            // Matches SignInStep's identical guard just after this step —
            // a returning user with a still-valid session isn't attempting
            // to sign in right now, so there's nothing here for them to
            // agree to before doing. `onDecline` (skip, don't record
            // acceptance) rather than `onAgree`: they weren't actually
            // asked, so nothing should be recorded on their behalf.
            if auth.isSignedIn {
                onDecline()
            }
        }
    }
}

// MARK: - Step 3: Sign In

private struct SignInStep: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var preferences: PreferencesStore
    let onNext: () -> Void
    let onSkip: () -> Void
    let onBack: () -> Void
    let headerFocus: AccessibilityFocusState<Bool>.Binding

    @State private var username = ""
    @State private var password = ""
    @State private var validationMessage: String?
    @AccessibilityFocusState private var isErrorFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    WizardStepHeader(
                        title: "Sign In", icon: "person.crop.circle",
                        stepIndex: 3, stepTotal: 9, onBack: onBack, headerFocus: headerFocus
                    )
                    Text("Sign in to post content, track saved items, and sync your activity between the AppleVis app and website. You can skip this and sign in later.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Username").font(.caption).foregroundStyle(.secondary)
                        TextField("Username", text: $username)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            // Missing here despite being present and correct
                            // on the standalone SignInView (ONBOARD-05) — no
                            // shared component, so the two drifted. This is
                            // most users' very first sign-in in the app,
                            // arguably the moment AutoFill/Strong Password/
                            // Keychain credential offers matter most.
                            .textContentType(.username)
                            .accessibilityLabel(String(localized: "Username field"))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password").font(.caption).foregroundStyle(.secondary)
                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.password)
                            .accessibilityLabel(String(localized: "Password field"))
                            .onSubmit { signIn() }
                    }

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(preferences.colors.error)
                            .accessibilityFocused($isErrorFocused)
                    } else if let error = auth.error {
                        VStack(alignment: .leading, spacing: 6) {
                            // The Link below is deliberately a sibling, not a
                            // child, of this combined block — .combine would
                            // otherwise swallow it into a single static
                            // element, leaving VoiceOver/Switch Control users
                            // with no way to reach or activate Reset Password
                            // after a failed sign-in. Reported directly.
                            VStack(alignment: .leading, spacing: 6) {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(preferences.colors.error)
                                Text("If you have forgotten your password, you can reset it on the AppleVis website.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(String(localized: "Error: \(error). If you have forgotten your password, you can reset it on the AppleVis website."))
                            .accessibilityFocused($isErrorFocused)

                            WebLink(destination: URL(string: "https://www.applevis.com/user/password")!) {
                                Text("Reset Password")
                            }
                            .font(.caption).fontWeight(.semibold)
                        }
                    }

                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .font(.caption).foregroundStyle(.secondary)
                        WebLink(destination: URL(string: "https://www.applevis.com/user/register")!) {
                            Text("Sign up for free")
                        }
                        .font(.caption).fontWeight(.semibold)
                    }
                }
                .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    Button(action: signIn) {
                        Group {
                            if auth.isLoading {
                                ProgressView()
                            } else {
                                Text("Sign In")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(auth.isLoading)

                    Button("Skip for Now", action: onSkip)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .padding(.top, 48)
        }
        .onAppear {
            // A returning user still signed in from a previous session
            // shouldn't have to manually tap through a sign-in screen they
            // don't need — matches RN's mount-time isSignedIn check.
            if auth.isSignedIn {
                onNext()
            }
            // Focus lands on the header here now, same as every other
            // step (driven by nextStep()/previousStep()'s shared
            // retryAccessibilityFocus call) — this step used to jump
            // straight to the Username field instead, which meant a
            // VoiceOver user landing here heard "Username field" with no
            // "Sign In. Step 3 of 9." or explanation unless they swiped
            // backward past it. Reported directly.
        }
    }

    private func signIn() {
        let name = username.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            validationMessage = "Please enter your AppleVis username or email address."
            UIAccessibility.post(notification: .announcement, argument: validationMessage!)
            isErrorFocused = true
            return
        }
        guard !password.isEmpty else {
            validationMessage = "Please enter your AppleVis password."
            UIAccessibility.post(notification: .announcement, argument: validationMessage!)
            isErrorFocused = true
            return
        }
        validationMessage = nil
        Task {
            await auth.signIn(username: name, password: password)
            if auth.isSignedIn {
                onNext()
            } else {
                isErrorFocused = true
            }
        }
    }
}

// MARK: - Step 4: New Activity Display

private struct NewActivityDisplayStep: View {
    @EnvironmentObject private var preferences: PreferencesStore
    let onNext: () -> Void
    let onBack: () -> Void
    let headerFocus: AccessibilityFocusState<Bool>.Binding

    // Previously asked whether to remember reading history at all — but
    // that conflated two different things: whether AppleVis tracks what
    // you've read (needed for All/New/Recap to work, purely on-device,
    // never transmitted while signed out, so there's no real reason to
    // ever turn it off) versus whether Home actually *shows* new-activity
    // indicators (something people genuinely have different preferences
    // about — some find a running tally of what's new distracting rather
    // than helpful). Tracking itself is now unconditional; this step only
    // sets `showNewActivityIndicators`. Same reasoning as before for why
    // every user still sees all 9 steps rather than this one being skipped
    // for anyone: the total was announced up front, so silently skipping a
    // step would break the count a VoiceOver user was already told.
    // Requested directly.
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    WizardStepHeader(
                        title: "Show What's New?", icon: "bell.badge",
                        stepIndex: 4, stepTotal: 9, onBack: onBack, headerFocus: headerFocus
                    )
                    Text("Home can highlight what's changed since your last visit — a New view alongside All and Mouse Recap, a quick summary at the top, and a small label on anything with new activity.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("A short summary and a New view each time you open Home.", systemImage: "sparkles")
                    Label("A small label like \"3 NEW\" on topics and posts with new comments.", systemImage: "text.badge.plus")
                    Label("You can change this anytime in Settings > General.", systemImage: "hand.raised")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
                .accessibilityElement(children: .combine)

                VStack(spacing: 12) {
                    Button {
                        preferences.showNewActivityIndicators = true
                        onNext()
                    } label: {
                        VStack(spacing: 4) {
                            RecommendedBadge()
                            Text("Yes, Show What's New")
                                .font(.headline)
                            Text("The default — a New view, labels, and a quick summary on Home.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        preferences.showNewActivityIndicators = false
                        onNext()
                    } label: {
                        VStack(spacing: 4) {
                            Text("No, Keep Home Quiet")
                                .font(.headline)
                            Text("Hides the New view, summary, and badges. Home still works normally otherwise.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .padding(.top, 48)
        }
    }
}

// MARK: - Step 5: Theme

/// Beta-tester feedback: a VoiceOver user would likely skip this step
/// assuming there's nothing here for them — reasonable, but the step never
/// said a default was already set, and Continue sat below all 15 themes
/// (about 20 swipes away). Now the intro says what's already chosen and who
/// the step can help, a "Continue with …" button sits right under it, and
/// the default carries a Recommended badge.
private struct ThemeStep: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.colorScheme) private var colorScheme
    let onNext: () -> Void
    let onBack: () -> Void
    let headerFocus: AccessibilityFocusState<Bool>.Binding

    /// Set once, ever — so going Back to this step after picking System on
    /// purpose doesn't switch it to High Contrast again.
    @AppStorage("onboarding.contrastThemeSuggested") private var contrastThemeSuggested = false
    /// Whether this visit pre-selected a High Contrast theme (drives the
    /// intro wording and which option gets the Recommended badge).
    @State private var suggestedHighContrast: AppTheme?

    private var recommendedTheme: AppTheme { suggestedHighContrast ?? .system }

    private var introText: String {
        if let suggestedHighContrast {
            return String(localized: "Since Increase Contrast is turned on for your iPhone, we've picked \(suggestedHighContrast.displayName) for you. If that works for you, just continue, or choose another theme below. You can always change this later in Settings.")
        }
        return String(localized: "It's already set to System, which matches your iPhone's Light or Dark Mode. If that works for you, just continue. If you have some vision, High Contrast or Midnight can make text easier to read. You can always change this later in Settings.")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    WizardStepHeader(
                        title: "Choose a Theme", icon: "paintbrush",
                        stepIndex: 5, stepTotal: 9, onBack: onBack, headerFocus: headerFocus
                    )
                    Text(introText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    // Two swipes from the heading instead of ~20 — the full
                    // list below stays for anyone who wants to browse.
                    Button(action: onNext) {
                        Text("Continue with \(preferences.theme.displayName)")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal, 24)
                    .accessibilityHint(String(localized: "Keeps this theme and moves to the next step."))
                }

                VStack(alignment: .leading, spacing: 20) {
                    ForEach(ThemeGroup.allCases) { group in
                        VStack(alignment: .leading, spacing: 12) {
                            // `group.label` is a String, not a string literal —
                            // Text(_ content: String) treats a String argument as
                            // already-resolved display text and skips catalog
                            // lookup entirely, so these three group headers were
                            // silently never being translated. Same fix as
                            // WizardStepHeader's title for the identical problem.
                            Text(LocalizedStringKey(group.label))
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .accessibilityAddTraits(.isHeader)

                            VStack(spacing: 12) {
                                ForEach(AppTheme.allCases.filter { $0.group == group }) { theme in
                                    Button {
                                        preferences.theme = theme
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                if theme == recommendedTheme {
                                                    ThemeRecommendedBadge()
                                                }
                                                Text(theme.displayName)
                                                    .font(.headline)
                                                    .foregroundStyle(.primary)
                                                Text(theme.subtitle)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            if preferences.theme == theme {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(Color.accentColor)
                                                    .accessibilityHidden(true)
                                            }
                                        }
                                        .padding(16)
                                        .background(preferences.colors.card, in: RoundedRectangle(cornerRadius: 12))
                                    }
                                    .accessibilityAddTraits(preferences.theme == theme ? [.isSelected] : [])
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Button(action: onNext) {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .padding(.top, 48)
        }
        .onAppear(perform: suggestHighContrastIfNeeded)
    }

    /// Someone who's turned on iOS's Increase Contrast has already told
    /// their iPhone they need more contrast — so if they haven't picked a
    /// theme yet, start them on the matching High Contrast one instead of
    /// System. Only ever once, and only while still on the default.
    private func suggestHighContrastIfNeeded() {
        guard !contrastThemeSuggested, preferences.theme == .system, UIAccessibility.isDarkerSystemColorsEnabled else { return }
        contrastThemeSuggested = true
        let theme: AppTheme = colorScheme == .dark ? .highContrastDark : .highContrastLight
        preferences.theme = theme
        suggestedHighContrast = theme
    }
}

/// RecommendedBadge (below) is white-on-translucent, built for sitting on a
/// filled prominent button — on a theme row's plain background it would be
/// close to invisible. Primary-colored text on a pale accent tint instead:
/// white on the default accent blue is only ~3.6:1, under the 4.5:1 small
/// text needs, while primary text keeps full contrast in every theme.
private struct ThemeRecommendedBadge: View {
    var body: some View {
        Text("Recommended")
            .font(.caption2)
            .fontWeight(.bold)
            .textCase(.uppercase)
            .tracking(0.4)
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.15), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.accentColor, lineWidth: 1))
    }
}

// MARK: - Step 6: Apple Topics

private struct AppleTopicsStep: View {
    @EnvironmentObject private var preferences: PreferencesStore
    let onNext: () -> Void
    let onBack: () -> Void
    let headerFocus: AccessibilityFocusState<Bool>.Binding

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    WizardStepHeader(
                        title: "Apple Topics Only?", icon: "apps.iphone",
                        stepIndex: 6, stepTotal: 9, onBack: onBack, headerFocus: headerFocus
                    )
                    Text("Forums on AppleVis include some non-Apple topics too. Want Home and Forums to focus on Apple only?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Apple Related covers Apple products and platforms — iPhone, Mac, Apple Watch, apps, and more.", systemImage: "apps.iphone")
                    Label("Non-Apple topics include Windows, Android, smart home tech, and general assistive technology discussions.", systemImage: "globe")
                    Label("Podcasts, Guides, Apps, and Blogs are already all about Apple — only Forums has non-Apple discussions to filter. Change this anytime from Customize Home (on the Home tab) or Settings > Home Feed.", systemImage: "gearshape")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
                .accessibilityElement(children: .combine)

                VStack(spacing: 12) {
                    Button {
                        preferences.appleOnlyForums = true
                        onNext()
                    } label: {
                        VStack(spacing: 4) {
                            RecommendedBadge()
                            Text("Apple Topics Only")
                                .font(.headline)
                            Text("Home and Forums stay focused on Apple products and services.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        preferences.appleOnlyForums = false
                        onNext()
                    } label: {
                        VStack(spacing: 4) {
                            Text("Include Everything")
                                .font(.headline)
                            Text("Also see Windows, Android, smart home, and other assistive tech discussions in Forums.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .padding(.top, 48)
        }
    }
}

// MARK: - Step 7: Language Filtering

private struct LanguageFilterStep: View {
    @EnvironmentObject private var preferences: PreferencesStore
    let onNext: () -> Void
    let onBack: () -> Void
    let headerFocus: AccessibilityFocusState<Bool>.Binding

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    WizardStepHeader(
                        title: "Filter Milder Language?", icon: "text.badge.checkmark",
                        stepIndex: 7, stepTotal: 9, onBack: onBack, headerFocus: headerFocus
                    )
                    Text("AppleVis always blocks strong or explicit language from every post and comment — that never changes. This is just about whether milder language, which the site otherwise allows, shows up masked or spelled out.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Masked text looks like \"s***\" instead of the word spelled out.", systemImage: "text.badge.checkmark")
                    Label("We keep this on by default to help AppleVis stay welcoming, and to stay within Apple's guidelines for our age rating.", systemImage: "checkmark.shield")
                    Label("Change this anytime in Settings > General.", systemImage: "hand.raised")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
                .accessibilityElement(children: .combine)

                VStack(spacing: 12) {
                    Button {
                        preferences.filterProfanity = true
                        onNext()
                    } label: {
                        VStack(spacing: 4) {
                            RecommendedBadge()
                            Text("Yes, Filter Milder Language")
                                .font(.headline)
                            Text("The default — milder language is shown masked.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        preferences.filterProfanity = false
                        onNext()
                    } label: {
                        VStack(spacing: 4) {
                            Text("No, Show Everything")
                                .font(.headline)
                            Text("See milder language exactly as written. Strong language is still always blocked from posting.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .padding(.top, 48)
        }
    }
}

// MARK: - Step 8: Notifications

private struct NotificationsStep: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var auth: AuthStore
    let onNext: () -> Void
    let onBack: () -> Void
    let headerFocus: AccessibilityFocusState<Bool>.Binding

    @State private var permissionGranted: Bool? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    WizardStepHeader(
                        title: "Notifications", icon: "bell.badge",
                        stepIndex: 8, stepTotal: 9, onBack: onBack, headerFocus: headerFocus
                    )
                    Text("Choose which alerts you'd like to receive. You can update these anytime in Settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Matches Settings > Notifications' own "My Activity" grouping
                // and sign-in gating — previously omitted here entirely, along
                // with New Resources and New Comments below, so onboarding only
                // ever offered 3 of the app's 8 real notification categories.
                // Shown (not hidden) even when signed out, same reasoning as
                // every other step that only fully applies in some situations:
                // dimmed and explained rather than silently missing. Requested
                // directly.
                VStack(alignment: .leading, spacing: 8) {
                    Text("My Activity")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 0) {
                        NotifToggle("Replies to My Posts", isOn: $preferences.notifyForumReplies)
                            .disabled(!auth.isSignedIn)
                            .accessibilityHint(String(localized: auth.isSignedIn
                                ? "Get notified when someone replies to your forum topics."
                                : "Requires signing in."))
                        // Mentions shelved (2026-09-23, beta-tester feedback): AppleVis
                        // has no real @mention feature — typing someone's username
                        // doesn't notify them — so this promised something the site
                        // can't deliver. `notifyMentions` and the "mention" push
                        // category are kept for if the website ever adds real
                        // mentions; only the switch is hidden.
                        NotifToggle("Followed Topics", isOn: $preferences.notifyFollowedTopics)
                            .disabled(!auth.isSignedIn)
                            .accessibilityHint(String(localized: auth.isSignedIn
                                ? "Get notified about activity in topics you follow."
                                : "Requires signing in."))
                    }
                    .background(preferences.colors.card, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24)
                    // A ternary passed directly to Text(_:) risks Swift inferring
                    // the branches as plain String rather than LocalizedStringKey,
                    // silently skipping the catalog — same bug class documented
                    // elsewhere in this file. Splitting into two literal Text()
                    // calls keeps each one unambiguously translatable.
                    if auth.isSignedIn {
                        Text("These alerts are only available while signed in.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                    } else {
                        Text("You're continuing as a guest, so these stay dimmed — sign in anytime to turn them on.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("New Content")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 0) {
                        // "Announcements" excluded — AppleVis has no
                        // "announcement" content type of its own;
                        // announcements are posted to the Blog, Forum, or
                        // Newsletter, each already covered by its own category
                        // here. (Settings > Notifications still has this
                        // toggle too — flagged separately, not touched in
                        // this pass.) Reported directly.
                        NotifToggle("New Forum Topics",  isOn: $preferences.notifyNewTopics)
                        NotifToggle("New Podcast Episodes", isOn: $preferences.notifyNewEpisodes)
                        NotifToggle("New App Directory Entries", isOn: $preferences.notifyAppUpdates)
                        NotifToggle("New Guides", isOn: $preferences.notifyNewResources)
                        NotifToggle("New Comments", isOn: $preferences.notifyNewComments)
                    }
                    .background(preferences.colors.card, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24)
                }

                // Sound picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notification Sound")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 0) {
                        ForEach(NotificationSound.allCases) { sound in
                            let row = Button {
                                preferences.notificationSound = sound
                                SoundPlayer.shared.playNotificationPreview(sound)
                            } label: {
                                HStack {
                                    // `sound.displayName`/`.description` are String
                                    // values, not string literals — Text(_ content:
                                    // String) skips catalog lookup entirely, same
                                    // bug already fixed for ThemeGroup.label above.
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(LocalizedStringKey(sound.displayName))
                                            .foregroundStyle(.primary)
                                        Text(LocalizedStringKey(sound.description))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if preferences.notificationSound == sound {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.accentColor)
                                            .accessibilityHidden(true)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }
                            .accessibilityAddTraits(preferences.notificationSound == sound ? [.isSelected] : [])

                            // System Default's own description already says
                            // "Preview unavailable" — SoundPlayer.playNotification-
                            // Preview(.system) deliberately does nothing (iOS has
                            // no API to play back a device's actual default alert
                            // tone). Offering a VoiceOver "Preview" action here
                            // anyway would silently no-op, contradicting what the
                            // row itself says. Every other sound keeps the action.
                            // Requested directly.
                            if sound == .system {
                                row
                            } else {
                                // Double-tapping to select a sound also plays its
                                // preview immediately — with VoiceOver's audio
                                // ducking, VoiceOver's own selection announcement
                                // talks over the clip, making it hard to actually
                                // hear. This action (reachable via the rotor's
                                // Actions category, or swiping down once it's
                                // selected there) just plays the clip on its own,
                                // without also changing the selection or
                                // triggering that announcement. Reported directly
                                // as a workaround for the ducking collision.
                                row.accessibilityAction(named: Text("Preview")) {
                                    SoundPlayer.shared.playNotificationPreview(sound)
                                }
                            }
                            if sound != NotificationSound.allCases.last {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .background(preferences.colors.card, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24)
                }

                VStack(spacing: 12) {
                    if permissionGranted != true {
                        // A bare "Allow Notifications" button gave no sense of
                        // what iOS's own permission prompt was about to ask, or
                        // why AppleVis wanted it — priming with what happens and
                        // why before the system dialog appears. Requested
                        // directly.
                        Text("iOS will ask you to confirm — this only sends alerts for what you turned on above, and you can change it anytime in Settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button(action: requestPermission) {
                            Text("Allow Notifications")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if permissionGranted == true {
                        Button(action: onNext) {
                            Text("Continue")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button(action: onNext) {
                            Text("Skip")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .padding(.top, 48)
        }
        .task { await checkPermission() }
    }

    private func checkPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionGranted = settings.authorizationStatus == .authorized
    }

    private func requestPermission() {
        Task {
            let granted = await PushNotificationManager.requestAuthorizationAndRegister()
            permissionGranted = granted
            if granted { onNext() }
        }
    }
}

private struct NotifToggle: View {
    let label: String
    @Binding var isOn: Bool

    init(_ label: String, isOn: Binding<Bool>) {
        self.label = label
        self._isOn = isOn
    }

    var body: some View {
        Toggle(label, isOn: $isOn)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
}

// MARK: - Step 9: Ready

private struct ReadyStep: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onFinish: () -> Void
    let onBack: () -> Void
    let headerFocus: AccessibilityFocusState<Bool>.Binding
    // See WelcomeStep.featureIconWidth — same fixed-vs-scaling mismatch
    // against the adjacent summary text.
    @ScaledMetric(relativeTo: .body) private var summaryIconWidth: CGFloat = 28

    // Reordered to match the actual step order (Sign In first, then every
    // step after it in sequence) instead of an arbitrary order that used to
    // put Theme first and Sign In third. Also: dropped the VoiceOver Detail
    // Level line entirely (that step no longer exists), added a Sign In line
    // for guests too (previously silent), added the New Activity Display
    // step's own choice (never appeared here at all, despite a comment here
    // once claiming Notifications was "the only step" missing from this
    // recap), added the notification sound (categories only, no sound,
    // previously), and rewrote every line as a full warm sentence instead of
    // a bare "Label: Value" pair — "Language: Milder Language Filtered" read
    // as a setting name rather than a sentence, and "Notifications: Off"
    // implied the feature itself was disabled rather than "you didn't pick
    // any yet." Requested directly.
    private var summaryItems: [(icon: String, text: String)] {
        var items: [(String, String)] = []

        items.append(auth.isSignedIn
            ? ("person.crop.circle.fill", "You're signed in as \(auth.user!.name).")
            : ("person.crop.circle", "You're continuing as a guest — sign in anytime from Profile.")
        )
        items.append(preferences.showNewActivityIndicators
            ? ("sparkles", "Home will highlight what's new since your last visit.")
            : ("sparkles", "Home stays quiet, with no new-activity indicators.")
        )
        items.append(("paintbrush", "Using the \(preferences.theme.displayName) theme."))
        items.append(preferences.appleOnlyForums
            ? ("apps.iphone", "Forums focus on Apple topics only.")
            : ("apps.iphone", "Forums show everything, Apple and beyond.")
        )
        items.append(preferences.filterProfanity
            ? ("text.badge.checkmark", "Milder language is filtered to keep things welcoming.")
            : ("text.badge.checkmark", "Language shows up exactly as written.")
        )

        let enabledCategories = [
            auth.isSignedIn && preferences.notifyForumReplies ? "Replies to My Posts" : nil,
            auth.isSignedIn && preferences.notifyFollowedTopics ? "Followed Topics" : nil,
            preferences.notifyNewTopics ? "New Forum Topics" : nil,
            preferences.notifyNewEpisodes ? "New Podcast Episodes" : nil,
            preferences.notifyAppUpdates ? "New App Directory Entries" : nil,
            preferences.notifyNewResources ? "New Guides" : nil,
            preferences.notifyNewComments ? "New Comments" : nil,
        ].compactMap { $0 }
        items.append(enabledCategories.isEmpty
            ? ("bell.slash", "No notification categories are turned on yet.")
            : ("bell.badge", "You'll be notified about \(enabledCategories.joined(separator: ", ")).")
        )
        items.append(("speaker.wave.2", "Notifications will play the \(preferences.notificationSound.displayName) sound."))

        return items
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    WizardStepHeader(
                        title: "You're All Set", icon: "checkmark.circle.fill",
                        stepIndex: 9, stepTotal: 9, onBack: onBack, headerFocus: headerFocus
                    )
                    Text("AppleVis is ready for you. Here's a summary of your setup:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 12) {
                    ForEach(summaryItems, id: \.text) { item in
                        HStack(spacing: 14) {
                            Image(systemName: item.icon)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: summaryIconWidth)
                                .accessibilityHidden(true)
                            Text(LocalizedStringKey(item.text))
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .accessibilityElement(children: .combine)
                    }
                }

                Text("Everything can be changed anytime in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button(action: onFinish) {
                    Text("Start Exploring")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .accessibilityHint(String(localized: "Completes setup and opens the main app."))
            }
            .padding(.top, 48)
        }
        // Onboarding's own finale, structurally separate from the Welcome
        // Tour's — same reasoning as GuidedExperienceView's last step:
        // ConfettiView already hides itself from VoiceOver and disables hit
        // testing, so only the Reduce Motion gate is needed here.
        .overlay {
            if !reduceMotion {
                ConfettiView()
            }
        }
        .onAppear {
            let summary = summaryItems.map(\.text).joined(separator: ". ")
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                UIAccessibility.post(notification: .announcement, argument: "Setup complete. \(summary).")
            }
        }
    }
}

// MARK: - Recommended badge

/// Marks the pre-highlighted option on a binary-choice step (New Activity
/// Display, Apple Topics, Language Filter) — those steps commit and advance
/// on a single tap instead of select-then-Continue, so there's no separate
/// moment to show a theme-style "Selected" checkmark. This is the only way
/// those steps say "this one's our default," matching what the highlighted
/// `.borderedProminent` button already implies visually. Requested directly.
private struct RecommendedBadge: View {
    var body: some View {
        Text("Recommended")
            .font(.caption2)
            .fontWeight(.bold)
            .textCase(.uppercase)
            .tracking(0.4)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(.white.opacity(0.25), in: Capsule())
    }
}

