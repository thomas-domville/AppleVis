import Foundation

enum ContentSubmissionPolicy {
    enum ToneConcern: Int {
        case low = 1
        case medium = 2
        case high = 3
    }

    /// Governs only the *live, as-you-type* translate-offer hint
    /// (`ComposeIntelligenceState.textChanged`'s `detectionEnabled`) — a
    /// personal convenience preference about whether to be proactively
    /// nudged while composing. `blockingMessage` below no longer takes a
    /// matching parameter: AppleVis's "must be in English" rule is a site
    /// policy, not something an individual's Settings toggle should be able
    /// to opt out of, and every one of this function's ~13 call sites was
    /// wiring this exact preference straight into the enforcement gate —
    /// turning off "nudge me while typing" silently turned off "actually
    /// enforce English-only" too. Reported directly.
    static var shouldDetectNonEnglish: Bool {
        UserDefaults.standard.object(forKey: "intel.nonEnglish") as? Bool ?? true
    }

    static func blockingMessage(subject: String? = nil, body: String) -> String? {
        let text = policyText(subject: subject, body: body)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        if containsImageReference(text) {
            return String(localized: "Images and embedded image links are not allowed in AppleVis posts. Please remove the image reference before posting.")
        }

        if containsStrongVulgarLanguage(text) {
            return String(localized: "AppleVis posts must avoid vulgar or explicit language. Please edit your wording before posting.")
        }

        if toneConcern(in: text) == .high {
            return String(localized: "This draft may break the AppleVis guidelines on respectful discussion. Please change the tone before posting.")
        }

        // Unconditional — see shouldDetectNonEnglish's doc comment. Only
        // runs where on-device language detection is actually available;
        // there's currently no fallback check for devices/OS versions
        // without it, so this can't be a true hard guarantee on every
        // device from the client alone.
        if IntelligenceService.detectNonEnglish(text) {
            return String(localized: "AppleVis posts must be in English. Please use Translate or edit your draft in English before posting.")
        }

        return nil
    }

