import Foundation
import NaturalLanguage
import FoundationModels
import os

/// On-device "Apple Intelligence" features — non-English detection (NaturalLanguage),
/// and rewrite/translate/summarize (FoundationModels on-device LLM, iOS 26+).
/// Everything here runs entirely on-device; nothing is sent to a server.
enum IntelligenceService {

    // MARK: - Availability

    // FoundationModels itself requires iOS 26+; the app's deployment target
    // is iOS 17, so every reference to its types must be behind a runtime
    // #available check even though every public function here keeps a
    // plain, OS-agnostic signature (Bool/String?/[GuidelineWarning]) — on
    // iOS 17-25 these simply behave as if Apple Intelligence were never
    // available, exactly like an unsupported device today.
    static var isAvailable: Bool {
        guard #available(iOS 26.0, *) else { return false }
        return SystemLanguageModel.default.availability == .available
    }

    /// For the support information in bug reports and Contact: whether
    /// Apple Intelligence is ready, and if not, why. Ask the Mouse and the
    /// other AI features depend on it, so this answers "why don't I see
    /// it?" without a follow-up email. English on purpose (team-facing).
    /// Requested directly (2026-09-28).
    static var diagnosticStatus: String {
        guard #available(iOS 26.0, *) else { return "Not available (needs iOS 26 or later)" }
        switch SystemLanguageModel.default.availability {
        case .available:
            return "Available"
        case .unavailable(.deviceNotEligible):
            return "Not available (device not supported)"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Off (turned off in iOS Settings)"
        case .unavailable(.modelNotReady):
            return "Not ready yet (model still downloading)"
        case .unavailable:
            return "Not available"
        }
    }

    // MARK: - Non-English detection (NaturalLanguage — no model download needed)

    /// True when the dominant detected language of `text` isn't English,
    /// with reasonable confidence. Mirrors the intent of the original
    /// Unicode-heuristic check but uses Apple's language recognizer for
    /// better accuracy across scripts that overlap Latin (e.g. French, Spanish).
    static func detectNonEnglish(_ text: String) -> Bool {
        let stripped = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard stripped.count >= 8 else { return false }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(stripped)
        guard let dominant = recognizer.dominantLanguage else { return false }
        let confidence = recognizer.languageHypotheses(withMaximum: 1)[dominant] ?? 0
        return dominant != .english && confidence > 0.5
    }

    // MARK: - FoundationModels-backed features

    struct DraftRewriteResult {
        var subject: String?
        var body: String
    }

    static func rewriteFriendly(subject: String?, body: String, isTopic: Bool) async -> DraftRewriteResult? {
        guard isAvailable else { return nil }
        guard let rewrittenBody = await cleanedResponse(
            "Rewrite this AppleVis \(isTopic ? "forum topic body" : "comment") so it is personable, friendly, clear, and respectful. " +
            "Preserve the author's meaning, facts, questions, and tone. Do not add new information. " +
            "Do not include labels, explanations, markdown fences, or quotation marks around the result.\n\n\(body)"
        ) else { return nil }

        guard isTopic, let subject, !subject.trimmingCharacters(in: .whitespaces).isEmpty else {
            return DraftRewriteResult(body: rewrittenBody)
        }
        let rewrittenSubject = await cleanedResponse(
            "Rewrite this AppleVis forum topic subject to be clear, friendly, and concise. " +
            "Keep it under 90 characters. Do not add new information. Return only the subject text.\n\n\(subject)"
        )
        return DraftRewriteResult(subject: rewrittenSubject ?? subject, body: rewrittenBody)
    }

