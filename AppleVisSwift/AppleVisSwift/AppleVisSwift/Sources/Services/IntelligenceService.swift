import Foundation
import NaturalLanguage
import FoundationModels

/// On-device "Apple Intelligence" features — non-English detection (NaturalLanguage),
/// and rewrite/translate/summarize (FoundationModels on-device LLM, iOS 26+).
/// Everything here runs entirely on-device; nothing is sent to a server.
enum IntelligenceService {

    // MARK: - Availability

    static var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
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

    static func generateDigest(_ activitySummary: String) async -> String? {
        guard isAvailable else { return nil }
        return await cleanedResponse(
            "Here is a list of new AppleVis activity since the user's last visit. " +
            "Write a friendly 2-3 sentence digest for a blind VoiceOver user:\n\n\(activitySummary)"
        )
    }

    /// AI-assisted second pass on top of the rule-based `GuidelinesChecker` —
    /// conservative, only flags obvious violations the rules missed.
    static func checkAgainstGuidelinesAI(_ text: String) async -> [GuidelineWarning] {
        guard isAvailable else { return [] }
        guard let result = await rawResponse(
            "You are a content moderation assistant for AppleVis, an accessibility community " +
            "for blind and low vision Apple users. Review the following draft post and identify " +
            "any CLEAR violations of the AppleVis posting guidelines. Be conservative — only flag " +
            "obvious violations. Respond ONLY with a JSON array where each item has: id, rule, message, severity (\"high\"|\"medium\"|\"low\"). " +
            "If no violations, return []\n\nDraft post:\n\(text)"
        ) else { return [] }

        struct RawWarning: Decodable { let id: String; let rule: String; let message: String; let severity: String }
        guard let data = result.data(using: .utf8),
              let raw = try? JSONDecoder().decode([RawWarning].self, from: data) else { return [] }
        return raw.compactMap { w in
            let severity: GuidelineWarning.Severity
            switch w.severity {
            case "high": severity = .high
            case "low": severity = .low
            default: severity = .medium
            }
            return GuidelineWarning(id: w.id, rule: w.rule, message: w.message, severity: severity)
        }
    }

    // MARK: - Private

    private static func rawResponse(_ prompt: String) async -> String? {
        guard isAvailable else { return nil }
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
            #if DEBUG
            print("IntelligenceService generation failed: \(error)")
            #endif
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
