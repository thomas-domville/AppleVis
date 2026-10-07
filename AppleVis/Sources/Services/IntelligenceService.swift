import Foundation
import UIKit
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
    nonisolated static func detectNonEnglish(_ text: String) -> Bool {
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
            "Here is a list of new AppleVis activity the user hasn't read yet. " +
            "Write a friendly 2-3 sentence digest for a blind VoiceOver user:\n\n\(activitySummary)"
        )
    }

    // MARK: - Guideline second opinion

    /// Apple Intelligence's read on one rule-based guideline flag.
    nonisolated struct GuidelineSecondOpinion: Sendable, Equatable, Codable {
        /// False when, read in context, the post doesn't really break the
        /// guideline: the rule's keywords matched, but the meaning didn't.
        /// True for "not sure" too, so an unsure answer keeps the flag.
        let isRealConcern: Bool
        /// Apple Intelligence couldn't tell. Kept as a flag, but shown as
        /// genuinely borderline. It used to have to pick yes or no, and was
        /// told to say yes when unsure. Requested directly (2026-10-06).
        var isUnsure = false
        /// One short sentence saying why, for the admin check.
        let reason: String
        /// Decided after reading the conversation around the post.
        var readConversation = false
    }

    /// Double-checks a rule-based flag in context. It can only confirm or
    /// clear a flag the rules raised, never add one, and it's only used
    /// for context-dependent rules (see `GuidelineWarning.allowsSecondOpinion`).
    /// Replaces an earlier pass that asked the model to find violations on
    /// its own, which could invent flags and showed untranslated wording.
    /// Requested directly (2026-09-27).
    /// Where a flagged post sits. The model used to see a comment on its
    /// own, so a developer replying in their own "looking for game ideas"
    /// thread with the prototype they'd built looked like promotion, and it
    /// agreed with the flag (2026-10-06). Reported directly.
    struct FlagContext: Sendable {
        var threadTitle: String = ""
        var isReply: Bool = false
        var authorStartedThread: Bool = false

        nonisolated init(threadTitle: String = "", isReply: Bool = false, authorStartedThread: Bool = false) {
            self.threadTitle = threadTitle
            self.isReply = isReply
            self.authorStartedThread = authorStartedThread
        }
    }

    /// Two steps. First the post alone, as before: clear-cut rules never get
    /// here, and if the post is plainly fine that's the answer. Only if it
    /// still looks like a problem, and it's a reply, is the conversation
    /// read (the opening post, what it replied to, and the comments just
    /// before), and the question asked again with it. So the extra reading
    /// is spent only on the borderline flags that need it. If the
    /// conversation can't be loaded or read, the first verdict stands.
    /// Requested directly (2026-10-06).
    static func reviewFlag(
        _ warning: GuidelineWarning, in text: String, context: FlagContext,
        loadConversation: (() async -> ConversationContext?)?
    ) async -> GuidelineSecondOpinion? {
        guard let first = await secondOpinion(on: warning, in: text, context: context) else { return nil }
        guard first.isRealConcern, context.isReply, let loadConversation,
              let conversation = await loadConversation(),
              let notes = await conversationNotes(conversation, for: warning) else { return first }
        var withThread = context
        withThread.threadTitle = conversation.threadTitle.isEmpty ? context.threadTitle : conversation.threadTitle
        withThread.authorStartedThread = context.authorStartedThread || conversation.flaggedAuthorStartedThread
        guard var second = await secondOpinion(on: warning, in: text, context: withThread, conversation: notes) else { return first }
        second.readConversation = true
        return second
    }

    /// Room for the conversation in one request, in characters. The on-device
    /// model reads about 4,096 tokens at once, instructions, post, and answer
    /// included (Apple TN3193), and the post takes up to 3,000 characters.
    private static let conversationBudget = 5_000
    private static let conversationPartSize = 4_000

    /// The conversation as it will be shown to the model. When it's too long
    /// for one request, it's read in parts (at most three), each reduced to a
    /// short note on what matters for this guideline, and the notes are used
    /// instead. The model can't carry one part over to the next, since
    /// everything in a session counts toward the same limit.
    static func conversationNotes(_ conversation: ConversationContext, for warning: GuidelineWarning) async -> String? {
        guard let meaning = guidelineMeaning(warning.id) else { return nil }
        func clip(_ text: String, _ limit: Int) -> String {
            text.count > limit ? String(text.prefix(limit)) + "…" : text
        }
        var units = ["Thread title: \(conversation.threadTitle)",
                     "Opening post: \(clip(conversation.openingPost, 3_000))"]
        if !conversation.earlier.isEmpty {
            units.append("Comments just before it, oldest first:\n" + conversation.earlier.map { "- " + clip($0, 1_000) }.joined(separator: "\n"))
        }
        if let replyingTo = conversation.replyingTo {
            units.append("The comment it replies to: \(clip(replyingTo, 2_000))")
        }
        let whole = units.joined(separator: "\n\n")
        if whole.count <= conversationBudget { return whole }

        guard #available(iOS 26.0, *), isAvailable else { return nil }
        var parts: [String] = []
        var current = ""
        for unit in units {
            if !current.isEmpty, current.count + unit.count > conversationPartSize {
                parts.append(current)
                current = ""
            }
            current += (current.isEmpty ? "" : "\n\n") + clip(unit, conversationPartSize)
        }
        if !current.isEmpty { parts.append(current) }
        var notes: [String] = []
        for part in parts.prefix(3) {
            let prompt = """
            Here is part of a conversation on AppleVis. A later reply in it was flagged for this guideline: \(meaning)

            In one or two short sentences, note only what in this part matters for judging that reply, such as what the thread is about, who started it, or what was asked. If nothing matters, say so.

            \(part)
            """
            if let note = await cleanedResponse(prompt) { notes.append(note) }
        }
        return notes.isEmpty ? nil : "Notes on the conversation:\n" + notes.map { "- " + $0 }.joined(separator: "\n")
    }

    static func secondOpinion(on warning: GuidelineWarning, in text: String, context: FlagContext = FlagContext(), conversation: String? = nil) async -> GuidelineSecondOpinion? {
        guard warning.allowsSecondOpinion, let meaning = guidelineMeaning(warning.id) else { return nil }
        guard #available(iOS 26.0, *), isAvailable else { return nil }
        let post = String(HTMLText.plainText(fromHTML: text).prefix(3000))
        var placement = ""
        if context.isReply {
            placement = "This is a reply in the thread titled \"\(context.threadTitle)\"."
            if context.authorStartedThread { placement += " The person who wrote it started that thread." }
        } else if !context.threadTitle.isEmpty {
            placement = "This is the opening post, titled \"\(context.threadTitle)\"."
        }
        let thread = conversation.map {
            "The conversation it's part of, for context only. Judge only the post at the end, not anything in here.\n\($0)\n\n"
        } ?? ""
        let prompt = """
        An automatic check flagged this AppleVis post for the guideline below. Read the post in context and decide whether it really breaks the guideline: breaks, fine, or unsure. Say unsure when it could reasonably go either way.

        Guideline: \(meaning)

        \(placement)

        \(thread)Post:
        \(post)
        """
        do {
            let session = LanguageModelSession(instructions: """
            You help moderators of AppleVis, a friendly community of blind and low vision Apple users. \
            You check whether a flagged post really breaks one community guideline. \
            Friendly, helpful, excited, or merely frustrated posts are fine. Only confirm real problems.
            """)
            let response = try await session.respond(to: prompt, generating: GuidelineVerdict.self)
            let verdict = response.content.verdict
            return GuidelineSecondOpinion(isRealConcern: verdict != "fine", isUnsure: verdict == "unsure", reason: response.content.reason)
        } catch {
            AppLog.intelligence.error("Guideline second opinion failed: \(error, privacy: .private)")
            return nil
        }
    }

    /// What each context-dependent guideline is really about, including
    /// what's fine, so the model judges meaning rather than keywords.
    /// What a judgement-call rule means, with a real AppleVis example of
    /// each side (small on-device models judge borderline cases better with
    /// examples). Kept in the shared rules file, so a better description or
    /// example reaches everyone without an app update (2026-10-06).
    private static func guidelineMeaning(_ id: String) -> String? {
        GuidelineRules.current.meaning(forRule: id)
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
            /// Nothing to do with Apple, accessibility, or AppleVis, such
            /// as cars or recipes. Answered with a friendly redirect, and
            /// nothing is searched. Requested directly (2026-10-01).
            case offTopic
        }
        var kind: Kind = .other
        /// Short English phrases for the site's search.
        var searchPhrases: [String] = []
        var appKeyword = ""
        var fullyAccessibleOnly = false
        var appCategory: String?
        /// Which App Directory to search for apps.
        var appPlatform: AppPlatform = .ios
        var place: MousePlace?
        var mouseSwitch: MouseSwitch?
        var turnOn = true
        /// A sharper search for Search the Web: the device and feature
        /// named, in English.
        var webQuery = ""
        /// A page outside AppleVis that covers the question, if one does.
        var appleLink: MouseAppleLink?
        /// Or a page from Apple's user guides, chosen from the candidates.
        var catalogLink: MouseAppleCatalog.Entry?
        /// An essential AppleVis guide on the subject, always read.
        var essentialGuide: MouseEssentialGuide?
        /// The one app the question asks about by name, if any.
        var appName = ""
        /// Read the person's own settings on `place`'s screen, for "why
        /// doesn't…" questions about the app. Requested directly (2026-10-01).
        var checkSetup = false
        /// When the question can't be understood, such as "How do I turn it
        /// off?" with nothing before it: what to ask back, and two or three
        /// questions they might mean. Requested directly (2026-10-01).
        var clarify = ""
        var clarifyChoices: [String] = []
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
        /// The steps to follow, in order, when the answer is a how-to.
        /// `text` is then a short introduction to them.
        var steps: [String] = []
        /// Two or three questions the person might ask next.
        var followUps: [String] = []
        /// When nothing answers it: what came close, and how it differs.
        var nearMiss = ""
        /// The source each step came from, by id, in step order.
        var stepSources: [String] = []
    }

    /// Why Apple Intelligence couldn't answer, when it's worth telling the
    /// person. Requested directly (2026-09-29).
    enum MouseFailure: Sendable, Equatable {
        /// Apple's safety check stopped it, sometimes by mistake.
        case blocked
        /// The question's language isn't supported yet.
        case unsupportedLanguage
        /// Too many requests at once.
        case busy
    }

    struct MouseAnswerResult: Sendable {
        var answer: MouseAnswer?
        var failure: MouseFailure?
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

    // Speaks as the Mouse, warmly, answer first. Requested directly (2026-10-01).
    private static let mouseInstructions = """
    You are the Mouse, the friendly helper in the AppleVis app. AppleVis is a community of blind, DeafBlind, \
    low vision, and sighted people who share how well Apple devices and apps work with accessibility features \
    like VoiceOver. You are warm, brief, and plain-spoken, and you speak as yourself, the Mouse, in the first \
    person: "I found this in a guide." Lead with the answer itself, said warmly, with no openers like "Great \
    question". When it genuinely helps, end with one short, practical tip. You only use the information you are \
    given, and you never make up apps, steps, settings, or facts. Copy commands, gestures, key combinations, \
    Braille dot patterns, keyboard shortcuts, and setting names exactly as the source writes them; never reword \
    them.
    """

    private static let mousePlanInstructions = mouseInstructions + """
     Work out what the person wants and plan the searches. Search phrases are always in English, \
    even if the question isn't. Use none when nothing fits. whatsNew means changes to this AppleVis \
    app itself; news about iOS, Apple, or other apps is appleHowTo or communityDiscussion. Make one of the \
    search phrases the broader topic, the way AppleVis guides are titled, such as "VoiceOver gestures" for a \
    gesture question or "braille display commands" for a braille question. offTopic is only for questions \
    with nothing to do with Apple products, accessibility, assistive technology, blindness or low vision, or \
    AppleVis, such as cars, sports, or recipes. Questions about accessibility or assistive technology in \
    general are on topic, even without Apple. When unsure, it is not offTopic.
    """

    /// A planning session loaded ahead of time by `prewarmMouse()`.
    nonisolated(unsafe) private static var warmPlanSession: AnyObject?

    /// Loads the model as soon as Ask the Mouse opens, so the first
    /// question doesn't wait for it. Requested directly (2026-09-29).
    static func prewarmMouse() {
        guard #available(iOS 26.0, *), isAvailable, warmPlanSession == nil else { return }
        let session = LanguageModelSession(instructions: mousePlanInstructions)
        session.prewarm()
        warmPlanSession = session
    }

    /// Why a generation failed, in the terms the person is told.
    @available(iOS 26.0, *)
    private static func mouseFailure(_ error: Error) -> MouseFailure? {
        guard let error = error as? LanguageModelSession.GenerationError else { return nil }
        switch error {
        case .guardrailViolation: return .blocked
        case .unsupportedLanguageOrLocale: return .unsupportedLanguage
        case .rateLimited, .concurrentRequests: return .busy
        default: return nil
        }
    }

    @available(iOS 26.0, *)
    private static func isTooLong(_ error: Error) -> Bool {
        guard let error = error as? LanguageModelSession.GenerationError,
              case .exceededContextWindowSize = error else { return false }
        return true
    }

    /// Works out what the question is asking for and turns it into searches.
    /// `earlier` holds the last question or two, so follow-ups like "and how
    /// do I stop it?" make sense.
    static func mousePlan(for question: String, earlier: [String], catalog: [MouseAppleCatalog.Entry] = [], aboutMe: String = "") async -> MousePlan? {
        guard #available(iOS 26.0, *), isAvailable else { return nil }
        let places = MousePlace.allCases.map { "\($0.rawValue): \($0.modelDescription)" }.joined(separator: "\n")
        let switches = MouseSwitch.allCases.map { "\($0.rawValue): \($0.modelDescription)" }.joined(separator: "\n")
        let categories = AppEndpoints.iOSCategoryNames.joined(separator: ", ")
        let history = earlier.isEmpty ? "" : "Earlier questions in this conversation:\n" + earlier.joined(separator: "\n") + "\n\n"
        // When the question doesn't name a device, the person's own.
        let profile = aboutMe.isEmpty ? "" : aboutMe + " When the question doesn't name a device, plan for theirs.\n\n"
        let prompt = """
        \(profile)\(history)Question: \(question)

        App Directory categories: \(categories)

        Screens the app can open:
        \(places)

        Settings that can be switched on or off:
        \(switches)

        Helpful pages outside AppleVis:
        \(MouseAppleLink.allCases.map { "\($0.rawValue): \($0.modelDescription)" }.joined(separator: "\n"))

        Apple user guide pages:
        \(catalog.enumerated().map { "catalog-\($0.offset): \($0.element.t) (\($0.element.d))" }.joined(separator: "\n"))

        Essential AppleVis guides:
        \(MouseEssentialGuide.allCases.map { "\($0.rawValue): \($0.modelDescription)" }.joined(separator: "\n"))
        """
        do {
            // The session loaded when the screen opened, used once.
            let warm = warmPlanSession as? LanguageModelSession
            warmPlanSession = nil
            let session = warm ?? LanguageModelSession(instructions: mousePlanInstructions)
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
            switch result.appPlatform {
            case "mac": plan.appPlatform = .macos
            case "watch": plan.appPlatform = .watchos
            case "tv": plan.appPlatform = .tvos
            default: plan.appPlatform = .ios
            }
            plan.place = MousePlace(rawValue: result.place)
            plan.mouseSwitch = MouseSwitch(rawValue: result.switchId)
            plan.turnOn = result.turnOn
            plan.webQuery = result.webQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            plan.appleLink = MouseAppleLink(rawValue: result.appleLink)
            if result.appleLink.hasPrefix("catalog-"), let index = Int(result.appleLink.dropFirst("catalog-".count)), catalog.indices.contains(index) {
                plan.catalogLink = catalog[index]
            }
            plan.essentialGuide = MouseEssentialGuide(rawValue: result.essentialGuide)
            plan.appName = result.appName.trimmingCharacters(in: .whitespacesAndNewlines)
            plan.checkSetup = result.checkSetup
            plan.clarify = result.clarify.trimmingCharacters(in: .whitespacesAndNewlines)
            plan.clarifyChoices = result.clarifyChoices
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0.caseInsensitiveCompare(question) != .orderedSame }
            return plan
        } catch {
            AppLog.intelligence.error("Mouse plan failed: \(error, privacy: .private)")
            return nil
        }
    }

    /// Answers only from `sources`, in the question's language. Says it
    /// couldn't answer rather than guessing.
    ///
    /// `onPartial` gets the answer as it's written, for the screen only.
    /// When the sources are too long for the model, it tries again with
    /// each one shortened, rather than giving up. Requested directly
    /// (2026-09-29).
    static func mouseAnswer(
        to question: String, earlier: [String], sources: [MouseSource], iOSVersion: String = "", aboutMe: String = "",
        onPartial: (@MainActor @Sendable (String) -> Void)? = nil
    ) async -> MouseAnswerResult {
        guard #available(iOS 26.0, *), isAvailable, !sources.isEmpty else { return MouseAnswerResult() }
        var current = sources
        for attempt in 0..<3 {
            do {
                let answer = try await streamMouseAnswer(to: question, earlier: earlier, sources: current,
                                                         iOSVersion: iOSVersion, aboutMe: aboutMe, onPartial: onPartial)
                return MouseAnswerResult(answer: answer)
            } catch {
                if isTooLong(error), attempt < 2 {
                    AppLog.intelligence.info("Mouse answer too long; shortening sources")
                    current = current.map { MouseSource(id: $0.id, title: $0.title, text: String($0.text.prefix($0.text.count * 3 / 5))) }
                    continue
                }
                AppLog.intelligence.error("Mouse answer failed: \(error, privacy: .private)")
                return MouseAnswerResult(failure: mouseFailure(error))
            }
        }
        return MouseAnswerResult()
    }

    /// The answer so far, as it would be shown: the introduction, then the
    /// numbered steps.
    static func mouseAnswerText(_ answer: String, steps: [String]) -> String {
        let steps = steps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !steps.isEmpty else { return answer }
        let numbered = steps.enumerated().map { "\($0.offset + 1). \($0.element)" }
        return ([answer.trimmingCharacters(in: .whitespacesAndNewlines)] + numbered)
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    @available(iOS 26.0, *)
    private static func streamMouseAnswer(
        to question: String, earlier: [String], sources: [MouseSource], iOSVersion: String, aboutMe: String,
        onPartial: (@MainActor @Sendable (String) -> Void)?
    ) async throws -> MouseAnswer {
        let listed = sources.map { "[\($0.id)] \($0.title)\n\($0.text)" }.joined(separator: "\n\n")
        let history = earlier.isEmpty ? "" : "Earlier questions: " + earlier.joined(separator: " / ") + "\n\n"
        // Sources written for the person's own iOS version come first.
        // Requested directly (2026-09-29).
        // The device they're asking from, so a question that doesn't say
        // is answered for it, and older sources are called out (2026-10-06).
        let device = UIDevice.current.model
        let version = iOSVersion.isEmpty ? "" : "The person is asking from an \(device) with iOS \(iOSVersion). When sources disagree, prefer what fits that version. When the question and About Me don't say which device, answer for their \(device) and say so in a few words. When the only sources that answer are written for an older iOS, say the steps may have changed.\n\n"
        // About Me: lead with the person's own device and way of using it
        // when the question doesn't say. Requested directly (2026-10-01).
        let profile = aboutMe.isEmpty ? "" : aboutMe + " When the question doesn't say which device or method, and the sources cover theirs, lead with that.\n\n"
        let prompt = """
        \(profile)\(version)\(history)Question: \(question)

        Sources:
        \(listed)
        """
        let session = LanguageModelSession(instructions: mouseInstructions + """
         Answer the question using only the sources. Keep it to the main steps or facts, in one to four \
        short sentences, and write in the same language as the question. Speak to the person as "you". \
        When the answer is steps to follow, write a short introduction as the answer and put each step, \
        in order, in steps. If the sources don't answer it, say so and don't guess. Prefer Help and guides. \
        Members' comments and forum discussions are advice from community members: use them when they add \
        something useful or the other sources don't answer, and then say so, for example "A member suggests…". \
        Only use a source that is about the same device as the question (iPhone, iPad, Mac, Apple Watch, or \
        Apple TV) and the same way of using it (a braille display, Braille Screen Input, a keyboard, or touch \
        gestures). A source about a different device or method doesn't answer the question, even if it uses \
        the same words; mention it in nearMiss instead. Bug reports are known accessibility bugs from \
        the AppleVis Bug Tracker: when one matches, say it's a known bug, whether it's still active or fixed and \
        in which version, and give any workaround. Members' comments on an app entry say how accessible members \
        found that app: sum up what they report, mention how recent the comments are, and say it's members' \
        experience. If that app isn't the one the person asked about, don't use it. A source about the person's own \
        AppleVis app settings, checked on their device just now, is fact: when a setting explains the problem, say \
        which one, that it's on or off, and where to change it. A podcast episode's transcript is people talking: use it when it explains the answer. iPhone and iPad work the same way, so a source \
        about one answers a question about the other unless it says otherwise.
        """)
        // Streamed, so the answer can appear as it's written. Only the
        // finished answer is given to VoiceOver.
        let stream = session.streamResponse(to: prompt, generating: MouseAnswerOutput.self)
        var latest: MouseAnswerOutput.PartiallyGenerated?
        for try await snapshot in stream {
            latest = snapshot.content
            if let onPartial {
                onPartial(mouseAnswerText(snapshot.content.answer ?? "", steps: snapshot.content.steps ?? []))
            }
        }
        let known = Set(sources.map(\.id))
        let text = (latest?.answer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let steps = (latest?.steps ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let answered = (latest?.answered ?? false) && !(text.isEmpty && steps.isEmpty)
        return MouseAnswer(
            answered: answered,
            text: text,
            sourceIds: (latest?.sourceIds ?? []).filter { known.contains($0) },
            steps: answered ? steps : [],
            followUps: answered
                ? (latest?.followUps ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                : [],
            nearMiss: answered ? "" : (latest?.nearMiss ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            stepSources: answered ? (latest?.stepSources ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } : []
        )
    }

    /// One result's answer to the question: a short line written only from
    /// that page's matching passage, or "doesn't answer" so the result can
    /// be dropped. Nil when Apple Intelligence can't run or fails.
    /// Requested directly (2026-09-29).
    ///
    /// With `answer`, also says whether the page agrees with it, so other
    /// sources can be marked "Says the same" or "Says something different".
    /// Requested directly (2026-10-01).
    static func mouseResultLine(question: String, title: String, passage: String, answer: String? = nil) async -> (answers: Bool, line: String, agreement: String)? {
        guard #available(iOS 26.0, *), isAvailable, !passage.isEmpty else { return nil }
        let given = answer.map { "\n\nThe answer already given: \($0)" } ?? ""
        let prompt = """
        Question: \(question)\(given)

        Page: \(title)
        \(passage)
        """
        do {
            let session = LanguageModelSession(instructions: mouseInstructions + """
             Read this one page and say what it tells the person about their question, in one short sentence, \
            in the same language as the question. If it doesn't answer the question, say so.
            """)
            let result = try await session.respond(to: prompt, generating: MouseResultLineOutput.self).content
            let line = result.line.trimmingCharacters(in: .whitespacesAndNewlines)
            return (result.answers && !line.isEmpty, line, answer == nil ? "none" : result.agreement)
        } catch {
            AppLog.intelligence.error("Mouse result line failed: \(error, privacy: .private)")
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
    @Guide(description: "breaks if the post really breaks the guideline in context, fine if the automatic flag was a false alarm, unsure if it could reasonably go either way.", .anyOf(["breaks", "fine", "unsure"]))
    var verdict: String
    @Guide(description: "One short plain sentence, under 20 words, saying why.")
    var reason: String
}

// MARK: - Ask the Mouse model output

@available(iOS 26.0, *)
@Generable
private struct MousePlanOutput {
    @Guide(description: "What the person wants.", .anyOf(["howToUseApp", "findApps", "appleHowTo", "communityDiscussion", "changeSetting", "whatsNew", "savedItems", "other", "offTopic"]))
    var kind: String
    @Guide(description: "One to three short English search phrases for the AppleVis website, including other common ways to word it. No filler words.")
    var searchPhrases: [String]
    @Guide(description: "When finding apps: one to three English words, separated by commas, likely to appear in the app's name or description, such as card, solitaire, poker for card games, or dice for dice games. Avoid short words found inside other words: for car games use racing, driving rather than car. Otherwise empty.")
    var appKeyword: String
    @Guide(description: "True only if the person asked for apps that are fully, totally, or completely accessible.")
    var fullyAccessibleOnly: Bool
    @Guide(description: "When finding apps: one App Directory category name from the list, or none.")
    var appCategory: String
    @Guide(description: "When finding apps: the device they're for. mac for a Mac, watch for Apple Watch, tv for Apple TV, otherwise ios.", .anyOf(["ios", "mac", "watch", "tv"]))
    var appPlatform: String
    @Guide(description: "The id of the one screen that would help most, from the list, or none.")
    var place: String
    @Guide(description: "When the person wants a setting changed: the id of that setting from the list, or none.")
    var switchId: String
    @Guide(description: "When a setting is chosen: true to turn it on, false to turn it off.")
    var turnOn: Bool
    @Guide(description: "A short English web search for the question, naming the Apple device and the feature, such as iPhone VoiceOver braille display command Control Center. Empty when offTopic.")
    var webQuery: String
    @Guide(description: "The id of the one page outside AppleVis from either list that covers the question: a helpful page or an Apple user guide page (catalog-…). Prefer the most specific page for the device asked about; for Be My Eyes questions a Be My Eyes page; for someone just starting to learn VoiceOver, a Hadley lesson. When no specific page fits, the user guide for the Apple device the question is about. none when offTopic or nothing fits.")
    var appleLink: String
    @Guide(description: "The id of the one essential AppleVis guide from the list whose subject the question is about, or none.")
    var essentialGuide: String
    @Guide(description: "When the question asks about one specific app by name, such as how accessible it is, the app's name. Otherwise empty.")
    var appName: String
    @Guide(description: "True only when the person asks why something in this AppleVis app isn't working as expected, or how their own AppleVis settings are set, such as why they don't get notifications or why sounds don't play. Then place is that settings screen.")
    var checkSetup: Bool
    @Guide(description: "Almost always empty. Only when the question can't be understood even with the earlier questions, because it doesn't say what it's about, such as How do I turn it off? with no earlier question: one short, warm question asking what they mean, in the same language as the question.")
    var clarify: String
    @Guide(description: "Only when asking what they mean: two or three complete questions they might mean, worded as they would ask them, in the same language as the question. Otherwise empty.", .maximumCount(3))
    var clarifyChoices: [String]
}

@available(iOS 26.0, *)
@Generable
private struct MouseAnswerOutput {
    @Guide(description: "True if the sources answer the question.")
    var answered: Bool
    @Guide(description: "The answer in one to four short, warm, plain sentences, speaking as the Mouse, only from the sources. When it's steps to follow, one short sentence introducing them. Empty if they don't answer it.")
    var answer: String
    @Guide(description: "When the answer is steps to follow in order, each step as one short instruction, in order, copying commands and setting names exactly. Otherwise empty.", .maximumCount(8))
    var steps: [String]
    @Guide(description: "The ids, in square brackets in the sources, of the sources the answer used, without the brackets.")
    var sourceIds: [String]
    @Guide(description: "When there are steps: for each step, in the same order, the id of the source it came from, without the brackets. Otherwise empty.", .maximumCount(8))
    var stepSources: [String]
    @Guide(description: "Only when the sources don't answer it: one or two warm sentences saying you couldn't find exactly that on AppleVis, then what was close and how it differs, such as a Mac shortcut instead of an iPhone one, or Braille Screen Input instead of a braille display. Empty when the sources answer it or nothing is close.")
    var nearMiss: String
    @Guide(description: "Two or three short questions the person might ask next about the same subject, worded as they would ask them, in the same language as the question. Empty if the sources don't answer it.", .maximumCount(3))
    var followUps: [String]
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

@available(iOS 26.0, *)
@Generable
private struct MouseResultLineOutput {
    @Guide(description: "True if the page answers the question.")
    var answers: Bool
    @Guide(description: "One short sentence, under 30 words, saying what the page tells the person about their question. Copy commands, gestures, and setting names exactly. Empty if it doesn't answer.")
    var line: String
    @Guide(description: "When an answer already given is shown: same if the page says the same, different if it says something different, none if no answer was given or the page doesn't answer.", .anyOf(["same", "different", "none"]))
    var agreement: String
}
