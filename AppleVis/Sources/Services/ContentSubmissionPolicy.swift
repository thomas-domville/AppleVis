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

    /// Any of the rules file's patterns under `key` match.
    private static func hits(_ key: String, in text: String, caseInsensitive: Bool = true) -> Bool {
        GuidelineRules.current.patterns(key).contains { matches(text, $0, caseInsensitive: caseInsensitive) }
    }

    static func toneConcern(in text: String) -> ToneConcern? {
        // Patterns from the rules file. Quoted, an insult is an example,
        // not an attack: blocking needs the words outside quotes; inside
        // quotes it drops to medium (2026-09-27 review).
        let unquoted = removingQuotedPassages(text)
        if hits("toneHigh", in: unquoted) {
            return .high
        }
        if hits("toneHigh", in: text) {
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
        if hits("toneMedium", in: text) {
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
        if hits("tonePutDown", in: unquoted) {
            return .medium
        }
        // Only as a whole sentence: "Who asked?" is a jab, but "who asked
        // about Android support earlier?" is a real question.
        let putDownSentenceHit = sentenceChunks(text).contains { sentence in
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            return hits("tonePutDownSentence", in: trimmed)
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
        if hits("shutUp", in: removingSelfShutUp(removingShutUpAtDevice(text))) {
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
        let lowSentenceHit = sentenceChunks(text).contains { sentence in
            if hits("toneThanks", in: sentence) { return false }
            let checked = removingMannerAdverbs(sentence)
            return hits("toneLowSentence", in: checked)
        }
        // "Suck it up" added from the three-month review: dismissive, mild.
        if lowSentenceHit || hits("toneLowAnywhere", in: text) {
            return .low
        }

        return nil
    }

    /// Removes each "shut up" that sits next to a speech voice or device —
    /// "shut up Daniel," "Siri, shut up," "make it shut up," "VoiceOver to
    /// shut up" — so the bare "shut up" check only sees ones aimed
    /// elsewhere. The voices, devices, and linking words are in the rules
    /// file.
    private static func removingShutUpAtDevice(_ text: String) -> String {
        GuidelineRules.current.patterns("shutUpAtDevice").reduce(text) {
            $0.replacingOccurrences(of: $1, with: " ", options: [.regularExpression, .caseInsensitive])
        }
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
        return GuidelineRules.current.patterns("quotedPassage").reduce(text) { partial, pattern in
            partial.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
    }

    /// Reads like a moderator or editor addressing the community: asking
    /// people to be respectful, citing the guidelines, or warning about
    /// posting privileges.
    private static func soundsLikeModeration(_ text: String) -> Bool {
        hits("moderation", in: text)
    }

    /// Removes "shut up" whose subject is the writer ("I", "we", "me", "us").
    private static func removingSelfShutUp(_ text: String) -> String {
        GuidelineRules.current.patterns("selfShutUp").reduce(text) {
            $0.replacingOccurrences(of: $1, with: " ", options: [.regularExpression, .caseInsensitive])
        }
    }

    /// Drops "clearly"/"obviously" where it only describes how something
    /// was explained, heard, seen, written, or shown ("explained it
    /// clearly", "speak clearly", "clearly labelled"), leaving the
    /// dismissive use for the tone check.
    private static func removingMannerAdverbs(_ text: String) -> String {
        let rules = GuidelineRules.current
        return (rules.patterns("mannerAdverbAfter") + rules.patterns("mannerAdverbBefore")).reduce(text) {
            $0.replacingOccurrences(of: $1, with: " ", options: [.regularExpression, .caseInsensitive])
        }
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
        hits("image", in: text)
    }

    /// Blocks posting. Widened 2026-09-25 after an admin scan missed a
    /// vulgar post: the old list only matched the f-word with the endings
    /// -er/-ing/-ed/-s, so "fuckin", "fuckhead", "clusterfuck", and every
    /// censored ("f*ck") or misspelled ("fck") form got through. Reported
    /// directly.
    static func containsStrongVulgarLanguage(_ text: String) -> Bool {
        // Any ending or compound, censored and misspelled forms: see the
        // rules file.
        hits("vulgarStrong", in: text)
    }

    /// Promotion needs an invitation, not just a mention. The rule used to
    /// fire on any "my website"/"my podcast", so "I am editing code for my
    /// website" (someone asking for help after a VoiceOver crash) was
    /// flagged as self-promotion (2026-09-25, admin scan). It now needs
    /// "check out / subscribe to / visit my …", a launch ("my new podcast",
    /// "I just started a channel"), "like and subscribe", or "my …" with a
    /// link in the same sentence. Reported directly.
    static func looksLikeSelfPromotion(_ text: String) -> Bool {
        if hits("selfPromotion", in: text) {
            return true
        }
        // "My website" with a link, while asking people to try something
        // and say what they think, is a developer seeking feedback. The
        // guidelines allow that ("Developers may share and discuss their
        // apps on the Forum ... seek feedback"), and sharing your own
        // resource where it helps the discussion. A developer sharing a game
        // prototype from their site for testers was flagged (2026-10-06).
        // Asking people to subscribe, follow, or check out the site itself
        // is still caught above.
        if hits("selfPromotionFeedback", in: text) { return false }
        return sentenceChunks(text).contains { sentence in
            hits("selfPromotionMyThing", in: sentence) && hits("link", in: sentence)
        }
    }

    /// Crude but not strong: a gentle, dismissible reminder while writing
    /// and a medium flag in the admin scan, never a block. The guidelines
    /// allow mild language, so damn, hell, crap, and sucks aren't here.
    /// "dick", "prick", and "bastard" only count as insults aimed at
    /// someone, so Moby Dick, Dickens, and "a pin prick" stay clean.
    static func containsCrudeLanguage(_ text: String) -> Bool {
        hits("crude", in: text)
    }

    private static func matches(_ text: String, _ pattern: String, caseInsensitive: Bool = false) -> Bool {
        var options: String.CompareOptions = [.regularExpression]
        if caseInsensitive { options.insert(.caseInsensitive) }
        return text.range(of: pattern, options: options) != nil
    }
}
