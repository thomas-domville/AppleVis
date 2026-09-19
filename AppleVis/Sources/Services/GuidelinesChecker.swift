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

    var isToneConcern: Bool {
        id.hasPrefix("tone-")
    }
}

enum GuidelinesChecker {
    /// `isReply` — true for a comment/reply/review on existing content,
    /// false (default) for a new topic/post/entry's own body. Only affects
    /// "One Topic Per Post" below, which is meaningless applied to a reply:
    /// live-data review (2026-09-19) found it firing constantly on ordinary
    /// back-and-forth replies asking several short clarifying questions in a
    /// busy support thread — ordinary conversation, not someone cramming
    /// unrelated topics into a single post, which is what the rule is
    /// actually for. Every other check still applies to both.
    ///
    /// Returns warnings sorted by severity: high -> medium -> low.
    static func check(_ text: String, isReply: Bool = false) -> [GuidelineWarning] {
        let trimmed = ContentSubmissionPolicy.policyText(body: text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else { return [] }
        let lower = trimmed.lowercased()

        var warnings: [GuidelineWarning] = []

        if ContentSubmissionPolicy.containsImageReference(trimmed) {
            warnings.append(GuidelineWarning(
                id: "no-images", rule: "No Images in Posts",
                message: "AppleVis posts should not include embedded images or direct image links. Please describe the relevant information in text instead.",
                severity: .high
            ))
        }

        if ContentSubmissionPolicy.containsStrongVulgarLanguage(trimmed) {
            warnings.append(GuidelineWarning(
                id: "vulgar-language", rule: "Keep AppleVis 13+",
                message: "AppleVis allows mild language, but posts must avoid vulgar or explicit wording so the community stays welcoming and appropriate for the app's age rating.",
                severity: .high
            ))
        }

        if let tone = ContentSubmissionPolicy.toneConcern(in: trimmed) {
            switch tone {
            case .high:
                warnings.append(GuidelineWarning(
                    id: "tone-high", rule: "Respectful Discussion",
                    message: "This draft may come across as a personal attack, harassment, hate, or trolling. Please revise it to focus on the issue rather than the person before posting.",
                    severity: .high
                ))
            case .medium:
                warnings.append(GuidelineWarning(
                    id: "tone-medium", rule: "Respectful Discussion",
                    message: "This draft may sound hostile or inflammatory. Consider softening the tone so it focuses on the problem, experience, or question.",
                    severity: .medium
                ))
            case .low:
                warnings.append(GuidelineWarning(
                    id: "tone-low", rule: "Tone Check",
                    message: "This draft may read as frustrated or sharp. A calmer tone may help other community members respond constructively.",
                    severity: .low
                ))
            }
        }

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

        // Self-promotion. The negative lookahead excludes "my podcast
        // player"/"my podcast app" etc (2026-09-19, live-data review) — a
        // possession ("the device/app I use"), not a promotion ("check out
        // my podcast"), which the bare pattern couldn't tell apart.
        if matches(text, #"\bmy (podcast|youtube channel|channel|website|blog|newsletter|mailing list|substack|patreon)\b(?!\s+(player|app|reader|client))"#, caseInsensitive: true) {
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

        // Announcements requiring prior approval. Checked sentence-by-
        // sentence, skipping any sentence that also contains "thank"
        // (2026-09-19, live-data review) — "thank you to everyone who
        // contributed to our survey" is thanking past participants, not
        // soliciting new ones, and the whole-text match couldn't tell that
        // apart from an actual unapproved solicitation.
        if announcementNeedsApproval(text) {
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

        // Multiple questions / topics — root posts only, see `isReply`'s
        // doc comment above.
        let questionCount = text.filter { $0 == "?" }.count
        if !isReply && questionCount >= 3 && trimmed.count > 120 {
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

    /// True if any sentence contains a survey/study/announcement keyword
    /// *and* that same sentence doesn't also contain "thank" — see the
    /// call site's doc comment.
    private static func announcementNeedsApproval(_ text: String) -> Bool {
        let pattern = #"\b(survey|research study|research project|focus group|participants? needed|looking for participants?|study participants?)\b"#
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        for sentence in sentences where matches(sentence, pattern, caseInsensitive: true) {
            if !sentence.localizedCaseInsensitiveContains("thank") {
                return true
            }
        }
        return false
    }
}
