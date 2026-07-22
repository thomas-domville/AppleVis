import SwiftUI
import UniformTypeIdentifiers

/// Ported against src/services/drupalForm.ts's `/podcasts/upload` webform
/// (multipart, includes an audio file). Requires an authenticated session —
/// see DrupalFormClient's header comment on verification status.
struct SubmitPodcastView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var description = ""
    @State private var audioFileURL: URL?
    @State private var showFileImporter = false
    @State private var isSubmitting = false
    @State private var error: String?

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty &&
        audioFileURL != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Submit an episode for the AppleVis podcast feed. An editor will review it before it's published.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section("Your Details") {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
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
                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Submit a Podcast")
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
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.audio]) { result in
                if case .success(let url) = result { audioFileURL = url }
            }
        }
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
