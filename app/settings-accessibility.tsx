import { useEffect, useRef } from 'react';
import { AccessibilityInfo, findNodeHandle, Linking, Pressable, ScrollView, Switch, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { SettingsPickerRow } from '../src/components/SettingsPickerRow';
import { useTheme } from '../src/contexts/ThemeContext';
import { usePreferences } from '../src/contexts/PreferencesContext';
import { useAccessibilityPreferences } from '../src/hooks/useAccessibilityPreferences';
import type { AnnouncementLevel } from '../src/contexts/PreferencesContext';

type LevelOption = {
  id: AnnouncementLevel;
  label: string;
  badge: string;
  description: string;
  preview: string;
};

const LEVELS: LevelOption[] = [
  {
    id: 'simple',
    label: 'Simple',
    badge: 'Fastest',
    description: 'Title and content type only. Fast to scan; author, date, and comment count are a swipe away.',
    preview: '"iOS 18 VoiceOver Tips. Forum."',
  },
  {
    id: 'normal',
    label: 'Normal',
    badge: 'Recommended',
    description: 'Title plus author and comment count, giving useful context without the full date history.',
    preview: '"iOS 18 VoiceOver Tips. Forum. By JaneD. 14 comments."',
  },
  {
    id: 'all',
    label: 'All',
    badge: 'Most Detailed',
    description: 'Everything at once: title, author, comment count, posted date, and last comment time.',
    preview: '"iOS 18 VoiceOver Tips. Forum. By JaneD. 14 comments. Posted 2 days ago. Last comment 3 hours ago."',
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

function ToggleCard({
  label,
  description,
  value,
  onChange,
}: {
  label: string;
  description: string;
  value: boolean;
  onChange: (value: boolean) => void;
}) {
  const { colors, styles } = useTheme();
  return (
    <Pressable
      onPress={() => {
        const next = !value;
        onChange(next);
        AccessibilityInfo.announceForAccessibility(`${label}, ${next ? 'on' : 'off'}.`);
      }}
      accessible
      accessibilityRole="switch"
      accessibilityState={{ checked: value }}
      accessibilityLabel={`${label}. ${description}`}
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
        onValueChange={onChange}
        accessibilityElementsHidden
        importantForAccessibility="no-hide-descendants"
        trackColor={{ false: colors.border, true: colors.appleVisBlue }}
        thumbColor="#FFFFFF"
      />
    </Pressable>
  );
}

function IosStatusRow({
  label,
  value,
  description,
}: {
  label: string;
  value: boolean | null;
  description: string;
}) {
  const { colors, styles } = useTheme();
  const status = value === null ? 'Not available' : value ? 'On' : 'Off';
  const statusColor = value === null ? colors.textSecondary : value ? colors.accent : colors.textSecondary;

  return (
    <View
      style={[styles.cardSmall, {
        borderLeftWidth: 3,
        borderLeftColor: value ? colors.accent : colors.border,
      }]}
      accessible
      accessibilityLabel={`${label}. Controlled by iOS. Current status: ${status}. ${description}`}
    >
      <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 12 }}>
        <View
          style={{
            width: 34,
            height: 34,
            borderRadius: 9,
            backgroundColor: colors.pill,
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
          }}
          accessibilityElementsHidden
        >
          <Ionicons name={value ? 'checkmark-circle-outline' : 'settings-outline'} size={19} color={statusColor} />
        </View>
        <View style={{ flex: 1 }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, flexWrap: 'wrap', marginBottom: 3 }}>
            <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text }}>{label}</Text>
            <View style={{ backgroundColor: value ? colors.accent : colors.pill, borderRadius: 6, paddingHorizontal: 7, paddingVertical: 2 }}>
              <Text style={{ color: value ? colors.accentText : colors.pillText, fontSize: 11, fontWeight: '800' }}>
                {status}
              </Text>
            </View>
          </View>
          <Text style={[styles.cardMeta, { fontSize: 13, fontWeight: '700', color: colors.accent, marginBottom: 3 }]}>
            Controlled by iOS
          </Text>
          <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>
            {description}
          </Text>
        </View>
      </View>
    </View>
  );
}

