import { useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActivityIndicator, Alert, Animated, Clipboard,
  findNodeHandle, KeyboardAvoidingView, Modal, PanResponder,
  Platform, Pressable, ScrollView, Text, TextInput, View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useWizard } from '../../src/contexts/SubmitWizardContext';
import { usePreferences } from '../../src/contexts/PreferencesContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { useAuth } from '../../src/contexts/AuthContext';
import { isAppleIntelligenceAvailable, summariseText } from '../../src/services/intelligenceService';
import { sounds } from '../../src/services/sounds';
import { api } from '../../src/services/api';

// ─── Step 5: Notes + Assessment + Submit ──────────────────────────────────────

// ── Picker options (match Drupal field values exactly) ────────────────────────

const VOICEOVER_OPTIONS = [
  'VoiceOver reads all page elements.',
  'VoiceOver reads most page elements.',
  'VoiceOver reads a few page elements.',
  'VoiceOver reads no page elements.',
  'Not applicable for this app.',
] as const;

const BUTTON_LABELLING_OPTIONS = [
  'All buttons are clearly labeled.',
  'Most buttons are clearly labeled.',
  'Few buttons are clearly labeled.',
  'No buttons are clearly labeled.',
] as const;

const USABILITY_OPTIONS = [
  'The app is fully accessible with VoiceOver and is easy to navigate and use.',
  'The app is fully accessible with VoiceOver, but the interface could be easier to navigate and use.',
  'The app is fully accessible with VoiceOver, but the interface makes the app very difficult to use.',
  'The app is fully accessible without the use of VoiceOver',
  'There are some minor accessibility issues with this app, but they are easy to deal with.',
  'There are some accessibility issues with this app, but it can still be used if you are willing to tolerate these issues and learn how to work around them.',
  'Some parts of the app are accessible with VoiceOver, but not enough to make it usable.',
  'The app is totally inaccessible.',
] as const;

const MACOS_VERSIONS = [
  'macOS Sequoia 15',
  'macOS Sonoma 14',
  'macOS Ventura 13',
] as const;

const TVOS_VERSIONS = [
  'tvOS 18',
  'tvOS 17',
  'tvOS 16',
] as const;

const A11Y_PLACEHOLDER: Record<string, string> = {
  ios:   'Describe what makes this app useful for blind and low-vision iPhone and iPad users — VoiceOver support, Switch Control, Dynamic Type, known issues, tips, etc.',
  macos: 'Describe VoiceOver on Mac, keyboard navigation, full keyboard access, known issues, and anything that benefits blind or low-vision Mac users.',
  tvos:  'Describe VoiceOver navigation, the remote control experience, spoken labels, and anything that benefits blind or low-vision Apple TV users.',
};

const SUMMARY_PLACEHOLDER: Record<string, string> = {
  ios:   '"Full VoiceOver support with meaningful labels throughout. Excellent Dynamic Type implementation…"',
  macos: '"Excellent VoiceOver on Mac with full keyboard navigation support…"',
  tvos:  '"Strong VoiceOver support for remote navigation…"',
};

// ─── WizardPicker ─────────────────────────────────────────────────────────────
// Full-width bottom-sheet picker for long accessibility assessment options.

type WizardPickerProps = {
  label:        string;
  value:        string;
  options:      readonly string[];
  onChange:     (v: string) => void;
  placeholder?: string;
};

