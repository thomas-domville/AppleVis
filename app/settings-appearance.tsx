import { useEffect, useRef } from 'react';
import { AccessibilityInfo, findNodeHandle, Pressable, ScrollView, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { usePreferences } from '../src/contexts/PreferencesContext';
import { THEMES, THEME_GROUPS, ALL_THEME_IDS } from '../src/theme/themes';
import type { ThemeId } from '../src/theme/themes';

function densityLabel(value: 'comfortable' | 'compact'): string {
  return value === 'comfortable' ? 'Comfortable' : 'Compact';
}

function themeModeLabel(themeId: ThemeId): string {
  if (themeId === 'system') return 'Follows iOS appearance';
  if (themeId === 'oppositeToSystem') return 'Opposite of iOS appearance';
  return THEMES[themeId].isDark ? 'Dark theme' : 'Light theme';
}

function groupSummary(groupId: string, count: number): string {
  switch (groupId) {
    case 'accessibility':
      return `${count} high contrast themes for maximum readability`;
    case 'applevis':
      return `${count} AppleVis-inspired themes`;
    case 'standard':
      return `${count} standard light, dark, and system themes`;
    default:
      return `${count} themes`;
  }
}

function ThemePreview({ themeId, selected = false }: { themeId: ThemeId; selected?: boolean }) {
  const c = THEMES[themeId].colors;
  return (
    <View
      style={{
        width: 72,
        height: 54,
        borderRadius: 10,
        backgroundColor: c.background,
        borderWidth: selected ? 2 : 1,
        borderColor: selected ? c.accent : c.border,
        padding: 6,
        justifyContent: 'center',
      }}
      accessibilityElementsHidden
    >
      <View
        style={{
          backgroundColor: c.card,
          borderRadius: 7,
          borderWidth: 1,
          borderColor: c.border,
          padding: 5,
          gap: 4,
        }}
      >
        <View style={{ width: '72%', height: 5, borderRadius: 3, backgroundColor: c.text }} />
        <View style={{ width: '52%', height: 4, borderRadius: 2, backgroundColor: c.textSecondary }} />
        <View style={{ width: 22, height: 7, borderRadius: 4, backgroundColor: c.accent }} />
      </View>
    </View>
  );
}

function DensityPreview({ density, selected, colors }: {
  density: 'comfortable' | 'compact';
  selected: boolean;
  colors: ReturnType<typeof useTheme>['colors'];
}) {
  const pad = density === 'comfortable' ? 8 : 5;
  const gap = density === 'comfortable' ? 5 : 3;
  return (
    <View
      style={{
        width: 64,
        height: 48,
        borderRadius: 10,
        backgroundColor: colors.pill,
        borderWidth: selected ? 2 : 1,
        borderColor: selected ? colors.accent : colors.border,
        padding: pad,
        gap,
      }}
      accessibilityElementsHidden
    >
      {[0, 1].map((item) => (
        <View
          key={item}
          style={{
            flex: 1,
            borderRadius: 6,
            backgroundColor: colors.card,
            borderWidth: 1,
            borderColor: colors.border,
          }}
        />
      ))}
    </View>
  );
}

export default function AppearanceSettings() {
  const { colors, styles, themeId, setTheme } = useTheme();
  const { cardDensity, setCardDensity }       = usePreferences();
  const firstHeadingRef = useRef<Text | null>(null);
  const didFocusFirstHeadingRef = useRef(false);
  const currentTheme = THEMES[themeId];
  const appearanceSummary = `Current theme is ${currentTheme.name}. ${themeModeLabel(themeId)}. Card density is ${densityLabel(cardDensity)}. Theme and density changes apply instantly.`;

  useEffect(() => {
    const timers = [350, 700, 1100].map((delay) =>
      setTimeout(() => {
        if (didFocusFirstHeadingRef.current) return;
        const handle = findNodeHandle(firstHeadingRef.current);
        if (handle) {
          didFocusFirstHeadingRef.current = true;
          AccessibilityInfo.setAccessibilityFocus(handle);
        }
      }, delay),
    );

    return () => timers.forEach(clearTimeout);
  }, []);

  return (
    <Screen title="Appearance" showSettings={false}>
      <ScrollView showsVerticalScrollIndicator={false}>
        <View
          style={[styles.card, {
            borderLeftWidth: 4,
            borderLeftColor: colors.accent,
            marginBottom: 14,
          }]}
        >
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
            <ThemePreview themeId={themeId} selected />
            <View style={{ flex: 1 }}>
              <Text
                ref={firstHeadingRef}
                style={styles.cardTitle}
                accessibilityRole="header"
                accessibilityActions={[{ name: 'readAppearanceSummary', label: 'Read Appearance Summary' }]}
                onAccessibilityAction={(event) => {
                  if (event.nativeEvent.actionName === 'readAppearanceSummary') {
                    AccessibilityInfo.announceForAccessibility(`Appearance settings. ${appearanceSummary}`);
                  }
                }}
              >
                Appearance Settings
              </Text>
              <Text style={styles.cardMeta}>
                {currentTheme.name} theme, {densityLabel(cardDensity)} density
              </Text>
              <Text style={[styles.cardMeta, { marginTop: 4 }]}>
                Theme and density changes apply instantly.
              </Text>
            </View>
          </View>
        </View>

        <Text
          style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 8 }}
          accessibilityRole="header"
        >
          Card Density
        </Text>

        {([
          { value: 'comfortable', label: 'Comfortable', description: 'More padding around each card. Easier to read and tap.' },
          { value: 'compact',     label: 'Compact',     description: 'Tighter spacing. More items visible before scrolling.' },
        ] as const).map(({ value, label, description }) => {
          const isSelected = cardDensity === value;
          return (
            <Pressable
              key={value}
              onPress={() => {
                setCardDensity(value);
                AccessibilityInfo.announceForAccessibility(`${label} card density selected.`);
              }}
              accessible
              accessibilityRole="button"
              accessibilityState={{ selected: isSelected }}
              accessibilityLabel={`${label}${isSelected ? ', selected' : ''}. ${description}`}
              style={({ pressed }) => [styles.cardSmall, {
                borderWidth: isSelected ? 2 : 1,
                borderColor: isSelected ? colors.accent : colors.border,
                borderLeftWidth: isSelected ? 5 : 3,
                borderLeftColor: isSelected ? colors.accent : colors.border,
              }, pressed && { opacity: 0.85 }]}
            >
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
                <DensityPreview density={value} selected={isSelected} colors={colors} />
                <View style={{ flex: 1 }}>
                  <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                    <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text }}>{label}</Text>
                    {isSelected && (
                      <View style={{ backgroundColor: colors.accent, borderRadius: 6, paddingHorizontal: 7, paddingVertical: 2 }}>
                        <Text style={{ color: colors.accentText, fontSize: 11, fontWeight: '800' }}>Selected</Text>
                      </View>
                    )}
                  </View>
                  <Text style={[styles.cardMeta, { marginTop: 2 }]}>{description}</Text>
                </View>
                {isSelected && <Ionicons name="checkmark-circle" size={20} color={colors.accent} accessibilityElementsHidden />}
              </View>
            </Pressable>
          );
        })}

        <View
          style={[styles.cardSmall, {
            backgroundColor: colors.pill,
            borderColor: colors.border,
            borderWidth: 1,
            marginTop: 8,
          }]}
          accessible
          accessibilityLabel="Low vision tip. For maximum readability, choose High Contrast Light or High Contrast Dark in the Accessibility theme group."
        >
          <Text style={{ color: colors.pillText, fontSize: 14, lineHeight: 20, fontWeight: '700' }}>
            Low vision tip
          </Text>
          <Text style={[styles.cardMeta, { marginTop: 2 }]}>
            For maximum readability, choose High Contrast Light or High Contrast Dark in the Accessibility group.
          </Text>
        </View>

        {THEME_GROUPS.map(({ id: groupId, label: groupLabel }) => {
          const groupThemes = ALL_THEME_IDS.filter((id) => THEMES[id].group === groupId);
          if (groupThemes.length === 0) return null;
          return (
            <View key={groupId} style={{ marginTop: 22 }}>
              <Text
                style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
                  textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 3 }}
                accessibilityRole="header"
                accessibilityLabel={`${groupLabel}. ${groupSummary(groupId, groupThemes.length)}.`}
              >
                {groupLabel}
              </Text>
              <Text style={[styles.cardMeta, { marginBottom: 10, fontSize: 13 }]}>
                {groupSummary(groupId, groupThemes.length)}
              </Text>

              {groupThemes.map((id) => {
                const theme = THEMES[id];
                const isSelected = themeId === id;
                const modeLabel = themeModeLabel(id);
                return (
                  <Pressable
                    key={id}
                    onPress={() => {
                      setTheme(id);
                      AccessibilityInfo.announceForAccessibility(`${theme.name} theme selected.`);
                    }}
                    accessible
                    accessibilityRole="button"
                    accessibilityState={{ selected: isSelected }}
                    accessibilityLabel={`${theme.name}${isSelected ? ', selected' : ''}. ${modeLabel}. ${theme.description}`}
                    accessibilityHint="Double tap to apply this theme. Use the Actions rotor for a theme example."
                    accessibilityActions={[{ name: 'readThemeExample', label: 'Read Theme Example' }]}
                    onAccessibilityAction={(event) => {
                      if (event.nativeEvent.actionName === 'readThemeExample') {
                        AccessibilityInfo.announceForAccessibility(`${theme.name}. ${theme.example}`);
                      }
                    }}
                    style={({ pressed }) => [styles.cardSmall, {
                      borderWidth: isSelected ? 2 : 1,
                      borderColor: isSelected ? colors.accent : colors.border,
                      borderLeftWidth: isSelected ? 5 : 3,
                      borderLeftColor: isSelected ? colors.accent : colors.border,
                    }, pressed && { opacity: 0.85 }]}
                  >
                    <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 12 }}>
                      <ThemePreview themeId={id} selected={isSelected} />
                      <View style={{ flex: 1 }}>
                        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 2, flexWrap: 'wrap' }}>
                          <Text style={{ fontSize: 16, fontWeight: '800', color: colors.text }}>{theme.name}</Text>
                          {isSelected && (
                            <View style={{ backgroundColor: colors.accent, borderRadius: 6,
                              paddingHorizontal: 7, paddingVertical: 2 }}>
                              <Text style={{ color: colors.accentText, fontSize: 11, fontWeight: '800' }}>Selected</Text>
                            </View>
                          )}
                        </View>
                        <Text style={{ fontSize: 13, fontWeight: '700', color: colors.accent, marginBottom: 3 }}>
                          {modeLabel}
                        </Text>
                        <Text style={{ fontSize: 13, lineHeight: 18, color: colors.textSecondary }}>
                          {theme.description}
                        </Text>
                      </View>
                      {isSelected && <Ionicons name="checkmark-circle" size={20} color={colors.accent} accessibilityElementsHidden />}
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
