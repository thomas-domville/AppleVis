import Foundation

/// Text the app adds to what a member posts on applevis.com. The website is
/// in English, so this stays English whatever language the app is in.
enum SiteText {
    /// Added under an App Store description the app translated, so readers
    /// of the entry know it isn't the developer's own English.
    static func translatedDescriptionNote(languageCode: String) -> String {
        let language = Locale(identifier: "en").localizedString(forLanguageCode: languageCode) ?? "another language"
        return "(Translated automatically from \(language) by the AppleVis app.)"
    }

    // MARK: - Notes sent to the AppleVis team through the Contact form

    static let mouseNotesSubject = "Ask the Mouse Notes"

    /// The sender's optional note, above the notes themselves.
    static func withSenderNote(_ note: String, _ body: String) -> String {
        (note.isEmpty ? "" : "Note from the sender: \(note)\n\n") + body
    }

    static func reasonText(_ reason: MouseNote.Reason) -> String {
        switch reason {
        case .wrong: return "wrong answer"
        case .outOfDate: return "out of date"
        case .notWhatIAsked: return "not what I asked"
        case .nothingUseful: return "nothing useful found"
        }
    }

    /// Ask the Mouse notes, in English apart from the person's own words.
    /// Kept under 15,000 characters so the Contact form takes them; the
    /// rest go next time.
    static func mouseNotesMessage(_ notes: [MouseNote], includeText: Bool) -> (text: String, ids: [String]) {
        var text = "Ask the Mouse notes: \(notes.count). App \(DiagnosticInfo.appVersion) (\(DiagnosticInfo.buildNumber)), iOS \(DiagnosticInfo.iosVersion), \(DiagnosticInfo.deviceModel), language \(Locale.current.identifier).\n\n"
        var ids: [String] = []
        for note in notes {
            var entry: String
            switch note.kind {
            case .notHelpful: entry = "[DIDN'T HELP\(note.reason.map { ": \(reasonText($0))" } ?? "")] "
            case .noAnswer: entry = "[NO ANSWER ON APPLEVIS] "
            }
            entry += "Question: \(note.question)\n"
            if includeText { entry += "Answer: \(note.answer.replacingOccurrences(of: "\n", with: " "))\n" }
            if !note.sources.isEmpty { entry += "Looked at: \(note.sources.prefix(6).joined(separator: "; "))\n" }
            entry += "\n"
            if text.count + entry.count > 15_000 { break }
            text += entry
            ids.append(note.id)
        }
        if ids.count < notes.count { text += "(\(notes.count - ids.count) more to send next time.)\n" }
        return (text, ids)
    }
}
