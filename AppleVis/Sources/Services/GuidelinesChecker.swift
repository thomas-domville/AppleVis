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
                message: "AppleVis posts shouldn't include images or direct links to images. Please describe the information in text instead.",
                severity: .high
            ))
        }

        if ContentSubmissionPolicy.containsStrongVulgarLanguage(trimmed) {
            warnings.append(GuidelineWarning(
                id: "vulgar-language", rule: "Keep AppleVis 13+",
                message: "AppleVis allows mild language, but not vulgar or explicit wording. This keeps the community welcoming and suitable for the app's age rating.",
                severity: .high
            ))
        }

        if let tone = ContentSubmissionPolicy.toneConcern(in: trimmed) {
            switch tone {
            case .high:
                warnings.append(GuidelineWarning(
                    id: "tone-high", rule: "Respectful Discussion",
                    message: "This draft may come across as a personal attack, harassment, hate, or trolling. Please change it to focus on the issue, not the person, before posting.",
                    severity: .high
                ))
            case .medium:
                warnings.append(GuidelineWarning(
                    id: "tone-medium", rule: "Respectful Discussion",
                    message: "This draft may sound hostile. Consider a softer tone that focuses on the problem, your experience, or your question.",
                    severity: .medium
                ))
            case .low:
                warnings.append(GuidelineWarning(
                    id: "tone-low", rule: "Tone Check",
                    message: "This draft may sound frustrated or sharp. A calmer tone can help others respond helpfully.",
                    severity: .low
                ))
            }
        }

        // Personal information (email address). Excludes well-known
        // institutional/role addresses (2026-09-21, live-data mock scan) —
        // "accessibility@apple.com," posted while pointing someone to
        // Apple's own official channel, matched just as readily as an
        // actual personal email, despite not being anyone's personal
        // contact info at all. Also excludes generic placeholder local
        // parts ("user," "example") — a wider 21-day pass turned up
        // "Example: User@iCloud.com" (illustrating a domain format, not
        // anyone's real address) tripping the same warning. Reported
        // directly.
        if matches(text, #"\b(?!(?:accessibility|support|contact|info|help|press|sales|admin|team|hello|feedback|abuse|legal|privacy|webmaster|postmaster|user|example|someone|yourname)@)[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#) {
            warnings.append(GuidelineWarning(
                id: "personal-info", rule: "Personal Information",
                message: "Your post seems to include an email address. For your privacy and safety, the AppleVis guidelines recommend not sharing personal contact details publicly.",
                severity: .medium
            ))
        }

        // Referral / affiliate links
        if matches(text, #"[?&](ref|referral|affiliate|aff|partner|subid)="#, caseInsensitive: true) {
            warnings.append(GuidelineWarning(
                id: "referral-link", rule: "No Referral Links",
                message: "Your post may include a referral or affiliate link. These aren't allowed on AppleVis because they can create a conflict of interest.",
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
                message: "AppleVis asks members not to use the forums to promote their own podcast, YouTube channel, website, newsletter, or other resource.",
                severity: .medium
            ))
        }

        // Advertising / selling
        if matches(text, #"(\bfor sale\b|\bwanted to buy\b|\bbuy now\b|\bpromo code\b|\bcoupon code\b|\bget \d+% off\b)"#, caseInsensitive: true) {
            warnings.append(GuidelineWarning(
                id: "advertising", rule: "No Advertising or Selling",
                message: "The AppleVis forums aren't for selling, trading, or advertising. If you think this would really help the community, please contact AppleVis first.",
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
                message: "Posts about surveys, research projects, or studies need approval from the AppleVis editorial team first. Please use the Contact Form before posting.",
                severity: .high
            ))
        }

        // Press releases for pure promotion
        if matches(text, #"\bpress release\b"#, caseInsensitive: true) || matches(text, #"\bfor immediate release\b"#, caseInsensitive: true) {
            warnings.append(GuidelineWarning(
                id: "press-release", rule: "Press Releases",
                message: "Press releases can only be posted as part of a wider discussion, not just to promote a product or service. Please add context beyond the release itself.",
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
                message: "Your post may contain AI-generated text. AppleVis asks you to say clearly in your post when AI tools helped create it.",
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
                    message: "Your post uses a lot of capital letters, which can read as shouting. Normal capitalization is easier and friendlier to read.",
                    severity: .low
                ))
            }
        }

        // Excessive punctuation
        if matches(text, #"[!?]{3,}"#) {
            warnings.append(GuidelineWarning(
                id: "excessive-punctuation", rule: "Be Polite",
                message: "Your post has several exclamation or question marks in a row. Using fewer will help your message sound calmer.",
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
                    message: "Short replies like \"me too\" or \"I haven't used that\" don't add much to the discussion. Consider sharing details, your experience, or a follow-up question instead.",
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
                message: "Your post seems to ask several different questions. The AppleVis guidelines ask for one topic per post. Separate posts will get you better answers.",
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
                    message: "Your post repeats some phrases or sentences. Please avoid repeating the same content in one post.",
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
