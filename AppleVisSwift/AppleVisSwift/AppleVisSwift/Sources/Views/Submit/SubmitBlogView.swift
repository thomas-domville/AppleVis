import SwiftUI

/// Ported against src/services/drupalForm.ts's `/form/blog-submission` webform.
/// Requires an authenticated session to reach the real form — could not be
/// end-to-end verified live (see DrupalFormClient's header comment).
///
/// Three-step wizard: Your Details → Content → Review, matching the original
/// step-by-step design (index → content → review).
struct SubmitBlogView: View {
    private enum Step: Int { case details, content, review }

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .details
    @State private var name = ""
    @State private var email = ""
    @State private var coverNote = ""
    @State private var blogDraft = ""
    @State private var isSubmitting = false
    @State private var error: String?

    /// Set when opened from the Share Extension with shared text.
    init(prefillText: String? = nil) {
        _blogDraft = State(initialValue: prefillText ?? "")
    }

    private var detailsValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var contentValid: Bool {
        !blogDraft.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                switch step {
                case .details: detailsSection
                case .content: contentSection
                case .review:  reviewSection
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Submit a Blog Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == .details ? "Cancel" : "Back") {
                        if step == .details {
                            SoundPlayer.shared.play(.screenClose)
                            dismiss()
                        } else {
                            goBack()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if step == .review {
                        Button("Submit") { Task { await submit() } }
                            .disabled(isSubmitting)
                    } else {
                        Button("Next") { goNext() }
                            .disabled(step == .details ? !detailsValid : !contentValid)
                    }
                }
            }
            .onAppear {
                if name.isEmpty { name = auth.user?.name ?? "" }
            }
        }
    }

    private var detailsSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: 1, total: 3, title: "Your Details")
                Text("Submit a blog post draft for the AppleVis editorial team to review. This does not publish immediately — an editor will follow up.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Your Details") {
                TextField("Name", text: $name)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }
        }
    }

    private var contentSection: some View {
        Group {
            Section { WizardStepIndicator(step: 2, total: 3, title: "Your Content") }
            Section("Cover Note") {
                TextEditor(text: $coverNote)
                    .frame(minHeight: 80)
            }
            Section("Blog Post Draft") {
                TextEditor(text: $blogDraft)
                    .frame(minHeight: 200)
            }
        }
    }

    private var reviewSection: some View {
        Group {
            Section { WizardStepIndicator(step: 3, total: 3, title: "Review & Submit") }
            Section("Your Details") {
                WizardReviewRow(label: "Name", value: name)
                WizardReviewRow(label: "Email", value: email)
            }
            Section("Content") {
                WizardReviewRow(label: "Cover Note", value: coverNote)
                WizardReviewRow(label: "Blog Post Draft", value: blogDraft)
            }
        }
    }

    private func goNext() {
        SoundPlayer.shared.play(.pickerTick)
        step = Step(rawValue: step.rawValue + 1) ?? .review
    }

    private func goBack() {
        SoundPlayer.shared.play(.pickerTick)
        step = Step(rawValue: step.rawValue - 1) ?? .details
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
