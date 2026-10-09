import Foundation

/// One App Store category or type, from Apple's own list.
nonisolated struct AppGenre: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    var subgenres: [AppGenre] = []
}

/// Apple's App Store categories and the types some of them have, such as
/// Games (Board, Card, Dice…) and Stickers. The AppleVis website only stores
/// the main category, so the app works out each app's types from the App
/// Store itself: for the one-line Category on an entry, the Type picker in
/// the App Directory, and Ask the Mouse. Everything here comes from Apple,
/// so a category that gains types later gets them too. Requested directly
/// (2026-10-09); the website may store types itself one day.
@MainActor
final class AppGenres {
    static let shared = AppGenres()

    /// Apple's list for the iPhone and iPad App Store (36) or the Mac App
    /// Store (39).
    private static func rootId(_ platform: AppPlatform) -> String { platform == .macos ? "39" : "36" }
    private static let keepTreeFor: TimeInterval = 30 * 24 * 60 * 60
    private static let keepIndexFor: TimeInterval = 7 * 24 * 60 * 60

    private var trees: [String: [AppGenre]] = [:]

    // MARK: Apple's list of categories and types

    /// The main categories, with their types, named in the person's language
    /// when Apple has a store that uses it.
    func categories(for platform: AppPlatform) async -> [AppGenre] {
        await tree(root: Self.rootId(platform), country: Self.displayCountry)
    }

