import SwiftUI

/// docs/APPLEVIS_2026_1_MASTER_SPEC.md requires "Transcript support when
/// available." WhatsNewView.swift had already told users this shipped as
/// "a dedicated full-screen modal" before this file existed — the endpoint
/// (PodcastEndpoints.transcript) was real, nothing called it.
struct TranscriptView: View {
    let episodeId: String
    let episodeTitle: String

    @State private var transcript: String?
    @State private var isLoading = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var preferences: PreferencesStore

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    LoadingView()
                } else if let error {
                    ErrorView(message: error) { await load() }
                } else if let transcript, !transcript.isEmpty {
                    ScrollView {
                        Text(transcript)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .background(preferences.colors.background)
                } else {
                    EmptyStateView(
                        title: "No Transcript",
                        message: "A transcript isn't available for this episode yet.",
                        systemImage: "text.quote"
                    )
                }
            }
            .navigationTitle("Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        error = nil
        do {
            transcript = try await APIClient.shared.podcasts.transcript(id: episodeId)
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Couldn't load transcript." }
        isLoading = false
    }
}
