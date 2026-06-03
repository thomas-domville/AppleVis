import { useState } from 'react';
import { Pressable, Text, View } from 'react-native';
import { router } from 'expo-router';
import { useTheme } from '../../src/contexts/ThemeContext';
import { WizardLayout } from '../../src/components/WizardLayout';
import { THEMES, THEME_GROUPS, ALL_THEME_IDS } from '../../src/theme/themes';
import type { ThemeId } from '../../src/theme/themes';

/** Solid colour swatch showing a theme's key colours. */
function ThemeSwatch({ themeId }: { themeId: ThemeId }) {
  const theme = THEMES[themeId];
  const c = theme.colors;
  return (
    <View style={{ flexDirection: 'row', gap: 3, marginBottom: 8 }}>
      <View style={{ width: 20, height: 20, borderRadius: 10, backgroundColor: c.background, borderWidth: 1, borderColor: c.border }} />
      <View style={{ width: 20, height: 20, borderRadius: 10, backgroundColor: c.card,       borderWidth: 1, borderColor: c.border }} />
      <View style={{ width: 20, height: 20, borderRadius: 10, backgroundColor: c.accent }} />
      <View style={{ width: 20, height: 20, borderRadius: 10, backgroundColor: c.text }} />
    </View>
  );
}

export default function ThemeStep() {
  const { colors, themeId: currentId, setTheme } = useTheme();
  const [selected, setSelected] = useState<ThemeId>(currentId);

  function pick(id: ThemeId) {
    setSelected(id);
    setTheme(id); // live preview — the whole wizard re-themes instantly
  }

  return (
    <WizardLayout
      step={3}
      totalSteps={5}
      title="Choose your theme"
      description="Pick how AppleVis looks. You can change this any time in Settings → Appearance. The app previews your choice as you select it."
      onNext={() => router.push('/onboarding/announcement')}
      nextLabel="Next"
    >
      {THEME_GROUPS.map(({ id: groupId, label: groupLabel }) => {
        const groupThemes = ALL_THEME_IDS.filter((id) => THEMES[id].group === groupId);
        if (groupThemes.length === 0) return null;
        return (
          <View key={groupId} style={{ marginBottom: 20 }}>
            <Text
              accessibilityRole="header"
              style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
                textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 10 }}>
              {groupLabel}
            </Text>

            {groupThemes.map((id) => {
              const theme = THEMES[id];
              const isSelected = selected === id;
              return (
                <Pressable
                  key={id}
                  onPress={() => pick(id)}
                  accessible
                  accessibilityRole="none"
                  accessibilityState={{ selected: isSelected }}
                  accessibilityLabel={theme.name}
                  accessibilityHint={`${theme.description} ${theme.example}`}
                  style={{
                    backgroundColor: colors.card,
                    borderRadius: 14,
                    padding: 14,
                    marginBottom: 8,
                    borderWidth: isSelected ? 2 : 1,
                    borderColor: isSelected ? colors.accent : colors.border,
                  }}
                >
                  <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 12 }}>
                    {/* Colour swatches */}
                    <View style={{ paddingTop: 2 }}>
                      <ThemeSwatch themeId={id} />
                    </View>

                    {/* Text */}
                    <View style={{ flex: 1 }}>
                      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 3 }}>
                        <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text }}>
                          {theme.name}
                        </Text>
                        {isSelected && (
                          <View style={{ backgroundColor: colors.accent, borderRadius: 8,
                            paddingHorizontal: 8, paddingVertical: 2 }}>
                            <Text style={{ color: colors.accentText, fontSize: 11, fontWeight: '700' }}>
                              Selected
                            </Text>
                          </View>
                        )}
                      </View>
                      <Text style={{ fontSize: 14, lineHeight: 20, color: colors.textSecondary }}>
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
    </WizardLayout>
  );
}