    static func rewriteRespectfully(subject: String?, body: String, isTopic: Bool) async -> DraftRewriteResult? {
        guard isAvailable else { return nil }
        guard let rewrittenBody = await cleanedResponse(
            "Rewrite this AppleVis \(isTopic ? "forum topic body" : "comment") to be respectful, constructive, and appropriate for a 13+ community. " +
            "Preserve the author's core point, facts, accessibility concern, and disagreement if any. " +
            "Remove personal attacks, insults, hostile sarcasm, blame, trolling language, threats, and hate. " +
            "Focus on the issue rather than the person. Do not add new information. " +
            "Do not include labels, explanations, markdown fences, or quotation marks around the result.\n\n\(body)"
        ) else { return nil }

        guard isTopic, let subject, !subject.trimmingCharacters(in: .whitespaces).isEmpty else {
            return DraftRewriteResult(body: rewrittenBody)
        }
        let rewrittenSubject = await cleanedResponse(
            "Rewrite this AppleVis forum topic subject to be respectful, clear, and concise. " +
            "Keep it under 90 characters. Preserve the core topic, remove hostile wording, and return only the subject text.\n\n\(subject)"
        )
        return DraftRewriteResult(subject: rewrittenSubject ?? subject, body: rewrittenBody)
    }

    static func translateToEnglish(subject: String?, body: String, isTopic: Bool) async -> DraftRewriteResult? {
        guard isAvailable else { return nil }
        guard let translatedBody = await cleanedResponse(
            "Translate this AppleVis \(isTopic ? "forum topic body" : "comment") into natural English. " +
            "Preserve the author's meaning, facts, questions, and intent. Do not add new information. " +
            "Return only the translated text.\n\n\(body)"
        ) else { return nil }

        guard isTopic, let subject, !subject.trimmingCharacters(in: .whitespaces).isEmpty else {
            return DraftRewriteResult(body: translatedBody)
        }
        let translatedSubject = await cleanedResponse(
            "Translate this AppleVis forum topic subject into natural English. " +
            "Keep it concise. Return only the translated subject text.\n\n\(subject)"
        )
        return DraftRewriteResult(subject: translatedSubject ?? subject, body: translatedBody)
    }

    static func translateSearchQuery(_ query: String) async -> String? {
        guard isAvailable else { return nil }
        return await cleanedResponse(
            "Translate this AppleVis search query into natural English. " +
            "Keep it short and search-friendly. Return only the translated query.\n\n\(query.trimmingCharacters(in: .whitespaces))"
        )
    }

    static func summarize(_ text: String) async -> String? {
        guard isAvailable else { return nil }
        return await cleanedResponse("Summarise the following in 2-3 sentences:\n\n\(text)")
    }

    static func appDirectoryTeaser(appName: String, description: String) async -> String? {
        guard isAvailable else { return nil }
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDescription.isEmpty else { return nil }
        let trimmedName = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameClause = trimmedName.isEmpty ? "this app" : "\"\(trimmedName)\""
        return await cleanedResponse(
            "Write one plain-language sentence for an AppleVis app directory listing preview for \(nameClause). " +
            "Base it only on the App Store description below. Do not mention accessibility unless the description does. " +
            "Keep it under 180 characters. Return only the sentence.\n\n\(trimmedDescription)"
        )
    }

    /// RN's "Accessibility Consensus" (settingsData.ts) — aggregates app
    /// reviews into one verdict sentence about how well the app actually
    /// works with VoiceOver, e.g. "Most reviewers say this app works well
    /// with VoiceOver, though some note issues with the settings screen,"
    /// instead of a generic discussion summary.
    static func accessibilityConsensus(_ reviewText: String) async -> String? {
        guard isAvailable else { return nil }
        return await cleanedResponse(
            "Here are reviews of an iOS app from blind and low-vision users. " +
            "In 1-2 sentences, summarize the consensus on how well this app works " +
            "with VoiceOver and other accessibility features — call out any " +
            "specific problem areas reviewers agree on:\n\n\(reviewText)"
        )
    }

    static func generateDigest(_ activitySummary: String) async -> String? {
        guard isAvailable else { return nil }
        return await cleanedResponse(
            "Here is a list of new AppleVis activity since the user's last visit. " +
            "Write a friendly 2-3 sentence digest for a blind VoiceOver user:\n\n\(activitySummary)"
        )
    }

