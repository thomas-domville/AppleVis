import SwiftUI

/// Everything that used to sit directly under the identity card on
/// ProfileView's root list — split out so the main Profile screen is a
/// short 3-stop list (My Account / Settings / About) instead of the
/// identity card plus 7 more rows all requiring a swipe past. Requested
/// directly.
struct AccountDetailView: View {
    let user: AuthUser
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss
    @State private var showEditProfile = false
    @State private var showSignOutConfirm = false
    @State private var accountSecurityMode: AccountSecurityWizard.Mode?
    @AccessibilityFocusState private var focusTarget: AnyHashable?
    private static let titleFocusID = AnyHashable("account.title")

    var body: some View {
        List {
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
                .accessibilityLabel(String(localized: "Signed in as \(user.name)\(user.isAdmin ? ", Administrator" : "")"))
                .accessibilityFocused($focusTarget, equals: Self.titleFocusID)
            }

            Section("Account") {
                Button {
                    showEditProfile = true
                } label: {
                    Label("Edit Profile", systemImage: "person.crop.circle.badge.pencil")
                }
                .accessibilityLabel(String(localized: "Edit your public profile"))

                Button {
                    accountSecurityMode = .password
                } label: {
                    Label("Change Password", systemImage: "lock.rotation")
                }
                .accessibilityLabel(String(localized: "Change your account password"))

                Button {
                    accountSecurityMode = .email
                } label: {
                    Label("Change Email Address", systemImage: "envelope.badge")
                }
                .accessibilityLabel(String(localized: "Change your account email address"))

                WebLink(destination: URL(string: "https://www.applevis.com/users/\(user.name)")!) {
                    Label("View Full Profile on applevis.com", systemImage: "arrow.up.right.square")
                }
                .accessibilityLabel(String(localized: "View your full public profile on applevis.com, opens in browser"))

                WebLink(destination: URL(string: "https://www.applevis.com/user")!) {
                    Label("More Account Settings on applevis.com", systemImage: "arrow.up.right.square")
                }
                .accessibilityLabel(String(localized: "More Account Settings on applevis.com, opens in browser"))

                NavigationLink {
                    DeleteAccountView()
                        .onDisappear {
                            Task { await retryAccessibilityFocus(into: $focusTarget, returningTo: AnyHashable("deleteAccount")) }
                        }
                } label: {
                    Label("Delete Account", systemImage: "person.crop.circle.badge.minus")
                        .foregroundStyle(.red)
                }
                .accessibilityFocused($focusTarget, equals: AnyHashable("deleteAccount"))
                .accessibilityLabel(String(localized: "Permanently delete your AppleVis account"))

                Button(role: .destructive) {
                    showSignOutConfirm = true
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                }
                .accessibilityLabel(String(localized: "Sign out of your AppleVis account"))
            }
        }
        .listStyle(.insetGrouped)
        .themedList(preferences.colors)
        .navigationTitle("My Account")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
        }
        .sheet(item: $accountSecurityMode) { mode in
            AccountSecurityWizard(mode: mode)
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
        // Sign Out (above) and Delete Account (pushed one level deeper via
        // DeleteAccountView) both end in auth.user going nil — without this,
        // this screen (and DeleteAccountView on top of it) would be left
        // stranded showing a now-signed-out account.
        .onChange(of: auth.user == nil) { _, signedOut in
            if signedOut { dismiss() }
        }
        .task { await retryAccessibilityFocus(into: $focusTarget, returningTo: Self.titleFocusID) }
    }

    private func signOut() async {
        await auth.signOut()
        toast.success(String(localized: "Signed out"))
    }
}
