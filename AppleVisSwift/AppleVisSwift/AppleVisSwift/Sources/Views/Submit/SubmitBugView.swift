import SwiftUI

/// Ported against src/services/drupalForm.ts's `/form/community-bug-report-form`
/// webform. Requires an authenticated session — see DrupalFormClient's header
/// comment on verification status.
///
/// Four-step wizard: Your Details → Description → Bug Details → Review,
/// matching the original step-by-step design.
struct SubmitBugView: View {
    private enum Step: Int { case details, description, bugInfo, review }

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .details
    @State private var name = ""
    @State private var email = ""
    @State private var title = ""
    @State private var appleFeedbackId = ""
    @State private var platform = "iOS"
    @State private var softwareVersion = ""
    @State private var canReproduce = "Yes, always"
    @State private var description = ""
    @State private var recognition = "Yes - please use my AppleVis username"
    @State private var isSubmitting = false
    @State private var error: String?

    private let platforms = ["iOS", "iPadOS", "macOS"]
    private let reproduceOptions = ["Yes, always", "Yes, sometimes", "No"]
    private let recognitionOptions = [
        "Yes - please use my name.",
        "Yes - please use my AppleVis username",
        "No - please thank/recognize me anonymously",
    ]

    private var detailsValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var descriptionValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                switch step {
                case .details:     detailsSection
                case .description: descriptionSection
                case .bugInfo:     bugInfoSection
                case .review:      reviewSection
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Submit a Bug Report")
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
                            .disabled(step == .details ? !detailsValid : (step == .description ? !descriptionValid : false))
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
                WizardStepIndicator(step: 1, total: 4, title: "Your Details")
                Text("Report an accessibility bug for the community Bug Tracker. Apple does not see this directly — file Feedback Assistant separately if you want Apple to see it.")
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

    private var descriptionSection: some View {
        Group {
            Section { WizardStepIndicator(step: 2, total: 4, title: "Describe the Bug") }
            Section("Bug Details") {
                TextField("Title", text: $title)
            }
            Section("Description") {
                TextEditor(text: $description)
                    .frame(minHeight: 160)
            }
        }
    }

    private var bugInfoSection: some View {
        Group {
            Section { WizardStepIndicator(step: 3, total: 4, title: "Environment") }
            Section("Where It Happens") {
                Picker("Platform", selection: $platform) {
                    ForEach(platforms, id: \.self) { Text($0) }
                }
                TextField("Software Version", text: $softwareVersion)
                TextField("Apple Feedback ID (optional)", text: $appleFeedbackId)
                Picker("Can you reproduce it?", selection: $canReproduce) {
                    ForEach(reproduceOptions, id: \.self) { Text($0) }
                }
            }
            Section("Recognition") {
                Picker("Recognize your contribution?", selection: $recognition) {
                    ForEach(recognitionOptions, id: \.self) { Text($0) }
                }
                .pickerStyle(.navigationLink)
            }
        }
    }

    private var reviewSection: some View {
        Group {
            Section { WizardStepIndicator(step: 4, total: 4, title: "Review & Submit") }
            Section("Your Details") {
                WizardReviewRow(label: "Name", value: name)
                WizardReviewRow(label: "Email", value: email)
            }
            Section("Bug") {
                WizardReviewRow(label: "Title", value: title)
                WizardReviewRow(label: "Description", value: description)
            }
            Section("Environment") {
                WizardReviewRow(label: "Platform", value: platform)
                WizardReviewRow(label: "Software Version", value: softwareVersion)
                WizardReviewRow(label: "Apple Feedback ID", value: appleFeedbackId)
                WizardReviewRow(label: "Can Reproduce", value: canReproduce)
                WizardReviewRow(label: "Recognition", value: recognition)
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
        let result = await DrupalFormClient.submitBug(
            name: name, email: email, title: title, appleFeedback: appleFeedbackId,
            platform: platform, softwareVersion: softwareVersion, canReproduce: canReproduce,
            description: description, recognition: recognition
        )
        switch result {
        case .ok:
            toast.success("Bug report submitted")
            dismiss()
        case .failure(let message):
            error = message
        }
        isSubmitting = false
    }
}
