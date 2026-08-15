import Testing
@testable import AppleVisSwift

/// Regression coverage for PODCAST-04: a transcript used to render as one
/// `Text` covering the entire multi-thousand-word string — a single
/// accessibility element with no per-paragraph VoiceOver/Braille navigation.
@Suite("Transcript segmentation")
struct TranscriptSegmentationTests {

    @Test("a multi-paragraph transcript produces more than one segment")
    func multiParagraphProducesMultipleSegments() {
        let transcript = "First paragraph of the transcript.\n\nSecond paragraph, a different point.\n\nThird and final paragraph."
        let segments = TranscriptView.segmentTranscript(transcript)
        #expect(segments.count == 3)
        #expect(segments[0].text == "First paragraph of the transcript.")
        #expect(segments[2].text == "Third and final paragraph.")
    }

    @Test("a single-line-per-turn transcript with no blank lines still splits by line")
    func lineDelimitedTranscriptSplitsByLine() {
        let transcript = "Host: Welcome to the show.\nGuest: Thanks for having me.\nHost: Let's get started."
        let segments = TranscriptView.segmentTranscript(transcript)
        #expect(segments.count == 3)
        #expect(segments[1].text == "Guest: Thanks for having me.")
    }

    @Test("a transcript with no line breaks at all still splits into more than one chunk")
    func unbrokenBlobSplitsBySentence() {
        let transcript = String(repeating: "This is one sentence in a long unbroken transcript. ", count: 20)
        let segments = TranscriptView.segmentTranscript(transcript)
        #expect(segments.count > 1)
    }

    @Test("empty pieces from stray blank lines are dropped")
    func blankLinesAreDropped() {
        let transcript = "First paragraph.\n\n\n\nSecond paragraph."
        let segments = TranscriptView.segmentTranscript(transcript)
        #expect(segments.count == 2)
    }

    @Test("a genuinely single short sentence still returns exactly one segment")
    func singleShortSentenceReturnsOneSegment() {
        let segments = TranscriptView.segmentTranscript("Just one short line.")
        #expect(segments.count == 1)
        #expect(segments[0].text == "Just one short line.")
    }
}
