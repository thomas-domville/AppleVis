import Foundation

/// Last-resort text chunking shared by `TranscriptView` (plain-text
/// transcripts) and `HTMLSegmenter` (HTML prose with no paragraph/line-break
/// structure at all) — previously a private copy living only in
/// `TranscriptView.segmentTranscript`. Groups a structureless blob of text
/// a few sentences at a time, so even a single unbroken wall of text still
/// becomes individually-navigable/Braille-panable chunks instead of one
/// giant element.
nonisolated enum TextSegmentation {
    static func sentenceGroups(_ text: String, groupSize: Int = 4) -> [String] {
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .bySentences) { substring, _, _, _ in
            if let s = substring?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                sentences.append(s)
            }
        }
        guard sentences.count > 1 else {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? [] : [trimmed]
        }
        return stride(from: 0, to: sentences.count, by: groupSize).map { start in
            let end = min(start + groupSize, sentences.count)
            return sentences[start..<end].joined(separator: " ")
        }
    }
}
