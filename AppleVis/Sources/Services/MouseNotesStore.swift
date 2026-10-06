import Combine
import Foundation
import UIKit

/// What helps Ask the Mouse improve for everyone: answers marked "No, It
/// Didn't" (and what was wrong), and questions AppleVis had nothing to answer.
/// Kept on the device until the person chooses to send them through the
/// Contact form. The unanswered questions also show the AppleVis team what
/// the community asks that no guide covers yet. Requested directly
/// (2026-10-06).
nonisolated struct MouseNote: Codable, Identifiable, Sendable {
    enum Kind: String, Codable, Sendable { case notHelpful, noAnswer }
    /// Why an answer didn't help, when the person said.
    enum Reason: String, Codable, Sendable, CaseIterable {
        case wrong, outOfDate, notWhatIAsked, nothingUseful
    }

    let id: String
    var kind: Kind
    var reason: Reason?
    let question: String
    let answer: String
    let sources: [String]
    let date: Date
}

@MainActor
final class MouseNotesStore: ObservableObject {
    static let shared = MouseNotesStore()

    @Published private(set) var notes: [MouseNote] = []
    private var sentIds: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "mouse.notesSent") ?? [])

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("mouse-notes.json")
    }

    private init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? JSONDecoder().decode([MouseNote].self, from: data) {
            notes = saved
        }
    }

    var unsent: [MouseNote] { notes.filter { !sentIds.contains($0.id) } }

    func recordNotHelpful(_ turn: MouseTurn) {
        upsert(id: turn.id.uuidString) { existing in
            MouseNote(id: turn.id.uuidString, kind: .notHelpful, reason: existing?.reason, question: turn.question,
                      answer: turn.savedAnswerText, sources: turn.savedSources.map(\.title), date: Date())
        }
    }

    func setReason(_ reason: MouseNote.Reason, for turnId: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == turnId.uuidString }) else { return }
        notes[index].reason = reason
        save()
    }

    /// Nothing on AppleVis answered it: a gap worth knowing about.
    func recordNoAnswer(_ turn: MouseTurn) {
        guard notes.first(where: { $0.id == turn.id.uuidString }) == nil else { return }
        upsert(id: turn.id.uuidString) { _ in
            MouseNote(id: turn.id.uuidString, kind: .noAnswer, question: turn.question,
                      answer: turn.savedAnswerText, sources: turn.savedSources.map(\.title), date: Date())
        }
    }

    private func upsert(id: String, _ make: (MouseNote?) -> MouseNote) {
        let existing = notes.first { $0.id == id }
        notes.removeAll { $0.id == id }
        notes.insert(make(existing), at: 0)
        if notes.count > 200 { notes = Array(notes.prefix(200)) }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        try? data.write(to: Self.fileURL, options: [.atomic, .completeFileProtection])
    }

    func notesPackage() -> NotesPackage {
        let pending = unsent
        let notHelpful = pending.filter { $0.kind == .notHelpful }.count
        return NotesPackage(
            title: "Send Mouse Notes",
            subject: SiteText.mouseNotesSubject,
            summary: [
                String(localized: "\(notHelpful) answers you said didn't help"),
                String(localized: "\(pending.count - notHelpful) questions AppleVis couldn't answer"),
                String(localized: "Each with your question and where the Mouse looked"),
            ],
            offersTextChoice: true,
            makeMessage: { includeText in SiteText.mouseNotesMessage(pending, includeText: includeText) },
            markSent: { [weak self] ids in self?.markSent(ids) }
        )
    }

    private func markSent(_ ids: [String]) {
        sentIds.formUnion(ids)
        UserDefaults.standard.set(Array(sentIds), forKey: "mouse.notesSent")
        objectWillChange.send()
    }
}
