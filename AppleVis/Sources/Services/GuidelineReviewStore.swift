import Combine
import Foundation
import CryptoKit

/// An admin's decision on one guideline flag, kept so the rules can be
/// improved from real cases rather than from flags someone happened to
/// notice. Exported now and then and used to tune the rules, the examples
/// Apple Intelligence is shown, and the tests, which then reach everyone
/// in an app update. Admin-only. Requested directly (2026-10-06).
nonisolated struct GuidelineReview: Codable, Identifiable, Sendable {
    enum Verdict: String, Codable, Sendable { case notAProblem, realProblem }

    /// The flag's id, so the same post isn't counted twice.
    let id: String
    let ruleIds: [String]
    let ruleNames: [String]
    let severity: String
    let verdict: Verdict
    /// The line that set the rule off, when known.
    let trigger: String
    /// The post in plain text, trimmed. Only kept on this device; the
    /// iCloud copy leaves it out to stay small.
    var text: String
    let threadTitle: String
    let kind: String
    let isReply: Bool
    /// Apple Intelligence's answer per rule at the time: breaks, fine, or unsure.
    let appleIntelligence: [String: String]
    let url: String?
    let postedAt: Date
    let decidedAt: Date
}

@MainActor
final class GuidelineReviewStore: ObservableObject {
    static let shared = GuidelineReviewStore()

    @Published private(set) var reviews: [String: GuidelineReview] = [:]
    /// Decisions already sent to AppleVis, so they're not sent twice.
    @Published private(set) var sentIds: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "admin.guidelineReviewsSent") ?? [])

    var unsent: [GuidelineReview] {
        reviews.values.filter { !sentIds.contains($0.id) }.sorted { $0.decidedAt > $1.decidedAt }
    }

    /// For the Send Notes wizard: the unsent decisions, newest first, up to
    /// what fits in one Contact form message. Requested directly (2026-10-06).
    func notesPackage() -> NotesPackage {
        let pending = unsent
        let real = pending.filter { $0.verdict == .realProblem }.count
        return NotesPackage(
            title: "Send Review Notes",
            subject: "App Guideline Review Notes",
            summary: [
                String(localized: "\(pending.count) decisions not sent yet"),
                String(localized: "\(real) real problems, \(pending.count - real) not a problem"),
                String(localized: "Each with its rule, the line that set it off, and Apple Intelligence's verdict"),
            ],
            offersTextChoice: true,
            makeMessage: { includeText in Self.message(for: pending, includeText: includeText) },
            markSent: { [weak self] ids in self?.markSent(ids) }
        )
    }

    private func markSent(_ ids: [String]) {
        sentIds.formUnion(ids)
        UserDefaults.standard.set(Array(sentIds), forKey: "admin.guidelineReviewsSent")
    }

    /// Readable notes, newest first, kept under 15,000 characters so the
    /// Contact form takes them; anything left goes next time.
    nonisolated static func message(for reviews: [GuidelineReview], includeText: Bool) -> (text: String, ids: [String]) {
        var text = "AppleVis guideline review notes, \(reviews.count) decisions.\n\n"
        var ids: [String] = []
        for review in reviews {
            var entry = "[\(review.verdict == .realProblem ? "REAL PROBLEM" : "NOT A PROBLEM")] \(review.ruleNames.joined(separator: ", ")) {\(review.ruleIds.joined(separator: ","))} (\(review.severity))\n"
            entry += "Reply: \(review.isReply ? "yes" : "no")\n"
            entry += "In: \(review.threadTitle)\(review.isReply ? " (reply)" : "")\n"
            if !review.trigger.isEmpty { entry += "Trigger: \(review.trigger)\n" }
            if !review.appleIntelligence.isEmpty {
                entry += "Apple Intelligence: " + review.appleIntelligence.map { "\($0.key) \($0.value)" }.sorted().joined(separator: ", ") + "\n"
            }
            if let url = review.url { entry += "\(url)\n" }
            if includeText, !review.text.isEmpty { entry += "Text: \(review.text.replacingOccurrences(of: "\n", with: " "))\n" }
            entry += "\n"
            if text.count + entry.count > 15_000 { break }
            text += entry
            ids.append(review.id)
        }
        if ids.count < reviews.count {
            text += "(\(reviews.count - ids.count) more to send next time.)\n"
        }
        return (text, ids)
    }

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("guideline-reviews.json")
    }

    private init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? JSONDecoder().decode([GuidelineReview].self, from: data) {
            reviews = Dictionary(saved.map { ($0.id, $0) }, uniquingKeysWith: { $0.decidedAt > $1.decidedAt ? $0 : $1 })
        }
    }

    func verdict(for flagId: String) -> GuidelineReview.Verdict? { reviews[flagId]?.verdict }

    func record(_ verdict: GuidelineReview.Verdict, for flag: GuidelineFlag,
                opinions: [String: IntelligenceService.GuidelineSecondOpinion]) {
        let ai = opinions.mapValues { $0.isUnsure ? "unsure" : ($0.isRealConcern ? "breaks" : "fine") }
        let trigger = flag.warnings.compactMap { flag.triggers[$0.id] }.first ?? ""
        // A flag with no rules comes from the "would be blocked as not
        // English" list.
        let isLanguageCheck = flag.warnings.isEmpty
        reviews[flag.id] = GuidelineReview(
            id: flag.id,
            ruleIds: isLanguageCheck ? ["english-only"] : flag.warnings.map(\.id),
            ruleNames: isLanguageCheck ? ["English Only (blocks posting)"] : flag.warnings.map(\.rule),
            severity: isLanguageCheck ? "high" : "\(flag.highestSeverity)", verdict: verdict, trigger: trigger,
            text: String(HTMLText.plainText(fromHTML: flag.body).prefix(1_500)),
            threadTitle: flag.itemTitle, kind: flag.kind.rawValue, isReply: !flag.isRootItem,
            appleIntelligence: ai, url: flag.url, postedAt: flag.createdAt, decidedAt: Date()
        )
        save()
        ICloudSyncManager.shared.pushGuidelineReviews()
    }

    func undo(for flagId: String) {
        reviews[flagId] = nil
        save()
        ICloudSyncManager.shared.pushGuidelineReviews()
    }

    /// How often each rule's flags turned out to be real, from your
    /// decisions. A rule that's mostly "Not a Problem" needs fixing.
    struct RuleScore: Identifiable {
        let id: String
        let name: String
        let real: Int
        let notAProblem: Int
        var total: Int { real + notAProblem }
        var realShare: Double { total == 0 ? 0 : Double(real) / Double(total) }
    }

    var ruleScores: [RuleScore] {
        var tally: [String: (name: String, real: Int, fine: Int)] = [:]
        for review in reviews.values {
            for (index, rule) in review.ruleIds.enumerated() {
                var entry = tally[rule] ?? (review.ruleNames[safe: index] ?? rule, 0, 0)
                if review.verdict == .realProblem { entry.real += 1 } else { entry.fine += 1 }
                tally[rule] = entry
            }
        }
        return tally.map { RuleScore(id: $0.key, name: $0.value.name, real: $0.value.real, notAProblem: $0.value.fine) }
            .sorted { $0.realShare != $1.realShare ? $0.realShare < $1.realShare : $0.total > $1.total }
    }

    // MARK: - iCloud (your own devices)

    /// What iCloud carries: decisions without the post text, newest 300,
    /// to stay well inside iCloud's small key-value storage.
    var cloudCopy: [GuidelineReview] {
        reviews.values.sorted { $0.decidedAt > $1.decidedAt }.prefix(300).map {
            var slim = $0
            slim.text = ""
            return slim
        }
    }

    /// Merges decisions from another device: the newer decision on a flag wins.
    func merge(fromCloud cloud: [GuidelineReview]) {
        var changed = false
        for review in cloud {
            if let local = reviews[review.id], local.decidedAt >= review.decidedAt { continue }
            var incoming = review
            if incoming.text.isEmpty, let local = reviews[review.id] { incoming.text = local.text }
            reviews[review.id] = incoming
            changed = true
        }
        if changed { save() }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(Array(reviews.values)) else { return }
        try? data.write(to: Self.fileURL, options: [.atomic, .completeFileProtection])
    }
}

