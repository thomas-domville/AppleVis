import { Pressable, ScrollView, Switch, Text, View } from 'react-native';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { usePreferences } from '../src/contexts/PreferencesContext';
import type { PlaybackSpeed, PodcastEQPreset, PodcastAutoDownload, PodcastAutoDelete } from '../src/contexts/PreferencesContext';

function SectionHeader({ label, colors }: { label: string; colors: ReturnType<typeof useTheme>['colors'] }) {
  return (
    <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
      textTransform: 'uppercase', letterSpacing: 0.8, marginTop: 20, marginBottom: 8 }}
      accessibilityRole="header">{label}</Text>
  );
}

function ToggleRow({ label, description, value, onValueChange, colors, styles }: {
  label: string; description: string; value: boolean;
  onValueChange: (v: boolean) => void;
  colors: ReturnType<typeof useTheme>['colors'];
  styles: ReturnType<typeof useTheme>['styles'];
}) {
  return (
    <View style={[styles.cardSmall, { flexDirection: 'row', alignItems: 'center', gap: 12 }]}
      accessible
      accessibilityLabel={`${label}. ${description}. ${value ? 'On' : 'Off'}.`}
      accessibilityRole="switch"
      accessibilityState={{ checked: value }}>
      <View style={{ flex: 1 }}>
        <Text style={{ fontSize: 16, fontWeight: '600', color: colors.text }}>{label}</Text>
        <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 18, marginTop: 2 }}>{description}</Text>
      </View>
      <Switch
        value={value}
        onValueChange={onValueChange}
        trackColor={{ false: colors.border, true: colors.accent }}
        thumbColor="#FFFFFF"
        accessibilityElementsHidden
      />
    </View>
  );
}

