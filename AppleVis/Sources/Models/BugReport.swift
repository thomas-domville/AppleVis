import Foundation

nonisolated struct BugReport: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let platform: BugPlatform
    let status: BugStatus
    let severity: BugSeverity
    let firstSeen: String?
    let fixedIn: String?
    let feedbackId: String?
    let commentCount: Int
    let createdAt: Date
    let changedAt: Date
    let summary: String
    let url: String
}

nonisolated struct BugReportDetail: Identifiable, Codable, Sendable {
    let id: String
    /// Drupal's internal integer node ID — needed to call History's
    /// `/history/{nid}/read`, distinct from `id` (the JSON:API UUID).
    let nid: Int
    let title: String
    let platform: BugPlatform
    let status: BugStatus
    let severity: BugSeverity
    let firstSeen: String?
    let fixedIn: String?
    let feedbackId: String?
    /// The submitter's user UUID — lets the detail screen offer the
    /// original reporter Edit/Delete on their own report, the same way a
    /// forum topic's author can. Previously never parsed at all; bug
    /// reports had no owner-level moderation, admin or otherwise. Reported
    /// directly.
    let authorId: String
    let body: String
    /// See `ForumTopicDetail.rawBody`/`bodyFormat`'s doc comment.
    var rawBody: String = ""
    var bodyFormat: String = drupalDefaultTextFormat
    let stepsToReproduce: String?
    let workaround: String?
    let device: String?
    let howOften: String?
    let commentCount: Int
    let createdAt: Date
    let changedAt: Date
    let url: String
    var comments: [BugComment]
}

nonisolated struct BugComment: Identifiable, Codable, Sendable {
    let id: String
    let authorName: String
    let authorId: String
    let subject: String
    let body: String
    var rawBody: String = ""
    var bodyFormat: String = drupalDefaultTextFormat
    let createdAt: Date
}

nonisolated enum BugPlatform: String, Codable, CaseIterable, Identifiable, Sendable {
    case ios
    case macos

    var id: String { rawValue }
    var displayName: String { rawValue == "ios" ? "iOS" : "macOS" }
}

nonisolated enum BugStatus: String, Codable, Sendable {
    case active
    case fixed

    var displayName: String { self == .active ? String(localized: "Active") : String(localized: "Fixed") }
    var color: String { rawValue == "active" ? "red" : "green" }
}

nonisolated enum BugSeverity: String, Codable, Sendable {
    case low, medium, high

    /// Was `rawValue.capitalized` — English in every language.
    var displayName: String {
        switch self {
        case .low: return String(localized: "Low")
        case .medium: return String(localized: "Medium")
        case .high: return String(localized: "High")
        }
    }

    // BUGS-06: severity previously had no visual distinction at all beyond
    // its plain text label — sighted/low-vision users scanning a bug list
    // had no non-text cue to pick out high-severity reports at a glance.
    // Icon is additive alongside the existing text label, not a
    // replacement for it, so nothing regresses for VoiceOver users (who
    // already get the label via `displayName`). Color is resolved by
    // callers from `ThemeColors.warning`/`.error`/`.success` (CARD-07) so
    // it stays theme-consistent rather than a fixed system color.
    var iconName: String {
        switch self {
        case .low: return "arrow.down.circle.fill"
        case .medium: return "equal.circle.fill"
        case .high: return "exclamationmark.triangle.fill"
        }
    }
}
