import Foundation
import SwiftUI

/// Small icon-only marker for card titles — a compact list row has no room
/// for the fuller "Translated from English · may not be exact" caption that
/// detail screens show (see `TranslationBanner`); the visible cue here is
/// just this icon, with the actual information carried in the accessibility
/// label via `ContentTranslation.accessibilityTitle` instead.
struct TranslatedTitleBadge: View {
    var body: some View {
        Image(systemName: "character.bubble")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }
}

/// Shared resolution logic for card-title translation — called from every
/// row struct's own `.task(id:)` (see `RowViews.swift`, `BugBrowseView`,
/// `ForYouView`, `HomeView`'s Mouse Recap cards). Deliberately a free
/// function rather than an `ObservableObject` wrapper view: the caller's own
/// visible `Text` and its accessibility label both need to read the exact
/// same resolved value, which is only guaranteed by keeping the `@State`
/// directly on the row struct itself rather than splitting it into a
/// separate view with its own private state.
enum ContentTranslation {
    /// `kind` is a plain string (not `ContentKind`) so callers outside that
    /// enum's cases — comments/replies, Help articles — can use this same
    /// cache/resolve path with their own kind labels.
    static func resolvedTitle(kind: String, id: String, originalTitle: String, targetLanguage: String?) async -> String? {
        await resolvedText(kind: kind, id: id, field: "title", originalText: originalTitle, targetLanguage: targetLanguage)
    }

    /// General-purpose version of `resolvedTitle` — same cache-then-translate
    /// path, but for any labeled field, not just "title" (e.g. Help
    /// articles' heading/body/bullet/step/tip/note/warning/faq-question/
    /// faq-answer blocks, each keyed by their own `field` under one
    /// article's `id` so they don't collide with each other in the cache).
    static func resolvedText(kind: String, id: String, field: String, originalText: String, targetLanguage: String?) async -> String? {
        guard let targetLanguage else { return nil }
        let trimmed = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let cached = PersistenceStore.shared.cachedTranslation(
            kind: kind, id: id, field: field, targetLanguage: targetLanguage, sourceText: trimmed
        ) {
            return cached
        }
        guard let translated = await TranslationCoordinator.shared.translate(trimmed, to: targetLanguage) else { return nil }
        PersistenceStore.shared.cacheTranslation(
            kind: kind, id: id, field: field, targetLanguage: targetLanguage, sourceText: trimmed, translatedText: translated
        )
        return translated
    }

    /// `.task(id:)` key for `resolvedText`/`resolvedTitle` callers that need
    /// the `field` folded in too (a screen with several independently
    /// translated pieces of text sharing one `id`, like a Help article's
    /// several blocks) — otherwise two blocks with coincidentally identical
    /// source text would share one `.task` identity and only resolve once.
    static func taskId(field: String, text: String, targetLanguage: String?) -> String {
        "\(targetLanguage ?? "")|\(field)|\(text)"
    }

    /// The `.task(id:)` key every title-translating row should use — changes
    /// (and thus re-triggers resolution) whenever either the source title or
    /// the content-language preference changes.
    static func taskId(title: String, targetLanguage: String?) -> String {
        "\(targetLanguage ?? "")|\(title)"
    }

    /// VoiceOver must never read a different title than what's on screen —
    /// this is the one place both the visible `Text` and every row's
    /// accessibility-label builder should get their title string from.
    static func accessibilityTitle(original: String, translated: String?) -> String {
        guard let translated else { return original }
        return String(localized: "Translated: \(translated)")
    }
}
