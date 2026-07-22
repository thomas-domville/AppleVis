import Foundation

struct BugReport: Identifiable, Codable, Hashable {
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

struct BugReportDetail: Identifiable, Codable {
    let id: String
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

struct BugComment: Identifiable, Codable {
    let id: String
    let authorName: String
    let body: String
    let createdAt: Date
}

enum BugPlatform: String, Codable, CaseIterable, Identifiable {
    case ios
    case macos

    var id: String { rawValue }
    var displayName: String { rawValue == "ios" ? "iOS" : "macOS" }
}

enum BugStatus: String, Codable {
    case active
    case fixed

    var displayName: String { rawValue == "active" ? "Active" : "Fixed" }
    var color: String { rawValue == "active" ? "red" : "green" }
}

enum BugSeverity: String, Codable {
    case low, medium, high

    var displayName: String { rawValue.capitalized }
}
