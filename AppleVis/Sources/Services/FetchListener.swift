import AVFoundation
import Combine
import SwiftUI

/// Listen to Fetch: reads the Fetch view aloud, group by group, like a
/// personal podcast of what's new — each item's heading, its preview (or,
/// for older posts, who wrote it and when), then every new comment in
/// full. Loads each group's content as it reaches it. Pause, resume, and
/// skip by group or by comment; Magic Tap (two-finger double tap) plays
/// and pauses from anywhere in Fetch. Requested directly (2026-09-25).
/// How fast Listen to Fetch reads. My Settings, the default, uses the voice
/// and speed chosen for VoiceOver or Spoken Content in iOS Settings, so it
/// sounds like the voice you already use. The others set the speed here.
/// Requested directly (2026-09-30).
enum ListenSpeed: String, CaseIterable, Identifiable {
    case mySettings, slow, normal, fast, faster, fastest

    static let storageKey = "fetch.listenSpeed"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .mySettings: return String(localized: "My Settings")
        case .slow: return String(localized: "Slow")
        case .normal: return String(localized: "Normal")
        case .fast: return String(localized: "Fast")
        case .faster: return String(localized: "Faster")
        case .fastest: return String(localized: "Fastest")
        }
    }

    /// AVSpeechUtterance's rate, where 0.5 is normal.
    var rate: Float {
        switch self {
        case .mySettings, .normal: return AVSpeechUtteranceDefaultSpeechRate
        case .slow: return 0.42
        case .fast: return 0.56
        case .faster: return 0.62
        case .fastest: return 0.7
        }
    }

    static var current: ListenSpeed {
        UserDefaults.standard.string(forKey: storageKey).flatMap(ListenSpeed.init(rawValue:)) ?? .mySettings
    }
}

@MainActor
final class FetchListener: NSObject, ObservableObject {
    static let shared = FetchListener()

    enum Status { case idle, playing, paused }

    struct Group {
        let item: FeedItem
        let newCount: Int
        let isBrandNew: Bool
        /// See `HomeViewModel.newCommentsSince`.
        var since: Date? = nil
    }

    @Published private(set) var status: Status = .idle
    /// The item currently being read, so Fetch can mark it on screen.
    @Published private(set) var currentItemId: String?

    /// Called when a group has been read to its end — Fetch uses it for
    /// the optional "mark as read when finished" setting.
    var onGroupFinished: ((FeedItem) -> Void)?

    private let synthesizer = AVSpeechSynthesizer()
    private var groups: [Group] = []
    private var groupIndex = 0
    private var segments: [String] = []
    private var segmentIndex = 0
    /// Where in the current segment speech started (a speed change starts
    /// again partway through), and the last word reached, both in UTF-16
    /// offsets into the segment.
    private var segmentStart = 0
    private var spokenLocation = 0
    /// Bumped on every skip or stop, so a stale "finished" callback from
    /// the utterance that was cut off can't advance twice.
    private var generation = 0

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: Controls

    func start(_ groups: [Group]) {
        guard !groups.isEmpty else { return }
        self.groups = groups
        groupIndex = 0
        status = .playing
        Task { await playGroup() }
    }

    /// Play, pause, or resume — what Magic Tap does.
    func toggle(_ groups: [Group]) {
        switch status {
        case .idle: start(groups)
        case .playing: pause()
        case .paused: resume()
        }
    }

    func pause() {
        guard status == .playing else { return }
        synthesizer.pauseSpeaking(at: .word)
        status = .paused
    }

