import Foundation
import UIKit

/// An Ask the Mouse answer kept in For You > Saved: the question, the
/// answer as it was when saved, and where it came from. A snapshot, so it
/// doesn't change if a guide is updated; the sources still open the current
/// page. Kept on the device and synced with iCloud like other saved items,
/// never sent to AppleVis. Requested directly (2026-09-28).
struct SavedMouseAnswer: Identifiable, Codable, Hashable {
    struct Source: Codable, Hashable {
        enum Kind: String, Codable {
            case help, guide, guideComments, forum, whatsNew, tip, app
        }
        let kind: Kind
        let title: String
        var url: String? = nil
        /// The guide, forum topic, or app entry's id, to open it in the app.
        var contentId: String? = nil
        var helpArticleId: String? = nil

        /// "Help", "Guide", and so on, for the copied and shared text.
        var kindLabel: String {
            switch kind {
            case .help: return String(localized: "Help")
            case .guide: return String(localized: "Guide")
            case .guideComments: return String(localized: "Members' comments on a guide")
            case .forum: return String(localized: "Forum discussion")
            case .whatsNew: return String(localized: "What's New")
            case .tip: return String(localized: "Tip")
            case .app: return String(localized: "App Entry")
            }
        }

        /// The kind of AppleVis content to open, for guides, topics, and apps.
        var contentKind: ContentKind? {
            switch kind {
            case .guide, .guideComments: return .resource
            case .forum: return .forumTopic
            case .app: return .appListing
            default: return nil
            }
        }
    }

    let id: String
    let question: String
    let answer: String
    let sources: [Source]
    let savedAt: Date

    /// Question, answer, and sources as plain text, for Copy and Share.
    var shareText: String {
        MouseAnswerText.full(question: question, answer: answer, sources: sources)
    }
}

/// The text Copy Answer with Sources and Share Answer produce.
enum MouseAnswerText {
    static func full(question: String, answer: String, sources: [SavedMouseAnswer.Source]) -> String {
        var lines = [
            String(localized: "Question: \(question)"),
            String(localized: "Answer: \(answer)"),
        ]
        if !sources.isEmpty {
            lines.append(String(localized: "Sources:"))
            for source in sources {
                let link = source.url.map { " \($0)" } ?? ""
                lines.append("- \(source.kindLabel): \(source.title)\(link)")
            }
        }
        lines.append(String(localized: "From Ask the Mouse in the AppleVis app"))
        return lines.joined(separator: "\n")
    }

    /// The share sheet, over whatever screen is showing, including a sheet.
    @MainActor
    static func presentShareSheet(_ text: String) {
        let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        var top = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
        while let presented = top?.presentedViewController { top = presented }
        top?.present(activity, animated: true)
    }
}
