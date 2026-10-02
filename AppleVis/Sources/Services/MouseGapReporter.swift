import Foundation

/// "Suggest This Topic to AppleVis": when Ask the Mouse couldn't answer, or
/// someone said the answer didn't help, a signed-in member can send just
/// the question to the editorial team, so real questions show which guides
/// are missing. Goes through the existing Contact pipeline, like the
/// guideline checker's false-positive report. Nothing is sent unless the
/// member chooses to. English on purpose (team-facing). Requested directly
/// (2026-10-01).
enum MouseGapReporter {
    enum Outcome: String {
        case notFound = "The Mouse couldn't find an answer on AppleVis."
        case nearMiss = "The Mouse found only something close."
        case notHelpful = "The member said the answer didn't help."
    }

    static func report(
        question: String,
        outcome: Outcome,
        sourceTitles: [String],
        reporterName: String,
        reporterEmail: String
    ) async -> Bool {
        let sources = sourceTitles.isEmpty ? "None" : sourceTitles.map { "- \($0)" }.joined(separator: "\n")
        let message = """
        A member suggested a topic from Ask the Mouse.

        Question: \(question)
        What happened: \(outcome.rawValue)

        AppleVis sources the Mouse used:
        \(sources)
        """
        let result = await DrupalFormClient.submitContact(
            name: reporterName,
            email: reporterEmail,
            subject: "Ask the Mouse: Topic Suggestion",
            message: message
        )
        if case .ok = result { return true }
        return false
    }
}
