import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @State private var showSignIn = false
    @State private var showSignOutConfirm = false
    @State private var showEditProfile = false
    @State private var showContact = false
    @State private var showWelcomeTour = false

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
            .navigationTitle("Profile")
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $showContact) {
            ContactView()
        }
        .sheet(isPresented: $showWelcomeTour) {
            GuidedExperienceView(experience: GuidedExperienceRegistry.welcome)
        }
        .confirmationDialog("Sign Out", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                Task { await signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            // RN's wording is precise that this is local-only, so it isn't
            // confused with the (much more serious) Delete Account option
            // right above it in the same section.
            Text("Removes your account session from this device only. You'll need to sign in again to post or access saved items.")
        }
    }

    // MARK: - Signed-in content

    @ViewBuilder
    private func signedInContent(_ user: AuthUser) -> some View {
        Section {
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Signed in as \(user.name)\(user.isAdmin ? ", Administrator" : "")")
        }

        Section("Saved Items") {
            savedCountRow(kind: .forumTopic, icon: "bubble.left.and.bubble.right")
            savedCountRow(kind: .appListing, icon: "square.grid.2x2")
            savedCountRow(kind: .resource, icon: "book")
        }

        Section("Account") {
            Button {
                showEditProfile = true
            } label: {
                Label("Edit Profile", systemImage: "person.crop.circle.badge.pencil")
            }
            .accessibilityLabel("Edit your public profile")

            if let username = auth.user?.name {
                Link(destination: URL(string: "https://www.applevis.com/users/\(username)")!) {
                    Label("View Full Profile on applevis.com", systemImage: "arrow.up.right.square")
                }
                .accessibilityLabel("View your full public profile on applevis.com, opens in browser")
            }

            Link(destination: URL(string: "https://www.applevis.com/user")!) {
                Label("Account Settings on applevis.com", systemImage: "arrow.up.right.square")
            }
            .accessibilityLabel("Account Settings on applevis.com, opens in browser")

            NavigationLink {
                DeleteAccountView()
            } label: {
                Label("Delete Account", systemImage: "person.crop.circle.badge.minus")
                    .foregroundStyle(.red)
            }
            .accessibilityLabel("Permanently delete your AppleVis account")

            Button(role: .destructive) {
                showSignOutConfirm = true
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(.red)
            }
            .accessibilityLabel("Sign out of your AppleVis account")
        }
    }

    /// RN's own Profile screen showed per-kind saved counts as tappable
    /// rows that deep-link into For You's Saved tab pre-filtered by kind —
    /// Swift's Profile had no Saved Items section at all (this is exactly
    /// what the `SiriDestination.savedItems(filter:)` plumbing added
    /// earlier this session was anticipating, previously unused anywhere).
    /// RN only showed these 3 kinds, not all 6.
    private func savedCountRow(kind: ContentKind, icon: String) -> some View {
        let count = PersistenceStore.shared.savedItems().filter { $0.kind == kind }.count
        return Button {
            deepLinkRouter.pendingSiriDestination = .savedItems(filter: kind)
        } label: {
            HStack {
                Label("Saved \(kind.displayName)s", systemImage: icon)
                Spacer()
                Text("\(count)").foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("Saved \(kind.displayName.lowercased())s, \(count)")
        .accessibilityHint("Double-tap to view.")
    }

    // MARK: - Signed-out content

    private var signedOutContent: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sign In")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text("Sign in to post in forums, follow topics, receive notifications, and sync your saved items.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button("Sign In to AppleVis") {
                    showSignIn = true
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Sign in to your AppleVis account")
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Settings section

    private var settingsSection: some View {
        Section("App") {
            NavigationLink {
                SettingsView()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .accessibilityLabel("Open Settings")
        }
    }

    // MARK: - About section

    private var aboutSection: some View {
        Section("About AppleVis") {
            NavigationLink {
                WhatsNewView()
            } label: {
                Label("What's New", systemImage: "sparkles")
            }
            .accessibilityLabel("What's New in AppleVis")

            NavigationLink {
                AboutView()
            } label: {
                Label("About & Credits", systemImage: "info.circle")
            }

            Button {
                showWelcomeTour = true
            } label: {
                Label("Replay Welcome Tour", systemImage: "arrow.clockwise")
            }
            .accessibilityLabel("Replay Welcome Tour")

            Link(destination: URL(string: "https://www.applevis.com/privacy")!) {
                Label("Privacy Policy", systemImage: "shield.checkmark")
            }
            .accessibilityLabel("Privacy Policy, opens in browser")

            Link(destination: URL(string: "https://www.applevis.com/terms")!) {
                Label("Terms of Use", systemImage: "doc.text")
            }
            .accessibilityLabel("Terms of Use, opens in browser")

            Button {
                showContact = true
            } label: {
                Label("Contact AppleVis", systemImage: "envelope")
            }
            .accessibilityLabel("Contact AppleVis")

            HStack {
                Text("Version")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")"
            )
        }
    }

    private func signOut() async {
        await auth.signOut()
        toast.success("Signed out.")
    }
}