    // MARK: - Guideline second opinion

    /// Apple Intelligence's read on one rule-based guideline flag.
    struct GuidelineSecondOpinion: Sendable, Equatable {
        /// False when, read in context, the post doesn't really break the
        /// guideline: the rule's keywords matched, but the meaning didn't.
        let isRealConcern: Bool
        /// One short sentence saying why, for the admin check.
        let reason: String
    }

    /// Double-checks a rule-based flag in context. It can only confirm or
    /// clear a flag the rules raised, never add one, and it's only used
    /// for context-dependent rules (see `GuidelineWarning.allowsSecondOpinion`).
    /// Replaces an earlier pass that asked the model to find violations on
    /// its own, which could invent flags and showed untranslated wording.
    /// Requested directly (2026-09-27).
    static func secondOpinion(on warning: GuidelineWarning, in text: String) async -> GuidelineSecondOpinion? {
        guard warning.allowsSecondOpinion, let meaning = guidelineMeaning(warning.id) else { return nil }
        guard #available(iOS 26.0, *), isAvailable else { return nil }
        let post = String(HTMLText.plainText(fromHTML: text).prefix(3000))
        let prompt = """
        An automatic check flagged this AppleVis post for the guideline below. Read the post in context and decide whether it really breaks the guideline. If you're unsure, say it does.

        Guideline: \(meaning)

        Post:
        \(post)
        """
        do {
            let session = LanguageModelSession(instructions: """
            You help moderators of AppleVis, a friendly community of blind and low vision Apple users. \
            You check whether a flagged post really breaks one community guideline. \
            Friendly, helpful, excited, or merely frustrated posts are fine. Only confirm real problems.
            """)
            let response = try await session.respond(to: prompt, generating: GuidelineVerdict.self)
            return GuidelineSecondOpinion(isRealConcern: response.content.breaksGuideline, reason: response.content.reason)
        } catch {
            AppLog.intelligence.error("Guideline second opinion failed: \(error, privacy: .private)")
            return nil
        }
    }

    /// What each context-dependent guideline is really about, including
    /// what's fine, so the model judges meaning rather than keywords.
    private static func guidelineMeaning(_ id: String) -> String? {
        switch id {
        case "tone-medium", "tone-low":
            return "Respectful discussion. No personal attacks, put-downs, or dismissive remarks aimed at another member. Criticising a product, company, or update, and venting about a bug, are fine."
        case "personal-info":
            return "Privacy. Members shouldn't accidentally expose their own or someone else's personal contact details. An address shared on purpose so people can get in touch, such as a developer's or a tester sign-up address, is fine."
        case "self-promotion":
            return "No self-promotion. Members shouldn't use posts to advertise their own podcast, channel, website, or newsletter. Mentioning your own site while asking for help, or a developer discussing their app in its own thread, is fine."
        case "advertising":
            return "No advertising or selling. Posts shouldn't be sales listings or adverts. Talking about wanting to buy something, or asking where to buy it, is fine."
        case "press-release":
            return "Press releases need discussion around them. Pasting a press release on its own just to promote something isn't allowed. Quoting part of one while discussing it is fine."
        case "ai-disclosure":
            return "If AI wrote a post, the member should say so. Quoting an AI's answer and saying it came from an AI is fine."
        case "multi-topic":
            return "One topic per post. A new post shouldn't mix unrelated subjects. Several questions about the same subject are fine."
        case "excessive-punctuation", "all-caps":
            return "Be polite. Don't shout at people with capitals or strings of exclamation marks. Excitement, like \"I love this app!!!\", is fine."
        default:
            return nil
        }
    }

