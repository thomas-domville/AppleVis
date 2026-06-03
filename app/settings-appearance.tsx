import { Pressable, ScrollView, Text, View } from 'react-native';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { usePreferences } from '../src/contexts/PreferencesContext';
import { THEMES, THEME_GROUPS, ALL_THEME_IDS } from '../src/theme/themes';
import type { ThemeId } from '../src/theme/themes';

function ThemeSwatch({ themeId }: { themeId: ThemeId }) {
  const c = THEMES[themeId].colors;
  return (
    <View style={{ flexDirection: 'row', gap: 3, marginBottom: 6 }}>
      {[c.background, c.card, c.accent, c.text].map((colour, i) => (
        <View key={i} style={{ width: 18, height: 18, borderRadius: 9,
          backgroundColor: colour, borderWidth: 0.5, borderColor: 'rgba(0,0,0,0.1)' }} />
      ))}
    </View>
  );
}

export default function AppearanceSettings() {
  const { colors, styles, themeId, setTheme } = useTheme();
  const { cardDensity, setCardDensity }       = usePreferences();

  return (
    <Screen title="Appearance" showSettings={false}>
      <ScrollView showsVerticalScrollIndicator={false}>
        <Text style={styles.lede}>
          Choose your theme and card density. The app re-themes instantly
          as you select each option.
        </Text>

        {/* Card density */}
        <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
          textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 8 }}
          accessibilityRole="header">Card Density</Text>

        {([
          { value: 'comfortable', label: 'Comfortable', description: 'More padding around each card. Easier to read and tap.' },
          { value: 'compact',     label: 'Compact',     description: 'Tighter spacing. More items visible before scrolling.' },
        ] as const).map(({ value, label, description }) => {
          const isSelected = cardDensity === value;
          return (
            <Pressable
              key={value}
              onPress={() => setCardDensity(value)}
              accessible accessibilityRole="none"
              accessibilityState={{ selected: isSelected }}
              accessibilityLabel={`${label}. ${description}${isSelected ? '. Selected.' : ''}`}
              style={[styles.cardSmall, {
                borderWidth: isSelected ? 2 : 1,
                borderColor: isSelected ? colors.accent : colors.border,
              }]}
            >
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
                <View style={{
                  width: 20, height: 20, borderRadius: 10,
                  borderWidth: 2, borderColor: isSelected ? colors.accent : colors.border,
                  backgroundColor: isSelected ? colors.accent : 'transparent',
                  alignItems: 'center', justifyContent: 'center', flexShrink: 0,
                }}>
                  {isSelected && <View style={{ width: 8, height: 8, borderRadius: 4, backgroundColor: colors.accentText }} />}
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>{label}</Text>
                  <Text style={{ fontSize: 13, color: colors.textSecondary }}>{description}</Text>
                </View>
              </View>
            </Pressable>
          );
        })}

        {/* Theme picker */}
        {THEME_GROUPS.map(({ id: groupId, label: groupLabel }) => {
          const groupThemes = ALL_THEME_IDS.filter((id) => THEMES[id].group === groupId);
          if (groupThemes.length === 0) return null;
          return (
            <View key={groupId} style={{ marginTop: 20 }}>
              <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
                textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 10 }}
                accessibilityRole="header">{groupLabel}</Text>

              {groupThemes.map((id) => {
                const theme = THEMES[id];
                const isSelected = themeId === id;
                return (
                  <Pressable
                    key={id}
                    onPress={() => setTheme(id)}
                    accessible accessibilityRole="none"
                    accessibilityState={{ selected: isSelected }}
                    accessibilityLabel={`${theme.name}${isSelected ? ', selected' : ''}`}
                    accessibilityHint={`${theme.description} ${theme.example}`}
                    style={[styles.cardSmall, {
                      borderWidth: isSelected ? 2 : 1,
                      borderColor: isSelected ? colors.accent : colors.border,
                    }]}
                  >
                    <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 12 }}>
                      <View style={{ paddingTop: 2 }}>
                        <ThemeSwatch themeId={id} />
                      </View>
                      <View style={{ flex: 1 }}>
                        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 2 }}>
                          <Text style={{ fontSize: 15, fontWeight: '700', color: colors.text }}>{theme.name}</Text>
                          {isSelected && (
                            <View style={{ backgroundColor: colors.accent, borderRadius: 6,
                              paddingHorizontal: 6, paddingVertical: 1 }}>
                              <Text style={{ color: colors.accentText, fontSize: 10, fontWeight: '700' }}>Selected</Text>
                            </View>
                          )}
                        </View>
                        <Text style={{ fontSize: 13, lineHeight: 18, color: colors.textSecondary }}>
                          {theme.description}
                        </Text>
                      </View>
                    </View>
                  </Pressable>
                );
              })}
            </View>
          );
        })}

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
