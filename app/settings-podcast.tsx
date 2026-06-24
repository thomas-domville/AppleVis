import { useEffect, useRef } from 'react';
import { AccessibilityInfo, findNodeHandle, Pressable, ScrollView, Switch, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { SettingsPickerRow } from '../src/components/SettingsPickerRow';
import { useTheme } from '../src/contexts/ThemeContext';
import { usePreferences } from '../src/contexts/PreferencesContext';
import type {
  PlaybackSpeed,
  PodcastEQPreset,
  PodcastAutoDownload,
  PodcastAutoDelete,
  PodcastResumeRewind,
} from '../src/contexts/PreferencesContext';

type Option<T extends string | number> = { value: T; label: string };

function SectionHeader({ label, colors }: { label: string; colors: ReturnType<typeof useTheme>['colors'] }) {
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

function secondsLabel(seconds: number): string {
  return `${seconds} second${seconds === 1 ? '' : 's'}`;
}

function minutesLabel(minutes: number): string {
  return `${minutes} minute${minutes === 1 ? '' : 's'}`;
}

function speedLabel(speed: PlaybackSpeed): string {
  return `${speed}x`;
}

function deleteLabel(value: PodcastAutoDelete): string {
  switch (value) {
    case 'immediate': return 'Immediately after playing';
    case '1day': return 'After 1 day';
    case '3days': return 'After 3 days';
    case '7days': return 'After 7 days';
    default: return 'Off';
  }
}

function ToggleCard({ label, description, value, onValueChange }: {
  label: string;
  description: string;
  value: boolean;
  onValueChange: (v: boolean) => void;
}) {
  const { colors, styles } = useTheme();
  return (
    <Pressable
      onPress={() => {
        const next = !value;
        onValueChange(next);
        AccessibilityInfo.announceForAccessibility(`${label}, ${next ? 'on' : 'off'}.`);
      }}
      accessible
      accessibilityRole="switch"
      accessibilityLabel={`${label}. ${description}`}
      accessibilityState={{ checked: value }}
      style={({ pressed }) => [styles.cardSmall, {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 12,
        borderLeftWidth: 4,
        borderLeftColor: value ? colors.accent : colors.border,
      }, pressed && { opacity: 0.85 }]}
    >
      <View style={{ flex: 1 }}>
        <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text, marginBottom: 3 }}>
          {label}
        </Text>
        <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>
          {description}
        </Text>
      </View>
      <Switch
        value={value}
        onValueChange={onValueChange}
        trackColor={{ false: colors.border, true: colors.accent }}
        thumbColor="#FFFFFF"
        accessibilityElementsHidden
        importantForAccessibility="no-hide-descendants"
      />
    </Pressable>
  );
}

const SPEED_OPTIONS: Option<PlaybackSpeed>[] = [
  0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0,
].map((value) => ({ value: value as PlaybackSpeed, label: speedLabel(value as PlaybackSpeed) }));

const SKIP_BACK_OPTIONS: Option<number>[] = [5, 10, 15, 30].map((value) => ({
  value,
  label: secondsLabel(value),
}));

const SKIP_FWD_OPTIONS: Option<number>[] = [15, 30, 45, 60].map((value) => ({
  value,
  label: secondsLabel(value),
}));

const SLEEP_OPTIONS: Option<string>[] = [
  { value: 'off', label: 'Off' },
  ...[15, 30, 45, 60].map((value) => ({ value: String(value), label: minutesLabel(value) })),
];

const RESUME_REWIND_OPTIONS: Option<PodcastResumeRewind>[] = [
  { value: 0, label: 'Off' },
  ...[10, 15, 30].map((value) => ({ value: value as PodcastResumeRewind, label: secondsLabel(value) })),
];

const EQ_OPTIONS: Option<PodcastEQPreset>[] = [
  { value: 'flat', label: 'Flat' },
  { value: 'speech', label: 'Speech clarity' },
  { value: 'bassBoost', label: 'Bass boost' },
  { value: 'trebleBoost', label: 'Treble boost' },
];

