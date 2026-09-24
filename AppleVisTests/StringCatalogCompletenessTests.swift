import Testing
import Foundation

/// Guards against translation gaps: every translatable key in the app's string
/// catalogs must have a non-empty translation in all 22 shipped languages, and
/// Siri phrases must keep their `${applicationName}` token or Siri drops them.
///
/// The catalogs are read from the source tree via `#filePath`, so this runs
/// against exactly what is checked in. It catches keys Xcode added during a
/// build that nobody translated. For literals that never reach the catalog at
/// all (the `Text(String)` verbatim trap), run `python tools/l10n_audit.py`.
@Suite("String catalog completeness")
struct StringCatalogCompletenessTests {

    static let languages = [
        "ar", "de", "el", "es", "fa", "fr", "he", "hi", "id", "it", "ja",
        "ko", "nl", "pl", "pt", "ru", "sv", "th", "tr", "uk", "vi", "zh-Hans",
    ]

    static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    static let catalogs = [
        "AppleVis/Sources/Resources/Localizable.xcstrings",
        "AppleVis/Sources/Resources/AppShortcuts.xcstrings",
        "AppleVisShareExtension/Localizable.xcstrings",
    ]

    @Test("every translatable key is translated into every language", arguments: StringCatalogCompletenessTests.catalogs)
    func everyKeyTranslated(catalog: String) throws {
        let strings = try Self.load(catalog)
        var missing: [String] = []

        for (key, entry) in strings {
            if entry["shouldTranslate"] as? Bool == false { continue }
            // Keys with no letters ("%@", "•") need no translation.
            guard key.range(of: "[A-Za-z]{2,}", options: .regularExpression) != nil else { continue }
            let localizations = entry["localizations"] as? [String: Any] ?? [:]
            for language in Self.languages where !Self.hasValue(localizations[language]) {
                missing.append("\(language): \(key.prefix(80))")
            }
        }

        #expect(missing.isEmpty, "\(missing.count) missing translations in \(catalog):\n\(missing.sorted().prefix(40).joined(separator: "\n"))")
    }

    @Test("Siri phrases keep ${applicationName} in every language")
    func siriPhrasesKeepAppName() throws {
        let strings = try Self.load("AppleVis/Sources/Resources/AppShortcuts.xcstrings")
        var broken: [String] = []

        for (key, entry) in strings {
            let localizations = entry["localizations"] as? [String: Any] ?? [:]
            for (language, value) in localizations {
                let unit = (value as? [String: Any])?["stringUnit"] as? [String: Any]
                if let text = unit?["value"] as? String, !text.contains("${applicationName}") {
                    broken.append("\(language): \(key)")
                }
            }
        }

        #expect(broken.isEmpty, "Siri phrases missing ${applicationName}:\n\(broken.sorted().joined(separator: "\n"))")
    }

    // MARK: - Helpers

    static func load(_ relativePath: String) throws -> [String: [String: Any]] {
        let data = try Data(contentsOf: repoRoot.appendingPathComponent(relativePath))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try #require(json["strings"] as? [String: [String: Any]])
    }

    /// A localization counts when it has a non-empty string unit, or plural /
    /// device variations whose every case has one.
    static func hasValue(_ localization: Any?) -> Bool {
        guard let localization = localization as? [String: Any] else { return false }
        if let unit = localization["stringUnit"] as? [String: Any] {
            return !((unit["value"] as? String) ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        }
        if let variations = localization["variations"] as? [String: Any] {
            return variations.values.allSatisfy { kind in
                guard let cases = kind as? [String: Any], !cases.isEmpty else { return false }
                return cases.values.allSatisfy { hasValue($0) }
            }
        }
        return false
    }
}
