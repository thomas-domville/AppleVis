import { useEffect, useRef } from 'react';
import { AccessibilityInfo, findNodeHandle, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { useAccessibilityPreferences } from '../src/hooks/useAccessibilityPreferences';
import { useFocusRestore } from '../src/hooks/useFocusRestore';
import { SETTINGS_SECTIONS } from '../src/data/settingsData';

function settingsSummary(sectionId: string, itemCount: number): string {
  switch (sectionId) {
    case 'appearance': return 'Themes and layout density';
    case 'accessibility': return 'VoiceOver and low vision controls';
    case 'notifications': return 'Alerts, sounds, and activity';
    case 'forums': return 'Home feed filter defaults';
    case 'podcasts': return 'Playback and download defaults';
    case 'savedSync': return 'Saved items and iCloud sync';
    case 'privacy': return 'Privacy and data handling';
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

function countByStatus(section: (typeof SETTINGS_SECTIONS)[number]) {
  return section.items.reduce(
    (counts, item) => {
      const status = item.status ?? 'live';
      counts[status] += 1;
      return counts;
    },
    { live: 0, coming: 0, ios: 0 },
  );
}

function sectionStatusLabel(section: (typeof SETTINGS_SECTIONS)[number]): string {
  const counts = countByStatus(section);
  const parts = [
    counts.live ? `${counts.live} live` : null,
    counts.ios ? `${counts.ios} iOS` : null,
    counts.coming ? `${counts.coming} coming soon` : null,
  ].filter(Boolean);
  return parts.join(', ');
}

export default function Settings() {
  const router             = useRouter();
  const { colors, styles } = useTheme();
  const a11y               = useAccessibilityPreferences();
  const { save }           = useFocusRestore();
  const sectionRefs        = useRef<Map<string, View>>(new Map());
  const firstHeadingRef    = useRef<Text | null>(null);
  const didFocusFirstHeadingRef = useRef(false);
  const visibleSections    = SETTINGS_SECTIONS.filter((section) => section.id !== 'account');
  const totalSettings      = visibleSections.reduce((total, section) => total + section.items.length, 0) + 1;
  const settingsSummaryText = `${visibleSections.length + 1} sections and ${totalSettings} settings areas. Appearance, accessibility, notifications, forums, podcasts, privacy, help, and storage. Account tools are in Profile.`;

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
    <Screen title="Settings" showSettings={false}>
      <ScrollView contentInsetAdjustmentBehavior="automatic">
        <View
          style={[styles.card, {
            marginBottom: 14,
            borderLeftWidth: 4,
            borderLeftColor: colors.accent,
            overflow: 'hidden',
          }]}
        >
          {!a11y.reduceTransparency && (
            <View
              style={{ ...StyleSheet.absoluteFillObject, backgroundColor: colors.accent, opacity: 0.06 }}
              pointerEvents="none"
            />
          )}
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
              <Text
                ref={firstHeadingRef}
                style={styles.cardTitle}
                accessibilityRole="header"
                accessibilityActions={[{ name: 'readSettingsSummary', label: 'Read Settings Summary' }]}
                onAccessibilityAction={(event) => {
                  if (event.nativeEvent.actionName === 'readSettingsSummary') {
                    AccessibilityInfo.announceForAccessibility(`Settings. ${settingsSummaryText}`);
                  }
                }}
              >
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

        <Pressable
          onPress={() => router.push('/profile' as any)}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Account tools are in Profile"
          accessibilityHint="Opens Profile for sign in, account settings, saved items, and app information."
          style={({ pressed }) => [styles.cardSmall, {
            flexDirection: 'row',
            alignItems: 'center',
            gap: 12,
            borderLeftWidth: 3,
            borderLeftColor: colors.border,
          }, pressed && { opacity: 0.85 }]}
        >
          <View
            style={{
              width: 34,
              height: 34,
              borderRadius: 9,
              backgroundColor: colors.pill,
              alignItems: 'center',
              justifyContent: 'center',
            }}
            accessibilityElementsHidden
          >
            <Ionicons name="person-circle-outline" size={19} color={colors.accent} />
          </View>
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text }}>Account tools are in Profile</Text>
            <Text style={[styles.cardMeta, { marginTop: 1 }]}>Sign in, saved items, support info, and credits</Text>
          </View>
          <Ionicons name="chevron-forward" size={16} color={colors.textSecondary} accessibilityElementsHidden />
        </Pressable>

        <Text
          style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.8, marginTop: 10, marginBottom: 8 }}
          accessibilityRole="header"
        >
          Settings Sections
        </Text>

        {visibleSections.map((section) => {
          const accent = sectionAccent(section.id);
          const statusLabel = sectionStatusLabel(section);
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
                savedSync:     '/settings-saved-sync',
                privacy:       '/settings-privacy',
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
            accessibilityLabel={`${section.title}. ${settingsSummary(section.id, section.items.length)}. ${statusLabel}. ${section.description}`}
            accessibilityHint="Opens this settings section."
            style={({ pressed }) => [styles.card, {
              borderLeftWidth: 4,
              borderLeftColor: accent,
              overflow: 'hidden',
            }, pressed && { opacity: 0.85 }]}
          >
            {!a11y.reduceTransparency && (
              <View
                style={{ ...StyleSheet.absoluteFillObject, backgroundColor: accent, opacity: 0.04 }}
                pointerEvents="none"
              />
            )}
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
                  <View
                    accessibilityElementsHidden
                    importantForAccessibility="no-hide-descendants"
                    style={{
                    backgroundColor: `${accent}22`,
                    borderRadius: 6,
                    paddingHorizontal: 7,
                    paddingVertical: 2,
                  }}>
                    <Text style={{ color: accent, fontSize: 11, fontWeight: '800' }}>
                      {section.items.length} Settings
                    </Text>
                  </View>
                </View>
                <Text style={[styles.cardMeta, { marginTop: 2 }]}>{settingsSummary(section.id, section.items.length)}</Text>
                <Text style={[styles.cardMeta, { marginTop: 2, fontSize: 13 }]}>{statusLabel}</Text>
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
            overflow: 'hidden',
          }, pressed && { opacity: 0.85 }]}
        >
          {!a11y.reduceTransparency && (
            <View
              style={{ ...StyleSheet.absoluteFillObject, backgroundColor: '#8E8E93', opacity: 0.05 }}
              pointerEvents="none"
            />
          )}
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
