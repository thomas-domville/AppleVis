import Testing
@testable import AppleVisSwift

/// Regression coverage for GUIDES-02: HTML tables previously fell into the
/// generic `.prose` case and were flattened into unstructured text by the
/// HTML importer, destroying row/column structure that a sighted user could
/// still visually parse but a VoiceOver/Braille user had no way to recover.
@Suite("HTMLSegmenter table parsing")
struct HTMLSegmenterTableTests {

    private static let simpleTable = """
    <p>Intro text.</p>
    <table>
        <tr><th>Gesture</th><th>Action</th></tr>
        <tr><td>Single tap</td><td>Select</td></tr>
        <tr><td>Double tap</td><td>Activate</td></tr>
    </table>
    <p>Outro text.</p>
    """

    @Test("a table produces a .table segment, not .prose")
    func tableProducesTableSegment() {
        let segments = HTMLSegmenter.segment(Self.simpleTable)
        let tableSegments = segments.filter {
            if case .table = $0.kind { return true }
            return false
        }
        #expect(tableSegments.count == 1)
    }

    @Test("table rows and header detection are parsed correctly")
    func tableRowsParsedCorrectly() {
        let segments = HTMLSegmenter.segment(Self.simpleTable)
        guard case .table(let rows, let hasHeaderRow)? = segments.first(where: {
            if case .table = $0.kind { return true }
            return false
        })?.kind else {
            Issue.record("Expected a .table segment")
            return
        }
        #expect(hasHeaderRow)
        #expect(rows.count == 3)
        #expect(rows[0] == ["Gesture", "Action"])
        #expect(rows[1] == ["Single tap", "Select"])
        #expect(rows[2] == ["Double tap", "Activate"])
    }

    @Test("surrounding prose is preserved as separate prose segments")
    func surroundingProseIsPreserved() {
        let segments = HTMLSegmenter.segment(Self.simpleTable)
        let proseSegments = segments.filter {
            if case .prose = $0.kind { return true }
            return false
        }
        #expect(proseSegments.count == 2)
    }

    @Test("a table with no header row (all td cells) is detected as headerless")
    func tableWithoutHeaderRow() {
        let html = "<table><tr><td>A</td><td>B</td></tr><tr><td>C</td><td>D</td></tr></table>"
        let segments = HTMLSegmenter.segment(html)
        guard case .table(let rows, let hasHeaderRow)? = segments.first?.kind else {
            Issue.record("Expected a .table segment")
            return
        }
        #expect(!hasHeaderRow)
        #expect(rows.count == 2)
    }

    @Test("plain prose with no table produces no .table segments")
    func plainProseHasNoTableSegments() {
        let segments = HTMLSegmenter.segment("<p>Just a normal paragraph, no tables here.</p>")
        let tableSegments = segments.filter {
            if case .table = $0.kind { return true }
            return false
        }
        #expect(tableSegments.isEmpty)
    }
}
