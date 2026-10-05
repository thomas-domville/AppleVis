import Foundation
import SwiftUI
import UIKit

/// What the website said when it refused something a member posted. Drupal
/// names the field and the problem ("field_ios_version.0.value: iOS
/// Version: may not be longer than 10 characters."), but the app used to
/// keep only the status code and say "AppleVis sent back something
/// unexpected," so neither the member nor we could tell what was wrong.
/// Reported directly (2026-10-05): a tester's app submission kept failing
/// with only that message.
nonisolated struct SiteRefusal: Sendable {
    nonisolated struct Problem: Sendable {
        /// The site's field name, such as `field_ios_version`, when it said.
        let field: String?
        /// The site's own words, in English. Never shown as-is; it goes in
        /// the copied details instead.
        let detail: String

        /// "may not be longer than 10 characters" → 10.
        var lengthLimit: Int? {
            guard let match = detail.range(of: #"longer than (\d+)"#, options: .regularExpression) else { return nil }
            return Int(detail[match].filter(\.isNumber))
        }
    }

    let statusCode: Int
    let problems: [Problem]
    /// Set when the refusal came from Cloudflare's firewall in front of the
    /// site rather than from the site itself.
    let fromFirewall: Bool

    static func parse(statusCode: Int, data: Data) -> SiteRefusal {
        let text = String(decoding: data.prefix(4000), as: UTF8.self)
        let firewall = text.localizedCaseInsensitiveContains("cloudflare")
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return SiteRefusal(statusCode: statusCode, problems: [], fromFirewall: firewall)
        }
        var problems: [Problem] = []
        for error in (json["errors"] as? [[String: Any]]) ?? [] {
            let detail = (error["detail"] as? String) ?? (error["title"] as? String) ?? ""
            let pointer = ((error["source"] as? [String: Any])?["pointer"] as? String) ?? ""
            problems.append(Problem(field: fieldName(pointer: pointer, detail: detail), detail: detail))
        }
        if problems.isEmpty, let message = json["message"] as? String, !message.isEmpty {
            problems.append(Problem(field: fieldName(pointer: "", detail: message), detail: message))
        }
        return SiteRefusal(statusCode: statusCode, problems: problems, fromFirewall: false)
    }

    /// "/data/attributes/field_ios_version/0/value", or a detail starting
    /// "field_ios_version.0.value: …".
    private static func fieldName(pointer: String, detail: String) -> String? {
        let parts = pointer.split(separator: "/").map(String.init)
        if let i = parts.firstIndex(where: { $0 == "attributes" || $0 == "relationships" }), i + 1 < parts.count {
            return parts[i + 1]
        }
        if let match = detail.range(of: #"^[a-z_0-9]+(?=[.:])"#, options: .regularExpression) {
            return String(detail[match])
        }
        return nil
    }

    /// The field as a member would know it, for the middle of a sentence.
    private static func friendlyName(_ field: String) -> String? {
        switch field {
        case "title": return String(localized: "the title")
        case "body": return String(localized: "the main text")
        case "comment_body": return String(localized: "your comment")
        case "subject": return String(localized: "the subject")
        case "field_comments": return String(localized: "your accessibility comments")
        case "field_other_comments": return String(localized: "your additional comments")
        case "field_version": return String(localized: "the app version")
        case "field_ios_version": return String(localized: "the iOS version")
        case "field_watchos_version": return String(localized: "the watchOS version")
        case "field_osx_version": return String(localized: "the macOS version")
        case "field_link2": return String(localized: "the App Store link")
        case "field_link3": return String(localized: "the developer's website")
        case "field_link_macupdate": return String(localized: "the MacUpdate link")
        case "field_cost": return String(localized: "the price")
        case "field_device_used": return String(localized: "the devices")
        case "field_voiceover": return String(localized: "the VoiceOver rating")
        case "field_labelling": return String(localized: "the button labelling rating")
        case "field_usability", "field_usability_tv", "field_usability_watch": return String(localized: "the usability rating")
        case "taxonomy_vocabulary_1", "taxonomy_vocabulary_16", "field_category_tv", "field_category_watch":
            return String(localized: "the category")
        case "taxonomy_forums": return String(localized: "the forum")
        default: return nil
        }
    }

    var userMessage: String {
        if fromFirewall {
            return String(localized: "AppleVis's security check stopped this before it reached the site. It's not something you did. Try again in a few minutes, and if it keeps happening, copy the details and send them to us.")
        }
        let problem = problems.first { $0.field.flatMap(Self.friendlyName) != nil }
        if let problem, let name = problem.field.flatMap(Self.friendlyName) {
            if let limit = problem.lengthLimit {
                return String(localized: "AppleVis couldn't accept \(name). It can be up to \(limit) characters, so shorten it a little and try again.")
            }
            return String(localized: "AppleVis couldn't accept \(name). Check it and try again. If it still won't go, copy the details and send them to us.")
        }
        return String(localized: "AppleVis couldn't accept this, and everything you wrote is still here. Check what you entered and try again. If it still won't go, copy the details and send them to us.")
    }
}

