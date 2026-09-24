import Foundation

/// One app in Discover → Community Picks: an App Directory entry plus how
/// often, and how recently, members have recommended it. Grouped per app by
/// the server, so an app recommended three times this week appears once with
/// a count of 3 instead of three separate rows (the website's own
/// "Latest Community App Recommendations" page lists every recommendation
/// separately, which is noisy with VoiceOver).
nonisolated struct CommunityPick: Identifiable, Hashable, Codable, Sendable {
    let app: AppListing
    /// Recommendations inside the chosen period (equal to `totalCount` for All Time).
    let periodCount: Int
    /// All-time recommendations, whatever period is chosen.
    let totalCount: Int
    let lastRecommendedAt: Date?

    var id: String { app.id }
}

/// Latest sorts by the most recent recommendation; Most Recommended sorts by
/// count. Both are grouped per app.
nonisolated enum CommunityPicksSort: String, CaseIterable, Identifiable, Codable, Sendable {
    case latest
    case most

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .latest: return String(localized: "Latest")
        case .most:   return String(localized: "Most Recommended")
        }
    }

    /// Latest is about what's new, so a short window; Most Recommended is
    /// about long-time favorites, so all time.
    var defaultPeriod: CommunityPicksPeriod {
        switch self {
        case .latest: return .threeMonths
        case .most:   return .allTime
        }
    }
}

nonisolated enum CommunityPicksPeriod: String, CaseIterable, Identifiable, Codable, Sendable {
    case month
    case threeMonths
    case sixMonths
    case year
    case allTime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .month:       return String(localized: "Past Month")
        case .threeMonths: return String(localized: "Past 3 Months")
        case .sixMonths:   return String(localized: "Past 6 Months")
        case .year:        return String(localized: "Past Year")
        case .allTime:     return String(localized: "All Time")
        }
    }

    /// Start of the window, or nil for All Time. Rounded down to the start
    /// of the day so repeated loads on the same day ask for the same range.
    func since(now: Date = .now, calendar: Calendar = .current) -> Date? {
        let months: Int
        switch self {
        case .month:       months = 1
        case .threeMonths: months = 3
        case .sixMonths:   months = 6
        case .year:        months = 12
        case .allTime:     return nil
        }
        guard let date = calendar.date(byAdding: .month, value: -months, to: now) else { return nil }
        return calendar.startOfDay(for: date)
    }

    /// "12 recommendations in the past 3 months" — one whole key per period
    /// so every language can word and pluralize it naturally.
    func countPhrase(_ count: Int) -> String {
        switch self {
        case .month:       return String(localized: "\(count) recommendations in the past month")
        case .threeMonths: return String(localized: "\(count) recommendations in the past 3 months")
        case .sixMonths:   return String(localized: "\(count) recommendations in the past 6 months")
        case .year:        return String(localized: "\(count) recommendations in the past year")
        case .allTime:     return String(localized: "\(count) recommendations")
        }
    }
}

extension AppPlatform {
    /// Drupal bundle machine names, as used by the website's own
    /// recommendations listing's `type` filter.
    nonisolated var drupalBundle: String {
        switch self {
        case .ios:     return "ios_app_directory"
        case .macos:   return "mac_app_directory"
        case .watchos: return "watch_directory"
        case .tvos:    return "tv_directory"
        }
    }

    nonisolated init?(drupalBundle: String) {
        let bundle = drupalBundle.replacingOccurrences(of: "node--", with: "")
        guard let match = AppPlatform.allCases.first(where: { $0.drupalBundle == bundle }) else { return nil }
        self = match
    }
}
