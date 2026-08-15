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
                    // Previously one Text(transcript) covering the whole
                    // multi-thousand-word string — a single accessibility
                    // element with no way to jump to a point, review one
                    // line at a time on a Braille display, or navigate by
                    // paragraph via the rotor (PODCAST-04). The API returns
                    // plain text, not HTML, so this is a dedicated plain-text
                    // segmenter rather than a reuse of SegmentedHTMLView's
                    // tag-based one.
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(Self.segmentTranscript(transcript)) { segment in
                                Text(segment.text)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
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

    /// Splits on blank-line paragraph breaks first (the common case for a
    /// prose transcript); falls back to single-line breaks if the text has
    /// no blank lines (common for a speaker-turn-per-line transcript); if
    /// neither produces more than one piece, falls back to sentence-boundary
    /// splitting grouped a few sentences at a time so even a single
    /// unbroken blob of text still becomes individually-navigable chunks
    /// instead of one giant element.
    static func segmentTranscript(_ text: String) -> [TranscriptSegment] {
        let byParagraph = nonEmptyTrimmedPieces(text.components(separatedBy: "\n\n"))
        if byParagraph.count > 1 { return byParagraph.map(TranscriptSegment.init) }

        let byLine = nonEmptyTrimmedPieces(text.components(separatedBy: "\n"))
        if byLine.count > 1 { return byLine.map(TranscriptSegment.init) }

        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .bySentences) { substring, _, _, _ in
            if let s = substring?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                sentences.append(s)
            }
        }
        guard sentences.count > 1 else {
            return [TranscriptSegment(text: text.trimmingCharacters(in: .whitespacesAndNewlines))]
        }
        let groupSize = 4
        return stride(from: 0, to: sentences.count, by: groupSize).map { start in
            let end = min(start + groupSize, sentences.count)
            return TranscriptSegment(text: sentences[start..<end].joined(separator: " "))
        }
    }

    private static func nonEmptyTrimmedPieces(_ pieces: [String]) -> [String] {
        pieces.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}

struct TranscriptSegment: Identifiable {
    let id = UUID()
    let text: String
}