    /// Turns a person's rough notes about themselves into a short first-
    /// person AppleVis profile bio — for members who know roughly what they
    /// want to say but find a blank bio field intimidating to start from
    /// scratch. Never auto-applied: EditProfileView always shows the draft
    /// for the person to accept, edit, or discard.
    static func draftBio(from notes: String) async -> String? {
        guard isAvailable else { return nil }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return await cleanedResponse(
            "Write a short, warm AppleVis member bio (2-4 sentences, first person) based on these rough " +
            "notes about the person. The audience is the AppleVis accessibility community for blind and " +
            "low vision Apple users. Keep it natural and friendly, do not invent facts not present in the " +
            "notes, and do not include labels, headings, or quotation marks around the result.\n\nNotes:\n\(trimmed)"
        )
    }

    /// Called once per item in a Mouse Recap section (up to several apps,
    /// episodes, etc. in a row), each as an independent generation with no
    /// visibility into its siblings. Without the "don't reintroduce"
    /// instruction below, the model reliably opened almost every blurb with
    /// some variant of "In this new \(kind)..." — harmless alone, but
    /// repetitive read back to back, since the section header, its intro
    /// sentence, and this card's own kicker label already say that. Reported
    /// directly.
    static func newsletterBlurb(title: String, kind: String, sourceText: String) async -> String? {
        guard isAvailable else { return nil }
        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return await cleanedResponse(
            "Write a warm AppleVis newsletter-style blurb in 2-3 concise sentences for this \(kind). " +
            "The audience is blind and low vision Apple users. Preserve facts from the source, do not invent details, " +
            "and do not include headings, labels, markdown, or links. " +
            "Do not open by reintroducing what this is (e.g. \"In this new \(kind)...\" or restating the title/kind) — " +
            "that context is already given elsewhere on screen. Start directly with what's notable about it.\n\n" +
            "Title: \(title)\n\nSource:\n\(trimmed)"
        )
    }

    // MARK: - Ask the Mouse

    /// What the Mouse understood the question to be.
    struct MousePlan: Sendable {
        enum Kind: String, Sendable {
            case howToUseApp, findApps, appleHowTo, communityDiscussion, changeSetting, whatsNew, savedItems, other
        }
        var kind: Kind = .other
        /// Short English phrases for the site's search.
        var searchPhrases: [String] = []
        var appKeyword = ""
        var fullyAccessibleOnly = false
        var appCategory: String?
        var place: MousePlace?
        var mouseSwitch: MouseSwitch?
        var turnOn = true
    }

    /// One thing the Mouse can quote from: a Help article, part of a
    /// guide, a What's New entry, or a tip.
    struct MouseSource: Sendable {
        let id: String
        let title: String
        let text: String
    }

    struct MouseAnswer: Sendable {
        let answered: Bool
        let text: String
        let sourceIds: [String]
    }

    struct MouseItem: Sendable {
        let id: String
        let title: String
        let details: String
    }

    struct MousePicks: Sendable {
        let intro: String
        let mainHeading: String
        let relatedHeading: String
        /// Item ids with their group ("main" or "related") and a one-line blurb, best first.
        let picks: [(id: String, isMain: Bool, blurb: String)]
    }

    private static let mouseInstructions = """
    You are the Mouse, the friendly helper in the AppleVis app. AppleVis is a community of blind, DeafBlind, \
    low vision, and sighted people who share how well Apple devices and apps work with accessibility features \
    like VoiceOver. You are warm, brief, and plain-spoken. You only use the information you are given, and you \
    never make up apps, steps, settings, or facts.
    """

