import { useRef } from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { useFocusRestore } from '../src/hooks/useFocusRestore';
import { SETTINGS_SECTIONS } from '../src/data/settingsData';

export default function Settings() {
  const router             = useRouter();
  const { colors, styles } = useTheme();
  const { save }           = useFocusRestore();
  const sectionRefs        = useRef<Map<string, View>>(new Map());

  return (
    <Screen title="Settings" showSettings={false}>
      <ScrollView contentInsetAdjustmentBehavior="automatic">

        {SETTINGS_SECTIONS.map((section) => (
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
            accessibilityLabel={`${section.title}. ${section.description}`}
            accessibilityHint="Opens this settings section."
            style={({ pressed }) => [styles.card, pressed && { opacity: 0.85 }]}
          >
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
              <Ionicons name={section.icon as any} size={22} color={colors.accent} accessibilityElementsHidden />
              <View style={{ flex: 1 }}>
                <Text style={styles.cardTitle}>{section.title}</Text>
                <Text style={styles.cardMeta}>{section.description}</Text>
              </View>
              <Ionicons name="chevron-forward" size={18} color={colors.textSecondary} accessibilityElementsHidden />
            </View>
          </Pressable>
        ))}

        {/* Storage & Cache — separate because it has destructive actions */}
        <Pressable
          onPress={() => router.push('/storage')}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Storage and Cache. Manage downloads, cached content, and data retention."
          accessibilityHint="Opens Storage and Cache settings."
          style={({ pressed }) => [styles.card, { marginTop: 8 }, pressed && { opacity: 0.85 }]}
        >
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
            <Ionicons name="server-outline" size={22} color={colors.accent} accessibilityElementsHidden />
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
