import { useEffect, useRef } from 'react';
import { AccessibilityInfo, findNodeHandle, Pressable, ScrollView, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { usePreferences } from '../src/contexts/PreferencesContext';
import type { DefaultForumFilter } from '../src/contexts/PreferencesContext';

type HomeFilterOption = {
  value: DefaultForumFilter;
  label: string;
  badge: string;
  icon: string;
  description: string;
  preview: string;
};

const HOME_FILTER_OPTIONS: HomeFilterOption[] = [
  {
    value: 'All',
    label: 'All',
    badge: 'Default',
    icon: 'newspaper-outline',
    description: 'Shows all Home activity from forums, podcasts, apps, guides, blogs, and comments.',
    preview: 'The Home tab opens on Latest Activity.',
  },
  {
    value: 'New',
    label: 'New',
    badge: 'Catch Up',
    icon: 'sparkles-outline',
    description: 'Shows only new activity since your last visit, including new topics, podcasts, apps, guides, blogs, and comments.',
    preview: 'The Home tab opens on New Activity.',
  },
];

function SectionHeader({ label, colors }: {
  label: string;
  colors: ReturnType<typeof useTheme>['colors'];
}) {
  return (
    <Text
      style={{
        fontSize: 13,
        fontWeight: '700',
        color: colors.textSecondary,
        textTransform: 'uppercase',
        letterSpacing: 0.8,
        marginTop: 18,
        marginBottom: 8,
      }}
      accessibilityRole="header"
    >
      {label}
    </Text>
  );
}

export default function ForumSettings() {
  const { colors, styles } = useTheme();
  const { defaultForumFilter, setDefaultForumFilter } = usePreferences();
  const firstHeadingRef = useRef<Text | null>(null);
  const didFocusFirstHeadingRef = useRef(false);
  const selected = HOME_FILTER_OPTIONS.find((option) => option.value === defaultForumFilter) ?? HOME_FILTER_OPTIONS[0];
  const summary = `Home opens with the ${selected.label} filter. ${selected.description}`;

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
    <Screen title="Forums" showSettings={false}>
      <ScrollView showsVerticalScrollIndicator={false}>
        <View
          style={[styles.card, {
            borderLeftWidth: 4,
            borderLeftColor: colors.accent,
            marginBottom: 14,
          }]}
        >
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
            <View
              style={{
                width: 48,
                height: 48,
                borderRadius: 13,
                backgroundColor: colors.pill,
                alignItems: 'center',
                justifyContent: 'center',
              }}
              accessibilityElementsHidden
            >
              <Ionicons name="chatbubbles-outline" size={25} color={colors.accent} />
            </View>
            <View style={{ flex: 1 }}>
              <Text
                ref={firstHeadingRef}
                style={styles.cardTitle}
                accessibilityRole="header"
                accessibilityActions={[{ name: 'readHomeFeedSummary', label: 'Read Home Feed Summary' }]}
                onAccessibilityAction={(event) => {
                  if (event.nativeEvent.actionName === 'readHomeFeedSummary') {
                    AccessibilityInfo.announceForAccessibility(`Home feed default. ${summary}`);
                  }
                }}
              >
                Home Feed Defaults
              </Text>
              <Text style={styles.cardMeta}>
                Current default: {selected.label}
              </Text>
              <Text style={[styles.cardMeta, { marginTop: 4 }]}>
                This matches the Home tab filter picker: All or New.
              </Text>
            </View>
          </View>
        </View>

        <View
          style={[styles.cardSmall, {
            backgroundColor: colors.pill,
            borderColor: colors.border,
            borderWidth: 1,
          }]}
          accessible
          accessibilityLabel="This setting affects the Home tab, not the Discover Forums page. The old Forum filters have moved into the Home feed experience."
        >
          <Text style={{ color: colors.pillText, fontSize: 14, lineHeight: 20, fontWeight: '800' }}>
            Note
          </Text>
          <Text style={[styles.cardMeta, { marginTop: 2 }]}>
            This setting now controls the Home tab default filter. The current Home picker options are All and New.
          </Text>
        </View>

        <SectionHeader label="Default Home Filter" colors={colors} />
        {HOME_FILTER_OPTIONS.map((option) => {
          const isSelected = defaultForumFilter === option.value;
          return (
            <Pressable
              key={option.value}
              onPress={() => {
                setDefaultForumFilter(option.value);
                AccessibilityInfo.announceForAccessibility(`${option.label} Home filter selected.`);
              }}
              accessible
              accessibilityRole="button"
              accessibilityState={{ selected: isSelected }}
              accessibilityLabel={`${option.label}${isSelected ? ', selected' : ''}. ${option.badge}. ${option.description}`}
              accessibilityHint="Double tap to make this the default Home tab filter."
              style={({ pressed }) => [styles.cardSmall, {
                borderWidth: isSelected ? 2 : 1,
                borderColor: isSelected ? colors.accent : colors.border,
                borderLeftWidth: isSelected ? 5 : 3,
                borderLeftColor: isSelected ? colors.accent : colors.border,
              }, pressed && { opacity: 0.85 }]}
            >
              <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 12 }}>
                <View
                  style={{
                    width: 40,
                    height: 40,
                    borderRadius: 10,
                    backgroundColor: isSelected ? colors.accent : colors.pill,
                    alignItems: 'center',
                    justifyContent: 'center',
                    flexShrink: 0,
                  }}
                  accessibilityElementsHidden
                >
                  <Ionicons name={option.icon as any} size={21} color={isSelected ? colors.accentText : colors.accent} />
                </View>
                <View style={{ flex: 1 }}>
                  <View style={{ flexDirection: 'row', gap: 8, alignItems: 'center', flexWrap: 'wrap', marginBottom: 3 }}>
                    <Text style={{ fontSize: 17, fontWeight: '800', color: colors.text }}>{option.label}</Text>
                    <View style={{ backgroundColor: isSelected ? colors.accent : colors.pill, borderRadius: 8, paddingHorizontal: 8, paddingVertical: 2 }}>
                      <Text style={{ color: isSelected ? colors.accentText : colors.pillText, fontSize: 11, fontWeight: '800' }}>
                        {option.badge}
                      </Text>
                    </View>
                  </View>
                  <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>
                    {option.description}
                  </Text>
                  <View style={{ backgroundColor: colors.background, borderRadius: 8, padding: 10, borderWidth: 1, borderColor: colors.border, marginTop: 10 }}>
                    <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 4 }}>
                      Home opens as
                    </Text>
                    <Text style={{ fontSize: 14, color: colors.text, lineHeight: 20, fontStyle: 'italic' }}>
                      {option.preview}
                    </Text>
                  </View>
                </View>
                {isSelected && <Ionicons name="checkmark-circle" size={20} color={colors.accent} accessibilityElementsHidden />}
              </View>
            </Pressable>
          );
        })}

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