    /// Works out what the question is asking for and turns it into searches.
    /// `earlier` holds the last question or two, so follow-ups like "and how
    /// do I stop it?" make sense.
    static func mousePlan(for question: String, earlier: [String]) async -> MousePlan? {
        guard #available(iOS 26.0, *), isAvailable else { return nil }
        let places = MousePlace.allCases.map { "\($0.rawValue): \($0.modelDescription)" }.joined(separator: "\n")
        let switches = MouseSwitch.allCases.map { "\($0.rawValue): \($0.modelDescription)" }.joined(separator: "\n")
        let categories = AppEndpoints.iOSCategoryNames.joined(separator: ", ")
        let history = earlier.isEmpty ? "" : "Earlier questions in this conversation:\n" + earlier.joined(separator: "\n") + "\n\n"
        let prompt = """
        \(history)Question: \(question)

        App Directory categories: \(categories)

        Screens the app can open:
        \(places)

        Settings that can be switched on or off:
        \(switches)
        """
        do {
            let session = LanguageModelSession(instructions: mouseInstructions + """
             Work out what the person wants and plan the searches. Search phrases are always in English, \
            even if the question isn't. Use none when nothing fits.
            """)
            let result = try await session.respond(to: prompt, generating: MousePlanOutput.self).content
            var plan = MousePlan()
            plan.kind = MousePlan.Kind(rawValue: result.kind) ?? .other
            plan.searchPhrases = Array(result.searchPhrases
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(3))
            plan.appKeyword = result.appKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
            plan.fullyAccessibleOnly = result.fullyAccessibleOnly
            plan.appCategory = AppEndpoints.iOSCategoryNames.first { $0.caseInsensitiveCompare(result.appCategory) == .orderedSame }
            plan.place = MousePlace(rawValue: result.place)
            plan.mouseSwitch = MouseSwitch(rawValue: result.switchId)
            plan.turnOn = result.turnOn
            return plan
        } catch {
            AppLog.intelligence.error("Mouse plan failed: \(error, privacy: .private)")
            return nil
        }
    }

    /// Answers only from `sources`, in the question's language. Says it
    /// couldn't answer rather than guessing.
    static func mouseAnswer(to question: String, earlier: [String], sources: [MouseSource]) async -> MouseAnswer? {
        guard #available(iOS 26.0, *), isAvailable, !sources.isEmpty else { return nil }
        let listed = sources.map { "[\($0.id)] \($0.title)\n\($0.text)" }.joined(separator: "\n\n")
        let history = earlier.isEmpty ? "" : "Earlier questions: " + earlier.joined(separator: " / ") + "\n\n"
        let prompt = """
        \(history)Question: \(question)

        Sources:
        \(listed)
        """
        do {
            let session = LanguageModelSession(instructions: mouseInstructions + """
             Answer the question using only the sources. Keep it to the main steps or facts, in one to four \
            short sentences, and write in the same language as the question. Speak to the person as "you". \
            If the sources don't answer it, say so and don't guess.
            """)
            let result = try await session.respond(to: prompt, generating: MouseAnswerOutput.self).content
            let known = Set(sources.map(\.id))
            return MouseAnswer(
                answered: result.answered && !result.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                text: result.answer.trimmingCharacters(in: .whitespacesAndNewlines),
                sourceIds: result.sourceIds.filter { known.contains($0) }
            )
        } catch {
            AppLog.intelligence.error("Mouse answer failed: \(error, privacy: .private)")
            return nil
        }
    }

    /// Sorts search results into what was asked for and what's close,
    /// dropping the rest, with a line about each taken from its description.
    static func mousePicks(for question: String, items: [MouseItem]) async -> MousePicks? {
        guard #available(iOS 26.0, *), isAvailable, !items.isEmpty else { return nil }
        let listed = items.map { "[\($0.id)] \($0.title): \($0.details)" }.joined(separator: "\n")
        let prompt = """
        Question: \(question)

        Results:
        \(listed)
        """
        do {
            let session = LanguageModelSession(instructions: mouseInstructions + """
             Sort the results. Put what the person asked for in main, things that are close in related, \
            and anything that doesn't fit in none. Write each blurb only from that result's own text, in the \
            same language as the question.
            """)
            let result = try await session.respond(to: prompt, generating: MousePicksOutput.self).content
            let known = Set(items.map(\.id))
            var seen = Set<String>()
            let picks = result.picks
                .filter { known.contains($0.id) && $0.group != "none" && seen.insert($0.id).inserted }
                .map { (id: $0.id, isMain: $0.group == "main", blurb: $0.blurb.trimmingCharacters(in: .whitespacesAndNewlines)) }
            return MousePicks(intro: result.intro, mainHeading: result.mainHeading, relatedHeading: result.relatedHeading, picks: picks)
        } catch {
            AppLog.intelligence.error("Mouse picks failed: \(error, privacy: .private)")
            return nil
        }
    }

