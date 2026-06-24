import { useEffect, useMemo, useRef, useState } from 'react';
import {
  AccessibilityInfo,
  ActivityIndicator,
  Alert,
  findNodeHandle,
  Pressable,
  ScrollView,
  Text,
  View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { useToast } from '../src/contexts/ToastContext';
import { contentCache } from '../src/services/contentCache';
import { deleteAllDownloads } from '../src/services/downloads';
import { persistence } from '../src/services/persistence';
import { useStorageStats } from '../src/hooks/useStorageStats';
import { useTheme } from '../src/contexts/ThemeContext';

type RetentionOption = {
  label: string;
  shortLabel: string;
  value: string;
  ms: number | null;
  description: string;
};

const RETENTION_OPTIONS: RetentionOption[] = [
  {
    label: '3 Months',
    shortLabel: '3 mo',
    value: '3months',
    ms: 90 * 24 * 60 * 60 * 1000,
    description: 'Keeps recent cached content and removes older cache automatically.',
  },
  {
    label: '6 Months',
    shortLabel: '6 mo',
    value: '6months',
    ms: 180 * 24 * 60 * 60 * 1000,
    description: 'A balanced choice for regular browsing and offline reuse.',
  },
  {
    label: '12 Months',
    shortLabel: '12 mo',
    value: '12months',
    ms: 365 * 24 * 60 * 60 * 1000,
    description: 'Keeps cached content longer for people who revisit older material.',
  },
  {
    label: 'Forever',
    shortLabel: 'Forever',
    value: 'forever',
    ms: null,
    description: 'Keeps cached content until you clear it manually.',
  },
];

function SectionHeader({ label }: { label: string }) {
  const { colors } = useTheme();
  return (
    <Text
      accessibilityRole="header"
      style={{
        fontSize: 13,
        fontWeight: '700',
        color: colors.textSecondary,
        textTransform: 'uppercase',
        letterSpacing: 0,
        marginTop: 14,
        marginBottom: 10,
      }}
    >
      {label}
    </Text>
  );
}

function MetricCard({
  icon,
  label,
  value,
  detail,
  accent,
}: {
  icon: React.ComponentProps<typeof Ionicons>['name'];
  label: string;
  value: string;
  detail: string;
  accent: string;
}) {
  const { colors, styles } = useTheme();
  return (
    <View
      accessible
      accessibilityRole="summary"
      accessibilityLabel={`${label}. ${value}. ${detail}`}
      style={[
        styles.cardSmall,
        {
          flex: 1,
          minWidth: 150,
          borderLeftWidth: 4,
          borderLeftColor: accent,
        },
      ]}
    >
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 8 }}>
        <Ionicons name={icon} size={20} color={accent} accessibilityElementsHidden />
        <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary, flex: 1 }}>
          {label}
        </Text>
      </View>
      <Text style={{ fontSize: 22, fontWeight: '800', color: colors.text }}>{value}</Text>
      <Text style={{ fontSize: 13, color: colors.textSecondary, marginTop: 4, lineHeight: 18 }}>
        {detail}
      </Text>
    </View>
  );
}

function RetentionChoice({
  option,
  selected,
  onPress,
}: {
  option: RetentionOption;
  selected: boolean;
  onPress: () => void;
}) {
  const { colors } = useTheme();
  return (
    <Pressable
      onPress={onPress}
      accessible
      accessibilityRole="button"
      accessibilityLabel={`${option.label}. ${selected ? 'Selected. ' : ''}${option.description}`}
      accessibilityState={{ selected }}
      style={({ pressed }) => ({
        flexGrow: 1,
        flexBasis: '47%',
        borderRadius: 12,
        borderWidth: 1.5,
        borderColor: selected ? colors.accent : colors.border,
        backgroundColor: selected ? colors.accent : colors.inputBackground,
        padding: 12,
        opacity: pressed ? 0.78 : 1,
      })}
    >
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
        <Ionicons
          name={selected ? 'checkmark-circle' : 'ellipse-outline'}
          size={18}
          color={selected ? colors.accentText : colors.textSecondary}
          accessibilityElementsHidden
        />
        <Text style={{ color: selected ? colors.accentText : colors.text, fontSize: 16, fontWeight: '800' }}>
          {option.shortLabel}
        </Text>
      </View>
      <Text
        style={{
          color: selected ? colors.accentText : colors.textSecondary,
          fontSize: 13,
          lineHeight: 18,
          marginTop: 6,
        }}
      >
        {option.description}
      </Text>
    </Pressable>
  );
}

