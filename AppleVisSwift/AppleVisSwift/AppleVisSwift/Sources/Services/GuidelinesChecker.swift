import Foundation

/// AppleVis Posting Guidelines checker — rule-based checks derived from
/// https://www.applevis.com/help/guidelines. Advisory only: never blocks
/// posting, just surfaces a dismissible reminder while composing.
struct GuidelineWarning: Identifiable, Equatable {
    enum Severity { case high, medium, low }

    /// Stable ID used to track which warnings the user has dismissed.
    let id: String
    /// Short guideline name shown as the banner heading.
    let rule: String
    /// Friendly, specific 1-2 sentence message shown to the user.
    let message: String
    let severity: Severity
}

enum GuidelinesChecker {
    /// Returns warnings sorted by severity: high -> medium -> low.
    static func check(_ text: String) -> [GuidelineWarning] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else { return [] }
        let lower = trimmed.lowercased()

        var warnings: [GuidelineWarning] = []

        // Personal information (email address)
        if matches(text, #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#) {
            warnings.append(GuidelineWarning(
                id: "personal-info", rule: "Personal Information",
                message: "Your post appears to contain an email address. For your privacy and security, the AppleVis guidelines recommend not sharing personal contact information publicly.",
                severity: .medium
            ))
        }

        // Referral / affiliate links
        if matches(text, #"[?&](ref|referral|affiliate|aff|partner|subid)="#, caseInsensitive: true) {
            warnings.append(GuidelineWarning(
                id: "referral-link", rule: "No Referral Links",
                message: "Your post may contain a referral or affiliate link. These are not permitted on AppleVis as they can create conflicts of interest.",
                severity: .medium
            ))
        }

        // Self-promotion
        if matches(text, #"\bmy (podcast|youtube channel|channel|website|blog|newsletter|mailing list|substack|patreon)\b"#, caseInsensitive: true) {
            warnings.append(GuidelineWarning(
                id: "self-promotion", rule: "No Self-Promotion",
                message: "AppleVis asks that you not use the forums to promote your own podcast, YouTube channel, website, newsletter, or other online resource.",
                severity: .medium
            ))
        }

        // Advertising / selling
        if matches(text, #"(\bfor sale\b|\bwanted to buy\b|\bbuy now\b|\bpromo code\b|\bcoupon code\b|\bget \d+% off\b)"#, caseInsensitive: true) {
            warnings.append(GuidelineWarning(
                id: "advertising", rule: "No Advertising or Selling",
                message: "AppleVis forums are not for selling, trading, or advertising products or services. If you believe this is genuinely useful to the community, please contact AppleVis first.",
                severity: .medium
            ))
        }

        // Announcements requiring prior approval
        if matches(text, #"\b(survey|research study|research project|focus group|participants? needed|looking for participants?|study participants?)\b"#, caseInsensitive: true) {
            warnings.append(GuidelineWarning(
                id: "announcement-approval", rule: "Approval Required for Announcements",
                message: "Posts about surveys, research projects, or studies require prior approval from the AppleVis Editorial Team. Please contact them via the Contact Form before posting.",
                severity: .high
            ))
        }

        // Press releases for pure promotion
        if matches(text, #"\bpress release\b"#, caseInsensitive: true) || matches(text, #"\bfor immediate release\b"#, caseInsensitive: true) {
            warnings.append(GuidelineWarning(
                id: "press-release", rule: "Press Releases",
                message: "Press releases may only be posted as part of a broader discussion, not purely to promote a product or service. Make sure your post adds context beyond the release itself.",
                severity: .medium
            ))
        }

        // AI-generated content without disclosure
        let aiArtifacts = [
            "as an ai", "as a language model", "i don't have personal experience",
            "i cannot browse the internet", "as of my knowledge cutoff",
            "i'm unable to access real-time", "certainly! here's", "absolutely! here's",
            "sure! here's a", "great question! here",
        ]
        if aiArtifacts.contains(where: { lower.contains($0) }) {
            warnings.append(GuidelineWarning(
                id: "ai-disclosure", rule: "Disclose AI-Generated Content",
                message: "Your post may contain AI-generated text. AppleVis requires you to clearly state in the body of your post when AI tools have been used to help generate the content.",
                severity: .medium
            ))
        }

        // All-caps (perceived shouting)
        let wordTokens = trimmed.split(separator: " ").map(String.init)
            .filter { $0.count > 3 && $0.contains(where: { $0.isLetter }) }
        if wordTokens.count >= 5 {
            let capsCount = wordTokens.filter { $0 == $0.uppercased() && $0.contains(where: { $0.isUppercase }) }.count
            if Double(capsCount) / Double(wordTokens.count) > 0.55 {
                warnings.append(GuidelineWarning(
                    id: "all-caps", rule: "Be Polite",
                    message: "Your post uses a lot of capital letters, which can read as shouting. Normal capitalization will make it easier and friendlier to read.",
                    severity: .low
                ))
            }
        }

        // Excessive punctuation
        if matches(text, #"[!?]{3,}"#) {
            warnings.append(GuidelineWarning(
                id: "excessive-punctuation", rule: "Be Polite",
                message: "Your post contains multiple consecutive exclamation marks or question marks. Toning these down will help your message come across more calmly.",
                severity: .low
            ))
        }

        // Low-value / no-value reply
        if trimmed.count < 60 {
            let noValuePhrases = [
                "me too", "same here", "same issue", "same problem", "same for me",
                "same thing", "ditto", "i agree", "agreed", "just google it",
                "try googling", "just search for it", "i haven't used", "i don't use that",
                "never used it", "haven't tried it", "can't help",
            ]
            if noValuePhrases.contains(where: { lower.contains($0) }) {
                warnings.append(GuidelineWarning(
                    id: "low-value", rule: "Add Value to the Discussion",
                    message: "Short replies like \"me too\" or \"I haven't used that\" don't add much to the discussion. Consider sharing specific details, experience, or a follow-up question instead.",
                    severity: .low
                ))
            }
        }

        // Multiple questions / topics
        let questionCount = text.filter { $0 == "?" }.count
        if questionCount >= 3 && trimmed.count > 120 {
            warnings.append(GuidelineWarning(
                id: "multi-topic", rule: "One Topic Per Post",
                message: "Your post appears to ask several different questions. AppleVis guidelines ask that you cover one topic per post — splitting into separate posts will get you better answers.",
                severity: .low
            ))
        }

        // Spam / repetition
        let sentences = trimmed
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { $0.count > 15 }
        if sentences.count >= 4 {
            let unique = Set(sentences)
            if Double(unique.count) / Double(sentences.count) < 0.55 {
                warnings.append(GuidelineWarning(
                    id: "repetition", rule: "No Spam or Repetition",
                    message: "Your post contains repeated phrases or sentences. Please avoid repeating the same content multiple times in a single post.",
                    severity: .medium
                ))
            }
        }

        let order: [GuidelineWarning.Severity: Int] = [.high: 0, .medium: 1, .low: 2]
        return warnings.sorted { order[$0.severity, default: 2] < order[$1.severity, default: 2] }
    }

    private static func matches(_ text: String, _ pattern: String, caseInsensitive: Bool = false) -> Bool {
        var options: String.CompareOptions = [.regularExpression]
        if caseInsensitive { options.insert(.caseInsensitive) }
        return text.range(of: pattern, options: options) != nil
    }
}
