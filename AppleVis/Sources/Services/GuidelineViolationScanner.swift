import Foundation

/// How far back a moderator scan looks. Deliberately just three coarse
/// options rather than a free date picker — this is meant to be a quick
/// glance, not an archival search tool.
enum GuidelineScanRange: Int, CaseIterable, Identifiable {
    case day, threeDays, week

    var id: Self { self }

    var days: Int {
        switch self {
        case .day: return 1
        case .threeDays: return 3
        case .week: return 7
        }
    }

    var displayName: String {
        switch self {
        case .day: return "Past Day"
        case .threeDays: return "Past 3 Days"
        case .week: return "Past Week"
        }
    }
}

/// One flagged piece of content — either a forum topic's own opening post,
/// or a reply within it. Reuses `GuidelinesChecker` unchanged: the same
/// rule engine that advises someone while composing their own draft, run
/// here against everyone's already-posted content instead.
struct GuidelineFlag: Identifiable {
    let id: String
    let topicId: String
    let topicTitle: String
    let authorName: String
    let excerpt: String
    let createdAt: Date
    let isTopicItself: Bool
    let warnings: [GuidelineWarning]

    var highestSeverity: GuidelineWarning.Severity {
        warnings.map(\.severity).min(by: { $0.sortOrder < $1.sortOrder }) ?? .low
    }
}

extension GuidelineWarning.Severity {
    /// High first, then medium, then low.
    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }
}

/// Scans recently-active forum topics (and their replies) for possible
/// guideline violations, for the Moderator Tools admin screen. Forums-only
/// for now — the highest-volume, highest-risk surface, and the only one
/// where `forums/recent` gives a cheap, activity-sorted way to find what's
/// actually new without an exhaustive site-wide fetch. Extending this to
/// app reviews, blog/guide/bug/podcast comments would need either the same
/// per-item fetch cost repeated per content type, or (better) a real
/// Drupal endpoint for "recent comments across every bundle."
///
/// Deliberately reuses `ForumEndpoints.recent`/`topicDetail` exactly as
/// ForumsBrowseView/ForumTopicDetailView already call them, key-for-key —
/// so this scan shares the same `fetchWithCache` disk cache those screens
/// already populate. A topic anyone using this device opened recently
/// costs nothing to re-scan; nothing here proactively fetches in the
/// background, only when a moderator explicitly opens this screen and
/// picks a range.
@MainActor
final class GuidelineViolationScanner: ObservableObject {
    @Published private(set) var flags: [GuidelineFlag] = []
    @Published private(set) var isScanning = false
    @Published private(set) var scannedTopicCount = 0
    @Published var error: String?

    private var currentScanId = UUID()

    func scan(range: GuidelineScanRange) async {
        let scanId = UUID()
        currentScanId = scanId
        isScanning = true
        error = nil
        flags = []
        scannedTopicCount = 0

        let cutoff = Calendar.current.date(byAdding: .day, value: -range.days, to: Date()) ?? Date()

        let candidates: [ForumTopic]
        do {
            candidates = try await Self.recentlyActiveTopics(since: cutoff)
        } catch {
            guard currentScanId == scanId else { return }
            self.error = "Couldn't load recent forum activity. Try again."
            isScanning = false
            return
        }
        guard currentScanId == scanId else { return }
        scannedTopicCount = candidates.count

        let results = await Self.scanTopics(candidates, cutoff: cutoff)
        guard currentScanId == scanId else { return }

        flags = results.sorted { a, b in
            if a.highestSeverity.sortOrder != b.highestSeverity.sortOrder {
                return a.highestSeverity.sortOrder < b.highestSeverity.sortOrder
            }
            return a.createdAt > b.createdAt
        }
        isScanning = false
    }

    /// Pages through `forums/recent` (already sorted by last activity, and
    /// deliberately `appleOnly: false` — this tool covers everything, no
    /// Home-style content filtering) until a page's topics fall outside the
    /// window, then stops. Safety-capped at 50 pages so a runaway loop
    /// can't hang indefinitely if the sort order ever misbehaves.
    private static func recentlyActiveTopics(since cutoff: Date) async throws -> [ForumTopic] {
        var results: [ForumTopic] = []
        var page = 0
        while page < 50 {
            let batch = try await APIClient.shared.forums.recent(page: page, appleOnly: false)
            if batch.isEmpty { break }
            var reachedCutoff = false
            for topic in batch {
                if topic.lastActivityAt < cutoff {
                    reachedCutoff = true
                    break
                }
                results.append(topic)
            }
            if reachedCutoff { break }
            page += 1
        }
        return results
    }

    /// Bounded concurrency (4 at a time) — fetching every candidate topic's
    /// full detail at once would be a needless burst against the API for a
    /// busy week; this stays a reasonable citizen while still being much
    /// faster than doing them one at a time.
    private static func scanTopics(_ topics: [ForumTopic], cutoff: Date) async -> [GuidelineFlag] {
        var results: [GuidelineFlag] = []
        await withTaskGroup(of: [GuidelineFlag].self) { group in
            var iterator = topics.makeIterator()
            let maxConcurrent = 4
            for _ in 0..<maxConcurrent {
                guard let topic = iterator.next() else { break }
                group.addTask { await scanTopic(topic, cutoff: cutoff) }
            }
            while let topicFlags = await group.next() {
                results.append(contentsOf: topicFlags)
                if let topic = iterator.next() {
                    group.addTask { await scanTopic(topic, cutoff: cutoff) }
                }
            }
        }
        return results
    }

    private static func scanTopic(_ topic: ForumTopic, cutoff: Date) async -> [GuidelineFlag] {
        guard let detail = try? await APIClient.shared.forums.topicDetail(id: topic.id) else { return [] }
        var flags: [GuidelineFlag] = []

        if detail.createdAt >= cutoff {
            let warnings = GuidelinesChecker.check(detail.body)
            if !warnings.isEmpty {
                flags.append(GuidelineFlag(
                    id: "topic-\(detail.id)", topicId: detail.id, topicTitle: detail.title,
                    authorName: detail.authorName, excerpt: .excerpt(from: detail.body),
                    createdAt: detail.createdAt, isTopicItself: true, warnings: warnings
                ))
            }
        }

        for reply in detail.replies where reply.createdAt >= cutoff {
            let warnings = GuidelinesChecker.check(reply.body)
            if !warnings.isEmpty {
                flags.append(GuidelineFlag(
                    id: "reply-\(reply.id)", topicId: detail.id, topicTitle: detail.title,
                    authorName: reply.authorName, excerpt: .excerpt(from: reply.body),
                    createdAt: reply.createdAt, isTopicItself: false, warnings: warnings
                ))
            }
        }

        return flags
    }
}
