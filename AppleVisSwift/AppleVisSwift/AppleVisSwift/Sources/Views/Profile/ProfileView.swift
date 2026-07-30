import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
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
            Text("You'll need to sign in again to post or access saved items.")
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
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Signed in as \(user.name)\(user.isAdmin ? ", Administrator" : "")")
        }

        Section("Account") {
            Button {
                showEditProfile = true
            } label: {
                Label("Edit Profile", systemImage: "person.crop.circle.badge.pencil")
            }
            .accessibilityLabel("Edit your public profile")

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
