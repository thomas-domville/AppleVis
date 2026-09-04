import SwiftUI

/// A searchable list rather than a `Picker`/`.accessibilityAdjustableAction`
/// (the pattern used elsewhere in Settings for short option sets, e.g.
/// Podcast Speed) — a world-language list is too long for VoiceOver
/// swipe-cycling to be a good experience. `.searchable` matches the
/// precedent already used by `SettingsView` itself.
struct ContentLanguagePickerView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var isPreparing = false

    /// The same 22 languages AppleVis's own UI is already localized into —
    /// content translation is scoped to languages this app already has a
    /// real localization investment in, rather than every language Apple's
    /// Translation framework happens to support.
    private static let languageCodes = [
        "es", "fr", "de", "pt", "it", "ja", "ko", "nl", "zh-Hans", "ar", "hi",
        "fa", "ru", "tr", "pl", "sv", "he", "id", "vi", "uk", "el", "th",
    ]

    private struct LanguageOption: Identifiable {
        let code: String
        let name: String
        var id: String { code }
    }

    private var allOptions: [LanguageOption] {
        Self.languageCodes
            .map { LanguageOption(code: $0, name: Locale.current.localizedString(forLanguageCode: $0)?.localizedCapitalized ?? $0) }
            .sorted { $0.name < $1.name }
    }

    private var filteredOptions: [LanguageOption] {
        guard !searchText.isEmpty else { return allOptions }
        return allOptions.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            ForEach(filteredOptions) { option in
                Button {
                    select(option)
                } label: {
                    HStack {
                        Text(option.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if preferences.contentLanguageCode == option.code {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                                .accessibilityHidden(true)
                        }
                        if isPreparing && preferences.contentLanguageCode == option.code {
                            ProgressView()
                        }
                    }
                }
                .accessibilityAddTraits(preferences.contentLanguageCode == option.code ? [.isButton, .isSelected] : .isButton)
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Translation Language")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search Languages")
    }

    private func select(_ option: LanguageOption) {
        preferences.contentLanguageCode = option.code
        SoundPlayer.shared.play(.pickerTick)
        isPreparing = true
        Task {
            await TranslationCoordinator.shared.prepareLanguagePack(for: option.code)
            isPreparing = false
            dismiss()
        }
    }
}
