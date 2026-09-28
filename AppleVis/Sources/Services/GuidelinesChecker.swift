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

    /// Rules whose hits depend on context (tone, privacy, promotion, and
    /// so on), which Apple Intelligence may double-check. Never the
    /// clear-cut ones (strong or crude language, images, referral links,
    /// "me too" replies, repetition) or anything high: those always apply
    /// exactly as the rules say. Requested directly (2026-09-27).
    var allowsSecondOpinion: Bool {
        severity != .high && Self.contextualRules.contains(id)
    }

    private static let contextualRules: Set<String> = [
        "tone-medium", "tone-low", "personal-info", "self-promotion", "advertising",
        "press-release", "ai-disclosure", "multi-topic", "excessive-punctuation", "all-caps",
    ]
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
        } else if ContentSubmissionPolicy.containsCrudeLanguage(trimmed) {
            warnings.append(GuidelineWarning(
                id: "crude-language", rule: "Keep AppleVis 13+",
                message: "AppleVis allows mild language, but this wording may be too crude for some readers. Consider a milder word.",
                severity: .medium
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
        //
        // Then judged by domain (2026-09-27). A personal mailbox (Gmail,
        // iCloud, and so on) stays medium: that's the privacy risk, like a
        // member's own address pasted in with an email thread. Any other
        // domain is almost always a work or developer address shared on
        // purpose ("email gokhan@birkinapps.com and I'll check your save
        // file"), so it's low: still findable, but hidden by default in
        // the Guideline Violation Check. Reported directly.
        //
        // Finally (2026-09-27, three-month review): medium only when a
        // personal address turns up in a pasted email header (after "From:"
        // or "wrote:", or in angle brackets), the way MamaPeach's did. An
        // address someone typed in themselves ("Can you add me please?
        // name@icloud.com", a signature, "my email:") is their choice, so
        // it's low: still a gentle reminder while writing. Reported directly.
        //
        // And by intent (2026-09-27, a month of real posts: 7 of 8 medium
        // email flags were developers and organisers inviting contact,
        // "email me at … and I'll add you to TestFlight"). An address the
        // writer clearly chose to share, or one named like a project
        // rather than a person (footlord.info@, youmbidev@), is low. Only
        // an address that just turns up, like one in a pasted email
        // header, stays medium. Reported directly.
        let addresses = emailAddresses(in: text)
        let domains = addresses.map(\.domain)
        let exposed = addresses.filter { isPersonalEmailDomain($0.domain) && $0.inPastedHeader && !$0.sharedOnPurpose && !$0.looksLikeProject }
        if !exposed.isEmpty {
            warnings.append(GuidelineWarning(
                id: "personal-info", rule: "Personal Information",
                message: "Your post seems to include an email address. For your privacy and safety, the AppleVis guidelines recommend not sharing personal contact details publicly.",
                severity: .medium
            ))
        } else if !domains.isEmpty {
            warnings.append(GuidelineWarning(
                id: "personal-info", rule: "Personal Information",
                message: "Your post includes an email address. That's fine for a work or support address you mean to share. Just avoid posting a personal one.",
                severity: .low
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

        // Self-promotion. See ContentSubmissionPolicy.looksLikeSelfPromotion
        // for why a bare "my website" no longer counts.
        if ContentSubmissionPolicy.looksLikeSelfPromotion(text) {
            warnings.append(GuidelineWarning(
                id: "self-promotion", rule: "No Self-Promotion",
                message: "AppleVis asks members not to use the forums to promote their own podcast, YouTube channel, website, newsletter, or other resource.",
                severity: .medium
            ))
        }

        // Advertising / selling. "For sale" and "wanted to buy" only count
        // as a listing ("For sale: iPhone 14", "WTB a Braille display", "I'm
        // selling my…"), not in passing ("I've wanted to buy a purple iMac"
        // was flagged, 2026-09-27 month review). Reported directly.
        let listing = [
            #"(?:^|[.!?\n]\s*)(?:for\s+sale|wanted\s+to\s+buy|wtb|wts)\b"#,
            #"\b(?:for\s+sale|wanted\s+to\s+buy)\s*[:\-–]"#,
            #"\b(?:i'm|i\s+am|we're|we\s+are)\s+selling\b"#,
            #"\b(?:have|has|got)\s+(?:an?\s+|my\s+|some\s+|two\s+|a\s+few\s+)?[\w\s-]{0,30}?\bfor\s+sale\b"#,
            #"\bbuy\s+now\b"#, #"\bget\s+\d+%\s+off\b"#,
            // A code only counts with discount or checkout wording. On
            // AppleVis a "promo code" is usually an App Store download code
            // a developer gives testers, or a member asks for: 3 of 4 code
            // flags in an unseen month were that (2026-09-27 review).
            #"\b(?:promo|coupon|discount)\s+code\b[^.!?\n]{0,80}\b(?:off|discount|save|savings|checkout|%)"#,
            #"\b(?:off|discount|save|savings|%)[^.!?\n]{0,80}\b(?:promo|coupon|discount)\s+code\b"#,
            #"\b(?:takes?|saves?|get)\s+(?:up\s+to\s+)?[$£€]\d+\s+off\b"#,
        ]
        if listing.contains(where: { matches(text, $0, caseInsensitive: true) }) {
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
        // Only an actual release: its header, a "Press release:" label, or a
        // news-wire credit. "After seeing a press release" and an AppleVis
        // news article were both flagged (2026-09-27 unseen-month review).
        let pressRelease = [
            #"\bfor\s+immediate\s+release\b"#,
            #"(?:^|\n)\s*press\s+release\b"#,
            #"\bpress\s+release\s*[:\-–]"#,
            #"\b(?:pr\s*newswire|business\s*wire|globe\s*newswire|accesswire)\b"#,
            #"\bmedia\s+contact\s*:"#,
        ]
        if pressRelease.contains(where: { matches(text, $0, caseInsensitive: true) }) {
            warnings.append(GuidelineWarning(
                id: "press-release", rule: "Press Releases",
                message: "Press releases can only be posted as part of a wider discussion, not just to promote a product or service. Please add context beyond the release itself.",
                severity: .medium
            ))
        }

        // AI-generated content without disclosure
        // Whole words, in their chatbot form: a plain substring check found
        // "as an AI" inside "it was an AI error" (2026-09-27 three-month
        // review). Reported directly.
        let aiArtifacts = [
            #"\bas\s+an\s+ai(?:\s+language\s+model|\s+model|\s+assistant)?\s*,\s*i\b"#,
            #"\bas\s+an\s+ai\s+language\s+model\b"#, #"\bas\s+a\s+language\s+model\b"#,
            #"\bi\s+don't\s+have\s+personal\s+experience\b"#, #"\bi\s+cannot\s+browse\s+the\s+internet\b"#,
            #"\bas\s+of\s+my\s+knowledge\s+cutoff\b"#, #"\bi'm\s+unable\s+to\s+access\s+real-time\b"#,
            #"\b(?:certainly|absolutely)!\s+here's\b"#, #"\bsure!\s+here's\s+a\b"#, #"\bgreat\s+question!\s+here\b"#,
        ]
        if aiArtifacts.contains(where: { matches(lower, $0) }) {
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

        // Excessive punctuation, only as shouting: a run of "!!!"/"???" in a
        // sentence that also has a word in capitals, and isn't excitement.
        // On its own it flagged "it's AWESOME!!!!" and "addicted too!!!!"
        // (6 of 8 in the 2026-09-27 month review were happy posts). Needs
        // two signals now, not one. Reported directly.
        let shouting = sentencesKeepingMarkRuns(trimmed).contains { sentence in
            matches(sentence, #"[!?]{3,}"#)
                && matches(sentence, #"\b[A-Z]{4,}\b"#)
                && !matches(sentence, #"\b(?:love|loving|awesome|amazing|great|excited|exciting|yay|wow|congrat\w*|thank\w*|brilliant|fantastic|wonderful|cool|fun|happy|finally)\b"#, caseInsensitive: true)
        }
        if shouting {
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

        // Multiple topics — root posts only, see `isReply`'s doc comment
        // above. This used to count question marks (3 or more), which
        // measured curiosity, not topics: 29 posts in a month, nearly all
        // one subject asked about several ways ("should I get an iPad? which
        // case? will my charger work?"). Now it only takes a clear change of
        // subject. Telling topics apart properly needs an understanding of
        // meaning. Reported directly (2026-09-27 month review).
        let topicSwitch = #"\b(?:unrelated\s+(?:question|note|topic|issue)|on\s+(?:a|an)\s+(?:different|unrelated|separate|other)\s+(?:note|topic|subject)|off[\s-]topic|(?:another|second|separate|different|other)\s+(?:question|thing|issue|topic)\s*,?\s*(?:not|un)\s*related|changing\s+(?:the\s+)?(?:topic|subject)|(?:totally|completely)\s+different\s+(?:question|topic|subject))\b"#
        if !isReply && matches(text, topicSwitch, caseInsensitive: true) {
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

    struct EmailAddress {
        let local: String
        let domain: String
        /// Offered for contact ("email me at", "drop me a line at", "send
        /// it to") rather than just turning up in the text.
        let sharedOnPurpose: Bool
        /// Named like a project or app ("footlord.info", "youmbidev")
        /// rather than a person.
        let looksLikeProject: Bool
        /// Sits in a pasted email header: after "From:", "To:", "Cc:", or
        /// "wrote:", or in angle brackets ("Name <name@gmail.com>").
        var inPastedHeader: Bool = false
    }

    /// The email addresses in `text`, leaving out role and placeholder
    /// addresses (see the call site).
    static func emailAddresses(in text: String) -> [EmailAddress] {
        // Only the words a reader sees: posts from the site arrive as HTML,
        // where a linked address also sits in a hidden "mailto:" link right
        // next to it, which hid the "email me at" in front of it. Only real
        // tags go: an address in angle brackets ("<name@gmail.com>", as in a
        // pasted email header) has an "@" in it, so it stays.
        let text = text
            .replacingOccurrences(of: #"</?[a-zA-Z][a-zA-Z0-9]*(?:\s[^<>]*)?/?>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
        let pattern = #"\b(?!(?:accessibility|support|contact|info|help|press|sales|admin|team|hello|feedback|abuse|legal|privacy|webmaster|postmaster|user|example|someone|yourname)@)([a-zA-Z0-9._%+-]+)@([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = text as NSString
        let found = regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { match in
            let local = ns.substring(with: match.range(at: 1)).lowercased()
            let domain = ns.substring(with: match.range(at: 2)).lowercased()
            let start = max(0, match.range.location - 80)
            let before = ns.substring(with: NSRange(location: start, length: match.range.location - start))
            let invitation = #"\b(?:e-?mail|mail|contact|reach|write\s+to|message|drop(?:ping)?\s+(?:me|us)\s+a\s+(?:line|note|message)|send\b[^.!?\n]{0,60}?\bto|email\s+address(?:\s+is)?|feedback\s+to)\s*:?[^.!?\n]{0,25}$"#
            let shared = matches(before, invitation, caseInsensitive: true)
            let project = matches(local, #"(?:^|[._-])(?:info|support|help|contact|feedback|dev|devs|app|apps|team|studio|games?|official|hello|mail)(?:[._-]|$)|(?:dev|app|apps|studio|games|official)$"#, caseInsensitive: true)
            let afterEnd = match.range.location + match.range.length
            let after = ns.substring(with: NSRange(location: afterEnd, length: min(40, ns.length - afterEnd)))
            let header = matches(before, #"(?:\b(?:from|to|cc|bcc|reply-to|sender)\s*:[^\n]{0,60}|<\s*|\[mailto:)$"#, caseInsensitive: true)
                || matches(after, #"^\s*>?\s*(?:\S+\s+){0,3}wrote\s*:"#, caseInsensitive: true)
            return EmailAddress(local: local, domain: domain, sharedOnPurpose: shared, looksLikeProject: project, inPastedHeader: header)
        }
        // One address, one judgement: offered on purpose once ("email the
        // code to: x@proton.me"), it's the same deliberate share wherever
        // else it's repeated in the post.
        let offered = Set(found.filter(\.sharedOnPurpose).map { "\($0.local)@\($0.domain)" })
        return found.map { address in
            guard !address.sharedOnPurpose, offered.contains("\(address.local)@\(address.domain)") else { return address }
            return EmailAddress(local: address.local, domain: address.domain, sharedOnPurpose: true, looksLikeProject: address.looksLikeProject, inPastedHeader: address.inPastedHeader)
        }
    }

    /// Domains of the email addresses in `text`.
    static func emailDomains(in text: String) -> [String] {
        emailAddresses(in: text).map(\.domain)
    }

    /// Free, personal mailbox services. An address on one of these is
    /// someone's own inbox, not a business or support address.
    private static let personalEmailProviders: Set<String> = [
        "gmail.com", "googlemail.com", "icloud.com", "me.com", "mac.com",
        "outlook.com", "hotmail.com", "live.com", "msn.com",
        "yahoo.com", "ymail.com", "rocketmail.com", "aol.com", "aim.com",
        "proton.me", "protonmail.com", "pm.me", "gmx.com", "gmx.net", "gmx.de",
        "mail.com", "zoho.com", "yandex.com", "yandex.ru", "fastmail.com", "hey.com",
        "tutanota.com", "tuta.io", "comcast.net", "att.net", "verizon.net", "sbcglobal.net",
        "btinternet.com", "sky.com", "virginmedia.com", "web.de", "orange.fr", "free.fr",
        "laposte.net", "libero.it", "qq.com", "163.com", "126.com", "naver.com",
    ]

    /// Also catches regional versions like yahoo.co.uk or hotmail.fr.
    static func isPersonalEmailDomain(_ domain: String) -> Bool {
        if personalEmailProviders.contains(domain) { return true }
        let regionalBases = ["yahoo", "hotmail", "outlook", "live", "gmx", "yandex", "aol"]
        let firstLabel = domain.split(separator: ".").first.map(String.init) ?? ""
        return regionalBases.contains(firstLabel)
    }

    /// Sentences, with a run like "!!!" kept whole at the end of its
    /// sentence instead of split at every mark.
    private static func sentencesKeepingMarkRuns(_ text: String) -> [String] {
        var chunks: [String] = []
        var current = ""
        let chars = Array(text)
        for (index, char) in chars.enumerated() {
            current.append(char)
            let isMark = ".!?".contains(char)
            let nextIsMark = index + 1 < chars.count && ".!?".contains(chars[index + 1])
            if isMark && !nextIsMark {
                chunks.append(current)
                current = ""
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    private static func matches(_ text: String, _ pattern: String, caseInsensitive: Bool = false) -> Bool {
        var options: String.CompareOptions = [.regularExpression]
        if caseInsensitive { options.insert(.caseInsensitive) }
        return text.range(of: pattern, options: options) != nil
    }

    /// True if any sentence contains a survey/study/announcement keyword
    /// *and* that same sentence doesn't also contain "thank" — see the
    /// call site's doc comment.
    /// Only an invitation to take part counts (2026-09-27, a month of real
    /// posts): quoting a survey's findings ("before answering the survey")
    /// and advising developers to "organise focus group discussion" were
    /// flagged as high, needing approval. Asking people to fill one in,
    /// sign up, or take part still is. Reported directly.
    private static func announcementNeedsApproval(_ text: String) -> Bool {
        let pattern = #"\b(survey|questionnaire|research study|research project|focus group|participants? needed|looking for participants?|study participants?)\b"#
        let invitation = #"\b(please|fill\s+(?:in|out)|take\s+(?:our|this|the|a|my|their|part)|complete\s+(?:our|this|the|a|my)|participate|sign\s+up|join\s+(?:our|the|a|my)|click|link\b|below|would\s+(?:you|like)|could\s+you|we'd\s+(?:love|like|appreciate)|we\s+would\s+(?:love|like|appreciate)|help\s+us|if\s+you're\s+interested|if\s+you\s+are\s+interested|few\s+minutes|looking\s+for|participants?\s+needed|recruiting|volunteers?)\b"#
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        for sentence in sentences where matches(sentence, pattern, caseInsensitive: true) {
            if !sentence.localizedCaseInsensitiveContains("thank") && matches(sentence, invitation, caseInsensitive: true) {
                return true
            }
        }
        return false
    }
}