function CleanupRow({
  icon,
  label,
  value,
  description,
  disabled,
  destructive,
  onPress,
}: {
  icon: React.ComponentProps<typeof Ionicons>['name'];
  label: string;
  value: string;
  description: string;
  disabled: boolean;
  destructive?: boolean;
  onPress: () => void;
}) {
  const { colors, styles } = useTheme();
  const tint = destructive ? '#B91C1C' : colors.accent;
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled}
      accessible
      accessibilityRole="button"
      accessibilityLabel={`${label}. ${value}. ${description}`}
      accessibilityHint={disabled ? 'Nothing to clear.' : 'Double tap to confirm before clearing.'}
      accessibilityState={{ disabled }}
      style={({ pressed }) => [
        styles.cardSmall,
        {
          flexDirection: 'row',
          alignItems: 'center',
          gap: 12,
          opacity: disabled ? 0.55 : pressed ? 0.82 : 1,
          borderLeftWidth: 4,
          borderLeftColor: destructive ? '#FCA5A5' : colors.border,
        },
      ]}
    >
      <Ionicons name={icon} size={22} color={disabled ? colors.textSecondary : tint} accessibilityElementsHidden />
      <View style={{ flex: 1 }}>
        <Text style={{ fontSize: 16, fontWeight: '800', color: destructive ? '#B91C1C' : colors.text }}>
          {label}
        </Text>
        <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 18, marginTop: 2 }}>
          {description}
        </Text>
      </View>
      <Text style={{ fontSize: 14, fontWeight: '700', color: colors.textSecondary }}>{value}</Text>
    </Pressable>
  );
}