/// One failed post, kept so a member can copy a short report for us. Holds
/// only what went wrong: never the text they wrote, their name, or any
/// sign-in token.
nonisolated struct PostingProblem: Sendable {
    let date: Date
    let method: String
    let path: String
    let statusCode: Int?
    let errorKind: String
    let siteSaid: [String]

    /// In English, for the AppleVis team; built in DiagnosticInfo.
    @MainActor var report: String { DiagnosticInfo.postingProblemReport(self) }
}

/// The most recent failed post, for the Copy Details button and Contact.
@MainActor
final class PostingProblemLog: ObservableObject {
    static let shared = PostingProblemLog()
    @Published private(set) var latest: PostingProblem?

    func record(_ problem: PostingProblem) {
        latest = problem
        AppLog.network.error("Post refused: \(problem.method, privacy: .public) \(problem.path, privacy: .public) \(problem.statusCode ?? 0) \(problem.siteSaid.joined(separator: " | "), privacy: .public)")
    }

    /// Recent enough that it's the problem on screen right now.
    var current: PostingProblem? {
        guard let latest, Date().timeIntervalSince(latest.date) < 180 else { return nil }
        return latest
    }

    /// Recent enough to offer when the member writes to us about it.
    var forContact: PostingProblem? {
        guard let latest, Date().timeIntervalSince(latest.date) < 86_400 else { return nil }
        return latest
    }
}

/// Shown under a posting error: copies the short report so a member can
/// paste it to us. Only appears when a post has just failed.
struct PostingProblemDetailsButton: View {
    @ObservedObject private var log = PostingProblemLog.shared
    @State private var copied = false

    var body: some View {
        if let problem = log.current {
            Button {
                UIPasteboard.general.string = problem.report
                copied = true
                UIAccessibility.post(
                    notification: .announcement,
                    argument: String(localized: "Details copied. Paste them into the Contact form or an email to AppleVis.")
                )
            } label: {
                if copied {
                    Label("Details Copied", systemImage: "checkmark")
                } else {
                    Label("Copy Details for AppleVis", systemImage: "doc.on.doc")
                }
            }
            .font(.subheadline)
            .accessibilityHint(String(localized: "Copies a short note of what went wrong, without anything you wrote, to send to AppleVis."))
        }
    }
}

/// A posting error on a compose screen: shown in red, played and read out
/// by VoiceOver the moment it appears (these screens used to show it
/// silently, so a VoiceOver user heard nothing after tapping Post), with
/// Copy Details underneath when the site turned the post down.
struct PostingErrorMessage: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "exclamationmark.circle")
                .foregroundStyle(.red)
            PostingProblemDetailsButton()
        }
        .task(id: message) {
            SoundPlayer.shared.play(.error)
            try? await Task.sleep(for: .milliseconds(300))
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}
