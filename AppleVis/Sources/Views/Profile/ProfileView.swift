import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var communityAgreement: CommunityAgreementStore
    @State private var showSignIn = false
    /// Gates `showSignIn` below — see `CommunityAgreementStore`. Shown
    /// first only when the current version hasn't been accepted yet;
    /// declining leaves `showSignIn` untouched.
    @State private var showCommunityAgreement = false
    @State private var showContact = false
    @State private var showWelcomeTour = false
    /// Replaying after the tour has been finished once offers its chapters,
    /// so someone looking for one thing doesn't have to go through it all.
    /// Suggested by a beta tester (2026-10-08).
    @State private var showTourChapters = false
    @State private var tourStartStep: Int?
    @State private var showSettings = false
    /// The row that opened a pushed screen, so VoiceOver goes back to it
    /// after a real Back (see `returnsFocusOnBack`), and whether the title
    /// has had its first focus (2026-10-09).
    @State private var returnFocus: AnyHashable?
    @State private var didFocusTitle = false
    /// Profile has its own navigation stack only as a sheet (Command-Comma).
    /// Pushed from Home, Discover, or For You, it uses their stack: a stack
    /// inside a stack isn't supported, and Help's article links could be
    /// taken by the wrong one, which can look like a jump back to Home
    /// (2026-10-09).
    var isInSheet = false
    /// Set by Settings' Done button, so closing Settings also leaves
    /// Profile and goes straight back to browsing. Swiping the sheet away
    /// instead returns to Profile as before.
    @State private var leaveProfileAfterSettings = false
    @Environment(\.dismiss) private var dismiss
    @AccessibilityFocusState private var focusTarget: AnyHashable?
    private static let titleFocusID = AnyHashable("profile.title")

    @ViewBuilder
    private func stackIfSheet<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if isInSheet {
            AppNavigationStack { content() }
        } else {
            content()
        }
    }

    var body: some View {
        stackIfSheet {
            List {
                if let user = auth.user {
                    signedInContent(user)
                    if user.isAdmin {
                        adminSection
                    }
                } else {
                    signedOutContent
                }

                settingsSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .themedList(preferences.colors)
            .navigationTitle("Profile")
            // The title only the first time; after Back, the row you came
            // from instead.
            .task {
                guard !didFocusTitle else { return }
                didFocusTitle = true
                await retryAccessibilityFocus(into: $focusTarget, returningTo: Self.titleFocusID)
            }
            .returnsFocusOnBack($returnFocus, into: $focusTarget)
            .navigationLog("Profile")
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
        .communityAgreementGate(
            showCommunityAgreement: $showCommunityAgreement,
            showSignIn: $showSignIn,
            declineHint: String(localized: "Returns to Profile without signing in. You can review the agreement again later.")
        )
        // Closing a sheet (sent or cancelled) otherwise drops VoiceOver on
        // the tab's back button; put it back on the row that opened it.
        // Reported directly.
        .sheet(isPresented: $showContact, onDismiss: {
            Task { await retryAccessibilityFocus(into: $focusTarget, returningTo: AnyHashable("contact")) }
        }) {
            ContactView()
        }
        // Settings opens as a sheet with Done on every screen, instead of
        // being pushed here: finishing a change in General meant several
        // Back presses to get back to browsing. Reported by a beta tester.
        .sheet(isPresented: $showSettings, onDismiss: {
            if leaveProfileAfterSettings {
                leaveProfileAfterSettings = false
                dismiss()
            } else {
                Task { await retryAccessibilityFocus(into: $focusTarget, returningTo: AnyHashable("settings")) }
            }
        }) {
            AppNavigationStack {
                SettingsView()
            }
            .environment(\.closeSettings, {
                leaveProfileAfterSettings = true
                showSettings = false
            })
        }
        .sheet(isPresented: $showWelcomeTour, onDismiss: {
            Task { await retryAccessibilityFocus(into: $focusTarget, returningTo: AnyHashable("welcomeTour")) }
        }) {
            GuidedExperienceView(experience: GuidedExperienceRegistry.welcome, startStep: tourStartStep)
        }
        .confirmationDialog("Replay Welcome Tour", isPresented: $showTourChapters, titleVisibility: .visible) {
            Button("Start from the Beginning") { replayTour(from: nil) }
            ForEach(GuidedExperienceRegistry.welcome.replayChapters, id: \.firstStep) { chapter in
                Button(LocalizedStringKey(chapter.title)) { replayTour(from: chapter.firstStep) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose where to start.")
        }
    }

    /// Restarts the tour, from the beginning or from a chosen chapter.
    private func replayTour(from step: Int?) {
        // Force a true restart — without this, if the tour is currently
        // `dismissed` (paused mid-tour via Explore This Screen) rather than
        // `completed`, GuidedExperienceView's own resume logic would jump
        // back into the middle of it instead of where was chosen.
        GuidedExperienceStore.restart(GuidedExperienceRegistry.welcome.id)
        tourStartStep = step
        showWelcomeTour = true
    }

    // MARK: - Signed-in content

    @ViewBuilder
    private func signedInContent(_ user: AuthUser) -> some View {
        Section {
            NavigationLink {
                AccountDetailView(user: user)
                    .notesReturnFocus(Self.titleFocusID, in: $returnFocus)
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
            .accessibilityLabel((user.isAdmin ? String(localized: "Signed in as \(user.name), Administrator") : String(localized: "Signed in as \(user.name)")))
            .accessibilityHint(String(localized: "Opens My Account for profile, password, email, and sign out options."))
            .accessibilityFocused($focusTarget, equals: Self.titleFocusID)
        }
    }

    // MARK: - Admin section
    // Admin/editor-only. Deliberately excluded from Help content, the
    // Welcome Tour, and What's New — this is internal team tooling, not a
    // user-facing feature, and gating on isAdmin already means almost
    // nobody would ever see a mention of it anyway. Applies to every item
    // added under this section going forward, not just the one below.
    // Requested directly.

    private var adminSection: some View {
        Section("Admin") {
            // Moderator Tools used to be its own hub screen holding just
            // this one row — an extra tap for no reason with only a single
            // tool in it. Flattened to match App Directory Health Check
            // below, which was already a direct row. Revisit grouping again
            // if this section grows enough tools to actually need it.
            // Discussed and requested directly.
            NavigationLink {
                GuidelineViolationCheckView()
                    .notesReturnFocus(AnyHashable("guidelineCheck"), in: $returnFocus)
            } label: {
                Label("Guideline Violation Check", systemImage: "text.magnifyingglass")
            }
            .accessibilityFocused($focusTarget, equals: AnyHashable("guidelineCheck"))
            .accessibilityHint(String(localized: "Scans recent activity across the site for possible guideline violations."))

            NavigationLink {
                AppEntryHealthCheckView()
                    .notesReturnFocus(AnyHashable("appHealthCheck"), in: $returnFocus)
            } label: {
                Label("App Directory Health Check", systemImage: "checkmark.shield")
            }
            .accessibilityFocused($focusTarget, equals: AnyHashable("appHealthCheck"))

            NavigationLink {
                DormantAccountsView()
                    .notesReturnFocus(AnyHashable("neverSignedIn"), in: $returnFocus)
            } label: {
                Label("Never Signed In", systemImage: "person.crop.circle.badge.questionmark")
            }
            .accessibilityFocused($focusTarget, equals: AnyHashable("neverSignedIn"))
            .accessibilityHint(String(localized: "Accounts created 30 or more days ago that have never signed in."))
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
                    communityAgreement.requestSignIn(showCommunityAgreement: $showCommunityAgreement, showSignIn: $showSignIn)
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
            Button {
                showSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .foregroundStyle(.primary)
            }
            .accessibilityFocused($focusTarget, equals: AnyHashable("settings"))
            .accessibilityLabel(String(localized: "Open Settings"))
        }
    }

    // MARK: - About section

    private var aboutSection: some View {
        Section("About AppleVis") {
            // Moved from Settings > Support, where it sat a level deeper
            // than it needed to (Profile > Settings > scroll to Support >
            // Help) despite being reference material people return to, not
            // a configuration screen — HelpView's own intro calls itself
            // "Your Offline Guide." Given its own home here instead of
            // staying duplicated in both places. Discussed and requested
            // directly.
            NavigationLink {
                HelpView()
                    .notesReturnFocus(AnyHashable("help"), in: $returnFocus)
            } label: {
                Label("Help", systemImage: "questionmark.circle")
            }
            .accessibilityFocused($focusTarget, equals: AnyHashable("help"))
            .accessibilityLabel(String(localized: "Help and Support"))

            NavigationLink {
                WhatsNewView()
                    .notesReturnFocus(AnyHashable("whatsNew"), in: $returnFocus)
            } label: {
                Label("What's New", systemImage: "sparkles")
            }
            .accessibilityFocused($focusTarget, equals: AnyHashable("whatsNew"))
            .accessibilityLabel(String(localized: "What's New in AppleVis"))

            NavigationLink {
                AboutView()
                    .notesReturnFocus(AnyHashable("about"), in: $returnFocus)
            } label: {
                Label("About & Credits", systemImage: "info.circle")
            }
            .accessibilityFocused($focusTarget, equals: AnyHashable("about"))

            Button {
                // Someone who has been through the tour before can pick a
                // chapter. A first-timer starts at the beginning as before.
                let progress = GuidedExperienceStore.getProgress(GuidedExperienceRegistry.welcome.id)
                if progress.completed || progress.replayCount > 0 {
                    showTourChapters = true
                } else {
                    replayTour(from: nil)
                }
            } label: {
                Label("Replay Welcome Tour", systemImage: "arrow.clockwise")
            }
            .accessibilityFocused($focusTarget, equals: AnyHashable("welcomeTour"))
            .accessibilityLabel(String(localized: "Replay Welcome Tour"))
            .accessibilityHint(String(localized: "Replays the guided tour of Home, Discover, For You, and Profile & Settings."))

            // Privacy Policy and Terms of Service used to be repeated here
            // directly, one tap away from the identical pair inside "About &
            // Credits" right above — About & Credits is the one home for
            // them now. Reported directly.

            Button {
                showContact = true
            } label: {
                Label("Contact AppleVis", systemImage: "envelope")
            }
            .accessibilityFocused($focusTarget, equals: AnyHashable("contact"))
            .accessibilityLabel(String(localized: "Contact AppleVis"))

            // AppleVis is a nonprofit under the Be My Eyes Foundation. Opens
            // the Foundation's Donate Now section in Safari, outside the app:
            // App Review 3.2.2(iv) allows a link out, and nothing is asked for
            // here first. No tax wording, since the Foundation's US charity
            // status is still pending. Requested directly (2026-10-09).
            Link(destination: URL(string: "https://www.bemyeyesfoundation.org/#donate-now")!) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Support AppleVis")
                        Text("Donate to the Be My Eyes Foundation")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "heart")
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "Support AppleVis. Donate to the Be My Eyes Foundation."))
            .accessibilityHint(String(localized: "Opens the Be My Eyes Foundation's website in Safari, outside the app."))

            HStack {
                Text("Version")
                    .foregroundStyle(.secondary)
                Spacer()
                // The build too: the version stays the same for every beta
                // until a public release, so testers report the build
                // (2026-10-07).
                Text(verbatim: "\(DiagnosticInfo.appVersion) (\(DiagnosticInfo.buildNumber))")
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                String(localized: "Version \(DiagnosticInfo.appVersion), build \(DiagnosticInfo.buildNumber)")
            )
        }
    }
}