const DOWNLOAD_OPTIONS: Option<PodcastAutoDownload>[] = [
  { value: 'off', label: 'Off' },
  { value: 'wifiOnly', label: 'Wi-Fi only' },
  { value: 'always', label: 'Always' },
];

const DELETE_OPTIONS: Option<PodcastAutoDelete>[] = [
  { value: 'off', label: 'Off' },
  { value: 'immediate', label: 'Immediately after playing' },
  { value: '1day', label: 'After 1 day' },
  { value: '3days', label: 'After 3 days' },
  { value: '7days', label: 'After 7 days' },
];

export default function PodcastSettings() {
  const { colors, styles } = useTheme();
  const prefs = usePreferences();
  const firstHeadingRef = useRef<Text | null>(null);
  const didFocusFirstHeadingRef = useRef(false);
  const sleepValue = prefs.podcastSleepTimer === null ? 'off' : String(prefs.podcastSleepTimer);
  const summary = `Default speed ${speedLabel(prefs.podcastSpeed)}. Skip back ${secondsLabel(prefs.podcastSkipBack)}. Skip forward ${secondsLabel(prefs.podcastSkipForward)}. Auto-play next episode ${prefs.podcastAutoPlay ? 'on' : 'off'}. Sleep timer ${prefs.podcastSleepTimer === null ? 'off' : minutesLabel(prefs.podcastSleepTimer)}. Resume rewind ${prefs.podcastResumeRewind === 0 ? 'off' : secondsLabel(prefs.podcastResumeRewind)}. Auto-delete played downloads ${deleteLabel(prefs.podcastAutoDelete)}.`;

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
    <Screen title="Podcasts" showSettings={false}>
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
              <Ionicons name="radio-outline" size={25} color={colors.accent} />
            </View>
            <View style={{ flex: 1 }}>
              <Text
                ref={firstHeadingRef}
                style={styles.cardTitle}
                accessibilityRole="header"
                accessibilityActions={[{ name: 'readPodcastSummary', label: 'Read Podcast Settings Summary' }]}
                onAccessibilityAction={(event) => {
                  if (event.nativeEvent.actionName === 'readPodcastSummary') {
                    AccessibilityInfo.announceForAccessibility(`Podcast settings. ${summary}`);
                  }
                }}
              >
                Podcast Settings
              </Text>
              <Text style={styles.cardMeta}>
                Defaults for playback, queue, audio, and downloads.
              </Text>
              <Text style={[styles.cardMeta, { marginTop: 4 }]}>
                You can still adjust playback per episode.
              </Text>
            </View>
          </View>
        </View>

        <SectionHeader label="Playback" colors={colors} />
        <SettingsPickerRow
          label="Default Speed"
          description="How fast episodes play when you start them."
          value={prefs.podcastSpeed}
          options={SPEED_OPTIONS}
          onSelect={(value) => {
            prefs.setPodcastSpeed(value);
            AccessibilityInfo.announceForAccessibility(`Default speed ${speedLabel(value)} selected.`);
          }}
        />
        <SettingsPickerRow
          label="Skip Back Time"
          description="How many seconds the skip-back button rewinds."
          value={prefs.podcastSkipBack}
          options={SKIP_BACK_OPTIONS}
          onSelect={(value) => {
            prefs.setPodcastSkipBack(value);
            AccessibilityInfo.announceForAccessibility(`Skip back ${secondsLabel(value)} selected.`);
          }}
        />
        <SettingsPickerRow
          label="Skip Forward Time"
          description="How many seconds the skip-forward button jumps ahead."
          value={prefs.podcastSkipForward}
          options={SKIP_FWD_OPTIONS}
          onSelect={(value) => {
            prefs.setPodcastSkipForward(value);
            AccessibilityInfo.announceForAccessibility(`Skip forward ${secondsLabel(value)} selected.`);
          }}
        />

        <SectionHeader label="Queue & Timer" colors={colors} />
        <ToggleCard
          label="Auto-Play Next Episode"
          description="When an episode finishes, automatically start the next one in your queue."
          value={prefs.podcastAutoPlay}
          onValueChange={prefs.setPodcastAutoPlay}
        />
        <SettingsPickerRow
          label="Default Sleep Timer"
          description="Automatically pause playback after this amount of time."
          value={sleepValue}
          options={SLEEP_OPTIONS}
          onSelect={(value) => {
            prefs.setPodcastSleepTimer(value === 'off' ? null : parseInt(value, 10));
            AccessibilityInfo.announceForAccessibility(`Sleep timer ${value === 'off' ? 'off' : minutesLabel(parseInt(value, 10))} selected.`);
          }}
        />
        <SettingsPickerRow<PodcastResumeRewind>
          label="Resume Rewind"
          description="Rewinds a few seconds when you resume a paused episode, so you do not miss context."
          value={prefs.podcastResumeRewind}
          options={RESUME_REWIND_OPTIONS}
          onSelect={(value) => {
            prefs.setPodcastResumeRewind(value);
            AccessibilityInfo.announceForAccessibility(`Resume rewind ${value === 0 ? 'off' : secondsLabel(value)} selected.`);
          }}
        />

        <SectionHeader label="Audio" colors={colors} />
        <ToggleCard
          label="Trim Silence"
          description="Skips over silent gaps in episodes to save time."
          value={prefs.podcastTrimSilence}
          onValueChange={prefs.setPodcastTrimSilence}
        />
        <ToggleCard
          label="Voice Enhancement"
          description="Boosts speech frequencies, making podcast voices clearer without raising overall volume."
          value={prefs.podcastVoiceBoost}
          onValueChange={prefs.setPodcastVoiceBoost}
        />
        <SettingsPickerRow
          label="EQ Preset"
          description="Flat is the default. Speech clarity helps talk shows. Bass and Treble suit different headphones."
          value={prefs.podcastEQ}
          options={EQ_OPTIONS}
          onSelect={(value) => {
            prefs.setPodcastEQ(value);
            AccessibilityInfo.announceForAccessibility(`${EQ_OPTIONS.find((option) => option.value === value)?.label ?? 'EQ preset'} selected.`);
          }}
        />

        <SectionHeader label="Downloads" colors={colors} />
        <SettingsPickerRow
          label="Auto-Download New Episodes"
          description="Automatically download new episodes so they play without buffering."
          value={prefs.podcastAutoDownload}
          options={DOWNLOAD_OPTIONS}
          onSelect={(value) => {
            prefs.setPodcastAutoDownload(value);
            AccessibilityInfo.announceForAccessibility(`${DOWNLOAD_OPTIONS.find((option) => option.value === value)?.label ?? 'Auto-download option'} selected.`);
          }}
        />
        <SettingsPickerRow
          label="Auto-Delete Played Downloads"
          description="Automatically remove downloaded episodes after you finish playing them."
          value={prefs.podcastAutoDelete}
          options={DELETE_OPTIONS}
          onSelect={(value) => {
            prefs.setPodcastAutoDelete(value);
            AccessibilityInfo.announceForAccessibility(`${deleteLabel(value)} selected for auto-delete played downloads.`);
          }}
        />

        <View
          style={[styles.cardSmall, {
            backgroundColor: colors.pill,
            borderWidth: 1,
            borderColor: colors.border,
            marginTop: 8,
          }]}
          accessible
          accessibilityLabel="Storage tip. Immediately after playing saves the most storage. Three days is a balanced choice if you sometimes replay episodes soon after listening."
        >
          <Text style={{ color: colors.pillText, fontSize: 14, lineHeight: 20, fontWeight: '800' }}>
            Storage tip
          </Text>
          <Text style={[styles.cardMeta, { marginTop: 2 }]}>
            “Immediately” saves the most storage. “After 3 days” is a balanced choice if you sometimes replay episodes soon after listening.
          </Text>
        </View>

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