function WizardPicker({ label, value, options, onChange, placeholder = 'Select an option…' }: WizardPickerProps) {
  const { colors }   = useTheme();
  const [open, setOpen] = useState(false);
  const sheetY = useRef(new Animated.Value(0)).current;

  const pan = useRef(
    PanResponder.create({
      onMoveShouldSetPanResponder: (_, { dy, dx }) => dy > 8 && dy > Math.abs(dx),
      onPanResponderMove:   (_, { dy }) => { if (dy > 0) sheetY.setValue(dy); },
      onPanResponderRelease: (_, { dy, vy }) => {
        if (dy > 80 || vy > 1.5) {
          Animated.timing(sheetY, { toValue: 600, duration: 200, useNativeDriver: true })
            .start(() => { sheetY.setValue(0); setOpen(false); });
        } else {
          Animated.spring(sheetY, { toValue: 0, useNativeDriver: true }).start();
        }
      },
      onPanResponderTerminate: () => {
        Animated.spring(sheetY, { toValue: 0, useNativeDriver: true }).start();
      },
    })
  ).current;

  const currentIdx = options.indexOf(value);

  function cycleBy(delta: 1 | -1) {
    const nextIdx = Math.max(0, Math.min(options.length - 1, currentIdx + delta));
    const next = options[nextIdx];
    if (next !== value) {
      sounds.pickerTick().catch(() => {});
      onChange(next);
      AccessibilityInfo.announceForAccessibility(`${label}: ${next}`);
    }
  }

  function select(option: string) {
    if (option !== value) sounds.pickerTick().catch(() => {});
    onChange(option);
    setOpen(false);
  }

  const isSet = !!value;

  return (
    <>
      <Pressable
        onPress={() => setOpen(true)}
        accessible
        accessibilityRole="adjustable"
        accessibilityLabel={label}
        accessibilityValue={{ text: value || placeholder }}
        accessibilityHint="Swipe up or down to change. Double-tap to see all options."
        onAccessibilityAction={({ nativeEvent }) => {
          if (nativeEvent.actionName === 'increment') cycleBy(1);
          if (nativeEvent.actionName === 'decrement') cycleBy(-1);
        }}
        style={({ pressed }) => ({
          flexDirection: 'row',
          alignItems: 'center',
          gap: 10,
          backgroundColor: colors.card,
          borderRadius: 12,
          borderWidth: 1.5,
          borderColor: isSet ? colors.accent : colors.border,
          padding: 14,
          marginBottom: 6,
          opacity: pressed ? 0.8 : 1,
        })}
      >
        <Text
          style={{ flex: 1, fontSize: 16, color: isSet ? colors.text : colors.textSecondary, lineHeight: 22 }}
          numberOfLines={2}
        >
          {value || placeholder}
        </Text>
        {isSet
          ? <Ionicons name="checkmark-circle" size={20} color={colors.accent} accessibilityElementsHidden />
          : <Ionicons name="chevron-down" size={16} color={colors.textSecondary} accessibilityElementsHidden />
        }
      </Pressable>

      <Modal
        visible={open}
        transparent
        animationType="slide"
        onRequestClose={() => setOpen(false)}
        accessibilityViewIsModal
      >
        <View style={{ flex: 1 }} onAccessibilityEscape={() => setOpen(false)}>
          <Pressable
            style={{ flex: 1, backgroundColor: 'rgba(0,0,0,0.45)' }}
            onPress={() => setOpen(false)}
            accessible
            accessibilityRole="button"
            accessibilityLabel="Close"
          />
          <Animated.View
            {...pan.panHandlers}
            style={{
              backgroundColor: colors.card,
              borderTopLeftRadius: 22,
              borderTopRightRadius: 22,
              paddingTop: 8,
              paddingBottom: 40,
              transform: [{ translateY: sheetY }],
            }}
          >
            {/* Drag handle */}
            <View
              style={{ width: 36, height: 4, borderRadius: 2, backgroundColor: colors.border, alignSelf: 'center', marginBottom: 14 }}
              accessible={false}
            />
            <Text
              accessibilityRole="header"
              style={{ fontSize: 17, fontWeight: '700', color: colors.text, paddingHorizontal: 20, marginBottom: 6 }}
            >
              {label}
            </Text>
            <ScrollView bounces={false} style={{ maxHeight: 440 }}>
              {options.map((option) => {
                const isSelected = option === value;
                return (
                  <Pressable
                    key={option}
                    onPress={() => select(option)}
                    accessible
                    accessibilityRole="button"
                    accessibilityLabel={option}
                    accessibilityState={{ selected: isSelected }}
                    style={({ pressed }) => ({
                      flexDirection: 'row',
                      alignItems: 'flex-start',
                      paddingHorizontal: 20,
                      paddingVertical: 14,
                      backgroundColor: pressed
                        ? colors.border
                        : isSelected
                          ? `${colors.accent}18`
                          : 'transparent',
                    })}
                  >
                    <Text
                      style={{
                        flex: 1,
                        fontSize: 16,
                        color: isSelected ? colors.accent : colors.text,
                        fontWeight: isSelected ? '600' : '400',
                        lineHeight: 23,
                        paddingRight: 10,
                      }}
                    >
                      {option}
                    </Text>
                    {isSelected && (
                      <Ionicons name="checkmark" size={20} color={colors.accent} accessibilityElementsHidden style={{ marginTop: 2 }} />
                    )}
                  </Pressable>
                );
              })}
            </ScrollView>
          </Animated.View>
        </View>
      </Modal>
    </>
  );
}

