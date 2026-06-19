import { useRef } from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { useFocusRestore } from '../src/hooks/useFocusRestore';
import { SETTINGS_SECTIONS } from '../src/data/settingsData';

function settingsSummary(sectionId: string, itemCount: number): string {
  switch (sectionId) {
    case 'appearance': return 'Themes and layout density';
    case 'accessibility': return 'VoiceOver and low vision controls';
    case 'notifications': return 'Alerts, sounds, and activity';
    case 'forums': return 'Forum reading preferences';
    case 'podcasts': return 'Playback and download defaults';
    case 'privacy': return 'Sync, storage, and privacy';
    case 'help': return 'Guides and support';
    default: return `${itemCount} settings`;
  }
}

function sectionAccent(sectionId: string): string {
  switch (sectionId) {
    case 'appearance': return '#5856D6';
    case 'accessibility': return '#0A84FF';
    case 'notifications': return '#FF9F0A';
    case 'forums': return '#34C759';
    case 'podcasts': return '#FF375F';
    case 'privacy': return '#30B0C7';
    case 'help': return '#AF52DE';
    default: return '#0A84FF';
  }
}

export default function Settings() {
  const router             = useRouter();
  const { colors, styles } = useTheme();
  const { save }           = useFocusRestore();
  const sectionRefs        = useRef<Map<string, View>>(new Map());
  const visibleSections    = SETTINGS_SECTIONS.filter((section) => section.id !== 'account');

  return (
    <Screen title="Settings" showSettings={false}>
      <ScrollView contentInsetAdjustmentBehavior="automatic">
        <View
          style={[styles.card, {
            marginBottom: 14,
            borderLeftWidth: 4,
            borderLeftColor: colors.accent,
          }]}
          accessible
          accessibilityRole="text"
          accessibilityLabel={`Settings. ${visibleSections.length + 1} sections. Appearance, accessibility, notifications, forums, podcasts, privacy, help, and storage. Account tools are in Profile.`}
        >
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
            <View
              style={{
                width: 46,
                height: 46,
                borderRadius: 12,
                backgroundColor: colors.pill,
                alignItems: 'center',
                justifyContent: 'center',
              }}
              accessibilityElementsHidden
            >
              <Ionicons name="options-outline" size={24} color={colors.accent} />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.cardTitle} accessibilityRole="header">
                Settings Center
              </Text>
              <Text style={[styles.cardMeta, { lineHeight: 20 }]}>
                Tune AppleVis for VoiceOver, Braille, low vision, podcasts, notifications, and sync.
              </Text>
              <Text style={[styles.cardMeta, { lineHeight: 20, marginTop: 4 }]}>
                Account and sign-in tools now live in Profile.
              </Text>
            </View>
          </View>
        </View>

        {visibleSections.map((section) => {
          const accent = sectionAccent(section.id);
          return (
          <Pressable
            key={section.id}
            ref={(el) => {
              if (el) sectionRefs.current.set(section.id, el);
              else sectionRefs.current.delete(section.id);
            }}
            onPress={() => {
              save(sectionRefs.current.get(section.id) ?? null);
              const directRoutes: Record<string, string> = {
                appearance:    '/settings-appearance',
                accessibility: '/settings-accessibility',
                notifications: '/settings-notifications',
                forums:        '/settings-forums',
                podcasts:      '/settings-podcast',
                help:          '/help',
              };
              const route = directRoutes[section.id];
              if (route) {
                router.push(route as any);
              } else {
                router.push({ pathname: '/settings-detail', params: { sectionId: section.id } });
              }
            }}
            accessible
            accessibilityRole="button"
            accessibilityLabel={`${section.title}. ${settingsSummary(section.id, section.items.length)}. ${section.items.length} ${section.items.length === 1 ? 'setting' : 'settings'}. ${section.description}`}
            accessibilityHint="Opens this settings section."
            style={({ pressed }) => [styles.card, {
              borderLeftWidth: 4,
              borderLeftColor: accent,
            }, pressed && { opacity: 0.85 }]}
          >
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
              <View
                style={{
                  width: 42,
                  height: 42,
                  borderRadius: 10,
                  backgroundColor: `${accent}1F`,
                  alignItems: 'center',
                  justifyContent: 'center',
                  borderWidth: 1,
                  borderColor: `${accent}55`,
                }}
                accessibilityElementsHidden
              >
                <Ionicons name={section.icon as any} size={22} color={accent} />
              </View>
              <View style={{ flex: 1 }}>
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                  <Text style={styles.cardTitle}>{section.title}</Text>
                  <View style={{
                    backgroundColor: `${accent}22`,
                    borderRadius: 6,
                    paddingHorizontal: 7,
                    paddingVertical: 2,
                  }}>
                    <Text style={{ color: accent, fontSize: 11, fontWeight: '800' }}>
                      {section.items.length}
                    </Text>
                  </View>
                </View>
                <Text style={[styles.cardMeta, { marginTop: 2 }]}>{settingsSummary(section.id, section.items.length)}</Text>
                <Text style={[styles.cardMeta, { marginTop: 3, lineHeight: 19 }]}>{section.description}</Text>
              </View>
              <Ionicons name="chevron-forward" size={18} color={colors.textSecondary} accessibilityElementsHidden />
            </View>
          </Pressable>
          );
        })}

        {/* Storage & Cache — separate because it has destructive actions */}
        <Pressable
          onPress={() => router.push('/storage')}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Storage and Cache. Manage downloads, cached content, and data retention."
          accessibilityHint="Opens Storage and Cache settings."
          style={({ pressed }) => [styles.card, {
            marginTop: 8,
            borderLeftWidth: 4,
            borderLeftColor: '#8E8E93',
          }, pressed && { opacity: 0.85 }]}
        >
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
            <View
              style={{
                width: 42,
                height: 42,
                borderRadius: 10,
                backgroundColor: '#8E8E9322',
                alignItems: 'center',
                justifyContent: 'center',
                borderWidth: 1,
                borderColor: '#8E8E9355',
              }}
              accessibilityElementsHidden
            >
              <Ionicons name="server-outline" size={22} color="#8E8E93" />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.cardTitle}>Storage & Cache</Text>
              <Text style={styles.cardMeta}>Manage downloads, cached content, and data retention policy.</Text>
            </View>
            <Ionicons name="chevron-forward" size={18} color={colors.textSecondary} accessibilityElementsHidden />
          </View>
        </Pressable>

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
