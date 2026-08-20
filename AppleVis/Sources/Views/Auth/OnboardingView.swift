import SwiftUI
import UserNotifications
import UIKit

struct OnboardingView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var preferences: PreferencesStore

    @State private var step = 0
    @State private var showCancelConfirm = false
    private let totalSteps = 7
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
                case 2: SignedOutHistoryStep(onNext: nextStep, headerFocus: $isStepHeaderFocused, stepInfo: (3, totalSteps))
                case 3: ThemeStep(onNext: nextStep, headerFocus: $isStepHeaderFocused, stepInfo: (4, totalSteps))
                case 4: AnnouncementStep(onNext: nextStep, headerFocus: $isStepHeaderFocused, stepInfo: (5, totalSteps))
                case 5: NotificationsStep(onNext: nextStep, headerFocus: $isStepHeaderFocused, stepInfo: (6, totalSteps))
                case 6: ReadyStep(onFinish: finish, headerFocus: $isStepHeaderFocused, stepInfo: (7, totalSteps))
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
        let next = step == 1 && auth.isSignedIn ? 3 : min(step + 1, totalSteps - 1)
        withReduceMotionAwareAnimation { step = next }
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            isStepHeaderFocused = true
        }
    }

    private func previousStep() {
        let previous = step == 3 && auth.isSignedIn ? 1 : max(step - 1, 0)
        withReduceMotionAwareAnimation { step = previous }
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            isStepHeaderFocused = true
        }
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

    private let features: [(icon: String, title: String, desc: String)] = [
        // Was "Built for VoiceOver" — every app claims some variant of this
        // wording now, so it reads as filler rather than a real signal.
        // "Community-Driven" below already covers who makes AppleVis, so
        // this one names something concrete instead: real testing, not a
        // slogan. Reported by a beta tester.
        ("voiceover",       "Tested, Not Just Labeled",    "Every screen is actually used and tested with VoiceOver, not just checked off against a guideline."),
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
                    Text("This is a rebuilt version of the app. Your forum posts, reviews, and account are all still there on the website — just sign back in. Local settings like your saved episodes and preferences were reset and will need to be set up again.")
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
                                .frame(width: 32)
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
    let onNext: () -> Void
    let onSkip: () -> Void
    let headerFocus: AccessibilityFocusState<Bool>.Binding
    var stepInfo: (current: Int, total: Int)? = nil

    @State private var username = ""
    @State private var password = ""
    @State private var validationMessage: String?
    @AccessibilityFocusState private var isErrorFocused: Bool
    @AccessibilityFocusState private var isUsernameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                OnboardingHeader(
                    icon: "person.crop.circle",
                    title: "Sign In",
                    subtitle: "Sign in to post in forums, track saved items, and sync across devices. You can skip this and sign in later.",
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
                            .accessibilityFocused($isUsernameFocused)
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
                            .foregroundStyle(.red)
                            .accessibilityFocused($isErrorFocused)
                    } else if let error = auth.error {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                            Text("If you have forgotten your password, you can reset it on the AppleVis website.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Link("Reset Password", destination: URL(string: "https://www.applevis.com/user/password")!)
                                .font(.caption).fontWeight(.semibold)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(String(localized: "Error: \(error). If you have forgotten your password, you can reset it on the AppleVis website."))
                        .accessibilityFocused($isErrorFocused)
                    }

                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .font(.caption).foregroundStyle(.secondary)
                        Link("Sign up for free", destination: URL(string: "https://www.applevis.com/user/register")!)
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
                return
            }
            // RN focuses the username field directly on this step instead
            // of the generic header every other step gets, since this is
            // the one step that's actually a form.
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                isUsernameFocused = true
            }
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

// MARK: - Step 3: Signed-Out Reading History

private struct SignedOutHistoryStep: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var preferences: PreferencesStore
    let onNext: () -> Void
    let headerFocus: AccessibilityFocusState<Bool>.Binding
    var stepInfo: (current: Int, total: Int)? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                OnboardingHeader(
                    icon: "clock.arrow.circlepath",
                    title: "Remember What You've Read?",
                    subtitle: "If you stay signed out, AppleVis can optionally remember what you open on this device so Home can show what's new since your last visit.",
                    headerFocus: headerFocus,
                    stepInfo: stepInfo
                )

                VStack(alignment: .leading, spacing: 12) {
                    Label("Signed-in users use their AppleVis account history.", systemImage: "person.crop.circle.badge.checkmark")
                    Label("Signed-out history stays on this device.", systemImage: "iphone")
                    Label("You can change this later in Settings > Privacy.", systemImage: "hand.raised")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
                .accessibilityElement(children: .combine)

                VStack(spacing: 12) {
                    Button {
                        preferences.rememberSignedOutHistory = true
                        onNext()
                    } label: {
                        VStack(spacing: 4) {
                            Text("Yes, Remember on This Device")
                                .font(.headline)
                            Text("Home can show what's new since your last visit.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        preferences.rememberSignedOutHistory = false
                        PersistenceStore.shared.clearLocalReadHistory()
                        onNext()
                    } label: {
                        VStack(spacing: 4) {
                            Text("No, Don't Remember")
                                .font(.headline)
                            Text("Signed-out AppleVis will act more like the website.")
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
        .onAppear {
            if auth.isSignedIn {
                onNext()
            }
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
                                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
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

// MARK: - Step 4: VoiceOver Detail Level

private struct AnnouncementStep: View {
    @EnvironmentObject private var preferences: PreferencesStore
    let onNext: () -> Void
    let headerFocus: AccessibilityFocusState<Bool>.Binding
    var stepInfo: (current: Int, total: Int)? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                OnboardingHeader(
                    icon: "speaker.wave.3",
                    title: "VoiceOver Detail Level",
                    subtitle: "How much information should VoiceOver announce for each content item? You can change this in Accessibility Settings.",
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
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
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
    }
}

// MARK: - Step 5: Notifications

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
                    NotifToggle("New Forum Topics",  isOn: $preferences.notifyNewTopics)
                    NotifToggle("New Podcast Episodes", isOn: $preferences.notifyNewEpisodes)
                    NotifToggle("Announcements",     isOn: $preferences.notifyAnnouncements)
                    NotifToggle("New App Directory Entries", isOn: $preferences.notifyAppUpdates)
                }
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
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
                            if sound != NotificationSound.allCases.last {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
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

// MARK: - Step 6: Ready

private struct ReadyStep: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var auth: AuthStore
    let onFinish: () -> Void
    let headerFocus: AccessibilityFocusState<Bool>.Binding
    var stepInfo: (current: Int, total: Int)? = nil

    private var summaryItems: [(icon: String, text: String)] {
        var items: [(String, String)] = []
        items.append(("paintbrush", "Theme: \(preferences.theme.displayName)"))
        items.append(("speaker.wave.2", "VoiceOver: \(preferences.announcementLevel.displayName)"))
        if auth.isSignedIn { items.append(("person.crop.circle.fill", "Signed in as \(auth.user!.name)")) }
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
                                .frame(width: 28)
                                .accessibilityHidden(true)
                            Text(item.text)
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
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel(stepInfo.map { String(localized: "\(title). Step \($0.current) of \($0.total).") } ?? title)
                .modifier(OptionalAccessibilityFocus(isFocused: headerFocus))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }
}
