import { useEffect, useState } from 'react';
import { ActivityIndicator, Alert, Pressable, ScrollView, Text, View } from 'react-native';
import { Screen } from '../src/components/Screen';
import { useToast } from '../src/contexts/ToastContext';
import { contentCache } from '../src/services/contentCache';
import { deleteAllDownloads } from '../src/services/downloads';
import { persistence } from '../src/services/persistence';
import { useStorageStats } from '../src/hooks/useStorageStats';
import { useTheme } from '../src/contexts/ThemeContext';

type RetentionOption = {
  label: string;
  value: string;
  ms: number | null;
};

const RETENTION_OPTIONS: RetentionOption[] = [
  { label: '3 Months',  value: '3months',  ms: 90  * 24 * 60 * 60 * 1000 },
  { label: '6 Months',  value: '6months',  ms: 180 * 24 * 60 * 60 * 1000 },
  { label: '12 Months', value: '12months', ms: 365 * 24 * 60 * 60 * 1000 },
  { label: 'Forever',   value: 'forever',  ms: null },
];

export default function StorageScreen() {
  const { colors, styles } = useTheme();
  const { showToast } = useToast();
  const stats = useStorageStats();
  const [retention, setRetention] = useState<string>('3months');
  const [retentionLoading, setRetentionLoading] = useState(true);

  useEffect(() => {
    persistence.getSetting<string>('cacheRetention', 'forever').then((val) => {
      setRetention(val);
      setRetentionLoading(false);
      const option = RETENTION_OPTIONS.find((o) => o.value === val);
      if (option?.ms != null) contentCache.purgeOlderThan(option.ms);
    });
  }, []);

  async function applyRetention(value: string) {
    setRetention(value);
    await persistence.setSetting('cacheRetention', value);
    const option = RETENTION_OPTIONS.find((o) => o.value === value);
    if (option?.ms != null) {
      await contentCache.purgeOlderThan(option.ms);
      await stats.refresh();
    }
    showToast('Cache retention updated.', 'success');
  }

  function confirmClearDownloads() {
    Alert.alert(
      'Clear Downloads',
      `This will remove ${stats.formattedDownloads} of downloaded podcast episodes from this device.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Clear', style: 'destructive',
          onPress: async () => {
            await deleteAllDownloads();
            await stats.refresh();
            showToast('Downloads cleared.', 'success');
          },
        },
      ],
    );
  }

  function confirmClearCache() {
    Alert.alert(
      'Clear Content Cache',
      `This will remove ${stats.formattedCache} of cached content. It will be re-downloaded next time you open each section.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Clear', style: 'destructive',
          onPress: async () => {
            await contentCache.clear();
            await stats.refresh();
            showToast('Cache cleared.', 'success');
          },
        },
      ],
    );
  }

  function confirmClearAll() {
    Alert.alert(
      'Clear All Storage',
      `This will remove ${stats.formattedTotal} including all downloads and cached content.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Clear All', style: 'destructive',
          onPress: async () => {
            await Promise.all([deleteAllDownloads(), contentCache.clear()]);
            await stats.refresh();
            showToast('All storage cleared.', 'success');
          },
        },
      ],
    );
  }

  return (
    <Screen title="Storage & Cache" showSettings={false}>
      <ScrollView contentInsetAdjustmentBehavior="automatic">

        {/* ── Storage usage ───────────────────────────────────────────── */}
        <View style={styles.card}>
          <Text style={styles.cardTitle}>Storage Used</Text>
          {stats.isLoading ? (
            <ActivityIndicator color={colors.appleVisBlue} style={{ marginVertical: 12 }} />
          ) : (
            <>
              <StorageRow colors={colors} label="Downloaded episodes" value={stats.formattedDownloads} />
              <StorageRow colors={colors} label="Cached content"      value={stats.formattedCache} />
              <View style={{ height: 1, backgroundColor: colors.border, marginVertical: 8 }} />
              <StorageRow colors={colors} label="Total" value={stats.formattedTotal} bold />
            </>
          )}
        </View>

        {/* ── Retention picker ────────────────────────────────────────── */}
        <View style={styles.card}>
          <Text style={styles.cardTitle}>Cache Retention</Text>
          <Text style={[styles.cardMeta, { marginBottom: 14 }]}>
            How long to keep cached content before automatically removing it.
          </Text>
          {retentionLoading ? (
            <ActivityIndicator color={colors.appleVisBlue} />
          ) : (
            <View style={styles.pillRow}>
              {RETENTION_OPTIONS.map((opt) => {
                const selected = retention === opt.value;
                return (
                  <Pressable
                    key={opt.value}
                    onPress={() => applyRetention(opt.value)}
                    accessible
                    accessibilityRole="radio"
                    accessibilityLabel={opt.label}
                    accessibilityState={{ selected }}
                    style={{
                      paddingHorizontal: 16,
                      paddingVertical: 10,
                      borderRadius: 999,
                      backgroundColor: selected ? colors.appleVisBlue : '#F3F4F6',
                    }}
                  >
                    <Text style={{ color: selected ? '#FFF' : colors.text, fontWeight: '600', fontSize: 15 }}>
                      {opt.label}
                    </Text>
                  </Pressable>
                );
              })}
            </View>
          )}
        </View>

        {/* ── Clear buttons ───────────────────────────────────────────── */}
        <View style={styles.card}>
          <Text style={styles.cardTitle}>Clear Storage</Text>
          <Text style={[styles.cardMeta, { marginBottom: 14 }]}>
            Downloads stay until deleted here. Cached content re-downloads automatically when you open each section.
          </Text>
          <View style={{ gap: 10 }}>
            <ClearButton
              colors={colors}
              label="Clear Downloads"
              subtitle={stats.isLoading ? '…' : stats.formattedDownloads}
              disabled={stats.isLoading || stats.downloadsBytes === 0}
              onPress={confirmClearDownloads}
            />
            <ClearButton
              colors={colors}
              label="Clear Cache"
              subtitle={stats.isLoading ? '…' : stats.formattedCache}
              disabled={stats.isLoading || stats.cacheBytes === 0}
              onPress={confirmClearCache}
            />
            <ClearButton
              colors={colors}
              label="Clear All"
              subtitle={stats.isLoading ? '…' : stats.formattedTotal}
              disabled={stats.isLoading || (stats.downloadsBytes === 0 && stats.cacheBytes === 0)}
              onPress={confirmClearAll}
              destructive
            />
          </View>
        </View>

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}

function StorageRow({ colors, label, value, bold }: { colors: ReturnType<typeof useTheme>['colors']; label: string; value: string; bold?: boolean }) {
  return (
    <View
      style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: 5 }}
      accessible
      accessibilityLabel={`${label}: ${value}`}
    >
      <Text style={{ fontSize: 16, color: bold ? colors.text : colors.secondary, fontWeight: bold ? '700' : '400' }}>
        {label}
      </Text>
      <Text style={{ fontSize: 16, color: colors.text, fontWeight: bold ? '700' : '600' }}>
        {value}
      </Text>
    </View>
  );
}

function ClearButton({
  colors, label, subtitle, disabled, onPress, destructive,
}: {
  colors: ReturnType<typeof useTheme>['colors'];
  label: string;
  subtitle: string;
  disabled: boolean;
  onPress: () => void;
  destructive?: boolean;
}) {
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled}
      accessible
      accessibilityRole="button"
      accessibilityLabel={`${label}, ${subtitle}`}
      accessibilityState={{ disabled }}
      style={{
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        backgroundColor: disabled ? '#F9FAFB' : destructive ? '#FFF0F0' : '#F3F4F6',
        borderRadius: 12,
        padding: 14,
        opacity: disabled ? 0.5 : 1,
      }}
    >
      <Text style={{ fontSize: 16, fontWeight: '600', color: disabled ? colors.secondary : destructive ? '#B91C1C' : colors.text }}>
        {label}
      </Text>
      <Text style={{ fontSize: 14, color: colors.secondary }}>{subtitle}</Text>
    </Pressable>
  );
}
