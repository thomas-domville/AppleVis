import { useEffect, useMemo, useRef, useState } from 'react';
import {
  AccessibilityInfo,
  Alert,
  findNodeHandle,
  Linking,
  Pressable,
  ScrollView,
  Switch,
  Text,
  View,
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { usePreferences } from '../src/contexts/PreferencesContext';
import { useAuth } from '../src/contexts/AuthContext';
import { useToast } from '../src/contexts/ToastContext';
import { contentCache } from '../src/services/contentCache';
import { deleteAllDownloads } from '../src/services/downloads';
import { persistence } from '../src/services/persistence';

const BASE = 'https://www.applevis.com';

function isDeviceLocalAppleVisKey(key: string): boolean {
  return (
    key.startsWith('@applevis') ||
    key.startsWith('applevis:local:') ||
    key === 'applevis:downloads' ||
    key === 'applevis:episodeMeta' ||
    key === 'applevis:queue' ||
    key === 'applevis:playHistory' ||
    key === 'applevis:showSpeeds' ||
    key === 'applevis:lastEpisode' ||
    key === 'applevis:volume' ||
    key === 'applevis:savedEpisodeMeta' ||
    key === 'applevis:topicSeen' ||
    key === 'applevis:episodeDurations' ||
    key === 'applevis:episodeChapters' ||
    key === 'applevis:itemVisits'
  );
}

function SectionLabel({ children }: { children: string }) {
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
      {children}
    </Text>
  );
}

function Badge({ label, tone = 'info' }: { label: string; tone?: 'info' | 'private' | 'device' | 'warning' }) {
  const palette = {
    info:    { bg: '#E0F2FE', text: '#075985' },
    private: { bg: '#D1FAE5', text: '#065F46' },
    device:  { bg: '#E0E7FF', text: '#3730A3' },
    warning: { bg: '#FEF3C7', text: '#92400E' },
  }[tone];
  return (
    <View
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
      style={{ backgroundColor: palette.bg, borderRadius: 7, paddingHorizontal: 8, paddingVertical: 3 }}
    >
      <Text style={{ color: palette.text, fontSize: 12, fontWeight: '800' }}>{label}</Text>
    </View>
  );
}

function PrivacyCard({
  icon,
  title,
  badge,
  badgeTone,
  body,
}: {
  icon: React.ComponentProps<typeof Ionicons>['name'];
  title: string;
  badge: string;
  badgeTone?: 'info' | 'private' | 'device' | 'warning';
  body: string;
}) {
  const { colors, styles } = useTheme();
  return (
    <View
      accessible
      accessibilityRole="summary"
      accessibilityLabel={`${title}. ${badge}. ${body}`}
      style={[styles.card, { marginBottom: 10, borderLeftWidth: 4, borderLeftColor: colors.accent }]}
    >
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 8 }}>
        <Ionicons name={icon} size={21} color={colors.accent} accessibilityElementsHidden />
        <Text style={{ flex: 1, fontSize: 16, fontWeight: '800', color: colors.text }}>{title}</Text>
        <Badge label={badge} tone={badgeTone} />
      </View>
      <Text style={{ fontSize: 14, lineHeight: 20, color: colors.textSecondary }}>{body}</Text>
    </View>
  );
}