    // MARK: - Private

    private static func rawResponse(_ prompt: String) async -> String? {
        guard #available(iOS 26.0, *), isAvailable else { return nil }
        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            // Every caller here just returns nil on failure — this is the
            // one place that can see *why*, so log it rather than
            // discarding the reason entirely (context-window overflow,
            // guardrail rejection, and rate limiting all look identical to
            // callers otherwise, which made repeated reports of "it just
            // does nothing" hard to diagnose without a device console).
            // Previously DEBUG-only, which meant the exact field reports
            // this was added to diagnose were still invisible in Release.
            AppLog.intelligence.error("Generation failed: \(error, privacy: .private)")
            return nil
        }
    }

    private static func cleanedResponse(_ prompt: String) async -> String? {
        guard let text = await rawResponse(prompt) else { return nil }
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned.drop(while: { $0 != "\n" }).dropFirst().description
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }
}

/// The model's structured answer for `IntelligenceService.secondOpinion`.
@available(iOS 26.0, *)
@Generable
private struct GuidelineVerdict {
    @Guide(description: "True if the post really breaks the guideline in context. False if the automatic flag was a false alarm.")
    var breaksGuideline: Bool
    @Guide(description: "One short plain sentence, under 20 words, saying why.")
    var reason: String
}

// MARK: - Ask the Mouse model output

@available(iOS 26.0, *)
@Generable
private struct MousePlanOutput {
    @Guide(description: "What the person wants.", .anyOf(["howToUseApp", "findApps", "appleHowTo", "communityDiscussion", "changeSetting", "whatsNew", "savedItems", "other"]))
    var kind: String
    @Guide(description: "One to three short English search phrases for the AppleVis website, including other common ways to word it. No filler words.")
    var searchPhrases: [String]
    @Guide(description: "When finding apps: one English word likely to appear in the app's description, such as dice, weather, or podcast. Otherwise empty.")
    var appKeyword: String
    @Guide(description: "True only if the person asked for apps that are fully, totally, or completely accessible.")
    var fullyAccessibleOnly: Bool
    @Guide(description: "When finding apps: one App Directory category name from the list, or none.")
    var appCategory: String
    @Guide(description: "The id of the one screen that would help most, from the list, or none.")
    var place: String
    @Guide(description: "When the person wants a setting changed: the id of that setting from the list, or none.")
    var switchId: String
    @Guide(description: "When a setting is chosen: true to turn it on, false to turn it off.")
    var turnOn: Bool
}

@available(iOS 26.0, *)
@Generable
private struct MouseAnswerOutput {
    @Guide(description: "True if the sources answer the question.")
    var answered: Bool
    @Guide(description: "The answer in one to four short, warm, plain sentences, only from the sources. Empty if they don't answer it.")
    var answer: String
    @Guide(description: "The ids, in square brackets in the sources, of the sources the answer used, without the brackets.")
    var sourceIds: [String]
}

@available(iOS 26.0, *)
@Generable
private struct MousePicksOutput {
    @Guide(description: "One short, friendly sentence introducing what was found.")
    var intro: String
    @Guide(description: "A short heading for the main group, such as Dice games.")
    var mainHeading: String
    @Guide(description: "A short heading for the related group, such as Board games that use dice.")
    var relatedHeading: String
    var picks: [MousePickOutput]
}

@available(iOS 26.0, *)
@Generable
private struct MousePickOutput {
    @Guide(description: "The result's id exactly as given in square brackets, without the brackets.")
    var id: String
    @Guide(description: "main if it's what the person asked for, related if it's close, none if it doesn't fit.", .anyOf(["main", "related", "none"]))
    var group: String
    @Guide(description: "One short sentence about it, under 20 words, from its own text only.")
    var blurb: String
}
