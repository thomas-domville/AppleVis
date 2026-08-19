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
    let body: String
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

    var displayName: String { rawValue == "active" ? "Active" : "Fixed" }
    var color: String { rawValue == "active" ? "red" : "green" }
}

nonisolated enum BugSeverity: String, Codable, Sendable {
    case low, medium, high

    var displayName: String { rawValue.capitalized }

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
