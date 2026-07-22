import SwiftUI

struct DeleteAccountView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var confirmed = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label("This action is permanent", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.red)
                        .accessibilityAddTraits(.isHeader)

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
                    .accessibilityHint("You must confirm before the delete button becomes active.")
            }

            if let error = errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(role: .destructive) {
                    deleteAccount()
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
                .accessibilityLabel("Delete My Account Permanently")
                .accessibilityHint(confirmed ? "Deletes your account immediately and irreversibly." : "Confirm deletion above to activate this button.")
            }
        }
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private func deleteAccount() {
        guard let user = auth.user else { return }
        isDeleting = true
        errorMessage = nil
        Task {
            do {
                try await APIClient.shared.account.deleteAccount(uid: user.uid, csrfToken: user.csrfToken)
                await auth.signOut()
            } catch let error as APIError {
                errorMessage = error.localizedDescription
                isDeleting = false
            } catch {
                errorMessage = "Could not delete account. Please contact support."
                isDeleting = false
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
