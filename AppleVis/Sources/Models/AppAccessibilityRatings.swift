import Foundation

/// The App Directory's fixed accessibility-rating vocabularies — verified
/// directly against the live submission forms (`/node/add/ios_app_directory`,
/// `/node/add/tv_directory`), not assumed. Shared between `SubmitAppView`
/// (what a submitter can pick) and `AppDetailView`'s `RatingGaugeView` (how
/// an already-submitted value is displayed), so the two can't drift apart
/// the way they did before: the gauge assumed every rating was one of
/// "Excellent"/"Good"/"Fair"/"Poor" — a vocabulary that doesn't match a
/// single real value either content type actually stores, so every real
/// rating silently fell back to plain, ungauged text. Reported directly.
enum AppAccessibilityRatings {
    /// (submitted value, displayed label) — the two differ only for the
    /// shared "Not applicable" option, matching a real inconsistency in
    /// Drupal's own HTML: the stored value has no trailing period, the
    /// displayed text does. Ordered best (index 0) to worst.
    static let voiceOverPerformance: [(value: String, label: String)] = [
        ("VoiceOver reads all page elements.", "VoiceOver reads all page elements."),
        ("VoiceOver reads most page elements.", "VoiceOver reads most page elements."),
        ("VoiceOver reads a few page elements.", "VoiceOver reads a few page elements."),
        ("VoiceOver reads no page elements.", "VoiceOver reads no page elements."),
    ]
    static let buttonLabelling: [(value: String, label: String)] = [
        ("All buttons are clearly labeled.", "All buttons are clearly labeled."),
        ("Most buttons are clearly labeled.", "Most buttons are clearly labeled."),
        ("Few buttons are clearly labeled.", "Few buttons are clearly labeled."),
        ("No buttons are clearly labeled.", "No buttons are clearly labeled."),
    ]
    static let notApplicableValue = String(localized: "Not applicable for this app")
    static let notApplicableLabel = "Not applicable for this app."

    /// iOS/macOS's real 8-option Usability scale — ordered best to worst.
    static let usabilityIOS = [
        "The app is fully accessible with VoiceOver and is easy to navigate and use.",
        "The app is fully accessible with VoiceOver, but the interface could be easier to navigate and use.",
        "The app is fully accessible with VoiceOver, but the interface makes the app very difficult to use.",
        "The app is fully accessible without the use of VoiceOver",
        "There are some minor accessibility issues with this app, but they are easy to deal with.",
        "There are some accessibility issues with this app, but it can still be used if you are willing to tolerate these issues and learn how to work around them.",
        "Some parts of the app are accessible with VoiceOver, but not enough to make it usable.",
        "The app is totally inaccessible.",
    ]
    /// Apple TV's and Apple Watch's shared 4-option Usability scale — both
    /// content types use this exact same field/vocabulary
    /// (`field_usability_tv`/`field_usability_watch`), confirmed live
    /// against both submission forms. Neither has a split VoiceOver
    /// Performance/Button Labelling question the way iOS does — just this
    /// single field.
    static let usabilitySimpleScale = ["Fully Accessible", "Mostly Accessible", "Partially Accessible", "Inaccessible"]
}
