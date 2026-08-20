import Foundation

enum ContentSubmissionPolicy {
    enum ToneConcern: Int {
        case low = 1
        case medium = 2
        case high = 3
    }

    static var shouldDetectNonEnglish: Bool {
        UserDefaults.standard.object(forKey: "intel.nonEnglish") as? Bool ?? true
    }

    static func blockingMessage(subject: String? = nil, body: String, detectNonEnglish: Bool) -> String? {
        let text = policyText(subject: subject, body: body)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        if containsImageReference(text) {
            return String(localized: "Images and embedded image links are not allowed in AppleVis posts. Please remove the image reference before posting.")
        }

        if containsStrongVulgarLanguage(text) {
            return String(localized: "AppleVis posts must avoid vulgar or explicit language. Please edit your wording before posting.")
        }

        if toneConcern(in: text) == .high {
            return String(localized: "This draft may violate AppleVis guidelines on respectful community discussion. Please revise the tone before posting.")
        }

        if detectNonEnglish && IntelligenceService.detectNonEnglish(text) {
            return String(localized: "AppleVis posts must be in English. Please use Translate or edit your draft in English before posting.")
        }

        return nil
    }

    static func toneConcern(in text: String) -> ToneConcern? {
        let highPatterns = [
            #"\b(you|you're|you are|u r)\s+(an?\s+)?(idiot|moron|loser|stupid|dumb|clown|fool|jerk)\b"#,
            #"\b(shut\s+up|go\s+away|nobody\s+wants\s+you|you\s+should\s+leave)\b"#,
            #"\b(kill\s+yourself|kys|i\s+hope\s+you\s+(die|suffer))\b"#,
            #"\b(all|those)\s+(blind|disabled|deaf|autistic|lgbt|gay|trans|black|white|asian|jewish|muslim|christian)\s+(people\s+)?(are|should)\b"#,
            #"\b(troll|trolling)\b.*\b(shut\s+up|go\s+away|idiot|moron|stupid)\b"#,
        ]
        if highPatterns.contains(where: { matches(text, $0, caseInsensitive: true) }) {
            return .high
        }

        let mediumPatterns = [
            #"\b(this|that|your|you're|you are)\s+(is\s+)?(stupid|dumb|ridiculous|nonsense|garbage|trash)\b"#,
            #"\b(learn\s+to\s+read|use\s+your\s+brain|you\s+clearly\s+don't\s+know|you\s+obviously\s+don't\s+understand)\b"#,
            #"\b(stop\s+(whining|complaining|crying)|quit\s+(whining|complaining|crying))\b"#,
            #"\b(what\s+is\s+wrong\s+with\s+you|are\s+you\s+serious\s+right\s+now)\b"#,
        ]
        if mediumPatterns.contains(where: { matches(text, $0, caseInsensitive: true) }) {
            return .medium
        }

        let lowPatterns = [
            #"\b(obviously|clearly|whatever|come\s+on)\b.*[!?]"#,
            #"\b(i\s+can't\s+believe|that's\s+absurd|that's\s+annoying)\b"#,
        ]
        if lowPatterns.contains(where: { matches(text, $0, caseInsensitive: true) }) {
            return .low
        }

        return nil
    }

    static func policyText(subject: String? = nil, body: String) -> String {
        let joined = [subject, body].compactMap { $0 }.joined(separator: "\n")
        return joined
            .components(separatedBy: .newlines)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return !trimmed.hasPrefix(">") && !trimmed.localizedCaseInsensitiveContains(" wrote:")
            }
            .joined(separator: "\n")
    }

    static func containsImageReference(_ text: String) -> Bool {
        let patterns = [
            #"<\s*img\b"#,
            #"<\s*picture\b"#,
            #"<\s*source\b[^>]+type\s*=\s*["']image/"#,
            #"\!\[[^\]]*\]\([^)]+\)"#,
            #"data:image/"#,
            #"\bhttps?://\S+\.(png|jpe?g|gif|webp|heic|heif|tiff?|bmp|svg)(\?\S*)?\b"#,
            #"\b\S+\.(png|jpe?g|gif|webp|heic|heif|tiff?|bmp|svg)\b"#,
        ]
        return patterns.contains { matches(text, $0, caseInsensitive: true) }
    }

    static func containsStrongVulgarLanguage(_ text: String) -> Bool {
        let patterns = [
            #"\bf+[\W_]*u+[\W_]*c+[\W_]*k+(er|ing|ed|s)?\b"#,
            #"\bc+[\W_]*u+[\W_]*n+[\W_]*t+s?\b"#,
            #"\bm+[\W_]*o+[\W_]*t+[\W_]*h+[\W_]*e+[\W_]*r+[\W_]*f+[\W_]*u+[\W_]*c+[\W_]*k+(er|ing|ed|s)?\b"#,
            #"\bc+[\W_]*o+[\W_]*c+[\W_]*k+[\W_]*s+[\W_]*u+[\W_]*c+[\W_]*k+(er|ing|ing)?\b"#,
            #"\bc+[\W_]*u+[\W_]*m+[\W_]*s+[\W_]*h+[\W_]*o+[\W_]*t+s?\b"#,
        ]
        return patterns.contains { matches(text, $0, caseInsensitive: true) }
    }

    private static func matches(_ text: String, _ pattern: String, caseInsensitive: Bool = false) -> Bool {
        var options: String.CompareOptions = [.regularExpression]
        if caseInsensitive { options.insert(.caseInsensitive) }
        return text.range(of: pattern, options: options) != nil
    }
}
