import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore

    var body: some View {
        Form {
            Section {
                Text("Theme and colour scheme changes apply instantly throughout the app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(ThemeGroup.allCases) { group in
                Section(group.label) {
                    ForEach(AppTheme.allCases.filter { $0.group == group }) { theme in
                        Button {
                            preferences.theme = theme
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(theme.displayName)
                                        .foregroundStyle(.primary)
                                    Text(theme.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if preferences.theme == theme {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .accessibilityAddTraits(preferences.theme == theme ? [.isSelected] : [])
                    }
                }
            }

            Section("Card Density") {
                Picker("Card Density", selection: $preferences.cardDensity) {
                    ForEach(CardDensity.allCases) { density in
                        Text(density.displayName).tag(density)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityHint(String(localized: "Compact reduces spacing between items in lists."))
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Low Vision Tip", systemImage: "eye")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("For maximum readability, choose Dark or Light themes with your preferred iOS contrast settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }

            Section {
                ResetToDefaultsButton {
                    preferences.theme = .system
                    preferences.cardDensity = .comfortable
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}