export default function StorageScreen() {
  const { colors, styles } = useTheme();
  const { showToast } = useToast();
  const stats = useStorageStats();
  const headingRef = useRef<Text | null>(null);
  const [retention, setRetention] = useState<string>('3months');
  const [retentionLoading, setRetentionLoading] = useState(true);
  const [clearing, setClearing] = useState(false);

  const selectedRetention = RETENTION_OPTIONS.find((option) => option.value === retention) ?? RETENTION_OPTIONS[0];
  const hasDownloads = stats.downloadsBytes > 0 || stats.downloadCount > 0;
  const hasCache = stats.cacheBytes > 0 || stats.cacheCount > 0;
  const summary = useMemo(() => (
    `Storage and Cache. Downloaded episodes use ${stats.formattedDownloads} across ${stats.downloadCount} item${stats.downloadCount === 1 ? '' : 's'}. ` +
    `Cached content uses ${stats.formattedCache} across ${stats.cacheCount} cache entr${stats.cacheCount === 1 ? 'y' : 'ies'}. ` +
    `Total storage shown here is ${stats.formattedTotal}. Cache retention is ${selectedRetention.label}.`
  ), [selectedRetention.label, stats.cacheCount, stats.downloadCount, stats.formattedCache, stats.formattedDownloads, stats.formattedTotal]);

  useEffect(() => {
    persistence.getSetting<string>('cacheRetention', 'forever').then((val) => {
      setRetention(val);
      setRetentionLoading(false);
      const option = RETENTION_OPTIONS.find((o) => o.value === val);
      if (option?.ms != null) contentCache.purgeOlderThan(option.ms);
    });

    const timers = [350, 700].map((delay) => setTimeout(() => {
      const handle = findNodeHandle(headingRef.current);
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, delay));
    return () => timers.forEach(clearTimeout);
  }, []);

  async function applyRetention(value: string) {
    setRetention(value);
    await persistence.setSetting('cacheRetention', value);
    const option = RETENTION_OPTIONS.find((o) => o.value === value);
    if (option?.ms != null) {
      await contentCache.purgeOlderThan(option.ms);
      await stats.refresh();
    }
    const label = option?.label ?? 'Cache retention';
    showToast(`${label} selected.`, 'success');
    AccessibilityInfo.announceForAccessibility(`${label} selected.`);
  }

  function confirmClearDownloads() {
    Alert.alert(
      'Clear Downloads',
      `This will remove ${stats.formattedDownloads} of downloaded podcast audio from this device. Saved episode records and online episodes are not deleted.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Clear Downloads',
          style: 'destructive',
          onPress: async () => {
            setClearing(true);
            try {
              await deleteAllDownloads();
              await stats.refresh();
              showToast('Downloads cleared.', 'success');
              AccessibilityInfo.announceForAccessibility('Downloads cleared.');
            } finally {
              setClearing(false);
            }
          },
        },
      ],
    );
  }

  function confirmClearCache() {
    Alert.alert(
      'Clear Content Cache',
      `This will remove ${stats.formattedCache} of cached AppleVis content. It will re-download automatically when you open each section again.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Clear Cache',
          style: 'destructive',
          onPress: async () => {
            setClearing(true);
            try {
              await contentCache.clear();
              await stats.refresh();
              showToast('Cache cleared.', 'success');
              AccessibilityInfo.announceForAccessibility('Cache cleared.');
            } finally {
              setClearing(false);
            }
          },
        },
      ],
    );
  }

  function confirmClearAll() {
    Alert.alert(
      'Clear Downloads and Cache',
      `This will remove ${stats.formattedTotal} from this device, including downloaded podcast audio and cached AppleVis content. Account data, saved items, and app preferences are not deleted.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Clear All',
          style: 'destructive',
          onPress: async () => {
            setClearing(true);
            try {
              await Promise.all([deleteAllDownloads(), contentCache.clear()]);
              await stats.refresh();
              showToast('Downloads and cache cleared.', 'success');
              AccessibilityInfo.announceForAccessibility('Downloads and cache cleared.');
            } finally {
              setClearing(false);
            }
          },
        },
      ],
    );
  }

  return (
    <Screen title="Storage & Cache" showSettings={false}>
      <ScrollView contentInsetAdjustmentBehavior="automatic" showsVerticalScrollIndicator={false}>
        <Text
          ref={headingRef}
          accessibilityRole="header"
          accessibilityActions={[{ name: 'summary', label: 'Read Storage Summary' }]}
          onAccessibilityAction={({ nativeEvent }) => {
            if (nativeEvent.actionName === 'summary') {
              AccessibilityInfo.announceForAccessibility(summary);
            }
          }}
          style={{ fontSize: 24, fontWeight: '800', color: colors.text, marginBottom: 8 }}
        >
          Storage Center
        </Text>

        <Text style={styles.lede}>
          Manage downloaded podcast audio, cached AppleVis content, and how long cached content stays on this device.
        </Text>

        <View
          accessible
          accessibilityRole="summary"
          accessibilityLabel={stats.isLoading ? 'Storage totals are loading.' : summary}
          style={[styles.card, { marginBottom: 12, borderLeftWidth: 4, borderLeftColor: colors.accent }]}
        >
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
            <Ionicons name="server-outline" size={24} color={colors.accent} accessibilityElementsHidden />
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: 17, fontWeight: '800', color: colors.text }}>Storage at a Glance</Text>
              <Text style={{ fontSize: 14, color: colors.textSecondary, marginTop: 2 }}>
                Downloads are offline audio. Cache is temporary AppleVis content.
              </Text>
            </View>
            {stats.isLoading && <ActivityIndicator color={colors.appleVisBlue} accessibilityElementsHidden />}
          </View>
        </View>

        <SectionHeader label="Usage" />

        {stats.isLoading ? (
          <View
            accessible
            accessibilityRole="progressbar"
            accessibilityLabel="Loading storage usage"
            style={[styles.card, { alignItems: 'center', paddingVertical: 28 }]}
          >
            <ActivityIndicator color={colors.appleVisBlue} />
            <Text style={[styles.cardMeta, { marginTop: 10 }]}>Checking storage...</Text>
          </View>
        ) : (
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 10, marginBottom: 4 }}>
            <MetricCard
              icon="download-outline"
              label="Downloads"
              value={stats.formattedDownloads}
              detail={`${stats.downloadCount} podcast item${stats.downloadCount === 1 ? '' : 's'}`}
              accent="#0A84FF"
            />
            <MetricCard
              icon="albums-outline"
              label="Cache"
              value={stats.formattedCache}
              detail={`${stats.cacheCount} cached entr${stats.cacheCount === 1 ? 'y' : 'ies'}`}
              accent="#34C759"
            />
            <MetricCard
              icon="pie-chart-outline"
              label="Total"
              value={stats.formattedTotal}
              detail="Downloads plus cache"
              accent="#AF52DE"
            />
          </View>
        )}

        <SectionHeader label="Cache Retention" />

        <View style={styles.card}>
          <Text style={styles.cardTitle}>Keep Cached Content</Text>
          <Text style={[styles.cardMeta, { marginBottom: 14, lineHeight: 20 }]}>
            This only affects cached articles, lists, and metadata. Downloads stay until you clear them.
          </Text>
          {retentionLoading ? (
            <ActivityIndicator color={colors.appleVisBlue} />
          ) : (
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 10 }}>
              {RETENTION_OPTIONS.map((option) => (
                <RetentionChoice
                  key={option.value}
                  option={option}
                  selected={retention === option.value}
                  onPress={() => applyRetention(option.value)}
                />
              ))}
            </View>
          )}
        </View>

        <SectionHeader label="Cleanup Actions" />

        <View style={{ gap: 10 }}>
          <CleanupRow
            icon="download-outline"
            label="Clear Downloads"
            value={stats.isLoading ? 'Loading' : stats.formattedDownloads}
            description="Removes downloaded podcast audio from this device."
            disabled={stats.isLoading || clearing || !hasDownloads}
            onPress={confirmClearDownloads}
          />
          <CleanupRow
            icon="albums-outline"
            label="Clear Cache"
            value={stats.isLoading ? 'Loading' : stats.formattedCache}
            description="Removes cached AppleVis content. It can be downloaded again later."
            disabled={stats.isLoading || clearing || !hasCache}
            onPress={confirmClearCache}
          />
          <CleanupRow
            icon="trash-outline"
            label="Clear Downloads and Cache"
            value={stats.isLoading ? 'Loading' : stats.formattedTotal}
            description="Removes both downloaded audio and cached content from this device."
            disabled={stats.isLoading || clearing || (!hasDownloads && !hasCache)}
            destructive
            onPress={confirmClearAll}
          />
        </View>

        <View
          accessible
          accessibilityRole="summary"
          accessibilityLabel="Storage note. Clearing storage does not delete your AppleVis account, saved items, follows, preferences, or iCloud sync records."
          style={[styles.card, { marginTop: 14, borderLeftWidth: 4, borderLeftColor: '#F59E0B' }]}
        >
          <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 10 }}>
            <Ionicons name="information-circle-outline" size={21} color="#F59E0B" accessibilityElementsHidden />
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: 16, fontWeight: '800', color: colors.text }}>What stays safe?</Text>
              <Text style={{ fontSize: 14, lineHeight: 20, color: colors.textSecondary, marginTop: 4 }}>
                Clearing storage does not delete your AppleVis account, saved items, follows, preferences, or iCloud sync records.
              </Text>
            </View>
          </View>
        </View>

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
