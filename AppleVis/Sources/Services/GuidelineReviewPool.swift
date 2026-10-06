import CloudKit
import CryptoKit
import Foundation
import os

/// The team's guideline review decisions, pooled in CloudKit's public
/// database so every Site Editor and Admin sees how each rule is scoring
/// across everyone's reviews, not just their own. Admin-only: only the
/// Guideline Violation Check writes here. Requested directly (2026-10-06).
///
/// A decision is stored without the post itself: the rule, the verdict,
/// the line that set it off (trimmed), the thread title, and the link,
/// all of which are already public on the website. One record per flag per
/// reviewer, so changing your mind replaces your earlier decision.
///
/// Needs the iCloud container iCloud.com.applevis.AppleVisSwift with
/// CloudKit, and in the CloudKit Console the GuidelineReview record type
/// with decidedAt marked Queryable and Sortable, deployed to Production
/// before a TestFlight or App Store build can use it. Until then, or with
/// no iCloud account, it quietly does nothing and Your Reviews works as
/// before.
@MainActor
final class GuidelineReviewPool: ObservableObject {
    static let shared = GuidelineReviewPool()

    struct TeamReview: Sendable {
        let flagId: String
        let reviewer: String
        let ruleIds: [String]
        let ruleNames: [String]
        let verdict: GuidelineReview.Verdict
        let decidedAt: Date
    }

    @Published private(set) var teamReviews: [TeamReview] = []
    @Published private(set) var isLoading = false
    /// Set when the team's decisions couldn't be read, so the screen can
    /// say so instead of showing a team score built from nothing.
    @Published private(set) var unavailable = false

    private static let recordType = "GuidelineReview"
    private static let containerID = "iCloud.com.applevis.AppleVisSwift"
    /// How far back the team score looks.
    private static let window: TimeInterval = 180 * 24 * 3600

    private var database: CKDatabase {
        // Not CKContainer.default(): that crashes if the entitlement is missing.
        CKContainer(identifier: Self.containerID).publicCloudDatabase
    }

    private var reviewer: String? { AuthStore.current?.user?.name }

    private func recordID(flagId: String, reviewer: String) -> CKRecord.ID {
        // Record names allow up to 255 ASCII characters; flag ids and
        // usernames can hold anything, so a name that doesn't fit is hashed
        // (SHA-256, the same on every device and launch).
        let raw = "\(flagId)|\(reviewer.lowercased())"
        let name = raw.unicodeScalars.allSatisfy { $0.isASCII && $0 != " " } && raw.count < 200
            ? raw : "h-" + SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
        return CKRecord.ID(recordName: name)
    }

    // MARK: - Writing your decisions

    func share(_ review: GuidelineReview) {
        guard let reviewer else { return }
        let record = CKRecord(recordType: Self.recordType, recordID: recordID(flagId: review.id, reviewer: reviewer))
        record["flagId"] = review.id
        record["reviewer"] = reviewer
        record["ruleIds"] = review.ruleIds
        record["ruleNames"] = review.ruleNames
        record["verdict"] = review.verdict.rawValue
        record["severity"] = review.severity
        record["trigger"] = String(review.trigger.prefix(300))
        record["threadTitle"] = review.threadTitle
        record["url"] = review.url
        record["isReply"] = review.isReply ? 1 : 0
        record["appleIntelligence"] = review.appleIntelligence.map { "\($0.key)=\($0.value)" }.sorted()
        record["decidedAt"] = review.decidedAt
        let database = database
        Task {
            do {
                _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
                upsertLocally(TeamReview(flagId: review.id, reviewer: reviewer, ruleIds: review.ruleIds,
                                         ruleNames: review.ruleNames, verdict: review.verdict, decidedAt: review.decidedAt))
            } catch {
                AppLog.network.error("Guideline review pool save failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func withdraw(flagId: String) {
        guard let reviewer else { return }
        let id = recordID(flagId: flagId, reviewer: reviewer)
        teamReviews.removeAll { $0.flagId == flagId && $0.reviewer == reviewer }
        let database = database
        Task {
            do {
                _ = try await database.modifyRecords(saving: [], deleting: [id])
            } catch {
                AppLog.network.error("Guideline review pool delete failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func upsertLocally(_ review: TeamReview) {
        teamReviews.removeAll { $0.flagId == review.flagId && $0.reviewer == review.reviewer }
        teamReviews.append(review)
    }

    // MARK: - Reading the team's decisions

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let since = Date().addingTimeInterval(-Self.window)
        let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(format: "decidedAt > %@", since as NSDate))
        query.sortDescriptors = [NSSortDescriptor(key: "decidedAt", ascending: false)]
        var found: [TeamReview] = []
        do {
            var (results, cursor) = try await database.records(matching: query, resultsLimit: 400)
            found += results.compactMap { Self.teamReview(from: try? $0.1.get()) }
            // A few thousand decisions at most; stop well before that.
            var pages = 1
            while let next = cursor, pages < 10 {
                (results, cursor) = try await database.records(continuingMatchFrom: next, resultsLimit: 400)
                found += results.compactMap { Self.teamReview(from: try? $0.1.get()) }
                pages += 1
            }
            teamReviews = found
            unavailable = false
        } catch {
            unavailable = true
            AppLog.network.error("Guideline review pool fetch failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func teamReview(from record: CKRecord?) -> TeamReview? {
        guard let record,
              let flagId = record["flagId"] as? String,
              let reviewer = record["reviewer"] as? String,
              let ruleIds = record["ruleIds"] as? [String],
              let verdictRaw = record["verdict"] as? String,
              let verdict = GuidelineReview.Verdict(rawValue: verdictRaw),
              let decidedAt = record["decidedAt"] as? Date else { return nil }
        return TeamReview(flagId: flagId, reviewer: reviewer, ruleIds: ruleIds,
                          ruleNames: record["ruleNames"] as? [String] ?? ruleIds,
                          verdict: verdict, decidedAt: decidedAt)
    }

    // MARK: - Team scores

    /// Each rule's score across the whole team. Each flag counts once per
    /// rule, by majority; a tie counts as one of each, so a split decision
    /// shows up rather than disappearing.
    var ruleScores: [GuidelineReviewStore.RuleScore] {
        var byFlag: [String: [TeamReview]] = [:]
        for review in teamReviews { byFlag[review.flagId, default: []].append(review) }
        var tally: [String: (name: String, real: Int, fine: Int)] = [:]
        for reviews in byFlag.values {
            guard let first = reviews.first else { continue }
            let real = reviews.filter { $0.verdict == .realProblem }.count
            let fine = reviews.count - real
            for (index, rule) in first.ruleIds.enumerated() {
                var entry = tally[rule] ?? (first.ruleNames[safe: index] ?? rule, 0, 0)
                if real >= fine { entry.real += 1 }
                if fine >= real { entry.fine += 1 }
                tally[rule] = entry
            }
        }
        return tally.map { GuidelineReviewStore.RuleScore(id: $0.key, name: $0.value.name, real: $0.value.real, notAProblem: $0.value.fine) }
            .sorted { $0.realShare != $1.realShare ? $0.realShare < $1.realShare : $0.total > $1.total }
    }

    var reviewerCount: Int { Set(teamReviews.map { $0.reviewer.lowercased() }).count }

    /// Flags where reviewers disagreed, the most useful ones to talk over.
    var disagreements: Int {
        Dictionary(grouping: teamReviews, by: \.flagId).values
            .filter { Set($0.map(\.verdict)).count > 1 }.count
    }
}
