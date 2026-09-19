import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        Form {
            Section {
                Text("Theme and colour scheme changes apply instantly throughout the app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityFocused($isTitleFocused)
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
                Text("Controls how much space each item takes up in lists — Comfortable gives every card room to breathe, Compact tightens the spacing so more fit on screen at once.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("Card Density", selection: $preferences.cardDensity) {
                    ForEach(CardDensity.allCases) { density in
                        Text(density.displayName).tag(density)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityHint(String(localized: "Compact reduces spacing between items in lists."))
                // See GeneralSettingsView's Home Startup Behavior for the
                // full reasoning — a persistent .accessibilityValue() here
                // duplicated what the control already announces natively on
                // plain focus. Swapped for a one-shot announcement fired
                // only right after an adjustment.
                .accessibilityAdjustableAction { direction in
                    guard let idx = CardDensity.allCases.firstIndex(of: preferences.cardDensity) else { return }
                    switch direction {
                    case .increment:
                        preferences.cardDensity = CardDensity.allCases[(idx + 1) % CardDensity.allCases.count]
                    case .decrement:
                        preferences.cardDensity = CardDensity.allCases[(idx - 1 + CardDensity.allCases.count) % CardDensity.allCases.count]
                    @unknown default: break
                    }
                    UIAccessibility.post(notification: .announcement, argument: preferences.cardDensity.displayName)
                }
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
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
    }
}
