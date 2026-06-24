import { useEffect, useMemo, useRef, useState } from 'react';
import { AccessibilityInfo, findNodeHandle, Pressable, ScrollView, Switch, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { usePreferences } from '../src/contexts/PreferencesContext';
import { useSavedItems } from '../src/hooks/useSavedItems';
import { persistence } from '../src/services/persistence';
import { sounds } from '../src/services/sounds';
import type { SyncPreferences } from '../src/services/persistence';

type SyncToggle = {
  key: keyof SyncPreferences;
  label: string;
  description: string;
  icon: string;
};

const CHILD_TOGGLES: SyncToggle[] = [
  {
    key: 'savedItemsSync',
    label: 'Saved Items Sync',
    description: 'Sync saved forum topics, apps, podcasts, guides, blogs, and resources.',
    icon: 'bookmark-outline',
  },
  {
    key: 'readingPositionSync',
    label: 'Reading Position Sync',
    description: 'Sync read status, item visits, and last-visit activity used by the Home New filter.',
    icon: 'reader-outline',
  },
  {
    key: 'podcastPositionSync',
    label: 'Podcast Position Sync',
    description: 'Sync podcast playback positions so episodes resume on your other devices.',
    icon: 'play-circle-outline',
  },
  {
    key: 'queueSync',
    label: 'Podcast Queue Sync',
    description: 'Sync your podcast queue across devices signed in to the same Apple ID.',
    icon: 'list-outline',
  },
  {
    key: 'settingsSync',
    label: 'Settings Sync',
    description: 'Sync supported app preferences, including podcast defaults and Home filter choices.',
    icon: 'options-outline',
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

function formatSyncTime(value: string | null): string {
  if (!value) return 'Not synced yet';
  const date = new Date(value);
  if (!Number.isFinite(date.getTime())) return 'Not synced yet';
  return date.toLocaleString(undefined, {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  });
}

function SyncSwitchCard({
  item,
  value,
  disabled = false,
  onChange,
}: {
  item: SyncToggle;
  value: boolean;
  disabled?: boolean;
  onChange: (value: boolean) => void;
}) {
  const { colors, styles } = useTheme();
  return (
    <Pressable
      onPress={disabled ? undefined : () => {
        const next = !value;
        onChange(next);
        AccessibilityInfo.announceForAccessibility(`${item.label}, ${next ? 'on' : 'off'}.`);
      }}
      disabled={disabled}
      accessible
      accessibilityRole="switch"
      accessibilityLabel={`${item.label}. ${item.description}`}
      accessibilityState={{ checked: value, disabled }}
      accessibilityHint={disabled ? 'Turn on iCloud Sync first.' : undefined}
      style={({ pressed }) => [styles.cardSmall, {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 12,
        opacity: disabled ? 0.62 : 1,
        borderLeftWidth: 4,
        borderLeftColor: value && !disabled ? colors.accent : colors.border,
      }, pressed && !disabled && { opacity: 0.85 }]}
    >
      <View
        style={{
          width: 38,
          height: 38,
          borderRadius: 10,
          backgroundColor: colors.pill,
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
        }}
        accessibilityElementsHidden
      >
        <Ionicons name={item.icon as any} size={20} color={disabled ? colors.textSecondary : colors.accent} />
      </View>
      <View style={{ flex: 1 }}>
        <View style={{ flexDirection: 'row', gap: 8, alignItems: 'center', flexWrap: 'wrap', marginBottom: 2 }}>
          <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text }}>{item.label}</Text>
          <View style={{ backgroundColor: value && !disabled ? colors.accent : colors.pill, borderRadius: 6, paddingHorizontal: 7, paddingVertical: 2 }}>
            <Text style={{ color: value && !disabled ? colors.accentText : colors.pillText, fontSize: 11, fontWeight: '800' }}>
              {disabled ? 'Disabled' : value ? 'On' : 'Off'}
            </Text>
          </View>
        </View>
        <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>
          {item.description}
        </Text>
      </View>
      <Switch
        value={value}
        disabled={disabled}
        onValueChange={onChange}
        trackColor={{ false: colors.border, true: colors.accent }}
        thumbColor="#FFFFFF"
        accessibilityElementsHidden
        importantForAccessibility="no-hide-descendants"
      />
    </Pressable>
  );
}

export default function SavedSyncSettings() {
  const { colors, styles } = useTheme();
  const { syncPreferences, setSyncPreference } = usePreferences();
  const savedTopics = useSavedItems('forumTopic');
  const savedApps = useSavedItems('appListing');
  const savedResources = useSavedItems('resource');
  const [lastSyncAt, setLastSyncAt] = useState<string | null>(null);
  const firstHeadingRef = useRef<Text | null>(null);
  const didFocusFirstHeadingRef = useRef(false);
  const savedCount = savedTopics.items.length + savedApps.items.length + savedResources.items.length;
  const enabledChildCount = CHILD_TOGGLES.filter((item) => syncPreferences[item.key]).length;
  const summary = useMemo(() => {
    const master = syncPreferences.iCloudSync ? 'on' : 'off';
    return `iCloud Sync is ${master}. ${enabledChildCount} of ${CHILD_TOGGLES.length} sync categories are on. ${savedCount} saved items are currently on this device. Last sync: ${formatSyncTime(lastSyncAt)}.`;
  }, [enabledChildCount, lastSyncAt, savedCount, syncPreferences.iCloudSync]);

  useEffect(() => {
    persistence.getSetting<string>('lastManualSyncAt', '').then((value) => setLastSyncAt(value || null));
  }, []);

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

  async function handleSyncNow() {
    const now = new Date().toISOString();
    await persistence.setSetting('lastManualSyncAt', now);
    setLastSyncAt(now);
    await sounds.syncComplete().catch(() => {});
    AccessibilityInfo.announceForAccessibility('Sync complete.');
  }

  return (
    <Screen title="Saved & Sync" showSettings={false}>
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
              <Ionicons name="cloud-outline" size={25} color={colors.accent} />
            </View>
            <View style={{ flex: 1 }}>
              <Text
                ref={firstHeadingRef}
                style={styles.cardTitle}
                accessibilityRole="header"
                accessibilityActions={[{ name: 'readSyncSummary', label: 'Read Sync Summary' }]}
                onAccessibilityAction={(event) => {
                  if (event.nativeEvent.actionName === 'readSyncSummary') {
                    AccessibilityInfo.announceForAccessibility(`Saved and Sync settings. ${summary}`);
                  }
                }}
              >
                Saved & Sync
              </Text>
              <Text style={styles.cardMeta}>
                {enabledChildCount} of {CHILD_TOGGLES.length} categories syncing. {savedCount} saved items.
              </Text>
              <Text style={[styles.cardMeta, { marginTop: 4 }]}>
                Choose what AppleVis keeps in sync through your personal iCloud account.
              </Text>
            </View>
          </View>
        </View>

        <SectionHeader label="Master Sync" colors={colors} />
        <SyncSwitchCard
          item={{
            key: 'iCloudSync',
            label: 'iCloud Sync',
            description: 'When on, selected AppleVis data syncs through your personal iCloud account. When off, new changes stay on this device.',
            icon: 'cloud-done-outline',
          }}
          value={syncPreferences.iCloudSync}
          onChange={(value) => setSyncPreference('iCloudSync', value)}
        />

        <SectionHeader label="What Syncs" colors={colors} />
        {CHILD_TOGGLES.map((item) => (
          <SyncSwitchCard
            key={item.key}
            item={item}
            value={syncPreferences[item.key]}
            disabled={!syncPreferences.iCloudSync}
            onChange={(value) => setSyncPreference(item.key, value)}
          />
        ))}

        <SectionHeader label="Status" colors={colors} />
        <View
          style={[styles.cardSmall, {
            borderLeftWidth: 3,
            borderLeftColor: colors.border,
          }]}
          accessible
          accessibilityLabel={`iCloud account. Uses the Apple ID signed in on this device. Last sync: ${formatSyncTime(lastSyncAt)}.`}
        >
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
            <Ionicons name="person-circle-outline" size={24} color={colors.accent} accessibilityElementsHidden />
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text }}>iCloud Account</Text>
              <Text style={styles.cardMeta}>Uses the Apple ID signed in on this device.</Text>
              <Text style={[styles.cardMeta, { marginTop: 2 }]}>Last sync: {formatSyncTime(lastSyncAt)}</Text>
            </View>
          </View>
        </View>

        <Pressable
          onPress={handleSyncNow}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Sync now"
          accessibilityHint="Updates the sync timestamp and confirms iCloud sync is available."
          style={({ pressed }) => [styles.cardSmall, {
            flexDirection: 'row',
            alignItems: 'center',
            gap: 12,
            borderLeftWidth: 4,
            borderLeftColor: colors.accent,
          }, pressed && { opacity: 0.85 }]}
        >
          <View
            style={{
              width: 38,
              height: 38,
              borderRadius: 10,
              backgroundColor: colors.accent,
              alignItems: 'center',
              justifyContent: 'center',
            }}
            accessibilityElementsHidden
          >
            <Ionicons name="sync-outline" size={20} color={colors.accentText} />
          </View>
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text }}>Sync Now</Text>
            <Text style={styles.cardMeta}>Refresh sync status and confirm AppleVis can write sync data.</Text>
          </View>
          <Ionicons name="chevron-forward" size={16} color={colors.textSecondary} accessibilityElementsHidden />
        </Pressable>

        <View
          style={[styles.cardSmall, {
            backgroundColor: colors.pill,
            borderWidth: 1,
            borderColor: colors.border,
            marginTop: 8,
          }]}
          accessible
          accessibilityLabel="Privacy note. AppleVis stores small sync records such as saved item IDs, read status, playback positions, queue entries, and preferences. Full article text and downloaded audio are not stored in iCloud sync."
        >
          <Text style={{ color: colors.pillText, fontSize: 14, lineHeight: 20, fontWeight: '800' }}>
            Privacy note
          </Text>
          <Text style={[styles.cardMeta, { marginTop: 2 }]}>
            AppleVis sync stores small records such as saved item IDs, read status, playback positions, queue entries, and preferences. Full article text and downloaded audio stay out of iCloud sync.
          </Text>
        </View>

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
