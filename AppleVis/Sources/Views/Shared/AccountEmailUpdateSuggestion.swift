import SwiftUI

/// Opt-in, dismissible suggestion shown on a wizard's post-submit
/// confirmation screen when a signed-in user sent from a different email
/// than their account's — offers to update the account email via
/// AccountSecurityWizard, pre-filled with the address they just used.
/// Deliberately never automatic and never blocking: account email is a
/// security-sensitive setting (already gated behind a current-password
/// check in AccountSecurityWizard), and someone typing a different reply
/// address here — a work email for one report, a shared device someone
/// else used — doesn't necessarily want their login email changed. A plain
/// "Not Now" dismissal is always available. Shared by Contact Us, Submit
/// Bug Report, Submit Blog, and Report a Comment.
struct AccountEmailUpdateSuggestion: View {
    @Binding var isDismissed: Bool
    @Binding var showEmailChangeWizard: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text("You sent this from a different address than your account email. Want to update your account email too?")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 20) {
                Button("Not Now") { isDismissed = true }
                    .font(.footnote)
                Button("Update Account Email") { showEmailChangeWizard = true }
                    .font(.footnote)
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    /// True when this suggestion should actually be offered: the account's
    /// email is known, and it genuinely differs (case-insensitively) from
    /// the address just used.
    static func applies(usedEmail: String, accountEmail: String?) -> Bool {
        guard let accountEmail, !accountEmail.isEmpty else { return false }
        let used = usedEmail.trimmingCharacters(in: .whitespaces)
        guard !used.isEmpty else { return false }
        return used.lowercased() != accountEmail.lowercased()
    }
}
