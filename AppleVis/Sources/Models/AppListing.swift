import Foundation

nonisolated struct AppListing: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var nid: Int? = nil
    let name: String
    let developer: String
    let platform: AppPlatform
    let category: String
    let categoryId: String
    let reviewCount: Int
    let lastUpdatedAt: Date
    let lastActivityAt: Date
    let createdAt: Date
    let submittedBy: String
    let submitterUid: String
    let appStoreUrl: String?
    let iconUrl: String?
    let price: String
    let supportedDevices: [String]
    let voiceOverPerformance: String?
    let summary: String
    let url: String
    var isSaved: Bool
}

nonisolated struct AppDuplicateCheckResult: Sendable {
    let matches: [AppListing]
    let exactMatches: [AppListing]

    var hasExactMatch: Bool { !exactMatches.isEmpty }
}

nonisolated struct AppDetail: Identifiable, Codable, Sendable {
    let id: String
    /// Drupal's internal integer node ID — needed to call History's
    /// `/history/{nid}/read`, distinct from `id` (the JSON:API UUID).
    let nid: Int
    let name: String
    let developer: String
    let platform: AppPlatform
    let category: String
    let categoryId: String
    let reviewCount: Int
    let lastUpdatedAt: Date
    let createdAt: Date
    let submittedBy: String
    let submitterUid: String
    let appStoreUrl: String?
    let iconUrl: String?
    let price: String
    let supportedDevices: [String]
    let voiceOverPerformance: String?
    let buttonLabelling: String?
    let usabilityNotes: String?
    let body: String
    let reviewedVersion: String?
    let testedOnIOS: String?
    let accessibilityComments: String?
    let url: String
    var reviews: [AppReview]
    var isSaved: Bool
    /// A MacUpdate.com link (`field_link_macupdate`) — only ever populated
    /// for Mac App Directory entries, and only some of those: unlike every
    /// other platform, a real, sizable share of real Mac entries have no
    /// App Store link at all (confirmed live: VMware Fusion, Xcode,
    /// 1Password, and others in AppleVis's own directory), since Mac apps
    /// are commonly distributed outside the Mac App Store entirely.
    /// MacUpdate is AppleVis's own fallback reference for exactly that
    /// case. Defaulted so every other platform's `AppDetail(...)` call
    /// site needs no change. Reported directly.
    var macUpdateUrl: String? = nil
}

nonisolated struct AppReview: Identifiable, Codable, Sendable {
    let id: String
    let subject: String
    let authorName: String
    let authorId: String
    let rating: Int?
    let body: String
    let createdAt: Date
}

nonisolated struct AppCategory: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String
    let tid: Int
    let count: Int
}

nonisolated enum AppPlatform: String, Codable, CaseIterable, Identifiable, Sendable {
    case ios
    case macos
    case watchos
    case tvos

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ios:     return "iPhone and iPad"
        case .macos:   return "Mac"
        case .watchos: return "Apple Watch"
        case .tvos:    return "Apple TV"
        }
    }
}