    /// The types under one AppleVis category, such as Games. Matched to
    /// Apple's English names, then shown in the person's language. Empty
    /// for a category without types.
    func types(forCategory categoryName: String, platform: AppPlatform) async -> [AppGenre] {
        let english = await tree(root: Self.rootId(platform), country: "us")
        let wanted = Self.simplified(categoryName)
        guard let match = english.first(where: { Self.simplified($0.name) == wanted }), !match.subgenres.isEmpty else { return [] }
        let local = await categories(for: platform).first { $0.id == match.id }
        let names = Dictionary((local?.subgenres ?? []).map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        return match.subgenres
            .map { AppGenre(id: $0.id, name: names[$0.id] ?? $0.name) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// One line for an entry: "Games (Board, Family), also Social
    /// Networking". The types under the main category go in brackets, and
    /// any other category the app is in comes after "also". Nil when
    /// there's nothing beyond the main category.
    func categoryLine(primaryId: String?, genreIds: [String], platform: AppPlatform) async -> String? {
        let tops = await categories(for: platform)
        guard !tops.isEmpty, !genreIds.isEmpty else { return nil }
        let primary = tops.first { $0.id == (primaryId ?? genreIds.first) }
        guard let primary else { return nil }
        let typeNames = genreIds.compactMap { id in primary.subgenres.first { $0.id == id }?.name }
        let others = genreIds.compactMap { id in id == primary.id ? nil : tops.first { $0.id == id }?.name }
        guard !typeNames.isEmpty || !others.isEmpty else { return nil }
        var line = primary.name
        if !typeNames.isEmpty {
            line += " (" + ListFormatter.localizedString(byJoining: typeNames) + ")"
        }
        if !others.isEmpty {
            line = String(localized: "\(line), also \(ListFormatter.localizedString(byJoining: others))")
        }
        return line
    }

    // MARK: Ask the Mouse

    /// The Games type a question asks for, from its words: "card games",
    /// "dice", "games for kids" (Family), "an RPG" (Role Playing). Matched
    /// to Apple's English names, so new types work too. Nil when no type
    /// is named.
    func gameTypeId(for words: [String], platform: AppPlatform) async -> String? {
        let english = await tree(root: Self.rootId(platform), country: "us")
        guard let games = english.first(where: { Self.simplified($0.name) == "games" }) else { return nil }
        let alike: [String: String] = [
            "rpg": "roleplaying", "roleplay": "roleplaying", "role": "roleplaying",
            "kids": "family", "kid": "family", "children": "family", "child": "family",
            "toddler": "family", "toddlers": "family", "babysitting": "family",
            "learning": "educational", "education": "educational", "quiz": "trivia",
            "race": "racing", "driving": "racing", "sport": "sports", "cards": "card",
            "words": "word", "puzzles": "puzzle", "boardgame": "board",
        ]
        for word in words.map({ Self.simplified($0) }) where !word.isEmpty {
            let wanted = alike[word] ?? word
            if let type = games.subgenres.first(where: { Self.simplified($0.name) == wanted }) { return type.id }
        }
        return nil
    }

    /// Apple's id for Games on this platform, or nil before the list loads.
    func gamesId(platform: AppPlatform) async -> String? {
        let english = await tree(root: Self.rootId(platform), country: "us")
        return english.first(where: { Self.simplified($0.name) == "games" })?.id
    }

    /// Apple's English names for an app's types and other categories, for
    /// Apple Intelligence to read: "Games: Board, Family; also Social
    /// Networking".
    func englishSummary(genreIds: [String], platform: AppPlatform) async -> String {
        let tops = await tree(root: Self.rootId(platform), country: "us")
        guard let primary = tops.first(where: { $0.id == genreIds.first }) else { return "" }
        let types = genreIds.compactMap { id in primary.subgenres.first { $0.id == id }?.name }
        let others = genreIds.dropFirst().compactMap { id in tops.first { $0.id == id }?.name }
        var text = primary.name
        if !types.isEmpty { text += ": " + types.joined(separator: ", ") }
        if !others.isEmpty { text += "; also " + others.joined(separator: ", ") }
        return text
    }

    // MARK: Which apps in a category are which type

    /// Each app's App Store categories and types, by AppleVis entry id, for
    /// one category. Built from the App Store links on AppleVis and Apple's
    /// lookup (100 apps a request), and kept on this device for a week.
    /// Apps without an App Store link aren't in it.
    func typeIndex(platform: AppPlatform, categoryTid: Int) async -> [String: [String]] {
        guard let (bundle, field) = Self.directory(platform) else { return [:] }
        let file = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("app-types-\(bundle)-\(categoryTid).json")
        if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
           let modified = attributes[.modificationDate] as? Date,
           Date().timeIntervalSince(modified) < Self.keepIndexFor,
           let data = try? Data(contentsOf: file),
           let saved = try? JSONDecoder().decode([String: [String]].self, from: data) {
            return saved
        }

        // The App Store link of every entry in the category, 50 at a time.
        var storeIds: [String: String] = [:]
        var offset = 0
        while offset < 2000 {
            let query = [
                "filter[c][condition][path]": "\(field).drupal_internal__tid",
                "filter[c][condition][value]": "\(categoryTid)",
                "fields[node--\(bundle)]": "field_link2",
                "page[limit]": "50",
                "page[offset]": "\(offset)",
            ]
            guard let page = try? await APIClient.shared.jsonAPIList("node/\(bundle)", query: query) else { break }
            for node in page.data {
                if let link = node.attributes["field_link2"]?["uri"]?.stringValue,
                   let id = ItunesAPI.appStoreId(of: link) {
                    storeIds[node.id] = id
                }
            }
            if !page.hasNextPage { break }
            offset += 50
        }
        guard !storeIds.isEmpty else { return [:] }

        let entity = platform == .macos ? "macSoftware" : "software"
        var genresByStoreId: [String: [String]] = [:]
        let allIds = Array(Set(storeIds.values))
        for start in stride(from: 0, to: allIds.count, by: 100) {
            let chunk = Array(allIds[start..<min(start + 100, allIds.count)])
            let found = await ItunesAPI.batchLookup(appStoreIds: chunk, entity: entity)
            for (id, metadata) in found { genresByStoreId[id] = metadata.genreIds }
        }
        var index: [String: [String]] = [:]
        for (entryId, storeId) in storeIds {
            if let genres = genresByStoreId[storeId] { index[entryId] = genres }
        }
        if !index.isEmpty, let data = try? JSONEncoder().encode(index) {
            try? data.write(to: file, options: .atomic)
        }
        return index
    }

    /// Apple TV entries have no App Store link, so they can't be looked up.
    private static func directory(_ platform: AppPlatform) -> (bundle: String, field: String)? {
        switch platform {
        case .ios:     return ("ios_app_directory", "taxonomy_vocabulary_1")
        case .macos:   return ("mac_app_directory", "taxonomy_vocabulary_16")
        case .watchos: return ("watch_directory", "field_category_watch")
        case .tvos:    return nil
        }
    }

    // MARK: Fetching Apple's list

    private func tree(root: String, country: String) async -> [AppGenre] {
        let key = "\(root)-\(country)"
        if let cached = trees[key] { return cached }
        let file = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("app-genres-\(key).json")
        if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
           let modified = attributes[.modificationDate] as? Date,
           Date().timeIntervalSince(modified) < Self.keepTreeFor,
           let data = try? Data(contentsOf: file),
           let saved = try? JSONDecoder().decode([AppGenre].self, from: data) {
            trees[key] = saved
            return saved
        }
        guard let url = URL(string: "https://itunes.apple.com/WebObjects/MZStoreServices.woa/ws/genres?id=\(root)&cc=\(country)"),
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rootNode = json[root] as? [String: Any] else {
            // An older copy is better than none.
            if let data = try? Data(contentsOf: file), let saved = try? JSONDecoder().decode([AppGenre].self, from: data) {
                trees[key] = saved
                return saved
            }
            return []
        }
        let tops = Self.children(of: rootNode)
        trees[key] = tops
        if let encoded = try? JSONEncoder().encode(tops) { try? encoded.write(to: file, options: .atomic) }
        return tops
    }

    private static func children(of node: [String: Any]) -> [AppGenre] {
        guard let subs = node["subgenres"] as? [String: Any] else { return [] }
        return subs.values.compactMap { value -> AppGenre? in
            guard let sub = value as? [String: Any], let name = sub["name"] as? String else { return nil }
            let id = (sub["id"] as? String) ?? ""
            // German names carry invisible soft hyphens.
            let clean = name.replacingOccurrences(of: "\u{00AD}", with: "")
            return AppGenre(id: id, name: clean, subgenres: children(of: sub))
        }
    }

    /// An App Store country whose store uses the person's language, so
    /// Apple's names come back in it. English otherwise.
    private static var displayCountry: String {
        let language = Locale.preferredLanguages.first.map { Locale(identifier: $0).language.languageCode?.identifier ?? "en" } ?? "en"
        let script = Locale.preferredLanguages.first.flatMap { Locale(identifier: $0).language.script?.identifier }
        let map: [String: String] = [
            "es": "es", "fr": "fr", "de": "de", "pt": "pt", "it": "it", "ja": "jp", "ko": "kr",
            "nl": "nl", "ar": "sa", "ru": "ru", "tr": "tr", "pl": "pl", "sv": "se", "he": "il",
            "id": "id", "vi": "vn", "uk": "ua", "el": "gr", "th": "th", "hi": "in",
        ]
        if language == "zh" { return script == "Hant" ? "tw" : "cn" }
        return map[language] ?? "us"
    }

    /// "Food & Drink" and "Food and Drink" are the same category.
    private static func simplified(_ name: String) -> String {
        name.lowercased().replacingOccurrences(of: "&", with: "and").filter { $0.isLetter || $0.isNumber }
    }
}
