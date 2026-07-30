import SwiftUI
import UniformTypeIdentifiers

/// Ported against src/services/drupalForm.ts's `/podcasts/upload` webform
/// (multipart, includes an audio file). Requires an authenticated session —
/// see DrupalFormClient's header comment on verification status.
///
/// Three-step wizard: Your Details → Audio → Review, matching the original
/// step-by-step design (index → audio → review).
struct SubmitPodcastView: View {
    private enum Step: Int { case details, audio, review }

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .details
    @State private var name = ""
    @State private var email = ""
    @State private var description = ""
    @State private var audioFileURL: URL?
    @State private var showFileImporter = false
    @State private var isSubmitting = false
    @State private var error: String?

    private var detailsValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var audioValid: Bool {
        !description.trimmingCharacters(in: .whitespaces).isEmpty && audioFileURL != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                switch step {
                case .details: detailsSection
                case .audio:   audioSection
                case .review:  reviewSection
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Submit a Podcast")
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
                            .disabled(step == .details ? !detailsValid : !audioValid)
                    }
                }
            }
            .onAppear {
                if name.isEmpty { name = auth.user?.name ?? "" }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.audio]) { result in
                if case .success(let url) = result { audioFileURL = url }
            }
        }
    }

    private var detailsSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: 1, total: 3, title: "Your Details")
                Text("Submit an episode for the AppleVis podcast feed. An editor will review it before it's published.")
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

    private var audioSection: some View {
        Group {
            Section { WizardStepIndicator(step: 2, total: 3, title: "Episode & Audio") }
            Section("Episode Description") {
                TextEditor(text: $description)
                    .frame(minHeight: 120)
            }
            Section("Audio File") {
                Button {
                    showFileImporter = true
                } label: {
                    Label(audioFileURL?.lastPathComponent ?? "Choose Audio File", systemImage: "waveform")
                }
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
            Section("Episode") {
                WizardReviewRow(label: "Description", value: description)
                WizardReviewRow(label: "Audio File", value: audioFileURL?.lastPathComponent ?? "")
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
        let result = await DrupalFormClient.submitPodcast(name: name, email: email, description: description, audioFileURL: audioFileURL)
        switch result {
        case .ok:
            toast.success("Podcast submitted for review")
            dismiss()
        case .failure(let message):
            error = message
        }
        isSubmitting = false
    }
}
