import Testing
@testable import AppleVis

@Suite("Podcast transcript heading detection")
struct PodcastTranscriptHeadingTests {

    @Test("common transcript heading variants are detected")
    func commonTranscriptHeadingVariants() {
        #expect(EpisodeDetailView.isTranscriptHeading("Transcript"))
        #expect(EpisodeDetailView.isTranscriptHeading("Transcript:"))
        #expect(EpisodeDetailView.isTranscriptHeading("Transcription"))
        #expect(EpisodeDetailView.isTranscriptHeading("Episode Transcript"))
        #expect(EpisodeDetailView.isTranscriptHeading("Podcast Transcription"))
        #expect(EpisodeDetailView.isTranscriptHeading("Audio Transcript"))
    }

    @Test("ordinary show note headings are not detected as transcripts")
    func ordinaryHeadingsAreIgnored() {
        #expect(!EpisodeDetailView.isTranscriptHeading("Episode Notes"))
        #expect(!EpisodeDetailView.isTranscriptHeading("Links Mentioned"))
        #expect(!EpisodeDetailView.isTranscriptHeading("Chapters"))
    }
}
