import SwiftUI

struct DeleteAccountView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss

    @State private var confirmed = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var showFinalConfirm = false
    @AccessibilityFocusState private var isErrorFocused: Bool
    /// Had no initial-load focus at all. Full app-wide focus audit,
    /// requested directly.
    @AccessibilityFocusState private var isHeaderFocused: Bool

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label("This action is permanent", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.red)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($isHeaderFocused)

                    Text("Deleting your account will permanently remove:")
                        .font(.subheadline)

                    VStack(alignment: .leading, spacing: 6) {
                        BulletRow("Your AppleVis account and login credentials.")
                        BulletRow("All forum posts and comments you have authored.")
                        BulletRow("Your saved items and followed content.")
                        BulletRow("Your profile and public contributions.")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Text("Your downloaded episodes, playback queue, and app settings on this device are not affected and will remain until you clear them yourself in Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("This cannot be undone. Consider signing out instead if you just want a break.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }

            Section {
                Toggle("I understand this is permanent and cannot be reversed.", isOn: $confirmed)
                    .tint(.red)
                    .accessibilityHint(String(localized: "You must confirm before the delete button becomes active."))
            }

            if let error = errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red)
                        .accessibilityFocused($isErrorFocused)
                }
            }

            Section {
                Button(role: .destructive) {
                    showFinalConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        if isDeleting {
                            ProgressView()
                        } else {
                            Text("Delete My Account Permanently")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(!confirmed || isDeleting)
                .accessibilityLabel(String(localized: "Delete My Account Permanently"))
                .accessibilityHint(confirmed ? String(localized: "Deletes your account immediately and irreversibly.") : String(localized: "Confirm deletion above to activate this button."))
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        // Every other destructive action in the app (Sign Out, Remove
        // Downloads, Unsave All, Clear Queue) requires a confirmationDialog
        // as a second step; this one — the only truly irreversible action —
        // previously went straight from the toggle to the API call, so a
        // single mistimed tap (a slipped VoiceOver double-tap, a Switch
        // Control scan landing wrong) deleted the account immediately.
        .confirmationDialog(
            "Delete your account permanently?",
            isPresented: $showFinalConfirm, titleVisibility: .visible
        ) {
            Button("Delete My Account Permanently", role: .destructive) { deleteAccount() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .task { await retryAccessibilityFocus(into: $isHeaderFocused) }
    }

    private func deleteAccount() {
        guard let user = auth.user else { return }
        isDeleting = true
        errorMessage = nil
        Task {
            do {
                try await APIClient.shared.account.deleteAccount(uuid: user.uuid, csrfToken: user.csrfToken)
                await auth.signOut()
            } catch let error as APIError {
                errorMessage = error.localizedDescription
                isDeleting = false
                isErrorFocused = true
            } catch {
                errorMessage = "Could not delete account. Please contact support."
                isDeleting = false
                isErrorFocused = true
            }
        }
    }
}

private struct BulletRow: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").accessibilityHidden(true)
            Text(text)
        }
    }
}
