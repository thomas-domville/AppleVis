import Foundation
import AVFoundation

/// Reads duration and chapter markers directly from an episode's audio file
/// — Drupal never actually supplies either: the API's `duration` field is
/// hardcoded to 0 (`Mappers.swift`), and `field_chapters` is only ever
/// populated for episodes a host bothered to chapter-mark in the CMS, which
/// most aren't. Everything here runs entirely client-side and on-device;
/// results are cached in `PersistenceStore` so a given episode is only ever
/// probed once, not on every screen visit.
enum PodcastAudioMetadataProbe {
    /// Reads real duration from the audio file's own container metadata via
    /// AVFoundation. This only needs the file's format/moov atom, not a full
    /// download — `AVURLAsset` fetches just enough of the remote file under
    /// the hood via ranged HTTP requests.
    static func resolveDuration(audioUrl: String) async -> TimeInterval? {
        guard let url = URL(string: audioUrl) else { return nil }
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration), duration.isValid, !duration.isIndefinite else { return nil }
        let seconds = CMTimeGetSeconds(duration)
        return (seconds.isFinite && seconds > 0) ? seconds : nil
    }

    /// Reads ID3v2 CHAP frames embedded directly in the MP3 — the same
    /// convention most podcast apps read chapters from, independent of
    /// whatever Drupal's `field_chapters` does or doesn't have. ID3v2 tags
    /// sit at the very start of the file, so this only needs a small ranged
    /// fetch (the tag's own declared size), never the whole episode.
    static func resolveChapters(audioUrl: String) async -> [Chapter] {
        guard let url = URL(string: audioUrl), let tagData = await fetchID3Tag(url: url) else { return [] }
        return ID3ChapterParser.parse(tagData)
    }

    /// Fetched in two steps: first just the 10-byte ID3v2 header to learn
    /// the tag's declared total size, then exactly that many bytes. Avoids
    /// guessing a fixed byte count that's either wasteful (most of the tag
    /// is often embedded cover art) or truncates a tag larger than guessed.
    private static func fetchID3Tag(url: URL) async -> Data? {
        guard let header = await rangedFetch(url: url, length: 10), header.count == 10,
              header[0] == 0x49, header[1] == 0x44, header[2] == 0x33 // "ID3"
        else { return nil }
        let tagSize = synchsafeInt(header[6], header[7], header[8], header[9])
        guard tagSize > 0, tagSize < 20_000_000 else { return nil } // sanity ceiling, not a real-world tag size
        return await rangedFetch(url: url, length: 10 + tagSize)
    }

    private static func rangedFetch(url: URL, length: Int) async -> Data? {
        var request = URLRequest(url: url)
        request.setValue("bytes=0-\(length - 1)", forHTTPHeaderField: "Range")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode)
        else { return nil }
        return data
    }

    /// ID3v2's "syncsafe" integer: each of 4 bytes only uses its lower 7
    /// bits, guaranteeing no byte sequence inside a size field can ever be
    /// misread as an MP3 frame sync marker by a naive scanner. Used for the
    /// tag size in the ID3v2 header, and — in ID3v2.4 only — individual
    /// frame sizes too (`ID3ChapterParser` picks the right one per tag).
    fileprivate static func synchsafeInt(_ b0: UInt8, _ b1: UInt8, _ b2: UInt8, _ b3: UInt8) -> Int {
        (Int(b0 & 0x7F) << 21) | (Int(b1 & 0x7F) << 14) | (Int(b2 & 0x7F) << 7) | Int(b3 & 0x7F)
    }
}

/// Minimal ID3v2.3/2.4 frame walker, scoped to exactly what's needed to
/// recover chapter markers: finds "CHAP" frames, and within each, reads the
/// mandatory timing fields plus an embedded "TIT2" sub-frame for the title.
/// Everything else in the tag (embedded artwork, other text frames) is
/// skipped over using each frame's own declared size, never parsed.
///
/// Not unit-tested against a real file as part of this change — binary
/// frame parsing is exactly the kind of code that can silently misbehave on
/// a real-world tag (a v2.3 tag with an unusual flag byte, an
/// unsynchronization bit, an oddly-ordered sub-frame) in ways static review
/// can't catch. Needs verification against actual AppleVis podcast episodes
/// on a real device before this is trusted.
private enum ID3ChapterParser {
    static func parse(_ tagData: Data) -> [Chapter] {
        let bytes = [UInt8](tagData)
        guard bytes.count >= 10, bytes[0] == 0x49, bytes[1] == 0x44, bytes[2] == 0x33 else { return [] } // "ID3"
        let majorVersion = bytes[3]
        let usesSynchsafeFrameSizes = majorVersion >= 4
        let tagEnd = min(10 + PodcastAudioMetadataProbe.synchsafeInt(bytes[6], bytes[7], bytes[8], bytes[9]), bytes.count)

        var offset = 10
        var chapters: [Chapter] = []

        while offset + 10 <= tagEnd {
            guard let frameId = String(bytes: bytes[offset..<(offset + 4)], encoding: .ascii),
                  frameId.allSatisfy({ $0.isLetter || $0.isNumber })
            else { break } // padding (0x00 run) or malformed data — nothing more to read

            let frameSize = frameSize(bytes, at: offset + 4, synchsafe: usesSynchsafeFrameSizes)
            let bodyStart = offset + 10
            let bodyEnd = bodyStart + frameSize
            guard frameSize > 0, bodyEnd <= tagEnd else { break }

            if frameId == "CHAP", let chapter = parseChapterFrame(bytes, start: bodyStart, end: bodyEnd, synchsafe: usesSynchsafeFrameSizes) {
                chapters.append(chapter)
            }
            offset = bodyEnd
        }
        return chapters.sorted { $0.startTime < $1.startTime }
    }

