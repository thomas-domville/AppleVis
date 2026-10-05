import Foundation

/// Text the app adds to what a member posts on applevis.com. The website is
/// in English, so this stays English whatever language the app is in.
enum SiteText {
    /// Added under an App Store description the app translated, so readers
    /// of the entry know it isn't the developer's own English.
    static func translatedDescriptionNote(languageCode: String) -> String {
        let language = Locale(identifier: "en").localizedString(forLanguageCode: languageCode) ?? "another language"
        return "(Translated automatically from \(language) by the AppleVis app.)"
    }
}