/// Apple Intelligence's verdicts from earlier scans, so a re-scan only asks
/// about posts that are new or were edited since. Keyed by flag, rule, the
/// post's text, and whether the conversation was read. Requested directly
/// (2026-10-06).
@MainActor
final class GuidelineOpinionCache {
    static let shared = GuidelineOpinionCache()

    private var entries: [String: Entry] = [:]
    private struct Entry: Codable {
        let opinion: IntelligenceService.GuidelineSecondOpinion
        let savedAt: Date
    }

    private static var fileURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("guideline-opinions.json")
    }

    private init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? JSONDecoder().decode([String: Entry].self, from: data) {
            entries = saved
        }
    }

    static func key(flagId: String, ruleId: String, text: String, readsConversation: Bool) -> String {
        let digest = SHA256.hash(data: Data(text.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
        return "\(flagId)|\(ruleId)|\(digest)|\(readsConversation ? 1 : 0)"
    }

    func opinion(for key: String) -> IntelligenceService.GuidelineSecondOpinion? { entries[key]?.opinion }

    func store(_ opinion: IntelligenceService.GuidelineSecondOpinion, for key: String) {
        entries[key] = Entry(opinion: opinion, savedAt: Date())
        // Keep the newest 3,000; a busy month is a few hundred.
        if entries.count > 3_000 {
            for old in entries.sorted(by: { $0.value.savedAt < $1.value.savedAt }).prefix(entries.count - 3_000) {
                entries[old.key] = nil
            }
        }
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }

    /// Forgets every saved verdict, for a fresh look after the rules change.
    func clear() {
        entries = [:]
        try? FileManager.default.removeItem(at: Self.fileURL)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
