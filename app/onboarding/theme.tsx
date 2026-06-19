import { useState } from 'react';
import { PixelRatio, Pressable, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
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

const HC_THEMES: ThemeId[] = ['highContrastLight', 'highContrastDark'];

export default function ThemeStep() {
  const { colors, themeId: currentId, setTheme } = useTheme();
  const [selected, setSelected] = useState<ThemeId>(currentId);
  const largeFontScale = PixelRatio.getFontScale() >= 1.3;

  function pick(id: ThemeId) {
    setSelected(id);
    setTheme(id); // live preview — the whole wizard re-themes instantly
  }

  function renderThemeOption(id: ThemeId) {
    const theme = THEMES[id];
    const isSelected = selected === id;
    return (
      <Pressable
        key={id}
        onPress={() => pick(id)}
        accessible
        accessibilityRole="radio"
        accessibilityState={{ checked: isSelected }}
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
          <View style={{ paddingTop: 2 }}>
            <ThemeSwatch themeId={id} />
          </View>
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
      {/* Accessibility assurance note */}
      <View
        accessible
        accessibilityLabel="iOS accessibility settings like larger text, bold text, and reduced motion are respected automatically. The AppleVis app will never override your system accessibility settings."
        style={{
          flexDirection: 'row', gap: 10, alignItems: 'flex-start',
          backgroundColor: '#EFF6FF', borderRadius: 12, padding: 14,
          borderWidth: 1, borderColor: '#BFDBFE', marginBottom: 20,
        }}
      >
        <Ionicons name="shield-checkmark-outline" size={18} color="#1D4ED8"
          style={{ marginTop: 1 }} accessibilityElementsHidden />
        <Text style={{ flex: 1, fontSize: 14, color: '#1E40AF', lineHeight: 20 }}>
          iOS accessibility settings like larger text, bold text, and reduced motion are respected automatically. The AppleVis app will never override your system accessibility settings.
        </Text>
      </View>

      {largeFontScale && (
        <View style={{ marginBottom: 20 }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 10 }}>
            <Text
              accessibilityRole="header"
              style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
                textTransform: 'uppercase', letterSpacing: 0.8 }}>
              Recommended for your settings
            </Text>
          </View>
          <View style={{ backgroundColor: colors.card, borderRadius: 10, padding: 10,
            borderWidth: 1, borderColor: colors.border, marginBottom: 10 }}>
            <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 18 }}>
              You have large text enabled. These high-contrast themes are easiest to read at larger sizes.
            </Text>
          </View>
          <View accessibilityRole="radiogroup" accessibilityLabel="Recommended themes">
            {HC_THEMES.map(renderThemeOption)}
          </View>
        </View>
      )}

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
            <View accessibilityRole="radiogroup" accessibilityLabel={`${groupLabel} themes`}>
              {groupThemes.map(renderThemeOption)}
            </View>
          </View>
        );
      })}
    </WizardLayout>
  );
}