// ─── Helper sub-components ────────────────────────────────────────────────────

function SectionHeader({ label }: { label: string }) {
  const { colors } = useTheme();
  return (
    <View
      style={{ flexDirection: 'row', alignItems: 'center', marginTop: 24, marginBottom: 16 }}
      accessible
      accessibilityRole="header"
    >
      <View style={{ flex: 1, height: 1, backgroundColor: colors.border }} />
      <Text style={{ marginHorizontal: 10, fontSize: 11, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 1 }}>
        {label}
      </Text>
      <View style={{ flex: 1, height: 1, backgroundColor: colors.border }} />
    </View>
  );
}

function FieldLabel({ text, required, hint }: { text: string; required?: boolean; hint?: string }) {
  const { colors } = useTheme();
  return (
    <View style={{ marginBottom: hint ? 4 : 8 }}>
      <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.5 }}>
        {text}{required && <Text style={{ color: colors.accent }}> *</Text>}
      </Text>
      {hint && (
        <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 19, marginTop: 4, marginBottom: 8 }}>
          {hint}
        </Text>
      )}
    </View>
  );
}

// ─── Main screen ──────────────────────────────────────────────────────────────

export default function NotesScreen() {
  const { colors }                     = useTheme();
  const router                         = useRouter();
  const { state, update }              = useWizard();
  const { user }                       = useAuth();
  const { aiSummariesEnabled }         = usePreferences();
  const { screenReaderEnabled, reduceMotion } = useAccessibilityPreferences();

  const headingRef   = useRef<Text>(null);
  const contentAnim  = useRef(new Animated.Value(0)).current;

  const [aiDrafting, setAiDrafting] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  const platform    = state.platform ?? 'ios';
  const meta        = state.fullMeta;
  const aiAvailable = aiSummariesEnabled && isAppleIntelligenceAvailable();

  // ── Auto-fill iOS version ───────────────────────────────────────────────────

  useEffect(() => {
    if (platform === 'ios' && !state.osVersion && Platform.OS === 'ios') {
      update({ osVersion: String(Platform.Version) });
    }
  }, []);

  // ── Entrance animation ──────────────────────────────────────────────────────

  useEffect(() => {
    if (reduceMotion || screenReaderEnabled) {
      contentAnim.setValue(1);
    } else {
      Animated.timing(contentAnim, { toValue: 1, duration: 360, useNativeDriver: true }).start();
    }
    if (screenReaderEnabled) {
      const id = setTimeout(() => {
        const node = findNodeHandle(headingRef.current);
        if (node) AccessibilityInfo.setAccessibilityFocus(node);
      }, 350);
      return () => clearTimeout(id);
    }
  }, []);

  // ── AI draft ───────────────────────────────────────────────────────────────

  async function handleAiDraft() {
    if (!meta) return;
    setAiDrafting(true);
    try {
      const platformHint = platform === 'macos' ? 'Mac' : platform === 'tvos' ? 'Apple TV' : 'iPhone and iPad';
      const desc = meta.appStoreDescription.slice(0, 600);
      const text = await summariseText(
        `Write a 2-sentence accessibility-focused summary for "${meta.appName}" by ${meta.developerName} on ${platformHint}. ` +
        `Highlight features that benefit blind and low-vision users. App description: ${desc}`
      );
      if (text) {
        update({ shortSummary: text });
      } else {
        AccessibilityInfo.announceForAccessibility('Could not generate summary. Please try again.');
      }
    } catch {
      AccessibilityInfo.announceForAccessibility('Apple Intelligence unavailable.');
    } finally {
      setAiDrafting(false);
    }
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  async function handleSubmit() {
    if (!canSubmit || !meta || !user) return;
    setSubmitting(true);

    try {
      const result = await api.apps.submitApp(
        {
          appName:               meta.appName,
          appStoreUrl:           meta.appStoreUrl,
          appVersion:            meta.version,
          price:                 meta.price,
          supportedDevices:      meta.supportedDevices,
          appStoreDescription:   meta.appStoreDescription,
          category:              meta.category,
          osVersion:             state.osVersion,
          voiceOverPerformance:  state.voiceOverPerformance,
          buttonLabelling:       state.buttonLabelling,
          usabilityNotes:        state.usabilityNotes,
          accessibilityComments: state.accessibilityComments,
          otherComments:         state.otherComments,
          shortSummary:          state.shortSummary,
        },
        user.csrfToken,
      );

      sounds.bookmarkSaved().catch(() => {});

      if (result.ok) {
        Alert.alert(
          'Submission Received!',
          `Thank you! Your entry for ${meta.appName} has been submitted to AppleVis for review. It will appear in the App Directory once approved.`,
          [{ text: 'Done', onPress: () => router.replace('/(tabs)/discover' as any) }],
        );
      } else {
        // Native submission failed — fall back to clipboard + web form.
        Clipboard.setString(state.accessibilityComments.trim());
        Alert.alert(
          'Complete on the Web',
          `Could not submit directly (${result.error}).\n\nYour accessibility comments have been copied to the clipboard. The AppleVis web form will open — paste them in the Accessibility Comments field to finish.`,
          [
            { text: 'Cancel', style: 'cancel' },
            {
              text: 'Open Web Form',
              onPress: () => {
                void import('expo-linking').then(({ default: Linking }) =>
                  Linking.openURL('https://www.applevis.com/node/add/ios_app_directory').catch(() =>
                    AccessibilityInfo.announceForAccessibility('Could not open the web form.')
                  )
                );
                router.replace('/(tabs)/discover' as any);
              },
            },
          ],
        );
      }
    } finally {
      setSubmitting(false);
    }
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  const charCount = state.accessibilityComments.trim().length;
  const canSubmit =
    !!meta &&
    !!user &&
    charCount >= 20 &&
    !!state.osVersion.trim() &&
    !!state.voiceOverPerformance &&
    !!state.buttonLabelling &&
    !!state.usabilityNotes;

  const missingCount = [
    !state.osVersion.trim(),
    !state.voiceOverPerformance,
    !state.buttonLabelling,
    !state.usabilityNotes,
    charCount < 20,
  ].filter(Boolean).length;

  const osVersionLabel =
    platform === 'macos' ? 'macOS version you tested on' :
    platform === 'tvos'  ? 'tvOS version you tested on'  :
    'iOS / iPadOS version you tested on';

  const appLabel = meta?.appName ?? state.searchHit?.appName ?? 'this app';

  return (
    <KeyboardAvoidingView
      style={{ flex: 1 }}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      keyboardVerticalOffset={100}
    >
      <ScrollView
        contentContainerStyle={{ padding: 20, paddingBottom: 60 }}
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
      >
        <Animated.View style={{
          opacity: contentAnim,
          transform: [{ translateY: contentAnim.interpolate({ inputRange: [0, 1], outputRange: [18, 0] }) }],
        }}>

          {/* ── Back ────────────────────────────────────────────────────────── */}
          <Pressable
            onPress={() => router.back()}
            accessible
            accessibilityRole="button"
            accessibilityLabel="Back to app confirmation"
            style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', gap: 4, marginBottom: 20, opacity: pressed ? 0.7 : 1 })}
          >
            <Ionicons name="chevron-back" size={18} color={colors.accent} />
            <Text style={{ fontSize: 15, color: colors.accent, fontWeight: '600' }}>Back</Text>
          </Pressable>

          {/* ── Heading ─────────────────────────────────────────────────────── */}
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 8 }}>
            <View
              style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: colors.accent, justifyContent: 'center', alignItems: 'center' }}
              accessibilityElementsHidden
            >
              <Ionicons name="accessibility-outline" size={24} color="#fff" />
            </View>
            <Text
              ref={headingRef}
              style={{ fontSize: 26, fontWeight: '800', color: colors.text, flex: 1, lineHeight: 32 }}
              accessibilityRole="header"
            >
              Your experience
            </Text>
          </View>
          <Text style={{ fontSize: 15, color: colors.textSecondary, lineHeight: 22, marginBottom: 2 }}>
            Tell the community about the accessibility of{' '}
            <Text style={{ fontWeight: '700', color: colors.text }}>{appLabel}</Text>.
          </Text>

          {/* Progress hint for VoiceOver */}
          {!canSubmit && missingCount > 0 && (
            <Text
              style={{ fontSize: 13, color: colors.textSecondary, marginTop: 6 }}
              accessibilityLiveRegion="polite"
            >
              {missingCount} required field{missingCount === 1 ? '' : 's'} remaining
            </Text>
          )}

          {/* ════════════════════════════════════════════════════════════════ */}
          {/* Section: Version Tested                                         */}
          {/* ════════════════════════════════════════════════════════════════ */}
          <SectionHeader label="Version Tested" />

          <FieldLabel
            text={osVersionLabel}
            required
            hint={platform === 'ios'
              ? 'Pre-filled from your device. Edit if you tested on a different version.'
              : `Select the ${platform === 'macos' ? 'macOS' : 'tvOS'} version you tested this app on.`
            }
          />

          {platform === 'ios' ? (
            <TextInput
              style={{
                backgroundColor: colors.card,
                borderRadius: 12, paddingHorizontal: 14, paddingVertical: 12,
                fontSize: 17, color: colors.text,
                borderWidth: 1.5,
                borderColor: state.osVersion ? colors.accent : colors.border,
                marginBottom: 6,
              }}
              value={state.osVersion}
              onChangeText={v => update({ osVersion: v })}
              placeholder="e.g. 18.1"
              placeholderTextColor={colors.textSecondary}
              keyboardType="decimal-pad"
              returnKeyType="done"
              accessible
              accessibilityLabel={osVersionLabel}
              accessibilityHint="Auto-filled with your current iOS version"
            />
          ) : platform === 'macos' ? (
            <WizardPicker
              label={osVersionLabel}
              value={state.osVersion}
              options={MACOS_VERSIONS}
              onChange={v => update({ osVersion: v })}
              placeholder="Select macOS version…"
            />
          ) : (
            <WizardPicker
              label={osVersionLabel}
              value={state.osVersion}
              options={TVOS_VERSIONS}
              onChange={v => update({ osVersion: v })}
              placeholder="Select tvOS version…"
            />
          )}

          {/* ════════════════════════════════════════════════════════════════ */}
          {/* Section: Accessibility Assessment                               */}
          {/* ════════════════════════════════════════════════════════════════ */}
          <SectionHeader label="Accessibility Assessment" />

          {/* VoiceOver Performance */}
          <FieldLabel
            text="VoiceOver Performance"
            required
            hint="Select the option that best describes how well VoiceOver works with this app."
          />
          <WizardPicker
            label="VoiceOver Performance"
            value={state.voiceOverPerformance}
            options={VOICEOVER_OPTIONS}
            onChange={v => update({ voiceOverPerformance: v })}
            placeholder="Select VoiceOver performance…"
          />

          {/* Button Labeling */}
          <View style={{ marginTop: 8 }}>
            <FieldLabel
              text="Button Labeling"
              required
              hint="Select the option that best describes the labelling of buttons in this app."
            />
            <WizardPicker
              label="Button Labeling"
              value={state.buttonLabelling}
              options={BUTTON_LABELLING_OPTIONS}
              onChange={v => update({ buttonLabelling: v })}
              placeholder="Select button labeling…"
            />
          </View>

          {/* Usability */}
          <View style={{ marginTop: 8 }}>
            <FieldLabel
              text="Usability"
              required
              hint="Select the description that most closely matches your experience using this app."
            />
            <WizardPicker
              label="Usability"
              value={state.usabilityNotes}
              options={USABILITY_OPTIONS}
              onChange={v => update({ usabilityNotes: v })}
              placeholder="Select usability rating…"
            />
          </View>

          {/* ════════════════════════════════════════════════════════════════ */}
          {/* Section: Your Description                                       */}
          {/* ════════════════════════════════════════════════════════════════ */}
          <SectionHeader label="Your Description" />

          {/* Accessibility Comments */}
          <FieldLabel
            text="Accessibility Comments"
            required
            hint="Please give a summary of how the app performs from an accessibility perspective. Be sure to give enough detail so that others will be able to make an informed judgement on whether they will be able to use the app."
          />

          <TextInput
            style={{
              backgroundColor: colors.card,
              borderRadius: 14, padding: 14,
              fontSize: 16, color: colors.text,
              borderWidth: 1.5,
              borderColor: charCount >= 20 ? colors.accent : colors.border,
              minHeight: 160,
              textAlignVertical: 'top',
              marginBottom: 4,
            }}
            value={state.accessibilityComments}
            onChangeText={v => update({ accessibilityComments: v })}
            placeholder={A11Y_PLACEHOLDER[platform]}
            placeholderTextColor={colors.textSecondary}
            multiline
            accessible
            accessibilityLabel="Accessibility Comments"
            accessibilityHint="Required. Minimum 20 characters. Describe this app's accessibility for blind and low-vision users."
          />

          <View
            style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}
            accessibilityElementsHidden
          >
            <Text style={{ fontSize: 12, color: colors.textSecondary }}>
              {charCount < 20 ? `${20 - charCount} more character${20 - charCount === 1 ? '' : 's'} required` : 'Minimum reached ✓'}
            </Text>
            <Text style={{ fontSize: 12, color: charCount >= 20 ? colors.accent : colors.textSecondary, fontWeight: '600' }}>
              {charCount} chars
            </Text>
          </View>

          {/* Other Comments */}
          <FieldLabel
            text="Other Comments"
            hint="Provide any general comments on this app that are not related to its accessibility, but might be of interest to others."
          />

          <TextInput
            style={{
              backgroundColor: colors.card,
              borderRadius: 14, padding: 14,
              fontSize: 16, color: colors.text,
              borderWidth: 1.5, borderColor: colors.border,
              minHeight: 100,
              textAlignVertical: 'top',
              marginBottom: 4,
            }}
            value={state.otherComments}
            onChangeText={v => update({ otherComments: v })}
            placeholder="Any non-accessibility comments that might interest the community…"
            placeholderTextColor={colors.textSecondary}
            multiline
            accessible
            accessibilityLabel="Other Comments"
            accessibilityHint="Optional. General comments not related to accessibility."
          />

          {/* ════════════════════════════════════════════════════════════════ */}
          {/* Section: Short Summary                                          */}
          {/* ════════════════════════════════════════════════════════════════ */}
          <SectionHeader label="Short Summary" />

          <FieldLabel
            text="One or two sentences (optional)"
            hint="A brief headline for the AppleVis listing — the accessibility story in a sentence."
          />

          <TextInput
            style={{
              backgroundColor: colors.card,
              borderRadius: 14, padding: 14,
              fontSize: 16, color: colors.text,
              borderWidth: 1.5, borderColor: colors.border,
              minHeight: 88,
              textAlignVertical: 'top',
              marginBottom: 10,
            }}
            value={state.shortSummary}
            onChangeText={v => update({ shortSummary: v })}
            placeholder={SUMMARY_PLACEHOLDER[platform]}
            placeholderTextColor={colors.textSecondary}
            multiline
            accessible
            accessibilityLabel="Short Summary"
            accessibilityHint="Optional. A brief headline for the AppleVis listing."
          />

          {aiAvailable && meta && (
            <Pressable
              onPress={() => void handleAiDraft()}
              disabled={aiDrafting}
              accessible
              accessibilityRole="button"
              accessibilityLabel={aiDrafting ? 'Drafting summary with Apple Intelligence…' : 'Draft summary with Apple Intelligence'}
              style={({ pressed }) => ({
                flexDirection: 'row', alignItems: 'center', gap: 8,
                alignSelf: 'flex-start',
                backgroundColor: colors.card,
                borderRadius: 20, paddingVertical: 9, paddingHorizontal: 14,
                borderWidth: 1.5, borderColor: colors.border,
                marginBottom: 28,
                opacity: pressed || aiDrafting ? 0.7 : 1,
              })}
            >
              {aiDrafting
                ? <ActivityIndicator size="small" color={colors.accent} />
                : <Ionicons name="sparkles" size={15} color={colors.accent} />
              }
              <Text style={{ fontSize: 14, fontWeight: '600', color: colors.accent }}>
                {aiDrafting ? 'Drafting…' : 'Draft with Apple Intelligence'}
              </Text>
            </Pressable>
          )}

          {/* ── Submit ────────────────────────────────────────────────────── */}
          <Pressable
            onPress={() => void handleSubmit()}
            disabled={!canSubmit || submitting}
            accessible
            accessibilityRole="button"
            accessibilityLabel={canSubmit ? 'Submit App Entry' : `Submit App Entry — ${missingCount} required field${missingCount === 1 ? '' : 's'} remaining`}
            accessibilityHint={canSubmit ? 'Submits your app entry to AppleVis for review' : undefined}
            accessibilityState={{ disabled: !canSubmit || submitting }}
            style={({ pressed }) => ({
              backgroundColor: canSubmit ? colors.accent : colors.border,
              borderRadius: 16, paddingVertical: 16,
              alignItems: 'center', flexDirection: 'row', justifyContent: 'center', gap: 8,
              opacity: pressed ? 0.85 : 1,
            })}
          >
            {submitting
              ? <ActivityIndicator color="#fff" />
              : <>
                  <Ionicons
                    name="checkmark-circle-outline"
                    size={20}
                    color={canSubmit ? '#fff' : colors.textSecondary}
                    accessibilityElementsHidden
                  />
                  <Text style={{ color: canSubmit ? '#fff' : colors.textSecondary, fontSize: 17, fontWeight: '700' }}>
                    Submit App Entry
                  </Text>
                </>
            }
          </Pressable>

          {!canSubmit && (
            <Text
              style={{ fontSize: 13, color: colors.textSecondary, textAlign: 'center', marginTop: 8 }}
              accessibilityElementsHidden
            >
              Complete all required fields (*) to submit
            </Text>
          )}

          <Text style={{ fontSize: 12, color: colors.textSecondary, textAlign: 'center', marginTop: canSubmit ? 10 : 4, lineHeight: 18 }}>
            Your entry will be submitted directly to AppleVis for review.{'\n'}It will appear in the App Directory once approved.
          </Text>
        </Animated.View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
