import Foundation

/// One Mac app from Homebrew's catalogue: its name, a one-line summary, the
/// latest version, and the developer's website.
nonisolated struct HomebrewApp: Codable, Hashable, Identifiable, Sendable {
    let token: String
    let name: String
    let summary: String
    let homepage: String
    let version: String
    var id: String { token }
}

/// Homebrew's public list of Mac apps (formulae.brew.sh), for Submit an App
/// when a Mac app isn't in the Mac App Store. Many aren't (VLC, Farrago,
/// DEVONthink), and their name, version, and developer's website had to be
/// typed by hand. Homebrew publishes this list for other apps and tools to
/// use. It's about 2 MB to download, so it's fetched the first time someone
/// searches for a Mac app, slimmed to the few fields used, kept on this
/// device for a week, and searched here. Requested directly (2026-10-09).
actor HomebrewCatalog {
    static let shared = HomebrewCatalog()

    private static let source = URL(string: "https://formulae.brew.sh/api/cask.json")!
    private static let keepFor: TimeInterval = 7 * 24 * 60 * 60
    private var apps: [HomebrewApp]?

    private static var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("homebrew-mac-apps.json")
    }

    /// Up to `limit` apps whose name matches, closest first: the exact
    /// name, then names that start with it, then names that contain it.
    func search(_ query: String, limit: Int = 8) async -> [HomebrewApp] {
        let wanted = Self.simplified(query)
        guard wanted.count >= 2 else { return [] }
        let all = await load()
        var scored: [(score: Int, app: HomebrewApp)] = []
        for app in all {
            let name = Self.simplified(app.name)
            let token = Self.simplified(app.token)
            let score: Int
            if name == wanted || token == wanted { score = 3 }
            else if name.hasPrefix(wanted) || token.hasPrefix(wanted) { score = 2 }
            else if name.contains(wanted) { score = 1 }
            else { continue }
            scored.append((score, app))
        }
        return scored
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.app.name.count < $1.app.name.count }
            .prefix(limit)
            .map(\.app)
    }

    private func load() async -> [HomebrewApp] {
        if let apps { return apps }
        let url = Self.cacheURL
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let modified = attributes[.modificationDate] as? Date,
           Date().timeIntervalSince(modified) < Self.keepFor,
           let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode([HomebrewApp].self, from: data) {
            apps = saved
            return saved
        }
        guard let (data, response) = try? await URLSession.shared.data(from: Self.source),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let raw = try? JSONDecoder().decode([RawCask].self, from: data) else {
            // Offline or unavailable: an older copy is better than none.
            if let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode([HomebrewApp].self, from: data) {
                apps = saved
                return saved
            }
            return []
        }
        let slim = raw.compactMap { cask -> HomebrewApp? in
            guard cask.disabled != true, let name = cask.name?.first, !name.isEmpty else { return nil }
            // "latest" isn't a version, and "1.2,345" adds a build number.
            let version = (cask.version ?? "").split(separator: ",").first.map(String.init) ?? ""
            return HomebrewApp(token: cask.token, name: name, summary: cask.desc ?? "",
                               homepage: cask.homepage ?? "", version: version == "latest" ? "" : version)
        }
        apps = slim
        if let encoded = try? JSONEncoder().encode(slim) {
            try? encoded.write(to: url, options: .atomic)
        }
        return slim
    }

    /// Lowercased letters and digits only, so "Audio Hijack" matches
    /// "audio-hijack" and "audiohijack".
    private static func simplified(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// Only the fields used; the rest of each entry is ignored.
    private nonisolated struct RawCask: Decodable, Sendable {
        let token: String
        let name: [String]?
        let desc: String?
        let homepage: String?
        let version: String?
        let disabled: Bool?
    }
}
