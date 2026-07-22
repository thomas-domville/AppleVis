import SwiftUI

/// Ported against src/services/drupalForm.ts's `/form/community-bug-report-form`
/// webform. Requires an authenticated session — see DrupalFormClient's header
/// comment on verification status.
struct SubmitBugView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @Environment(\.dismiss) private var dismiss

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

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Report an accessibility bug for the community Bug Tracker. Apple does not see this directly — file Feedback Assistant separately if you want Apple to see it.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section("Your Details") {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                Section("Bug Details") {
                    TextField("Title", text: $title)
                    Picker("Platform", selection: $platform) {
                        ForEach(platforms, id: \.self) { Text($0) }
                    }
                    TextField("Software Version", text: $softwareVersion)
                    TextField("Apple Feedback ID (optional)", text: $appleFeedbackId)
                    Picker("Can you reproduce it?", selection: $canReproduce) {
                        ForEach(reproduceOptions, id: \.self) { Text($0) }
                    }
                }
                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 160)
                }
                Section("Recognition") {
                    Picker("Recognize your contribution?", selection: $recognition) {
                        ForEach(recognitionOptions, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.navigationLink)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Submit a Bug Report")
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