    func resume() {
        guard status == .paused else { return }
        status = .playing
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        } else {
            speakCurrent(from: segmentStart)
        }
    }

    /// A new speed: starts the current sentence again at that speed, so you
    /// hear the change straight away without losing your place. While
    /// paused, it applies when you resume.
    func speedChanged() {
        guard status != .idle, segmentIndex < segments.count else { return }
        let from = Self.sentenceStart(in: segments[segmentIndex], before: spokenLocation)
        generation += 1
        synthesizer.stopSpeaking(at: .immediate)
        segmentStart = from
        if status == .playing { speakCurrent(from: from) }
    }

    /// The start of the sentence containing `location`.
    private static func sentenceStart(in text: String, before location: Int) -> Int {
        let string = text as NSString
        let end = min(max(location, 0), string.length)
        var start = 0
        string.enumerateSubstrings(in: NSRange(location: 0, length: string.length), options: .bySentences) { _, range, _, stop in
            if range.location > end { stop.pointee = true; return }
            start = range.location
        }
        return start
    }

    func stop() {
        generation += 1
        synthesizer.stopSpeaking(at: .immediate)
        status = .idle
        currentItemId = nil
        groups = []
    }

    func nextGroup() {
        guard status != .idle else { return }
        cutOff()
        groupIndex += 1
        Task { await playGroup() }
    }

    func previousGroup() {
        guard status != .idle else { return }
        cutOff()
        // Back to the start of this group if we're into it; otherwise the one before.
        if segmentIndex == 0 { groupIndex = max(0, groupIndex - 1) }
        Task { await playGroup() }
    }

    func nextComment() {
        guard status != .idle else { return }
        cutOff()
        advance()
    }

    // MARK: Playback

    private func cutOff() {
        generation += 1
        synthesizer.stopSpeaking(at: .immediate)
        if status == .paused { status = .playing }
    }

    private func playGroup() async {
        guard status != .idle else { return }
        guard groupIndex < groups.count else {
            finishAll()
            return
        }
        let group = groups[groupIndex]
        currentItemId = group.item.id
        let content = await FetchStore.shared.load(group.item, newCount: group.isBrandNew ? group.item.commentCount : group.newCount, since: group.since)
        guard status != .idle, groupIndex < groups.count, groups[groupIndex].item.id == group.item.id else { return }
        segments = Self.segments(for: group, content: content)
        segmentIndex = 0
        if status == .playing { speakCurrent() }
    }

    private func speakCurrent(from start: Int = 0) {
        guard segmentIndex < segments.count else { return }
        generation += 1
        let segment = segments[segmentIndex] as NSString
        let from = min(max(start, 0), segment.length)
        segmentStart = from
        spokenLocation = from
        let utterance = Self.utterance(segment.substring(from: from))
        utterance.postUtteranceDelay = 0.35
        synthesizer.speak(utterance)
    }

    /// Speech in the chosen voice and speed.
    private static func utterance(_ text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        let speed = ListenSpeed.current
        if speed == .mySettings {
            // The voice and speed set for VoiceOver or Spoken Content.
            utterance.prefersAssistiveTechnologySettings = true
        } else {
            utterance.rate = speed.rate
        }
        return utterance
    }

    private func advance() {
        segmentStart = 0
        spokenLocation = 0
        segmentIndex += 1
        if segmentIndex < segments.count {
            if status == .playing { speakCurrent() }
        } else {
            if groupIndex < groups.count { onGroupFinished?(groups[groupIndex].item) }
            groupIndex += 1
            Task { await playGroup() }
        }
    }

    private func finishAll() {
        status = .idle
        currentItemId = nil
        groups = []
        synthesizer.speak(Self.utterance(String(localized: "That's everything new. Goldie's all caught up.")))
    }

    /// What gets read for one group, in order.
    static func segments(for group: Group, content: FetchContent?) -> [String] {
        let item = group.item
        var result = [FetchText.heading(item, newCount: group.newCount, isBrandNew: group.isBrandNew)]
        guard let content else {
            result.append(String(localized: "Couldn't load this item."))
            return result
        }
        if group.isBrandNew {
            if !content.preview.isEmpty { result.append(content.preview) }
        } else {
            result.append(FetchText.originalPostLine(content))
        }
        result += content.comments.map { FetchText.commentSpeech($0) }
        return result
    }
}

extension FetchListener: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            // Only the utterance that was allowed to finish moves things on.
            let finishedGeneration = self.generation
            try? await Task.sleep(for: .milliseconds(10))
            guard self.status == .playing, finishedGeneration == self.generation else { return }
            self.advance()
        }
    }

    /// Keeps track of the word being spoken, so a speed change can start
    /// again from its sentence.
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let location = characterRange.location
        Task { @MainActor in
            self.spokenLocation = self.segmentStart + location
        }
    }
}

/// Shared wording for Fetch's rows and Listen to Fetch, so what VoiceOver
/// reads and what Listen speaks always match.
enum FetchText {
    static func heading(_ item: FeedItem, newCount: Int, isBrandNew: Bool) -> String {
        let kind = item.kind.displayName
        if isBrandNew {
            return String(localized: "\(item.title). New \(kind).")
        }
        let comments = String(localized: "\(newCount) new comments")
        return String(localized: "\(item.title). \(kind), \(comments).")
    }

    static func originalPostLine(_ content: FetchContent) -> String {
        let when = content.postedAt.formatted(.relative(presentation: .named))
        return String(localized: "Original post by \(content.author), \(when).")
    }

    static func commentHeader(_ comment: FetchComment) -> String {
        let when = comment.date.formatted(.relative(presentation: .named))
        return String(localized: "Comment by \(comment.author), \(when).")
    }

    static func commentSpeech(_ comment: FetchComment) -> String {
        var parts = [commentHeader(comment)]
        if let replyingTo = comment.replyingTo {
            parts.append(String(localized: "Replying to \(replyingTo)."))
        }
        parts.append(comment.text)
        return parts.joined(separator: " ")
    }
}
