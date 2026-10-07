import Foundation
import os

/// The guideline checks' patterns, word lists, and Apple Intelligence's rule
/// descriptions, from one shared file, guideline-rules.json, instead of being
/// written into the code twice (here and in the review tool). Requested
/// directly (2026-10-06).
///
/// Three copies, newest valid one wins:
/// 1. The built-in copy in every build, so the checks always work, even on
///    the first launch with no internet.
/// 2. The last downloaded copy, saved on the device, so a missing connection
///    or an unreachable GitHub never goes back to older rules.
/// 3. The published copy (published/guideline-rules.json in the public
///    GitHub repo), checked now and then, so a rule fix reaches members
///    without an app update.
/// A download that's damaged, older, missing a pattern, or has a pattern
/// that won't compile is ignored. A newer build's built-in copy replaces an
/// older download. Data only: what the patterns are, never how they're used.
nonisolated final class GuidelineRules: @unchecked Sendable {
    struct Document: Codable {
        let version: Int
        let updated: String
        let variables: [String: String]
        let patterns: [String: [String]]
        let lists: [String: [String]]
        let ai: AI
    }

    struct AI: Codable {
        let meanings: [String: String]
        let examples: [String: Example]
    }

    struct Example: Codable {
        let fine: String
        let breaks: String
    }

    static let publishedURL = URL(string: "https://raw.githubusercontent.com/thomas-domville/AppleVis/master/published/guideline-rules.json")!

    /// Every pattern the code asks for. A file missing any of them is ignored.
    static let requiredPatterns = [
        "image", "vulgarStrong", "crude", "toneHigh", "toneMedium", "tonePutDown", "tonePutDownSentence",
        "toneLowSentence", "toneLowAnywhere", "toneThanks", "shutUp", "shutUpAtDevice", "selfShutUp",
        "mannerAdverbAfter", "mannerAdverbBefore", "quotedPassage", "moderation", "selfPromotion",
        "selfPromotionFeedback", "selfPromotionMyThing", "link", "referral", "advertising", "pressRelease",
        "aiDisclosure", "shoutingMarks", "shoutingCaps", "shoutingExcitement", "topicSwitch", "emailAddress",
        "emailInvitation", "emailProject", "emailHeaderBefore", "emailHeaderAfter", "announcementTopic",
        "announcementInvitation",
    ]
    static let requiredLists = ["lowValuePhrases", "personalEmailProviders", "personalEmailRegionalBases"]

    let version: Int
    let source: String
    private let patterns: [String: [String]]
    private let lists: [String: [String]]
    private let ai: AI

    /// Nil when the file isn't a complete, working set of rules.
    init?(data: Data, source: String) {
        guard let doc = try? JSONDecoder().decode(Document.self, from: data) else { return nil }
        var expanded: [String: [String]] = [:]
        for (key, list) in doc.patterns {
            expanded[key] = list.map { pattern in
                doc.variables.reduce(pattern) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
            }
        }
        for key in Self.requiredPatterns {
            guard let list = expanded[key], !list.isEmpty,
                  list.allSatisfy({ (try? NSRegularExpression(pattern: $0)) != nil }) else {
                AppLog.network.error("Guideline rules from \(source, privacy: .public) rejected: pattern \(key, privacy: .public)")
                return nil
            }
        }
        for key in Self.requiredLists where (doc.lists[key] ?? []).isEmpty {
            AppLog.network.error("Guideline rules from \(source, privacy: .public) rejected: list \(key, privacy: .public)")
            return nil
        }
        version = doc.version
        self.source = source
        patterns = expanded
        lists = doc.lists
        ai = doc.ai
    }

    func patterns(_ key: String) -> [String] { patterns[key] ?? [] }
    /// The single pattern stored under `key`.
    func pattern(_ key: String) -> String { patterns[key]?.first ?? "(?!)" }
    func list(_ key: String) -> [String] { lists[key] ?? [] }

    /// What a judgement-call rule means, with a real example of each side,
    /// for Apple Intelligence's second opinion.
    func meaning(forRule id: String) -> String? {
        let key: String
        switch id {
        case "tone-medium", "tone-low": key = "tone"
        case "excessive-punctuation", "all-caps": key = "shouting"
        default: key = id
        }
        guard let meaning = ai.meanings[key] else { return nil }
        guard let example = ai.examples[key] else { return meaning }
        return meaning + " Example that's fine: \"\(example.fine)\" Example that breaks it: \"\(example.breaks)\""
    }

    // MARK: - Which copy is in use

    private static let lock = NSLock()
    nonisolated(unsafe) private static var active: GuidelineRules = best()

    static var current: GuidelineRules {
        lock.lock(); defer { lock.unlock() }
        return active
    }

    private static var savedURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("guideline-rules.json")
    }

    static var builtIn: GuidelineRules {
        guard let url = Bundle.main.url(forResource: "guideline-rules", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rules = GuidelineRules(data: data, source: "built-in") else {
            // Every build is checked by GuidelineRulesTests, so this can't ship broken.
            fatalError("The built-in guideline-rules.json is missing or invalid.")
        }
        return rules
    }

    /// The downloaded copy, when it's newer than the built-in one.
    private static func best() -> GuidelineRules {
        let builtIn = builtIn
        if let data = try? Data(contentsOf: savedURL),
           let saved = GuidelineRules(data: data, source: "downloaded"),
           saved.version > builtIn.version {
            return saved
        }
        return builtIn
    }

    // MARK: - Checking for a newer published copy

    private static let lastCheckKey = "guidelineRules.lastCheck"

    /// At most twice a day, when the app comes to the front. Quiet on
    /// failure: the copy in use carries on.
    static func refreshIfDue() async {
        let last = UserDefaults.standard.double(forKey: lastCheckKey)
        guard Date().timeIntervalSince1970 - last > 12 * 3600 else { return }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)
        var request = URLRequest(url: publishedURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let published = GuidelineRules(data: data, source: "published"),
              published.version > current.version
        else { return }
        try? data.write(to: savedURL, options: .atomic)
        Self.lock.withLock { active = published }
        AppLog.network.info("Guideline rules updated to version \(published.version)")
    }
}
