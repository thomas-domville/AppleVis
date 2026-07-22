import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var preferences: PreferencesStore

    @State private var step = 0
    private let totalSteps = 6

    var body: some View {
        ZStack {
            switch step {
            case 0: WelcomeStep(onNext: nextStep)
            case 1: SignInStep(onNext: nextStep, onSkip: nextStep)
            case 2: ThemeStep(onNext: nextStep)
            case 3: AnnouncementStep(onNext: nextStep)
            case 4: NotificationsStep(onNext: nextStep)
            case 5: ReadyStep(onFinish: finish)
            default: EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    private func nextStep() {
        withAnimation { step = min(step + 1, totalSteps - 1) }
    }

    private func finish() {
        auth.completeOnboarding()
    }
}

// MARK: - Step 1: Welcome

private struct WelcomeStep: View {
    let onNext: () -> Void

    private let features: [(icon: String, title: String, desc: String)] = [
        ("voiceover",       "Built for VoiceOver",         "Every screen crafted for screen-reader access from the ground up."),
        ("person.3",        "Community-Driven",             "Tips, reviews, and guides contributed by blind and low-vision users."),
        ("newspaper",       "All the Content You Need",     "Forums, app reviews, podcasts, tutorials, and news in one place."),
        ("paintbrush",      "Accessible Themes",            "High-contrast and low-vision-friendly themes built in."),
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

                    Text("The community for blind and low-vision Apple users.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 48)

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
                .accessibilityHint("Advances to the next setup step.")
            }
        }
    }
}

// MARK: - Step 2: Sign In

private struct SignInStep: View {
    @EnvironmentObject private var auth: AuthStore
    let onNext: () -> Void
    let onSkip: () -> Void

    @State private var username = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                OnboardingHeader(
                    icon: "person.crop.circle",
                    title: "Sign In",
                    subtitle: "Sign in to post in forums, track saved items, and sync across devices. You can skip this and sign in later."
                )

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Username").font(.caption).foregroundStyle(.secondary)
                        TextField("Username", text: $username)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityLabel("Username field")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password").font(.caption).foregroundStyle(.secondary)
                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Password field")
                    }

                    if let error = auth.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .accessibilityLabel("Error: \(error)")
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
                    .disabled(username.isEmpty || password.isEmpty || auth.isLoading)

                    Button("Skip for Now", action: onSkip)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .padding(.top, 48)
        }
    }

    private func signIn() {
        Task {
            await auth.signIn(username: username, password: password)
            if auth.isSignedIn { onNext() }
        }
    }
}

// MARK: - Step 3: Theme

private struct ThemeStep: View {
    @EnvironmentObject private var preferences: PreferencesStore
    let onNext: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                OnboardingHeader(
                    icon: "paintbrush",
                    title: "Choose a Theme",
                    subtitle: "Pick your preferred colour scheme. You can always change this later in Settings."
                )

                VStack(spacing: 12) {
                    ForEach(AppTheme.allCases) { theme in
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

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                OnboardingHeader(
                    icon: "speaker.wave.3",
                    title: "VoiceOver Detail Level",
                    subtitle: "How much information should VoiceOver announce for each content item? You can change this in Accessibility Settings."
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
                        .accessibilityAddTraits(preferences.announcementLevel == level ? [.isSelected] : [])
                        .accessibilityHint("Preview: \(level.preview)")
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

    @State private var permissionGranted: Bool? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                OnboardingHeader(
                    icon: "bell.badge",
                    title: "Notifications",
                    subtitle: "Choose which alerts you'd like to receive. You can update these anytime in Settings."
                )

                VStack(spacing: 0) {
                    NotifToggle("New Forum Topics",  isOn: $preferences.notifyNewTopics)
                    NotifToggle("New Podcast Episodes", isOn: $preferences.notifyNewEpisodes)
                    NotifToggle("Announcements",     isOn: $preferences.notifyAnnouncements)
                    NotifToggle("New App Listings",  isOn: $preferences.notifyAppUpdates)
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
            let granted = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            permissionGranted = granted == true
            if permissionGranted == true { onNext() }
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
                    subtitle: "AppleVis is ready for you. Here's a summary of your setup:"
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
                .accessibilityHint("Completes setup and opens the main app.")
            }
            .padding(.top, 48)
        }
    }
}

// MARK: - Shared header

private struct OnboardingHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
    }
}
