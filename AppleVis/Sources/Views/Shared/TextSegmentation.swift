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

    /// Whole paragraphs gathered into pieces of at most about `maxLength`
    /// characters; a paragraph longer than that is cut at sentence ends.
    /// Used where one long element causes trouble: Fetch, whose rows must
    /// stay shorter than the screen for VoiceOver to move past them, and
    /// Ask the Mouse, which reads long guides a part at a time.
    static func pieces(_ text: String, maxLength: Int) -> [String] {
        var paragraphs: [String] = []
        for paragraph in text.components(separatedBy: "\n") {
            let trimmed = paragraph.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if trimmed.count <= maxLength {
                paragraphs.append(trimmed)
                continue
            }
            var piece = ""
            for sentence in sentenceGroups(trimmed, groupSize: 1) {
                if !piece.isEmpty, piece.count + sentence.count + 1 > maxLength {
                    paragraphs.append(piece)
                    piece = ""
                }
                piece += (piece.isEmpty ? "" : " ") + String(sentence.prefix(maxLength))
            }
            if !piece.isEmpty { paragraphs.append(piece) }
        }
        var pieces: [String] = []
        var current = ""
        for paragraph in paragraphs {
            if !current.isEmpty, current.count + paragraph.count + 1 > maxLength {
                pieces.append(current)
                current = ""
            }
            current += (current.isEmpty ? "" : "\n") + paragraph
        }
        if !current.isEmpty { pieces.append(current) }
        return pieces
    }
}
