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
    /// See `ForumTopicDetail.rawBody`/`bodyFormat`'s doc comment.
    var rawBody: String = ""
    var bodyFormat: String = drupalDefaultTextFormat
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

extension AppDetail {
    /// The site's `field_device_used`, as readable names. The website still
    /// labels this "Device(s) App Was Tested On", but the app deliberately
    /// treats it as the devices the app *supports* — pre-filled from the
    /// App Store, trimmed by whoever submits or refreshes the entry — until
    /// the site renames the field to match (decided 2026-09-23). The live
    /// form stores iPad as the literal value "1" and Mac as "mac" (see
    /// SubmitAppView's `deviceOptions`), so raw values can't be shown as-is.
    nonisolated var siteDevices: [String] {
        var result: [String] = []
        for raw in supportedDevices {
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let name: String?
            switch value {
            case "iphone": name = "iPhone"
            case "1", "ipad": name = "iPad"
            case _ where value.contains("mac"): name = "Mac"
            default: name = raw.isEmpty ? nil : raw
            }
            if let name, !result.contains(name) { result.append(name) }
        }
        return result
    }

    /// What Refresh App Details offers for the devices field: the App
    /// Store's iPhone/iPad list, plus Mac if either the App Store lists it
    /// or the entry already has it — the App Store lookup only reports Mac
    /// for Catalyst builds, so an iPhone app that genuinely runs on Apple
    /// silicon Macs would otherwise silently lose Mac on every refresh.
    /// iOS directory entries only (the only platform with this field).
    nonisolated func refreshedDevices(storeFamilies: [String]) -> [String] {
        guard platform == .ios else { return [] }
        return ["iPhone", "iPad", "Mac"].filter {
            storeFamilies.contains($0) || ($0 == "Mac" && siteDevices.contains("Mac"))
        }
    }

    /// The value the live form submits for a device name.
    nonisolated static func siteDeviceValue(for name: String) -> String {
        switch name {
        case "iPad": return "1"
        case "Mac": return "mac"
        default: return name
        }
    }
}

nonisolated struct AppReview: Identifiable, Codable, Sendable {
    let id: String
    let subject: String
    let authorName: String
    let authorId: String
    let rating: Int?
    let body: String
    var rawBody: String = ""
    var bodyFormat: String = drupalDefaultTextFormat
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
