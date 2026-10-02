import Foundation

/// The AppleVis Golden Apple Awards, 2019 to 2025: every Best App and Best
/// Game winner, honorable mention, and nominee, taken from each year's
/// nominees and winners posts on the AppleVis blog on 2026-10-01 and shipped
/// in GoldenApples.json. They're the community's own picks of the year's
/// best accessible apps, so Ask the Mouse ranks them higher and says so.
/// Add each new year's results to the file. Requested directly (2026-10-01).
nonisolated enum GoldenApples {
    struct Entry: Codable, Hashable, Sendable {
        /// "path:/apps/ios/games/slug" (the App Directory entry) or
        /// "id:123456" (the App Store id).
        let key: String
        let name: String
        let year: Int
        /// "Best App" or "Best Game".
        let award: String
        /// "winner", "honorable mention", or "nominee".
        let status: String

        var rank: Int {
            switch status {
            case "winner": return 3
            case "honorable mention": return 2
            default: return 1
            }
        }
    }

    static let entries: [Entry] = {
        guard let url = Bundle.main.url(forResource: "GoldenApples", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return list
    }()

    private static let byKey: [String: [Entry]] = Dictionary(grouping: entries, by: \.key)

    /// The app's best honor: a win over a mention over a nomination, then
    /// the most recent year.
    static func best(for app: AppListing) -> Entry? {
        var keys: [String] = []
        if let path = URL(string: app.url)?.path, path.hasPrefix("/apps/") { keys.append("path:" + path) }
        if let store = app.appStoreUrl, let match = store.firstMatch(of: #/id(\d+)/#) { keys.append("id:" + match.output.1) }
        return keys.flatMap { byKey[$0] ?? [] }
            .max { $0.rank != $1.rank ? $0.rank < $1.rank : $0.year < $1.year }
    }

    /// "Golden Apple winner, Best Game 2024", for the app's row.
    static func line(for entry: Entry) -> String {
        let award = entry.award == "Best Game" ? String(localized: "Best Game") : String(localized: "Best App")
        let year = String(entry.year)
        switch entry.rank {
        case 3: return String(localized: "AppleVis Golden Apple winner, \(award) \(year)")
        case 2: return String(localized: "AppleVis Golden Apple honorable mention, \(award) \(year)")
        default: return String(localized: "AppleVis Golden Apple nominee, \(award) \(year)")
        }
    }
}
