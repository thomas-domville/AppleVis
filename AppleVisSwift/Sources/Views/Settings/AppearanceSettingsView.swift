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

            Section("Colour Scheme") {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        preferences.theme = theme
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(theme.displayName)
                                    .foregroundStyle(.primary)
                                Text(themeSubtitle(theme))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if preferences.theme == theme {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.accent)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .accessibilityAddTraits(preferences.theme == theme ? [.isSelected] : [])
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
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func themeSubtitle(_ theme: AppTheme) -> String {
        switch theme {
        case .system: return "Follows iOS appearance setting"
        case .light:  return "Always uses light colours"
        case .dark:   return "Always uses dark colours"
        }
    }
}
