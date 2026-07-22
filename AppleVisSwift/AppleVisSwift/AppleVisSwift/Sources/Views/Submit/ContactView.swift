import SwiftUI

/// In-app contact form — replaces linking out to Safari. Ported against the
/// live, verified `/contact` Drupal webform (see DrupalFormClient).
struct ContactView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var subject = ""
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var error: String?

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !subject.trimmingCharacters(in: .whitespaces).isEmpty &&
        !message.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Send a bug report, feedback, suggestion, or recommendation to the AppleVis team.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section("Your Details") {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                Section("Message") {
                    TextField("Subject", text: $subject)
                    TextEditor(text: $message)
                        .frame(minHeight: 160)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Contact AppleVis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { Task { await submit() } }
                        .disabled(!isValid || isSubmitting)
                }
            }
            .onAppear {
                if name.isEmpty { name = auth.user?.name ?? "" }
            }
        }
    }

    private func submit() async {
        isSubmitting = true; error = nil
        let result = await DrupalFormClient.submitContact(name: name, email: email, subject: subject, message: message)
        switch result {
        case .ok:
            toast.success("Message sent")
            dismiss()
        case .failure(let message):
            error = message
        }
        isSubmitting = false
    }
}
