import SwiftUI

/// Wraps a pre-computed embedded transcript as a single Identifiable value
/// so EpisodeDetailView can drive its sheet with `.sheet(item:)` instead of
/// `.sheet(isPresented:)` plus a separate sibling `@State` string — the
/// latter is a known SwiftUI race where the sheet's content closure can
/// capture the sibling state's *previous* value (here, still nil) instead
/// of what was just assigned in the same action. That sent TranscriptView
/// down its network-fallback path even when a transcript was embedded in
/// the show notes the whole time, surfacing a stale "This item is no
/// longer available" instead of the transcript. Reported directly.
struct TranscriptRequest: Identifiable {
    let id = UUID()
    let transcript: String?
}

/// docs/APPLEVIS_2026_1_MASTER_SPEC.md requires "Transcript support when
/// available." WhatsNewView.swift had already told users this shipped as
/// "a dedicated full-screen modal" before this file existed — the endpoint
/// (PodcastEndpoints.transcript) was real, nothing called it.
struct TranscriptView: View {
    let episodeId: String
    let episodeTitle: String
    var episodeURL: String? = nil
    var embeddedTranscript: String? = nil

    @State private var transcript: String?
    @State private var isLoading = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var preferences: PreferencesStore
    /// Had no focus management at all — full app-wide focus audit,
    /// requested directly.
    @AccessibilityFocusState private var isFirstSegmentFocused: Bool
    @AccessibilityFocusState private var isEmptyStateFocused: Bool

    private var shareText: String {
        var lines = ["\(episodeTitle) — Transcript", "", transcript ?? ""]
        if let episodeURL, !episodeURL.isEmpty {
            lines += ["", "Listen on AppleVis: \(episodeURL)"]
        }
        return lines.joined(separator: "\n")
    }

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
                            ForEach(Array(Self.segmentTranscript(transcript).enumerated()), id: \.element.id) { index, segment in
                                let row = Text(segment.text)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if index == 0 {
                                    row.accessibilityFocused($isFirstSegmentFocused)
                                } else {
                                    row
                                }
                            }
                        }
                        .padding()
                        .accessibilityElement(children: .contain)
                    }
                    .background(preferences.colors.background)
                } else {
                    EmptyStateView(
                        title: "No Transcript",
                        message: "A transcript isn't available for this episode yet.",
                        systemImage: "text.quote"
                    )
                    .accessibilityFocused($isEmptyStateFocused)
                }
            }
            .navigationTitle("Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                // Sharing the episode's own "Share Episode" action only ever
                // shared a link back to its web page — useful for the
                // episode itself, but not for the actual words someone
                // might want to quote or send from a transcript. Requested
                // directly.
                if let transcript, !transcript.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: shareText) {
                            Label("Share Transcript", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .task {
                await load()
                if let transcript, !transcript.isEmpty {
                    await retryAccessibilityFocus(into: $isFirstSegmentFocused)
                } else {
                    await retryAccessibilityFocus(into: $isEmptyStateFocused)
                }
            }
        }
    }

    /// Previously always hit `podcasts/episodes/{id}/transcript` first and
    /// only fell back to `embeddedTranscript` on failure — but that endpoint
    /// 404s for ordinary episodes (it's for a transcript stored as its own
    /// field, not the show-notes-embedded kind this screen mostly deals
    /// with), so opening a transcript that's really just embedded in the
    /// show notes meant a guaranteed failed network round trip, a visible
    /// loading spinner, and a brief flash of "This item is no longer
    /// available" before the fallback kicked in. `embeddedTranscript` is now
    /// used immediately when present — the id-based fetch only runs as a
    /// fallback for the rarer case where it isn't. Reported directly.
    private func load() async {
        if let embeddedTranscript, !embeddedTranscript.isEmpty {
            transcript = embeddedTranscript
            return
        }
        isLoading = true
        error = nil
        do {
            let fetched = try await APIClient.shared.podcasts.transcript(id: episodeId)
            transcript = fetched.isEmpty ? nil : fetched
        } catch let e as APIError {
            error = e.localizedDescription
        } catch {
            self.error = "Couldn't load transcript."
        }
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

        return TextSegmentation.sentenceGroups(text).map(TranscriptSegment.init)
    }

    private static func nonEmptyTrimmedPieces(_ pieces: [String]) -> [String] {
        pieces.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}

struct TranscriptSegment: Identifiable {
    let id = UUID()
    let text: String
}