    static func toneConcern(in text: String) -> ToneConcern? {
        let highPatterns = [
            #"\b(you|you're|you are|u r)\s+(an?\s+)?(idiot|moron|loser|stupid|dumb|clown|fool|jerk)\b"#,
            #"\b(nobody\s+wants\s+you|you\s+should\s+leave)\b"#,
            // Both scoped to a "you" subject (2026-09-21, live-data mock
            // scan) — bare "go away" matched "the bugs go away"/"speech
            // does not go away" (a symptom disappearing), and bare "shut
            // up" matched "the browser learning to shut up" (a changelog
            // describing quieter notifications) — neither aimed at a
            // person. "you ___" still catches the genuinely hostile,
            // directed form of each; the bare form drops to medium below
            // rather than disappearing outright, since it's still worth a
            // human glance, just not severe enough to block a post over.
            // Reported directly.
            #"\byou\s+(should\s+)?go\s+away\b"#,
            #"\byou\s+shut\s+up\b"#,
            #"\b(kill\s+yourself|kys|i\s+hope\s+you\s+(die|suffer))\b"#,
            // Only with an insult after it: "not all blind people are able to
            // walk in a straight line" blocked a caring post (2026-09-27
            // three-month review). Reported directly.
            #"\b(?<!not\s)(all|those)\s+(blind|disabled|deaf|autistic|lgbt|gay|trans|black|white|asian|jewish|muslim|christian)\s+(people\s+)?(are|should)\s+(?:all\s+|just\s+|so\s+)?(?:stupid|dumb|lazy|idiots?|useless|worthless|inferior|disgusting|freaks?|animals|scum|a\s+burden|a\s+waste|parasites|sick|die|leave|go\s+away|be\s+(?:banned|removed|locked\s+up|ashamed))\b"#,
            #"\b(troll|trolling)\b.*\b(shut\s+up|go\s+away|idiot|moron|stupid)\b"#,
        ]
        // Quoted, an insult is an example, not an attack: "there's a
        // difference between calling out behaviour and a personal attack
        // ('Michael, you're an idiot')" was blocked from posting (2026-09-27
        // unseen-month review). Blocking needs the words outside quotes;
        // inside quotes it drops to medium, so a moderator still sees it but
        // it can't be used to slip a real insult past review. Reported
        // directly.
        let unquoted = removingQuotedPassages(text)
        if highPatterns.contains(where: { matches(unquoted, $0, caseInsensitive: true) }) {
            return .high
        }
        if highPatterns.contains(where: { matches(text, $0, caseInsensitive: true) }) {
            // A moderator quoting it back while calling it out isn't a
            // concern at all (2026-09-27 three-month review, suggested
            // directly). Only ever applies to words inside quotes.
            return soundsLikeModeration(text) ? nil : .medium
        }

        // "this/that/your" dropped from this pattern (2026-09-19, live-data
        // review) — they matched "your app is garbage"/"this update is
        // trash" exactly as readily as an actual dig at a person, and every
        // real personal case ("you're an idiot," "you are ridiculous") is
        // already covered by "you're/you are" here or by the high-severity
        // pattern above. Reported directly after "Is your garbage" (about
        // an email client, not a person) got flagged as a tone concern.
        let mediumPatterns = [
            #"\b(you're|you are)\s+(is\s+)?(stupid|dumb|ridiculous|nonsense|garbage|trash)\b"#,
            #"\b(learn\s+to\s+read|use\s+your\s+brain|you\s+clearly\s+don't\s+know|you\s+obviously\s+don't\s+understand)\b"#,
            #"\b(stop\s+(whining|complaining|crying)|quit\s+(whining|complaining|crying))\b"#,
            #"\b(what\s+is\s+wrong\s+with\s+you|are\s+you\s+serious\s+right\s+now)\b"#,
        ]
        if mediumPatterns.contains(where: { matches(text, $0, caseInsensitive: true) }) {
            return .medium
        }

        // Dismissive put-downs aimed at another member (2026-09-25, a
        // moderator's review of a heated forum thread): "whatever helps you
        // sleep at night," "they always find someone like you to defend
        // them." Not hateful, but the kind of exchange that shouldn't
        // happen, so it's a gentle reminder and a medium flag. Each one is
        // scoped to its unfriendly form: "people like you make this
        // community great" and "how do you cope" stay clean. Reported
        // directly.
        let putDownPatterns = [
            #"\bwhatever\s+helps\s+you\s+sleep\b"#,
            #"\b(?:always|there's\s+always|of\s+course)\s+(?:(?:find|get|have)\s+)?(?:someone|somebody|people)\s+like\s+you\b"#,
            #"\bpeople\s+like\s+you\s+(?:always|never|keep|ruin|are\s+(?:the\s+problem|why))\b"#,
            #"\bcope\s+(?:and\s+seethe|harder)\b"#,
            #"\bstay\s+mad\b"#,
            #"\btouch(?:ing)?\s+grass\b"#,
            #"\bok(?:ay)?\s+boomer\b"#,
            #"\bget\s+a\s+life\b"#,
            #"\bskill\s+issue\b"#,
            // Missed in the three-month review (2026-09-27), both called out
            // by a moderator at the time: "mind your own business" aimed at a
            // member, and a jab dressed as advice ("you have some insecurities
            // that you should probably address with a mental health
            // counselor"). The second needs "you", "insecurities/issues", and
            // a counsellor or therapist together, so caring advice ("a
            // counsellor helped me") stays clean. Reported directly.
            #"\bmind\s+your\s+own\s+(?:damn\s+)?business\b"#,
            #"\byou(?:'ve|\s+have|\s+got|\s+obviously\s+have|\s+clearly\s+have)\s+(?:some\s+|serious\s+|a\s+lot\s+of\s+|real\s+|deep\s+)?(?:insecurit(?:y|ies)|issues)\b[^.!?]{0,80}\b(?:counsell?or|therapist|therapy|psychiatrist|professional\s+help)\b"#,
            #"\byou\s+(?:really\s+)?need\s+(?:some\s+)?(?:therapy|a\s+therapist|professional\s+help|to\s+see\s+a\s+(?:therapist|shrink))\b"#,
        ]
        // Outside quotes only: moderators quote a put-down while calling it
        // out ('Saying things like "Mind your own business" is
        // counterproductive'), and that isn't one (2026-09-27 review).
        if putDownPatterns.contains(where: { matches(unquoted, $0, caseInsensitive: true) }) {
            return .medium
        }
        // Only as a whole sentence: "Who asked?" is a jab, but "who asked
        // about Android support earlier?" is a real question.
        let putDownSentences = [
            #"^\W*(?:ok(?:ay)?\W+|but\W+|lol\W+|lmf?ao+\W+)?who\s+asked\W*$"#,
            #"^\W*(?:just\s+|you\s+need\s+to\s+|please\s+)?grow\s+up\W*$"#,
        ]
        let putDownSentenceHit = sentenceChunks(text).contains { sentence in
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            return putDownSentences.contains { matches(trimmed, $0, caseInsensitive: true) }
        }
        if putDownSentenceHit {
            return .medium
        }

        // Only ever reached when the high-severity "you shut up" above
        // didn't match — catches the ambiguous bare form ("shut up," no
        // clear personal target) at a severity that flags it for a
        // moderator without blocking a post over it outright. See the
        // high-severity comment above for the false positive that prompted
        // splitting these. Checked against the text with any "shut up"
        // aimed at a voice or device already removed (2026-09-23, live
        // flag): "SHUT UP DANIEL!!!" was someone venting at VoiceOver's
        // Daniel voice repeating Face ID setup prompts, not at a person —
        // and on AppleVis, telling VoiceOver, Siri, or a named speech
        // voice to be quiet is everyday frustration, not a tone problem.
        // A "shut up" aimed at anyone else is still flagged. Reported
        // directly.
        // Also drops "shut up" the writer says about themselves ("we should
        // just stay quiet and shut up about it", "I'll shut up now"): flagged
        // in the 2026-09-27 month review. Reported directly.
        if matches(removingSelfShutUp(removingShutUpAtDevice(text)), #"\bshut\s+up\b"#, caseInsensitive: true) {
            return .medium
        }

        // "(?<!or\s)" excludes "or whatever" (2026-09-19, live-data review)
        // — a common filler idiom ("a piece of mail or whatever") that this
        // pattern's unbounded ".*[!?]" was matching against any "!"/"?"
        // anywhere later in the message, however unrelated, misreading
        // entirely friendly messages as a tone concern. Still not enough
        // (2026-09-21, live-data mock scan): "whatever I am listening
        // [to] stop[ped]... Anyone having issues?" matched even though
        // "whatever" was a relative pronoun, not the dismissive
        // interjection, and the "?" belonged to an unrelated sentence two
        // clauses later. Scoped to one sentence at a time now — the same
        // technique `announcementNeedsApproval` below already uses —
        // instead of matching a "!"/"?" anywhere later in the whole text.
        // Reported directly.
        // "come on" dropped from this pattern (2026-09-21, live-data mock
        // scan) — "Come on, Sarries!" was cheering on a rugby team, not
        // being dismissive. Unlike "obviously"/"clearly," which are rarely
        // used to express genuine enthusiasm, "come on" is common as a
        // cheer or encouragement and too ambiguous to treat as a tone
        // signal on its own. Reported directly.
        // Aimed at someone, not just said (2026-09-27 month review: all 5
        // low tone flags were false). "Clearly" or "obviously" now needs a
        // "you" in the same sentence: "Clearly you didn't read it!" counts,
        // "they're obviously resyncing from somewhere, but where?" doesn't.
        // "Whatever" only counts as the dismissive "Whatever." opening a
        // sentence, or "whatever you say", not "documents, whatever?" or
        // "whatever app is playing music?". Reported directly.
        let lowSentencePatterns = [
            #"\b(obviously|clearly)\b(?=.*\byou(?:r|'re|'ve|'d|'ll)?\b).*[!?]|\byou(?:r|'re|'ve|'d|'ll)?\b.*\b(obviously|clearly)\b.*[!?]"#,
            #"^\W*whatever\b.*[!?]|^\W*whatever\W*$|\bwhatever\s+you\s+say\b"#,
        ]
        // Two exceptions (2026-09-27, live flag): a sentence that thanks
        // someone isn't sharp, and "clearly" describing how something was
        // said or seen ("thank you for explaining it clearly!", "I can hear
        // it clearly now!") isn't the dismissive "clearly, you didn't read
        // it!" A developer thanking a player was flagged for exactly this.
        // Reported directly.
        let lowSentenceHit = sentenceChunks(text).contains { sentence in
            if matches(sentence, #"\b(thank|thanks|thx|appreciate[ds]?)\b"#, caseInsensitive: true) { return false }
            let checked = removingMannerAdverbs(sentence)
            return lowSentencePatterns.contains { matches(checked, $0, caseInsensitive: true) }
        }
        // "Suck it up" added from the three-month review: dismissive, mild.
        if lowSentenceHit || matches(text, #"\b(i\s+can't\s+believe|that's\s+absurd|that's\s+annoying|suck\s+it\s+up)\b"#, caseInsensitive: true) {
            return .low
        }

        return nil
    }

    /// Speech voices, assistants, and devices people commonly tell to "shut
    /// up" — Apple's built-in VoiceOver/Siri voice names, third-party
    /// synthesizers, and generic device words. "it" covers "make it shut
    /// up," where "it" is almost always the phone or its speech.
    private static let speechTargets = "voiceover|voice\\s+over|siri|daniel|alex|samantha|karen|moira|tessa|fred|serena|arthur|martha|rishi|veena|fiona|eloquence|espeak|vocalizer|the\\s+voice|voice|speech|phone|iphone|ipad|mac|watch|browser|app|notifications?|alerts?|narrator|screen\\s+reader|it"

    /// Short linking words allowed between a speech target and "shut up" —
    /// "VoiceOver to shut up," "Daniel just won't shut up," and (2026-09-27
    /// three-month review) a changelog's "the browser learning to shut up."
    private static let shutUpLinkingWords = "to|would|will|just|finally|please|should|won't|wouldn't|doesn't|didn't|never|can't|couldn't|learning|learned|learns|trying|going|made|make|got|get"

    /// Removes each "shut up" that sits next to a speech voice or device —
    /// "shut up Daniel," "Siri, shut up," "make it shut up," "VoiceOver to
    /// shut up" — so the bare "shut up" check only sees ones aimed
    /// elsewhere. Tested against the real flagged post plus "John, shut
    /// up"/"Just shut up"/"Tell him to shut up," all of which still flag.
    private static func removingShutUpAtDevice(_ text: String) -> String {
        let pattern = "\\b(?:\(speechTargets))(?:[\\s,.:!-]+(?:\(shutUpLinkingWords)))*[\\s,.:!-]*shut\\s+up\\b|\\bshut\\s+up[\\s,.:!-]*(?:\(speechTargets))\\b"
        return text.replacingOccurrences(of: pattern, with: " ", options: [.regularExpression, .caseInsensitive])
    }

    /// Drops short passages in quotation marks (straight or curly, double
    /// or single), which are usually someone else's words or an example.
    private static func removingQuotedPassages(_ text: String) -> String {
        // Posts from the site arrive as HTML: quoted replies sit in
        // <blockquote> and quotation marks as &quot; codes, which hid them
        // from this check (a moderator's 'Saying things like "Mind your own
        // business"' was flagged). Decoded first, and quote blocks dropped.
        let text = text
            .replacingOccurrences(of: #"(?is)<blockquote\b.*?</blockquote>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&#8220;", with: "“")
            .replacingOccurrences(of: "&#8221;", with: "”")
            .replacingOccurrences(of: "&ldquo;", with: "“")
            .replacingOccurrences(of: "&rdquo;", with: "”")
        let patterns = [
            #""[^"\n]{1,200}""#,
            #"“[^”\n]{1,200}”"#,
            #"‘[^’\n]{1,200}’"#,
            #"(?<![\w])'[^'\n]{1,200}'(?![\w])"#,
        ]
        return patterns.reduce(text) { partial, pattern in
            partial.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
    }

    /// Reads like a moderator or editor addressing the community: asking
    /// people to be respectful, citing the guidelines, or warning about
    /// posting privileges.
    private static func soundsLikeModeration(_ text: String) -> Bool {
        matches(text, #"\b(?:please\s+be\s+(?:respectful|kind|civil)|(?:our|the|community|posting|appleVis)\s+guidelines|goes\s+against|posting\s+privileges|personal\s+attacks\s+(?:are|aren't|are\s+not)|(?:our|the)\s+(?:trolling|moderation)\s+policy|as\s+a\s+(?:friendly\s+)?reminder|moderator\s+note|keep\s+(?:the|this)\s+discussion|this\s+thread\s+(?:has|will)\s+been?\s+(?:locked|closed))\b"#, caseInsensitive: true)
    }

    /// Removes "shut up" whose subject is the writer ("I", "we", "me", "us").
    private static func removingSelfShutUp(_ text: String) -> String {
        let pattern = #"\b(?:i|we|i'll|we'll|i'd|we'd|i'm|we're|me|us|myself|ourselves)\b[^.!?\n]{0,40}?\bshut\s+up\b"#
        return text.replacingOccurrences(of: pattern, with: " ", options: [.regularExpression, .caseInsensitive])
    }

    /// Drops "clearly"/"obviously" where it only describes how something
    /// was explained, heard, seen, written, or shown ("explained it
    /// clearly", "speak clearly", "clearly labelled"), leaving the
    /// dismissive use for the tone check.
    private static func removingMannerAdverbs(_ text: String) -> String {
        let verbs = #"explain\w*|speak\w*|spoke|talk\w*|hear\w*|heard|see|seeing|seen|saw|read\w*|writ\w*|wrote|describ\w*|stat(?:e|es|ed|ing)|label\w*|mark\w*|show\w*|shown|sound\w*|pronounc\w*|announc\w*|display\w*|laid|lay|set|put|visible|audible|understand\w*|understood|communicat\w*"#
        let after = #"\b(?:\#(verbs))\s+(?:(?:it|this|that|them|things|everything|out|up|so|very|more|really)\s+){0,2}(?:clearly|obviously)\b"#
        let before = #"\b(?:clearly|obviously)\s+(?:labell?ed|marked|written|visible|audible|stated|explained|shown|displayed|announced)\b"#
        return text
            .replacingOccurrences(of: after, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: before, with: " ", options: [.regularExpression, .caseInsensitive])
    }

    /// Splits `text` into sentence-sized chunks, each ending with (and
    /// including) its own terminating `.`/`!`/`?` — unlike
    /// `components(separatedBy:)`, which would strip that punctuation out
    /// entirely, useless for a pattern that specifically needs to check
    /// whether a `!`/`?` appears within the *same* sentence as a trigger
    /// word rather than anywhere later in the whole text.
    private static func sentenceChunks(_ text: String) -> [String] {
        var chunks: [String] = []
        var current = ""
        for char in text {
            current.append(char)
            if ".!?".contains(char) {
                chunks.append(current)
                current = ""
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
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

    /// Blocks posting. Widened 2026-09-25 after an admin scan missed a
    /// vulgar post: the old list only matched the f-word with the endings
    /// -er/-ing/-ed/-s, so "fuckin", "fuckhead", "clusterfuck", and every
    /// censored ("f*ck") or misspelled ("fck") form got through. Reported
    /// directly.
    static func containsStrongVulgarLanguage(_ text: String) -> Bool {
        let patterns = [
            // Any ending or compound: "fuckin", "fuckhead", "clusterfuck".
            #"\b(?:mother|cluster|mind|brain)?f+[\W_]*u+[\W_]*c+[\W_]*k"#,
            // Censored and misspelled forms.
            #"\bf[*#@$%]{1,3}c?k(?:er|ers|ing|in|ed|s)?\b"#,
            #"\bf[*#@$%]{2,3}ing\b"#,
            #"\bf(?:ck|uk|kn)(?:ing|in|er|ers|ed|s)?\b"#,
            #"\bc+[\W_]*u+[\W_]*n+[\W_]*t+s?\b"#,
            #"\bc[*#@$%]nts?\b"#,
            #"\btwats?\b"#,
            #"\bc+[\W_]*o+[\W_]*c+[\W_]*k+[\W_]*s+[\W_]*u+[\W_]*c+[\W_]*k+(?:er|ers|ing)?\b"#,
            #"\bc+[\W_]*u+[\W_]*m+[\W_]*s+[\W_]*h+[\W_]*o+[\W_]*t+s?\b"#,
        ]
        return patterns.contains { matches(text, $0, caseInsensitive: true) }
    }

    /// Promotion needs an invitation, not just a mention. The rule used to
    /// fire on any "my website"/"my podcast", so "I am editing code for my
    /// website" (someone asking for help after a VoiceOver crash) was
    /// flagged as self-promotion (2026-09-25, admin scan). It now needs
    /// "check out / subscribe to / visit my …", a launch ("my new podcast",
    /// "I just started a channel"), "like and subscribe", or "my …" with a
    /// link in the same sentence. Reported directly.
    static func looksLikeSelfPromotion(_ text: String) -> Bool {
        let thing = #"(?:podcast|youtube\s+channel|channel|website|site|blog|newsletter|mailing\s+list|substack|patreon|videos?|episodes?)"#
        let notATool = #"(?!\s+(?:player|app|reader|client))"#
        let patterns = [
            #"\b(?:check\s+out|visit|subscribe\s+to|follow|listen\s+to|watch|join|head\s+(?:over\s+)?to|go\s+to|stop\s+by|support|sign\s+up\s+(?:for|to)|tune\s+in\s+to|give)\s+my\s+(?:new\s+|latest\s+)?"# + thing + #"\b"#,
            #"\bmy\s+(?:new|latest|brand[-\s]new)\s+"# + thing + #"\b"# + notATool,
            #"\bi(?:'ve|\s+have)?\s+(?:just\s+)?(?:started|launched|created)\s+(?:a|my)\s+(?:new\s+)?"# + thing + #"\b"#,
            #"\blike\s+and\s+subscribe\b"#,
        ]
        if patterns.contains(where: { matches(text, $0, caseInsensitive: true) }) {
            return true
        }
        let myThing = #"\bmy\s+"# + thing + #"\b"# + notATool
        let link = #"(?:https?://|www\.)\S+"#
        return sentenceChunks(text).contains { sentence in
            matches(sentence, myThing, caseInsensitive: true) && matches(sentence, link, caseInsensitive: true)
        }
    }

    /// Crude but not strong: a gentle, dismissible reminder while writing
    /// and a medium flag in the admin scan, never a block. The guidelines
    /// allow mild language, so damn, hell, crap, and sucks aren't here.
    /// "dick", "prick", and "bastard" only count as insults aimed at
    /// someone, so Moby Dick, Dickens, and "a pin prick" stay clean.
    static func containsCrudeLanguage(_ text: String) -> Bool {
        let patterns = [
            #"\b(?:bull|horse|dip|chicken)?sh+[*!1i]+t+(?:s|ty|tier|tiest|head|heads|show|load|storm|post|ting)?\b"#,
            #"\b(?:ass|arse)holes?\b"#,
            #"\b(?:dumb|jack|smart|bad)\s*ass(?:es)?\b"#,
            #"\bbitch(?:es|y|ing)?\b"#,
            #"\bdickheads?\b"#,
            #"\bwankers?\b"#,
            #"\bpiss\s+off\b"#,
            #"\b(?:you|you're|you are|such|what|he's|she's|they're)\s+(?:an?\s+)?(?:\w+\s+)?(?:prick|dick|bastard)s?\b"#,
        ]
        return patterns.contains { matches(text, $0, caseInsensitive: true) }
    }

    private static func matches(_ text: String, _ pattern: String, caseInsensitive: Bool = false) -> Bool {
        var options: String.CompareOptions = [.regularExpression]
        if caseInsensitive { options.insert(.caseInsensitive) }
        return text.range(of: pattern, options: options) != nil
    }
}