export default function AccessibilitySettings() {
  const router = useRouter();
  const { colors, styles } = useTheme();
  const a11y = useAccessibilityPreferences();
  const {
    announcementLevel,
    setAnnouncementLevel,
    helpfulTipsEnabled,
    setHelpfulTipsEnabled,
    welcomeSummaryEnabled,
    setWelcomeSummaryEnabled,
    homeStartupBehavior,
    setHomeStartupBehavior,
    searchAutoFocusEnabled,
    setSearchAutoFocusEnabled,
  } = usePreferences();
  const firstHeadingRef = useRef<Text | null>(null);
  const didFocusFirstHeadingRef = useRef(false);
  const selectedLevel = LEVELS.find((level) => level.id === announcementLevel) ?? LEVELS[2];
  const accessibilitySummary = `VoiceOver detail level is ${selectedLevel.label}. AppleVis Tips are ${helpfulTipsEnabled ? 'on' : 'off'}. Welcome Summary is ${welcomeSummaryEnabled ? 'on' : 'off'}. Home Startup Behavior is ${homeStartupBehavior}. iOS settings such as Dynamic Type, Reduce Motion, Bold Text, Reduce Transparency, Invert Colors, VoiceOver, Switch Control, and Grayscale are followed automatically.`;

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
    <Screen title="Accessibility" showSettings={false}>
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
              <Ionicons name="accessibility-outline" size={25} color={colors.accent} />
            </View>
            <View style={{ flex: 1 }}>
              <Text
                ref={firstHeadingRef}
                style={styles.cardTitle}
                accessibilityRole="header"
                accessibilityActions={[{ name: 'readAccessibilitySummary', label: 'Read Accessibility Summary' }]}
                onAccessibilityAction={(event) => {
                  if (event.nativeEvent.actionName === 'readAccessibilitySummary') {
                    AccessibilityInfo.announceForAccessibility(`Accessibility settings. ${accessibilitySummary}`);
                  }
                }}
              >
                Accessibility Settings
              </Text>
              <Text style={styles.cardMeta}>
                AppleVis controls plus the iOS accessibility settings the app follows automatically.
              </Text>
            </View>
          </View>
        </View>

        <SectionHeader label="AppleVis Accessibility Controls" colors={colors} />
        <ToggleCard
          label="AppleVis Tips"
          description="Shows short contextual tips and friendly reminders where they can save time."
          value={helpfulTipsEnabled}
          onChange={setHelpfulTipsEnabled}
        />
        <ToggleCard
          label="Welcome Summary"
          description="Shows a brief Home update with new AppleVis activity since your last visit."
          value={welcomeSummaryEnabled}
          onChange={setWelcomeSummaryEnabled}
        />
        <SettingsPickerRow
          label="Home Startup Behavior"
          description="Controls how much sound and spoken announcement Home produces when you open or return to it."
          value={homeStartupBehavior}
          options={[
            { value: 'quiet',    label: 'Quiet' },
            { value: 'helpful',  label: 'Helpful' },
            { value: 'detailed', label: 'Detailed' },
          ]}
          onSelect={setHomeStartupBehavior}
        />
        <ToggleCard
          label="Auto-Focus Search Field"
          description="Automatically focuses and raises the keyboard when you open Search. Turn off if you prefer to get oriented on the screen first."
          value={searchAutoFocusEnabled}
          onChange={setSearchAutoFocusEnabled}
        />

        <SectionHeader label="VoiceOver Detail Level" colors={colors} />
        {LEVELS.map((opt) => {
          const isSelected = announcementLevel === opt.id;
          return (
            <Pressable
              key={opt.id}
              onPress={() => {
                setAnnouncementLevel(opt.id);
                AccessibilityInfo.announceForAccessibility(`${opt.label} VoiceOver detail level selected.`);
              }}
              accessible
              accessibilityRole="button"
              accessibilityState={{ selected: isSelected }}
              accessibilityLabel={`${opt.label}${isSelected ? ', selected' : ''}. ${opt.badge}. ${opt.description}`}
              accessibilityHint="Double tap to select. Use the Actions rotor to hear the sample."
              accessibilityActions={[{ name: 'readVoiceOverSample', label: 'Read VoiceOver Sample' }]}
              onAccessibilityAction={(event) => {
                if (event.nativeEvent.actionName === 'readVoiceOverSample') {
                  AccessibilityInfo.announceForAccessibility(`${opt.label} sample. VoiceOver reads: ${opt.preview}`);
                }
              }}
              style={({ pressed }) => [styles.cardSmall, {
                borderWidth: isSelected ? 2 : 1,
                borderColor: isSelected ? colors.accent : colors.border,
                borderLeftWidth: isSelected ? 5 : 3,
                borderLeftColor: isSelected ? colors.accent : colors.border,
                marginBottom: 10,
              }, pressed && { opacity: 0.85 }]}
            >
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 6, flexWrap: 'wrap' }}>
                <Text style={{ fontSize: 17, fontWeight: '800', color: colors.text }}>{opt.label}</Text>
                <View style={{
                  backgroundColor: isSelected ? colors.accent : colors.pill,
                  borderRadius: 8,
                  paddingHorizontal: 8,
                  paddingVertical: 2,
                }}>
                  <Text style={{ color: isSelected ? colors.accentText : colors.pillText, fontSize: 11, fontWeight: '800' }}>
                    {opt.badge}
                  </Text>
                </View>
                {isSelected && <Ionicons name="checkmark-circle" size={19} color={colors.accent} accessibilityElementsHidden />}
              </View>
              <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20, marginBottom: 10 }}>
                {opt.description}
              </Text>
              <View style={{ backgroundColor: colors.background, borderRadius: 8, padding: 10, borderWidth: 1, borderColor: colors.border }}>
                <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 4 }}>
                  VoiceOver reads
                </Text>
                <Text style={{ fontSize: 14, color: colors.text, lineHeight: 20, fontStyle: 'italic' }}>
                  {opt.preview}
                </Text>
              </View>
            </Pressable>
          );
        })}

        <Pressable
          onPress={() => router.push({ pathname: '/help-article', params: { articleId: 'accessibility-voiceover' } })}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Learn more about VoiceOver in AppleVis in Help"
          style={({ pressed }) => [
            styles.cardSmall,
            { flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 10 },
            pressed && { opacity: 0.85 },
          ]}
        >
          <Ionicons name="help-buoy-outline" size={18} color={colors.accent} accessibilityElementsHidden />
          <Text style={{ flex: 1, fontSize: 15, fontWeight: '600', color: colors.accent }}>
            Learn more about VoiceOver in AppleVis
          </Text>
          <Ionicons name="chevron-forward" size={16} color={colors.textSecondary} accessibilityElementsHidden />
        </Pressable>

        <SectionHeader label="Controlled by iOS" colors={colors} />
        <View
          style={[styles.cardSmall, {
            backgroundColor: colors.pill,
            borderWidth: 1,
            borderColor: colors.border,
          }]}
          accessible
          accessibilityLabel="These are not AppleVis switches. Change them in iPhone Settings, and AppleVis follows them automatically."
        >
          <Text style={{ color: colors.pillText, fontSize: 14, lineHeight: 20, fontWeight: '800' }}>
            These are not AppleVis switches.
          </Text>
          <Text style={[styles.cardMeta, { marginTop: 2 }]}>
            Change them in iPhone Settings. AppleVis detects and respects them automatically.
          </Text>
        </View>

        <IosStatusRow
          label="VoiceOver"
          value={a11y.screenReaderEnabled}
          description="When VoiceOver is on, AppleVis optimizes focus movement, headings, labels, actions, and spoken feedback."
        />
        <IosStatusRow
          label="Switch Control"
          value={a11y.switchControlEnabled}
          description="AppleVis uses standard buttons, headings, and rows so Switch Control can scan the interface predictably."
        />
        <IosStatusRow
          label="Dynamic Type"
          value={null}
          description="AppleVis text scales with your preferred iOS text size. React Native does not expose the exact current size on this screen."
        />
        <IosStatusRow
          label="Reduce Motion"
          value={a11y.reduceMotion}
          description="Animations are shortened or avoided when Reduce Motion is enabled."
        />
        <IosStatusRow
          label="Bold Text"
          value={a11y.boldText}
          description="Text appears bolder throughout AppleVis when Bold Text is enabled."
        />
        <IosStatusRow
          label="Reduce Transparency"
          value={a11y.reduceTransparency}
          description="AppleVis avoids transparency and blur treatments that may reduce readability."
        />
        <IosStatusRow
          label="Invert Colors"
          value={a11y.invertColors}
          description="AppleVis marks important images so iOS can handle inversion more appropriately."
        />
        <IosStatusRow
          label="Grayscale"
          value={a11y.grayscaleEnabled}
          description="AppleVis avoids relying only on color, using labels, badges, borders, and icons as backup cues."
        />
        <IosStatusRow
          label="Increase Contrast"
          value={null}
          description="iOS does not expose this status to AppleVis yet. For similar readability, choose High Contrast Light or High Contrast Dark in Appearance."
        />

        <Pressable
          onPress={() => Linking.openSettings().catch(() => {})}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Open iOS Settings"
          accessibilityHint="Opens iOS Settings, where you can change system accessibility options."
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
            <Ionicons name="settings-outline" size={19} color={colors.accent} />
          </View>
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text }}>Open iOS Settings</Text>
            <Text style={styles.cardMeta}>Change system accessibility options outside AppleVis.</Text>
          </View>
          <Ionicons name="open-outline" size={16} color={colors.textSecondary} accessibilityElementsHidden />
        </Pressable>

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
