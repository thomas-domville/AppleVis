import Foundation

struct AppListing: Identifiable, Codable, Hashable {
    let id: String
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

struct AppDetail: Identifiable, Codable {
    let id: String
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
}

struct AppReview: Identifiable, Codable {
    let id: String
    let subject: String
    let authorName: String
    let authorId: String
    let rating: Int?
    let body: String
    let createdAt: Date
}

struct AppCategory: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let slug: String
    let tid: Int
    let count: Int
}

enum AppPlatform: String, Codable, CaseIterable, Identifiable {
    case ios
    case macos
    case watchos
    case tvos

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ios:    return "iOS"
        case .macos:  return "macOS"
        case .watchos: return "watchOS"
        case .tvos:   return "tvOS"
        }
    }
}
