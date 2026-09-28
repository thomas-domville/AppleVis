import AVFoundation
import Combine
import SwiftUI

/// Listen to Fetch: reads the Fetch view aloud, group by group, like a
/// personal podcast of what's new — each item's heading, its preview (or,
/// for older posts, who wrote it and when), then every new comment in
/// full. Loads each group's content as it reaches it. Pause, resume, and
/// skip by group or by comment; Magic Tap (two-finger double tap) plays
/// and pauses from anywhere in Fetch. Requested directly (2026-09-25).
@MainActor
final class FetchListener: NSObject, ObservableObject {
    static let shared = FetchListener()

    enum Status { case idle, playing, paused }

    struct Group {
        let item: FeedItem
        let newCount: Int
        let isBrandNew: Bool
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
            speakCurrent()
        }
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
        let content = await FetchStore.shared.load(group.item, newCount: group.isBrandNew ? group.item.commentCount : group.newCount)
        guard status != .idle, groupIndex < groups.count, groups[groupIndex].item.id == group.item.id else { return }
        segments = Self.segments(for: group, content: content)
        segmentIndex = 0
        if status == .playing { speakCurrent() }
    }

    private func speakCurrent() {
        guard segmentIndex < segments.count else { return }
        generation += 1
        let utterance = AVSpeechUtterance(string: segments[segmentIndex])
        utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        utterance.postUtteranceDelay = 0.35
        synthesizer.speak(utterance)
    }

    private func advance() {
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
        let done = AVSpeechUtterance(string: String(localized: "That's everything new. Goldie's all caught up."))
        done.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        synthesizer.speak(done)
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
