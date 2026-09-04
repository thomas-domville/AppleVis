import SwiftUI

/// Reading-side translation: blog posts, forum topics, app entries, podcast
/// episodes, guides, bug reports, comments, and Help articles, translated
/// into the reader's chosen language on-device via Apple's Translation
/// framework. Deliberately its own screen rather than folded into
/// `IntelligenceSettingsView` — that screen's whole framing is "Apple
/// Intelligence, iPhone 15 Pro and later" (see its footnote), and this
/// feature has no such hardware/OS requirement at all.
struct ContentTranslationSettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        Form {
            Section {
                Text("Translation runs entirely on your device using Apple's on-device translation. Nothing you read is sent to an external server.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityFocused($isTitleFocused)
            }

            Section("Auto-Translate") {
                Toggle("Auto-Translate Content", isOn: $preferences.autoTranslateEnabled)
                    .accessibilityHint(String(localized: "Automatically translates blog posts, forum topics, app entries, podcasts, guides, bug reports, comments, and Help articles into your chosen language."))
                Text("AppleVis is written and moderated in English — it's the one shared language that lets everyone in our community read and reply to each other in the same place. Turning this on translates what you read into your own language, right on your device. It's automatic, but never perfect — you can always see the exact English text with Show Original.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                NavigationLink {
                    ContentLanguagePickerView()
                } label: {
                    HStack {
                        Text("Translation Language")
                        Spacer()
                        Text(languageDisplayName)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityHint(String(localized: "Choose which language AppleVis content is translated into."))
            }

            Section {
                Text("This only changes what you read — AppleVis is still written and moderated in English, and posting still requires English, same as always.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                ResetToDefaultsButton {
                    preferences.autoTranslateEnabled = false
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Content Translation")
        .navigationBarTitleDisplayMode(.inline)
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
    }

    private var languageDisplayName: String {
        guard !preferences.contentLanguageCode.isEmpty,
              let name = Locale.current.localizedString(forLanguageCode: preferences.contentLanguageCode)
        else { return String(localized: "Not Set") }
        return name.localizedCapitalized
    }
}