function PickerRow<T extends string | number>({ label, description, value, options, onSelect, colors, styles }: {
  label: string; description: string; value: T;
  options: { value: T; label: string }[];
  onSelect: (v: T) => void;
  colors: ReturnType<typeof useTheme>['colors'];
  styles: ReturnType<typeof useTheme>['styles'];
}) {
  return (
    <View style={styles.cardSmall}>
      <Text style={{ fontSize: 16, fontWeight: '600', color: colors.text, marginBottom: 4 }}>{label}</Text>
      <Text style={{ fontSize: 13, color: colors.textSecondary, marginBottom: 10 }}>{description}</Text>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
        {options.map((opt) => {
          const isSelected = opt.value === value;
          return (
            <Pressable
              key={String(opt.value)}
              onPress={() => onSelect(opt.value)}
              accessible accessibilityRole="none"
              accessibilityState={{ selected: isSelected }}
              accessibilityLabel={`${opt.label}${isSelected ? ', selected' : ''}`}
              style={{
                paddingHorizontal: 14, paddingVertical: 8, borderRadius: 999,
                backgroundColor: isSelected ? colors.accent : colors.pill,
              }}
            >
              <Text style={{ color: isSelected ? colors.accentText : colors.pillText,
                fontWeight: '600', fontSize: 14 }}>{opt.label}</Text>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

const SPEED_OPTIONS: { value: PlaybackSpeed; label: string }[] = [
  { value: 0.5,  label: '0.5×' }, { value: 0.75, label: '0.75×' },
  { value: 1.0,  label: '1.0×' }, { value: 1.25, label: '1.25×' },
  { value: 1.5,  label: '1.5×' }, { value: 1.75, label: '1.75×' },
  { value: 2.0,  label: '2.0×' }, { value: 2.5,  label: '2.5×'  },
  { value: 3.0,  label: '3.0×' },
];

const SKIP_BACK_OPTIONS   = [{ value: 5, label: '5s' }, { value: 10, label: '10s' }, { value: 15, label: '15s' }, { value: 30, label: '30s' }];
const SKIP_FWD_OPTIONS    = [{ value: 15, label: '15s' }, { value: 30, label: '30s' }, { value: 45, label: '45s' }, { value: 60, label: '60s' }];
const EQ_OPTIONS: { value: PodcastEQPreset; label: string }[] = [
  { value: 'flat', label: 'Flat' }, { value: 'speech', label: 'Speech' },
  { value: 'bassBoost', label: 'Bass' }, { value: 'trebleBoost', label: 'Treble' },
];
const DOWNLOAD_OPTIONS: { value: PodcastAutoDownload; label: string }[] = [
  { value: 'off', label: 'Off' }, { value: 'wifiOnly', label: 'Wi-Fi Only' }, { value: 'always', label: 'Always' },
];
const DELETE_OPTIONS: { value: PodcastAutoDelete; label: string }[] = [
  { value: 'off', label: 'Off' }, { value: '1day', label: '1 day' }, { value: '1week', label: '1 week' },
];

export default function PodcastSettings() {
  const { colors, styles } = useTheme();
  const prefs = usePreferences();

  return (
    <Screen title="Podcasts" showSettings={false}>
      <ScrollView showsVerticalScrollIndicator={false}>
        <Text style={styles.lede}>
          Set your defaults for every episode. You can still adjust speed and sleep timer
          during playback -- these settings restore on the next episode.
        </Text>

        <SectionHeader label="Playback" colors={colors} />
        <PickerRow label="Default Speed" description="How fast episodes play when you start them."
          value={prefs.podcastSpeed} options={SPEED_OPTIONS} onSelect={prefs.setPodcastSpeed}
          colors={colors} styles={styles} />
        <PickerRow label="Skip Back Time" description="How many seconds the skip-back button rewinds."
          value={prefs.podcastSkipBack} options={SKIP_BACK_OPTIONS} onSelect={prefs.setPodcastSkipBack}
          colors={colors} styles={styles} />
        <PickerRow label="Skip Forward Time" description="How many seconds the skip-forward button jumps ahead."
          value={prefs.podcastSkipForward} options={SKIP_FWD_OPTIONS} onSelect={prefs.setPodcastSkipForward}
          colors={colors} styles={styles} />

        <SectionHeader label="Queue & Timer" colors={colors} />
        <ToggleRow label="Auto-Play Next Episode"
          description="When an episode finishes, automatically start the next one in your queue."
          value={prefs.podcastAutoPlay} onValueChange={prefs.setPodcastAutoPlay}
          colors={colors} styles={styles} />
        <PickerRow<string> label="Default Sleep Timer"
          description="Automatically pause playback after this amount of time."
          value={prefs.podcastSleepTimer === null ? 'off' : String(prefs.podcastSleepTimer)}
          options={[{ value: 'off', label: 'Off' }, { value: '15', label: '15m' }, { value: '30', label: '30m' }, { value: '45', label: '45m' }, { value: '60', label: '60m' }]}
          onSelect={(v) => prefs.setPodcastSleepTimer(v === 'off' ? null : parseInt(v, 10))}
          colors={colors} styles={styles} />

        <SectionHeader label="Audio" colors={colors} />
        <ToggleRow label="Trim Silence"
          description="Skips over silent gaps in episodes to save time. Requires a future native update to take effect."
          value={prefs.podcastTrimSilence} onValueChange={prefs.setPodcastTrimSilence}
          colors={colors} styles={styles} />
        <ToggleRow label="Voice Enhancement"
          description="Boosts speech frequencies -- makes podcast voices clearer without raising overall volume."
          value={prefs.podcastVoiceBoost} onValueChange={prefs.setPodcastVoiceBoost}
          colors={colors} styles={styles} />
        <PickerRow label="EQ Preset"
          description="Flat is the default. Speech boosts clarity for talk shows. Bass and Treble suit different headphones."
          value={prefs.podcastEQ} options={EQ_OPTIONS} onSelect={prefs.setPodcastEQ}
          colors={colors} styles={styles} />

        <SectionHeader label="Downloads" colors={colors} />
        <PickerRow label="Auto-Download New Episodes"
          description="Automatically download new episodes so they play without buffering."
          value={prefs.podcastAutoDownload} options={DOWNLOAD_OPTIONS} onSelect={prefs.setPodcastAutoDownload}
          colors={colors} styles={styles} />
        <PickerRow label="Auto-Delete Played Episodes"
          description="Automatically remove downloaded episodes after you finish them."
          value={prefs.podcastAutoDelete} options={DELETE_OPTIONS} onSelect={prefs.setPodcastAutoDelete}
          colors={colors} styles={styles} />

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
