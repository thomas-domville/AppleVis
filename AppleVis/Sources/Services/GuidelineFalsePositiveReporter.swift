import Foundation

/// Lets a signed-in user flag a guideline-checker warning as wrong while
/// composing, instead of just silently dismissing it — the same false-
/// positive review this app's own admin Guideline Violation Check has been
/// tuned against (see GuidelinesChecker.swift's "live-data" history), but
/// sourced continuously from real usage instead of an occasional manual
/// scan. Routes through the existing Contact Us pipeline rather than a new
/// backend endpoint, so it lands with the editorial team the same way a bug
/// report does. Requested directly.
enum GuidelineFalsePositiveReporter {
    static func report(
        warning: GuidelineWarning,
        draftText: String,
        context: String,
        reporterName: String,
        reporterEmail: String
    ) async -> Bool {
        let severityLabel: String
        switch warning.severity {
        case .high:   severityLabel = "High"
        case .medium: severityLabel = "Medium"
        case .low:    severityLabel = "Low"
        }

        let excerpt = draftText.count > 500 ? String(draftText.prefix(500)) + "…" : draftText

        let message = """
        A user flagged a guideline-checker warning as a false positive while composing.

        Screen: \(context)
        Rule: \(warning.rule) (\(severityLabel))
        Checker message shown: \(warning.message)

        Flagged draft text:
        \(excerpt)
        """

        let result = await DrupalFormClient.submitContact(
            name: reporterName,
            email: reporterEmail,
            subject: "Guideline Checker False Positive",
            message: message
        )
        if case .ok = result { return true }
        return false
    }
}