function ToggleRow({
  icon,
  label,
  description,
  value,
  onValueChange,
}: {
  icon: React.ComponentProps<typeof Ionicons>['name'];
  label: string;
  description: string;
  value: boolean;
  onValueChange: (value: boolean) => void;
}) {
  const { colors, styles } = useTheme();
  return (
    <Pressable
      onPress={() => onValueChange(!value)}
      accessible
      accessibilityRole="switch"
      accessibilityState={{ checked: value }}
      accessibilityLabel={`${label}, ${value ? 'on' : 'off'}`}
      accessibilityHint={description}
      style={({ pressed }) => [
        styles.cardSmall,
        {
          flexDirection: 'row',
          alignItems: 'center',
          gap: 12,
          borderLeftWidth: 4,
          borderLeftColor: value ? colors.accent : colors.border,
        },
        pressed && { opacity: 0.84 },
      ]}
    >
      <Ionicons name={icon} size={21} color={value ? colors.accent : colors.textSecondary} accessibilityElementsHidden />
      <View style={{ flex: 1 }}>
        <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text }}>{label}</Text>
        <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 18, marginTop: 2 }}>
          {description}
        </Text>
      </View>
      <Switch
        value={value}
        onValueChange={onValueChange}
        accessibilityElementsHidden
        importantForAccessibility="no-hide-descendants"
        trackColor={{ false: colors.border, true: colors.appleVisBlue }}
        thumbColor="#FFFFFF"
      />
    </Pressable>
  );
}

function ActionRow({
  icon,
  label,
  description,
  onPress,
  destructive = false,
}: {
  icon: React.ComponentProps<typeof Ionicons>['name'];
  label: string;
  description: string;
  onPress: () => void;
  destructive?: boolean;
}) {
  const { colors, styles } = useTheme();
  const tint = destructive ? '#B91C1C' : colors.accent;
  return (
    <Pressable
      onPress={onPress}
      accessible
      accessibilityRole="button"
      accessibilityLabel={`${label}. ${description}`}
      accessibilityHint={destructive ? 'Requires confirmation before continuing.' : 'Opens related privacy controls.'}
      style={({ pressed }) => [
        styles.cardSmall,
        {
          flexDirection: 'row',
          alignItems: 'center',
          gap: 12,
          borderLeftWidth: 4,
          borderLeftColor: destructive ? '#FCA5A5' : colors.border,
        },
        pressed && { opacity: 0.84 },
      ]}
    >
      <Ionicons name={icon} size={21} color={tint} accessibilityElementsHidden />
      <View style={{ flex: 1 }}>
        <Text style={{ fontSize: 16, fontWeight: '700', color: destructive ? '#B91C1C' : colors.text }}>
          {label}
        </Text>
        <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 18, marginTop: 2 }}>
          {description}
        </Text>
      </View>
      <Ionicons name="chevron-forward" size={16} color={colors.textSecondary} accessibilityElementsHidden />
    </Pressable>
  );
}

