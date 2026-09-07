import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var showSignIn = false
    @State private var showContact = false
    @State private var showWelcomeTour = false
    @AccessibilityFocusState private var focusTarget: AnyHashable?
    private static let titleFocusID = AnyHashable("profile.title")

    var body: some View {
        NavigationStack {
            List {
                if let user = auth.user {
                    signedInContent(user)
                } else {
                    signedOutContent
                }

                settingsSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .themedList(preferences.colors)
            .navigationTitle("Profile")
            .task { await retryAccessibilityFocus(into: $focusTarget, returningTo: Self.titleFocusID) }
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
        .sheet(isPresented: $showContact) {
            ContactView()
        }
        .sheet(isPresented: $showWelcomeTour) {
            GuidedExperienceView(experience: GuidedExperienceRegistry.welcome)
        }
    }

    // MARK: - Signed-in content

    @ViewBuilder
    private func signedInContent(_ user: AuthUser) -> some View {
        Section {
            NavigationLink {
                AccountDetailView(user: user)
                    .onDisappear {
                        Task { await retryAccessibilityFocus(into: $focusTarget, returningTo: Self.titleFocusID) }
                    }
            } label: {
                HStack(spacing: 14) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 52, height: 52)
                        .overlay(
                            Text(String(user.name.prefix(1)).uppercased())
                                .font(.title2).fontWeight(.bold).foregroundStyle(.white)
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name).font(.headline)
                        if user.isAdmin {
                            Label("Administrator", systemImage: "star.fill")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Purely a visual state indicator — the accessible text is
                    // already covered by this card's combined accessibility
                    // label below.
                    Text("Signed In")
                        .font(.caption2).fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.green, in: Capsule())
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 4)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "Signed in as \(user.name)\(user.isAdmin ? ", Administrator" : "")"))
            .accessibilityHint(String(localized: "Opens My Account for profile, password, email, and sign out options."))
            .accessibilityFocused($focusTarget, equals: Self.titleFocusID)
        }
    }

    // MARK: - Signed-out content

    private var signedOutContent: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sign In")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($focusTarget, equals: Self.titleFocusID)
                Text("Sign in to post in forums, follow topics, receive notifications, and sync your saved items.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button("Sign in to AppleVis") {
                    showSignIn = true
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(String(localized: "Sign in to your AppleVis account"))
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Settings section

    private var settingsSection: some View {
        Section("App") {
            NavigationLink {
                SettingsView()
                    .onDisappear {
                        Task { await retryAccessibilityFocus(into: $focusTarget, returningTo: AnyHashable("settings")) }
                    }
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .accessibilityFocused($focusTarget, equals: AnyHashable("settings"))
            .accessibilityLabel(String(localized: "Open Settings"))
        }
    }

    // MARK: - About section

    private var aboutSection: some View {
        Section("About AppleVis") {
            NavigationLink {
                WhatsNewView()
                    .onDisappear {
                        Task { await retryAccessibilityFocus(into: $focusTarget, returningTo: AnyHashable("whatsNew")) }
                    }
            } label: {
                Label("What's New", systemImage: "sparkles")
            }
            .accessibilityFocused($focusTarget, equals: AnyHashable("whatsNew"))
            .accessibilityLabel(String(localized: "What's New in AppleVis"))

            NavigationLink {
                AboutView()
                    .onDisappear {
                        Task { await retryAccessibilityFocus(into: $focusTarget, returningTo: AnyHashable("about")) }
                    }
            } label: {
                Label("About & Credits", systemImage: "info.circle")
            }
            .accessibilityFocused($focusTarget, equals: AnyHashable("about"))

            Button {
                // Force a true restart — without this, if the tour is
                // currently `dismissed` (paused mid-tour via Explore This
                // Screen) rather than `completed`, GuidedExperienceView's
                // own resume logic would jump back into the middle of it
                // instead of actually replaying from step 1.
                GuidedExperienceStore.restart(GuidedExperienceRegistry.welcome.id)
                showWelcomeTour = true
            } label: {
                Label("Replay Welcome Tour", systemImage: "arrow.clockwise")
            }
            .accessibilityLabel(String(localized: "Replay Welcome Tour"))
            .accessibilityHint(String(localized: "Replays the short guided tour of Home, Discover, For You, Search, Profile, and Settings."))

            // Privacy Policy and Terms of Service used to be repeated here
            // directly, one tap away from the identical pair inside "About &
            // Credits" right above — About & Credits is the one home for
            // them now. Reported directly.

            Button {
                showContact = true
            } label: {
                Label("Contact AppleVis", systemImage: "envelope")
            }
            .accessibilityLabel(String(localized: "Contact AppleVis"))

            HStack {
                Text("Version")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                String(localized: "Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")")
            )
        }
    }
}
