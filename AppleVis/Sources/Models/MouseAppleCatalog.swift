import Foundation

/// Every topic in Apple's user guides for iPhone, iPad, Apple Watch, Mac,
/// AirPods, and Apple TV, plus the VoiceOver guide for Mac: about 2,600
/// titles and addresses, taken from each guide's own table of contents
/// on 2026-10-01 and shipped in MouseAppleCatalog.json. The device picks
/// the few titles that best match a question, and Apple Intelligence
/// chooses among those, so any Apple question can get a link to Apple's
/// own page, not just the ones hand-picked in `MouseAppleLink`. Plain
/// links only: the Mouse never reads Apple's pages (App Review 4.5.1).
/// Titles are Apple's, in English. Requested directly (2026-10-01).
nonisolated enum MouseAppleCatalog {
    struct Entry: Codable, Hashable, Sendable {
        /// Apple's topic title, such as "Force restart iPhone".
        let t: String
        /// The guide's device, such as "iPhone" or "Apple Watch".
        let d: String
        /// The page's address.
        let u: String

        var title: String { t }
        var device: String { d }
        var url: URL? { URL(string: u) }
        /// "Force restart iPhone (iPhone User Guide)", so it's clear
        /// whose guide it's from.
        var label: String {
            d == "Mac VoiceOver"
                ? String(localized: "\(t) (VoiceOver User Guide for Mac)")
                : String(localized: "\(t) (\(d) User Guide)")
        }
    }

    static let entries: [Entry] = {
        guard let url = Bundle.main.url(forResource: "MouseAppleCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return list
    }()

    /// Words that don't tell topics apart.
    private static let common: Set<String> = [
        "use", "using", "iphone", "ipad", "mac", "apple", "watch", "your", "my", "how", "do", "i", "the", "a", "an",
        "on", "in", "to", "of", "and", "or", "with", "for", "what", "is", "can", "get", "set", "up", "about",
    ]

    /// The device a question is about, from its words. "Phone" means iPhone.
    static func device(in question: String) -> String? {
        let words = Set(AskTheMouse.normalizedForMatching(question).split(separator: " ").map(String.init))
        if words.contains("ipad") { return "iPad" }
        if words.contains("watch") { return "Apple Watch" }
        if words.contains("airpods") { return "AirPods" }
        if words.contains("tv") { return "Apple TV" }
        if words.contains("mac") || words.contains("macbook") || words.contains("macos") {
            return words.contains("voiceover") ? "Mac VoiceOver" : "Mac"
        }
        if words.contains("iphone") || words.contains("phone") { return "iPhone" }
        return nil
    }

    /// Words that can't start a word pair worth matching.
    private static let pairStop: Set<String> = ["how", "do", "i", "the", "a", "an", "to", "is", "what", "can"]

    /// How many titles each word appears in, so rare words count more.
    private static let titleCounts: [String: Int] = {
        var counts: [String: Int] = [:]
        for entry in entries {
            for word in Set(AskTheMouse.normalizedForMatching(entry.t).split(separator: " ").map(String.init)) {
                counts[word, default: 0] += 1
            }
        }
        return counts
    }()

    private static func weight(_ word: String) -> Double {
        log(Double(max(entries.count, 1)) / Double(1 + (titleCounts[word] ?? 0)))
    }

    /// The one topic that clearly matches, from English search words: at
    /// least two question words, or two in a row, in its title. For when
    /// the question itself didn't match any titles, such as one asked in
    /// another language. Nil when nothing is clear.
    static func confidentMatch(for question: String, phrases: [String]) -> Entry? {
        let english = phrases.joined(separator: " ")
        guard let best = candidates(for: question + " " + english, phrases: [], limit: 1).first else { return nil }
        let titleWords = Set(AskTheMouse.normalizedForMatching(best.t).split(separator: " ").map(String.init))
        let words = Set(AskTheMouse.normalizedForMatching(english).split(separator: " ").map(String.init))
            .subtracting(common).filter { $0.count >= 3 }
        let hits = words.filter { word in titleWords.contains { $0 == word || ($0.hasPrefix(word) && word.count >= 4) } }
        return hits.count >= 2 ? best : nil
    }

    /// The few topics whose titles best match the question, for its device
    /// (iPhone when it doesn't say). Rare words count more than common
    /// ones ("battery" more than "check"), a word counts when it matches a
    /// title word or starts it ("restart" and "restarting"), and two
    /// question words in a row in the title count extra ("back up" beats
    /// "Back Tap"). Tested on 2026-10-01 against the questions people ask
    /// most.
    static func candidates(for question: String, phrases: [String], limit: Int = 6) -> [Entry] {
        let text = ([question] + phrases).joined(separator: " ")
        let all = AskTheMouse.normalizedForMatching(text).split(separator: " ").map(String.init)
        let words = Set(all).subtracting(common).filter { $0.count >= 3 }
        let kept = all.filter { !pairStop.contains($0) }
        let pairs = Set(zip(kept, kept.dropFirst()).map { "\($0) \($1)" })
        guard !words.isEmpty || !pairs.isEmpty else { return [] }
        let wanted = device(in: question) ?? "iPhone"
        let scored: [(Entry, Double)] = entries.compactMap { entry in
            let normalized = AskTheMouse.normalizedForMatching(entry.t)
            let titleWords = normalized.split(separator: " ").map(String.init)
            let padded = " \(normalized) "
            var score = words.filter { word in
                titleWords.contains { $0 == word || ($0.hasPrefix(word) && word.count >= 4) || (word.hasPrefix($0) && $0.count >= 5) }
            }.reduce(0) { $0 + weight($1) }
            score += Double(pairs.filter { padded.contains(" \($0) ") }.count) * 4
            guard score > 0 else { return nil }
            return (entry, score + (entry.d == wanted ? 1.5 : 0))
        }
        return scored
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.t.count < $1.0.t.count }
            .prefix(limit)
            .map(\.0)
    }
}