export default function PrivacySettings() {
  const router = useRouter();
  const { colors, styles } = useTheme();
  const auth = useAuth();
  const { showToast } = useToast();
  const headingRef = useRef<Text | null>(null);
  const [clearing, setClearing] = useState(false);
  const {
    syncPreferences,
    setSyncPreference,
    nonEnglishDetectionEnabled,
    setNonEnglishDetectionEnabled,
    composeRewriteEnabled,
    setComposeRewriteEnabled,
    composeTranslationEnabled,
    setComposeTranslationEnabled,
    searchTranslationEnabled,
    setSearchTranslationEnabled,
    aiSummariesEnabled,
    setAiSummariesEnabled,
  } = usePreferences();

  const syncEnabledCount = Object.values(syncPreferences).filter(Boolean).length;
  const smartEnabledCount = [
    nonEnglishDetectionEnabled,
    composeRewriteEnabled,
    composeTranslationEnabled,
    searchTranslationEnabled,
    aiSummariesEnabled,
  ].filter(Boolean).length;

  const summary = useMemo(() => (
    `Privacy settings. ${syncEnabledCount} of 6 sync controls are on. ` +
    `${smartEnabledCount} of 5 smart feature controls are on. ` +
    'AppleVis does not use advertising tracking or third-party analytics. Account details live on AppleVis. Device data includes cache, downloads, queue, reading progress, and preferences.'
  ), [smartEnabledCount, syncEnabledCount]);

  useEffect(() => {
    const timers = [350, 700].map((delay) => setTimeout(() => {
      const handle = findNodeHandle(headingRef.current);
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, delay));
    return () => timers.forEach(clearTimeout);
  }, []);

  async function clearLocalData() {
    if (clearing) return;
    setClearing(true);
    try {
      await auth.signOut().catch(() => {});
      await Promise.all([
        deleteAllDownloads().catch(() => {}),
        contentCache.clear().catch(() => {}),
        persistence.clearPlayHistory().catch(() => {}),
      ]);
      const keys = await AsyncStorage.getAllKeys().catch(() => [] as string[]);
      const localKeys = keys.filter(isDeviceLocalAppleVisKey);
      if (localKeys.length > 0) await AsyncStorage.multiRemove(localKeys);
      showToast('Local AppleVis data cleared.', 'success');
      AccessibilityInfo.announceForAccessibility('Local AppleVis data cleared. Some settings may refresh after restarting the app.');
    } finally {
      setClearing(false);
    }
  }

  function confirmClearLocalData() {
    Alert.alert(
      'Clear Local Data',
      'This signs you out and removes AppleVis data stored on this device, including cache, downloads, queue, reading progress, and local preferences. It does not delete your applevis.com account.',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Clear Local Data', style: 'destructive', onPress: clearLocalData },
      ],
    );
  }

  return (
    <Screen title="Privacy" showSettings={false}>
      <ScrollView showsVerticalScrollIndicator={false} contentInsetAdjustmentBehavior="automatic">
        <Text
          ref={headingRef}
          accessibilityRole="header"
          accessibilityActions={[{ name: 'summary', label: 'Read Privacy Summary' }]}
          onAccessibilityAction={({ nativeEvent }) => {
            if (nativeEvent.actionName === 'summary') {
              AccessibilityInfo.announceForAccessibility(summary);
            }
          }}
          style={{ fontSize: 24, fontWeight: '800', color: colors.text, marginBottom: 8 }}
        >
          Privacy Center
        </Text>

        <Text style={styles.lede}>
          Review what AppleVis stores, control sync and smart features, and clear data from this device.
        </Text>

        <View
          accessible
          accessibilityRole="summary"
          accessibilityLabel={summary}
          style={[styles.card, { marginBottom: 12, borderLeftWidth: 4, borderLeftColor: colors.accent }]}
        >
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 8 }}>
            <Ionicons name="shield-checkmark-outline" size={24} color={colors.accent} accessibilityElementsHidden />
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: 17, fontWeight: '800', color: colors.text }}>Privacy at a Glance</Text>
              <Text style={{ fontSize: 14, color: colors.textSecondary, marginTop: 2 }}>
                No ads, no advertising tracking, no third-party analytics.
              </Text>
            </View>
          </View>
          <Text style={{ fontSize: 14, lineHeight: 20, color: colors.textSecondary }}>
            Account information is used for sign in and posting. Device data is used to keep your AppleVis experience working, such as saved items, downloads, read status, podcast progress, and preferences.
          </Text>
        </View>

        <SectionLabel>What Is Stored</SectionLabel>

        <PrivacyCard
          icon="person-circle-outline"
          title="Account Data"
          badge="AppleVis"
          badgeTone="info"
          body="Your username, email address, posts, comments, and account session are handled by AppleVis. Your password is not stored in the app."
        />
        <PrivacyCard
          icon="key-outline"
          title="Keychain Sign-In"
          badge="Encrypted"
          badgeTone="private"
          body="The app stores only a sign-in session token in the iOS Keychain, Apple’s encrypted credential storage."
        />
        <PrivacyCard
          icon="cloud-outline"
          title="iCloud Sync"
          badge="Private"
          badgeTone="private"
          body="Saved items, followed items, read status, podcast position, queue, and preferences can sync through your private iCloud account."
        />
        <PrivacyCard
          icon="phone-portrait-outline"
          title="Device Storage"
          badge="On Device"
          badgeTone="device"
          body="Downloads, cache, queue, podcast history, and some preferences are stored locally so the app can work faster and offline."
        />
        <PrivacyCard
          icon="sparkles-outline"
          title="Smart Features"
          badge="Controlled"
          badgeTone="device"
          body="Read Aloud runs on device. Google Translate handoff opens Google Translate. Apple Intelligence features run on device when available."
        />

        <SectionLabel>Sync Controls</SectionLabel>

        <ToggleRow
          icon="cloud-outline"
          label="iCloud Sync"
          description="Turns all AppleVis iCloud sync categories on or off."
          value={syncPreferences.iCloudSync}
          onValueChange={(value) => setSyncPreference('iCloudSync', value)}
        />
        <ToggleRow
          icon="bookmark-outline"
          label="Saved and Following Sync"
          description="Syncs saved items and followed content between your devices."
          value={syncPreferences.savedItemsSync}
          onValueChange={(value) => setSyncPreference('savedItemsSync', value)}
        />
        <ToggleRow
          icon="time-outline"
          label="Reading Progress Sync"
          description="Syncs read status, last visit, and reading position."
          value={syncPreferences.readingPositionSync}
          onValueChange={(value) => setSyncPreference('readingPositionSync', value)}
        />
        <ToggleRow
          icon="headset-outline"
          label="Podcast Position Sync"
          description="Syncs podcast playback positions across devices."
          value={syncPreferences.podcastPositionSync}
          onValueChange={(value) => setSyncPreference('podcastPositionSync', value)}
        />
        <ToggleRow
          icon="list-outline"
          label="Queue Sync"
          description="Syncs your podcast queue between devices."
          value={syncPreferences.queueSync}
          onValueChange={(value) => setSyncPreference('queueSync', value)}
        />
        <ToggleRow
          icon="options-outline"
          label="Settings Sync"
          description="Syncs AppleVis settings and preferences."
          value={syncPreferences.settingsSync}
          onValueChange={(value) => setSyncPreference('settingsSync', value)}
        />

        <SectionLabel>Smart Feature Privacy</SectionLabel>

        <ToggleRow
          icon="language-outline"
          label="Non-English Detection"
          description="Checks typed text locally so the app can offer translation."
          value={nonEnglishDetectionEnabled}
          onValueChange={setNonEnglishDetectionEnabled}
        />
        <ToggleRow
          icon="create-outline"
          label="Friendly Rewrite"
          description="Offers Apple Intelligence rewrite help before posting."
          value={composeRewriteEnabled}
          onValueChange={setComposeRewriteEnabled}
        />
        <ToggleRow
          icon="text-outline"
          label="Draft Translation"
          description="Offers Apple Intelligence translation for non-English drafts."
          value={composeTranslationEnabled}
          onValueChange={setComposeTranslationEnabled}
        />
        <ToggleRow
          icon="search-outline"
          label="Search Translation"
          description="Offers Apple Intelligence translation for Discover search."
          value={searchTranslationEnabled}
          onValueChange={setSearchTranslationEnabled}
        />
        <ToggleRow
          icon="document-text-outline"
          label="AI Summaries"
          description="Shows Apple Intelligence summary and simplify actions where supported."
          value={aiSummariesEnabled}
          onValueChange={setAiSummariesEnabled}
        />

        <SectionLabel>Manage Data</SectionLabel>

        <ActionRow
          icon="notifications-outline"
          label="Notification Privacy"
          description="Choose which notification categories can use your device push token."
          onPress={() => router.push('/settings-notifications' as any)}
        />
        <ActionRow
          icon="server-outline"
          label="Storage and Cache"
          description="Review downloads, cache size, cache retention, and storage cleanup."
          onPress={() => router.push('/storage' as any)}
        />
        <ActionRow
          icon="open-outline"
          label="Privacy Policy"
          description="Open the full AppleVis privacy policy on the website."
          onPress={() => Linking.openURL(`${BASE}/privacy`).catch(() => showToast('Could not open privacy policy.', 'error'))}
        />
        <ActionRow
          icon="trash-outline"
          label={clearing ? 'Clearing Local Data' : 'Clear Local Data'}
          description="Sign out and remove AppleVis data stored on this device."
          destructive
          onPress={confirmClearLocalData}
        />

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