    /// CHAP frame body: null-terminated element ID, then four 4-byte
    /// big-endian fields (start time ms, end time ms, start byte offset,
    /// end byte offset — the offsets are almost always 0xFFFFFFFF,
    /// "unused, go by time instead"), then zero or more embedded sub-frames
    /// in the ordinary frame format filling out the rest of the frame.
    private static func parseChapterFrame(_ bytes: [UInt8], start: Int, end: Int, synchsafe: Bool) -> Chapter? {
        guard let terminator = bytes[start..<end].firstIndex(of: 0) else { return nil }
        let elementId = String(bytes: bytes[start..<terminator], encoding: .isoLatin1) ?? UUID().uuidString
        var cursor = terminator + 1
        guard cursor + 16 <= end else { return nil }

        let startMs = bigEndianUInt32(bytes, at: cursor)
        let endMs = bigEndianUInt32(bytes, at: cursor + 4)
        cursor += 16

        var title = ""
        while cursor + 10 <= end {
            guard let subFrameId = String(bytes: bytes[cursor..<(cursor + 4)], encoding: .ascii),
                  subFrameId.allSatisfy({ $0.isLetter || $0.isNumber })
            else { break }
            let subSize = frameSize(bytes, at: cursor + 4, synchsafe: synchsafe)
            let subBodyStart = cursor + 10
            let subBodyEnd = subBodyStart + subSize
            guard subSize > 0, subBodyEnd <= end else { break }
            if subFrameId == "TIT2" {
                title = decodeTextFrame(bytes, start: subBodyStart, end: subBodyEnd)
            }
            cursor = subBodyEnd
        }

        guard !title.isEmpty else { return nil }
        return Chapter(
            id: elementId.isEmpty ? UUID().uuidString : elementId,
            title: title,
            startTime: TimeInterval(startMs) / 1000,
            endTime: endMs == 0xFFFF_FFFF ? 0 : TimeInterval(endMs) / 1000
        )
    }

    /// ID3 text frames open with a 1-byte encoding indicator: 0 =
    /// ISO-8859-1, 1 = UTF-16 with BOM, 2 = UTF-16BE without BOM, 3 = UTF-8.
    private static func decodeTextFrame(_ bytes: [UInt8], start: Int, end: Int) -> String {
        guard start < end else { return "" }
        let textBytes = Array(bytes[(start + 1)..<end])
        let raw: String?
        switch bytes[start] {
        case 1:  raw = String(bytes: textBytes, encoding: .utf16)
        case 2:  raw = String(bytes: textBytes, encoding: .utf16BigEndian)
        case 3:  raw = String(bytes: textBytes, encoding: .utf8)
        default: raw = String(bytes: textBytes, encoding: .isoLatin1)
        }
        return (raw ?? "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\0")))
    }

    private static func frameSize(_ bytes: [UInt8], at offset: Int, synchsafe: Bool) -> Int {
        guard offset + 4 <= bytes.count else { return 0 }
        return synchsafe
            ? PodcastAudioMetadataProbe.synchsafeInt(bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3])
            : (Int(bytes[offset]) << 24) | (Int(bytes[offset + 1]) << 16) | (Int(bytes[offset + 2]) << 8) | Int(bytes[offset + 3])
    }

    private static func bigEndianUInt32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        guard offset + 4 <= bytes.count else { return 0 }
        return (UInt32(bytes[offset]) << 24) | (UInt32(bytes[offset + 1]) << 16) | (UInt32(bytes[offset + 2]) << 8) | UInt32(bytes[offset + 3])
    }
}
