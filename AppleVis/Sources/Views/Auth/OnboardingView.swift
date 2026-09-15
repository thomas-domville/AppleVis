import SwiftUI
import UserNotifications
import UIKit

struct OnboardingView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var preferences: PreferencesStore

    @State private var step = 0
    @State private var showCancelConfirm = false
    private let totalSteps = 9
    /// Every step's header binds to this so VoiceOver focus moves there after
    /// Next/Skip — previously each step was a distinct pushed screen in the
    /// old RN app, which got an automatic focus/announcement from React
    /// Navigation's screen transition for free; collapsing all 6 steps into
    /// one ZStack + switch here lost that for free, and nothing was added to
    /// compensate, so every step change was completely silent for VoiceOver.
    @AccessibilityFocusState private var isStepHeaderFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            chrome
            Group {
                switch step {
                case 0: WelcomeStep(onNext: nextStep, headerFocus: $isStepHeaderFocused, stepInfo: (1, totalSteps))
                case 1: SignInStep(onNext: nextStep, onSkip: nextStep, headerFocus: $isStepHeaderFocused, stepInfo: (2, totalSteps))
                case 2: NewActivityDisplayStep(onNext: nextStep, headerFocus: $isStepHeaderFocused, stepInfo: (3, totalSteps))
                case 3: ThemeStep(onNext: nextStep, headerFocus: $isStepHeaderFocused, stepInfo: (4, totalSteps))
                case 4: AnnouncementStep(onNext: nextStep, headerFocus: $isStepHeaderFocused, stepInfo: (5, totalSteps))
                case 5: AppleTopicsStep(onNext: nextStep, headerFocus: $isStepHeaderFocused, stepInfo: (6, totalSteps))
                case 6: LanguageFilterStep(onNext: nextStep, headerFocus: $isStepHeaderFocused, stepInfo: (7, totalSteps))
                case 7: NotificationsStep(onNext: nextStep, headerFocus: $isStepHeaderFocused, stepInfo: (8, totalSteps))
                case 8: ReadyStep(onFinish: finish, headerFocus: $isStepHeaderFocused, stepInfo: (9, totalSteps))
                default: EmptyView()
                }
            }
        }
        .animation(UIAccessibility.isReduceMotionEnabled ? nil : .easeInOut(duration: 0.3), value: step)
        .background(preferences.colors.background)
        .confirmationDialog(
            "Skip the rest of setup?",
            isPresented: $showCancelConfirm, titleVisibility: .visible
        ) {
            Button("Skip Setup", role: .destructive) { finish() }
            Button("Continue Setup", role: .cancel) {}
        } message: {
            Text("You can change these settings anytime later in Settings.")
        }
    }

    /// Persistent Back/Cancel/progress row shown above every step — RN's
    /// shared WizardLayout gave every onboarding screen a Back button (once
    /// past the first step), a Cancel button, and a step-progress indicator
    /// (both visual dots and a "Step X of Y" VoiceOver announcement). None
    /// of this existed here: there was no way back once you'd advanced, no
    /// way to bail out of setup early, and no sense of progress at all.
    private var chrome: some View {
        VStack(spacing: 8) {
            HStack {
                if step > 0 {
                    Button(action: previousStep) {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .accessibilityHint(String(localized: "Returns to the previous step."))
                }
                Spacer()
                Button("Cancel") { showCancelConfirm = true }
                    .accessibilityHint(String(localized: "Cancels and closes this form."))
            }

            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: i == step ? 20 : 6, height: 6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Step \(step + 1) of \(totalSteps)"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
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
        // Can't land back on step 1 (SignIn): SignInStep's own onAppear
        // immediately calls onNext() whenever already signed in, which
        // just bounces straight back to step 2 — Back would silently do
        // nothing. Welcome is the nearest step that's actually a valid
        // destination for a signed-in user going back from Signed-Out
        // History (step 2), which — unlike SignIn — now shows a
        // sign-in-aware variant of its own content instead of skipping.
        let previous = step == 2 && auth.isSignedIn ? 0 : max(step - 1, 0)
        withReduceMotionAwareAnimation { step = previous }
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
    var stepInfo: (current: Int, total: Int)? = nil
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
                    Image(systemName: "eye.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)

                    Text("Welcome to AppleVis")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityLabel(stepInfo.map { String(localized: "Welcome to AppleVis. Step \($0.current) of \($0.total).") } ?? String(localized: "Welcome to AppleVis"))
                        .modifier(OptionalAccessibilityFocus(isFocused: headerFocus))

                    Text("The community for blind and low-vision Apple users.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
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

                Button(action: onNext) {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .accessibilityHint(String(localized: "Advances to the next setup step."))
            }
        }
    }
}

// MARK: - Step 2: Sign In

private struct SignInStep: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var preferences: PreferencesStore
    let onNext: () -> Void
    let onSkip: () -> Void
    let headerFocus: AccessibilityFocusState<Bool>.Binding
    var stepInfo: (current: Int, total: Int)? = nil

    @State private var username = ""
    @State private var password = ""
    @State private var validationMessage: String?
    @AccessibilityFocusState private var isErrorFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                OnboardingHeader(
                    icon: "person.crop.circle",
                    title: "Sign In",
                    subtitle: "Sign in to post content, track saved items, and sync your activity between the AppleVis app and website. You can skip this and sign in later.",
                    headerFocus: headerFocus,
                    stepInfo: stepInfo
                )

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
            // "Sign In. Step 2 of 8." or explanation unless they swiped
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

// MARK: - Step 3: New Activity Display

private struct NewActivityDisplayStep: View {
    @EnvironmentObject private var preferences: PreferencesStore
    let onNext: () -> Void
    let headerFocus: AccessibilityFocusState<Bool>.Binding
    var stepInfo: (current: Int, total: Int)? = nil

    // Previously asked whether to remember reading history at all — but
    // that conflated two different things: whether AppleVis tracks what
    // you've read (needed for All/New/Recap to work, purely on-device,
    // never transmitted while signed out, so there's no real reason to
    // ever turn it off) versus whether Home actually *shows* new-activity
    // indicators (something people genuinely have different preferences
    // about — some find a running tally of what's new distracting rather
    // than helpful). Tracking itself is now unconditional; this step only
    // sets `showNewActivityIndicators`. Same reasoning as before for why
    // every user still sees all 8 steps rather than this one being skipped
    // for anyone: the total was announced up front, so silently skipping a
    // step would break the count a VoiceOver user was already told.
    // Requested directly.
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                OnboardingHeader(
                    icon: "bell.badge",
                    title: "Show What's New?",
                    subtitle: "Home can highlight what's changed since your last visit — a New view alongside All and Mouse Recap, a quick summary card, and small badges on cards with new activity.",
                    headerFocus: headerFocus,
                    stepInfo: stepInfo
                )

                VStack(alignment: .leading, spacing: 12) {
                    Label("A short summary and a New view each time you open Home.", systemImage: "sparkles")
                    Label("Small badges on cards with new replies or comments.", systemImage: "text.badge.plus")
                    Label("You can change this anytime in Settings > Privacy.", systemImage: "hand.raised")
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
                            Text("Yes, Show What's New")
                                .font(.headline)
                            Text("The default — a New view, badges, and a quick summary on Home.")
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

// MARK: - Step 4: Theme

private struct ThemeStep: View {
    @EnvironmentObject private var preferences: PreferencesStore
    let onNext: () -> Void
    let headerFocus: AccessibilityFocusState<Bool>.Binding
    var stepInfo: (current: Int, total: Int)? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                OnboardingHeader(
                    icon: "paintbrush",
                    title: "Choose a Theme",
                    subtitle: "Pick your preferred colour scheme. You can always change this later in Settings.",
                    headerFocus: headerFocus,
                    stepInfo: stepInfo
                )

                VStack(alignment: .leading, spacing: 20) {
                    ForEach(ThemeGroup.allCases) { group in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(group.label)
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            VStack(spacing: 12) {
                                ForEach(AppTheme.allCases.filter { $0.group == group }) { theme in
                                    Button {
                                        preferences.theme = theme
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
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
    }

}

// MARK: - Step 5: VoiceOver Detail Level

private struct AnnouncementStep: View {
    @EnvironmentObject private var preferences: PreferencesStore
    let onNext: () -> Void
    let headerFocus: AccessibilityFocusState<Bool>.Binding
    var stepInfo: (current: Int, total: Int)? = nil

    // A beta tester flagged that this step reads as a non-sequitur for
    // low-vision users who rely on Zoom/large text/contrast instead of
    // VoiceOver — "how much should VoiceOver announce" means nothing if
    // you don't use VoiceOver. Rather than skip the step (which would
    // reintroduce the same step-count discontinuity fixed on Signed-Out
    // History), the choice stays available to everyone and only the
    // framing adapts: the announcementLevel preference takes effect the
    // moment VoiceOver is turned on, so setting it in advance is a real,
    // forward-looking choice even for someone not currently using it.
    @State private var isVoiceOverRunning = UIAccessibility.isVoiceOverRunning

    private var title: String {
        isVoiceOverRunning ? "VoiceOver Detail Level" : "In Case You Use VoiceOver"
    }
    private var subtitle: String {
        isVoiceOverRunning
            ? "How much information should VoiceOver announce for each content item? You can change this in Accessibility Settings."
            : "If you or someone else using this device turns on VoiceOver later, how much detail should it announce for each item? You can change this anytime in Accessibility Settings."
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                OnboardingHeader(
                    icon: "speaker.wave.3",
                    title: title,
                    subtitle: subtitle,
                    headerFocus: headerFocus,
                    stepInfo: stepInfo
                )

                VStack(spacing: 12) {
                    ForEach(AnnouncementLevel.allCases) { level in
                        Button {
                            preferences.announcementLevel = level
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(level.displayName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if preferences.announcementLevel == level {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.accentColor)
                                            .accessibilityHidden(true)
                                    }
                                }
                                Text(level.preview)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .italic()
                            }
                            .padding(16)
                            .background(preferences.colors.card, in: RoundedRectangle(cornerRadius: 12))
                        }
                        // VoiceOver was auto-combining the displayName Text and the
                        // italic preview Text with no indication the second one was
                        // an example rather than a description, and the hint then
                        // repeated the same preview text again. A beta tester asked
                        // for this to clearly say "<Level>. Example: <preview>" once.
                        .accessibilityLabel(String(localized: "\(level.displayName). Example: \(level.preview)"))
                        .accessibilityAddTraits(preferences.announcementLevel == level ? [.isSelected] : [])
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
        .onAppear { isVoiceOverRunning = UIAccessibility.isVoiceOverRunning }
        .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)) { _ in
            isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        }
    }
}

// MARK: - Step 6: Apple Topics

private struct AppleTopicsStep: View {
    @EnvironmentObject private var preferences: PreferencesStore
    let onNext: () -> Void
    let headerFocus: AccessibilityFocusState<Bool>.Binding
    var stepInfo: (current: Int, total: Int)? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                OnboardingHeader(
                    icon: "apps.iphone",
                    title: "Apple Topics Only?",
                    subtitle: "Forums on AppleVis include some non-Apple topics too. Want Home and Forums to focus on Apple only?",
                    headerFocus: headerFocus,
                    stepInfo: stepInfo
                )

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
    let headerFocus: AccessibilityFocusState<Bool>.Binding
    var stepInfo: (current: Int, total: Int)? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                OnboardingHeader(
                    icon: "text.badge.checkmark",
                    title: "Filter Milder Language?",
                    subtitle: "AppleVis always blocks strong or explicit language from every post and comment — that never changes. This is just about whether milder language, which the site otherwise allows, shows up masked or spelled out.",
                    headerFocus: headerFocus,
                    stepInfo: stepInfo
                )

                VStack(alignment: .leading, spacing: 12) {
                    Label("Masked text looks like \"s***\" instead of the word spelled out.", systemImage: "text.badge.checkmark")
                    Label("We keep this on by default to help AppleVis stay welcoming, and to stay within Apple's guidelines for our age rating.", systemImage: "checkmark.shield")
                    Label("Change this anytime in Settings > Privacy.", systemImage: "hand.raised")
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
    let headerFocus: AccessibilityFocusState<Bool>.Binding
    var stepInfo: (current: Int, total: Int)? = nil

    @State private var permissionGranted: Bool? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                OnboardingHeader(
                    icon: "bell.badge",
                    title: "Notifications",
                    subtitle: "Choose which alerts you'd like to receive. You can update these anytime in Settings.",
                    headerFocus: headerFocus,
                    stepInfo: stepInfo
                )

                VStack(spacing: 0) {
                    // "Announcements" removed from onboarding — AppleVis has
                    // no "announcement" content type of its own;
                    // announcements are posted to the Blog, Forum, or
                    // Newsletter, each already covered by its own category
                    // here. (Settings > Notifications still has this toggle
                    // too — flagged separately, not touched in this pass.)
                    // Reported directly.
                    NotifToggle("New Forum Topics",  isOn: $preferences.notifyNewTopics)
                    NotifToggle("New Podcast Episodes", isOn: $preferences.notifyNewEpisodes)
                    NotifToggle("New App Directory Entries", isOn: $preferences.notifyAppUpdates)
                }
                .background(preferences.colors.card, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)

                // Sound picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notification Sound")
                        .font(.headline)
                        .padding(.horizontal, 24)
                    VStack(spacing: 0) {
                        ForEach(NotificationSound.allCases) { sound in
                            Button {
                                preferences.notificationSound = sound
                                SoundPlayer.shared.playNotificationPreview(sound)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(sound.displayName)
                                            .foregroundStyle(.primary)
                                        Text(sound.description)
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
                            .accessibilityAction(named: Text("Preview")) {
                                SoundPlayer.shared.playNotificationPreview(sound)
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
    let headerFocus: AccessibilityFocusState<Bool>.Binding
    var stepInfo: (current: Int, total: Int)? = nil
    // See WelcomeStep.featureIconWidth — same fixed-vs-scaling mismatch
    // against the adjacent summary text.
    @ScaledMetric(relativeTo: .body) private var summaryIconWidth: CGFloat = 28

    private var summaryItems: [(icon: String, text: String)] {
        var items: [(String, String)] = []
        items.append(("paintbrush", "Theme: \(preferences.theme.displayName)"))
        items.append(("speaker.wave.2", "VoiceOver: \(preferences.announcementLevel.displayName)"))
        if auth.isSignedIn { items.append(("person.crop.circle.fill", "Signed in as \(auth.user!.name)")) }
        items.append(("apps.iphone", preferences.appleOnlyForums ? "Forums: Apple Topics Only" : "Forums: Everything"))
        items.append(("text.badge.checkmark", preferences.filterProfanity ? "Language: Milder Language Filtered" : "Language: Show Everything"))
        // The choices made on the Notifications step (categories, sound)
        // never appeared anywhere in this summary — the only step in the
        // whole wizard whose configuration wasn't reflected back to the
        // user before finishing. Reported directly.
        let enabledCategories = [
            preferences.notifyNewTopics ? "New Forum Topics" : nil,
            preferences.notifyNewEpisodes ? "New Podcast Episodes" : nil,
            preferences.notifyAppUpdates ? "New App Directory Entries" : nil,
        ].compactMap { $0 }
        items.append(enabledCategories.isEmpty
            ? ("bell.slash", "Notifications: Off")
            : ("bell.badge", "Notifications: \(enabledCategories.joined(separator: ", "))")
        )
        return items
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                OnboardingHeader(
                    icon: "checkmark.circle.fill",
                    title: "You're All Set",
                    subtitle: "AppleVis is ready for you. Here's a summary of your setup:",
                    headerFocus: headerFocus,
                    stepInfo: stepInfo
                )

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

// MARK: - Shared header

private struct OnboardingHeader: View {
    let icon: String
    let title: String
    let subtitle: String
    var headerFocus: AccessibilityFocusState<Bool>.Binding? = nil
    /// (current, total) — appended to the spoken header so a VoiceOver user
    /// gets a sense of progress through the flow, matching RN's
    /// `"${title}. Step ${step} of ${totalSteps}."` pattern. Previously
    /// only the bare title was spoken.
    var stepInfo: (current: Int, total: Int)? = nil

    // `title`/`subtitle` are runtime String values (some steps compute them
    // conditionally on sign-in/VoiceOver state), not string literals —
    // Text(_ content: String) and String(localized: "\(title)...") both
    // treat a String argument as already-resolved display text and skip
    // catalog lookup entirely, so every step header in this wizard was
    // silently never being translated, catalog entries or not. Wrapping in
    // LocalizedStringKey/String.LocalizationValue (same fix already used in
    // WizardComponents.swift for this exact problem) routes it back
    // through the catalog using the string's own text as the key.
    private var localizedTitle: String { String(localized: String.LocalizationValue(title)) }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            // Title and subtitle used to be one combined swipe-stop, with
            // the full explanation folded into the same spoken label as the
            // heading — a beta tester found this made the heading read as
            // long and unclear. Splitting them (matching WelcomeStep's
            // existing pattern below) gives VoiceOver users a short heading
            // as one swipe-stop and the explanation as its own, separate
            // swipe-stop right after it.
            Text(LocalizedStringKey(title))
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel(stepInfo.map { String(localized: "\(localizedTitle). Step \($0.current) of \($0.total).") } ?? localizedTitle)
                .modifier(OptionalAccessibilityFocus(isFocused: headerFocus))
            Text(LocalizedStringKey(subtitle))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }
}
