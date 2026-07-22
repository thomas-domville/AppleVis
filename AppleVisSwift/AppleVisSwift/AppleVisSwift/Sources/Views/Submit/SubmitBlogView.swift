import SwiftUI

/// Ported against src/services/drupalForm.ts's `/form/blog-submission` webform.
/// Requires an authenticated session to reach the real form — could not be
/// end-to-end verified live (see DrupalFormClient's header comment).
struct SubmitBlogView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var coverNote = ""
    @State private var blogDraft = ""
    @State private var isSubmitting = false
    @State private var error: String?

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !blogDraft.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Submit a blog post draft for the AppleVis editorial team to review. This does not publish immediately — an editor will follow up.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section("Your Details") {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                Section("Cover Note") {
                    TextEditor(text: $coverNote)
                        .frame(minHeight: 80)
                }
                Section("Blog Post Draft") {
                    TextEditor(text: $blogDraft)
                        .frame(minHeight: 200)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Submit a Blog Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") { Task { await submit() } }
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
        let result = await DrupalFormClient.submitBlog(name: name, email: email, message: coverNote, blogDraft: blogDraft)
        switch result {
        case .ok:
            toast.success("Blog post submitted for review")
            dismiss()
        case .failure(let message):
            error = message
        }
        isSubmitting = false
    }
}
