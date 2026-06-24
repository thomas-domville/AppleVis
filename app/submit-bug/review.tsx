import { useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActivityIndicator, Alert, Animated,
  findNodeHandle, Pressable, ScrollView, Text, View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useBugWizard, RECOGNITION_OPTIONS, type BugRecognition } from '../../src/contexts/BugWizardContext';
import { useAuth } from '../../src/contexts/AuthContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { submitBugForm } from '../../src/services/drupalForm';
import { ThankYouScreen } from '../submit-blog/review';
import { sounds } from '../../src/services/sounds';

export default function BugStep4() {
  const { colors }                            = useTheme();
  const router                                = useRouter();
  const { state, update, reset }              = useBugWizard();
  const { user }                              = useAuth();
  const { screenReaderEnabled, reduceMotion } = useAccessibilityPreferences();

  const headingRef  = useRef<Text>(null);
  const fadeAnim    = useRef(new Animated.Value(reduceMotion || screenReaderEnabled ? 1 : 0)).current;
  const [submitting, setSubmitting] = useState(false);
  const [submitted, setSubmitted]   = useState(false);

  useEffect(() => {
    if (!reduceMotion && !screenReaderEnabled) {
      Animated.timing(fadeAnim, { toValue: 1, duration: 350, useNativeDriver: true }).start();
    }
    if (screenReaderEnabled) {
      const id = setTimeout(() => {
        const node = findNodeHandle(headingRef.current);
        if (node) AccessibilityInfo.setAccessibilityFocus(node);
      }, 350);
      return () => clearTimeout(id);
    }
  }, []);

  const canSubmit = !!state.recognition;

  async function handleSubmit() {
    if (!user || !state.recognition) return;
    setSubmitting(true);
    try {
      const result = await submitBugForm({
        name:            user.name,
        email:           '',
        title:           state.title,
        appleFeedback:   state.appleFeedback,
        platform:        state.platform as 'iOS' | 'iPadOS' | 'macOS',
        softwareVersion: state.softwareVersion,
        canReproduce:    state.canReproduce as 'Yes, always' | 'Yes, sometimes' | 'No',
        description:     state.description,
        recognition:     state.recognition,
      });

      sounds.bookmarkSaved().catch(() => {});

      if (result.ok) {
        setSubmitted(true);
        AccessibilityInfo.announceForAccessibility('Bug report submitted successfully.');
      } else {
        Alert.alert(
          'Submission Failed',
          `${result.error}\n\nPlease try again or visit applevis.com/form/community-bug-report-form to submit via the web.`,
          [{ text: 'OK' }],
        );
      }
    } finally {
      setSubmitting(false);
    }
  }

  if (submitted) {
    return <ThankYouScreen type="bug" onDone={() => { reset(); router.replace('/(tabs)/discover' as any); }} />;
  }

  return (
    <ScrollView contentContainerStyle={{ padding: 20, paddingBottom: 60 }} showsVerticalScrollIndicator={false}>
      <Animated.View style={{ opacity: fadeAnim, transform: [{ translateY: fadeAnim.interpolate({ inputRange: [0,1], outputRange: [16,0] }) }] }}>

        {/* Back */}
        <Pressable onPress={() => router.back()} accessible accessibilityRole="button" accessibilityLabel="Back to bug description"
          style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', gap: 4, marginBottom: 20, opacity: pressed ? 0.7 : 1 })}>
          <Ionicons name="chevron-back" size={18} color={colors.accent} />
          <Text style={{ fontSize: 15, color: colors.accent, fontWeight: '600' }}>Back</Text>
        </Pressable>

        {/* Heading */}
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 8 }}>
          <View style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: colors.accent, justifyContent: 'center', alignItems: 'center' }} accessibilityElementsHidden>
            <Ionicons name="ribbon-outline" size={24} color="#fff" />
          </View>
          <Text ref={headingRef} accessibilityRole="header" style={{ fontSize: 24, fontWeight: '800', color: colors.text, flex: 1 }}>
            Recognition & review
          </Text>
        </View>
        <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 21, marginBottom: 24 }}>
          Review your report and choose how you'd like to be credited if your bug is featured.
        </Text>

        {/* Summary card */}
        <View style={{ backgroundColor: colors.card, borderRadius: 16, overflow: 'hidden', borderWidth: 1, borderColor: colors.border, marginBottom: 24 }}>
          <ReviewRow label="Platform"   value={state.platform}        icon="layers-outline" />
          <ReviewRow label="OS version" value={state.softwareVersion} icon="code-slash-outline" divider />
          <ReviewRow label="Bug title"  value={state.title}           icon="bug-outline" divider />
          {state.appleFeedback ? (
            <ReviewRow label="Apple Feedback" value={state.appleFeedback} icon="logo-apple" divider />
          ) : null}
          <ReviewRow label="Reproducible"  value={state.canReproduce}   icon="repeat-outline" divider />
          <View style={{ padding: 16, borderTopWidth: 1, borderTopColor: colors.border }}>
            <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8 }}>
              Description
            </Text>
            <Text style={{ fontSize: 14, color: colors.text, lineHeight: 22 }} numberOfLines={5}>
              {state.description.length > 240 ? state.description.slice(0, 240) + '…' : state.description}
            </Text>
            {state.description.length > 240 && (
              <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 4 }}>
                {state.description.length} characters total
              </Text>
            )}
          </View>
        </View>

        {/* Recognition picker */}
        <FieldLabel text="Recognition" required />
        <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 19, marginBottom: 12 }}>
          If your bug is featured in AppleVis content, how would you like to be credited?
        </Text>
        <View style={{ gap: 8, marginBottom: 28 }}>
          {RECOGNITION_OPTIONS.map((option: BugRecognition) => {
            const selected = state.recognition === option;
            return (
              <Pressable
                key={option}
                onPress={() => { sounds.pickerTick().catch(() => {}); update({ recognition: option }); }}
                accessible
                accessibilityRole="radio"
                accessibilityLabel={option}
                accessibilityState={{ selected }}
                style={({ pressed }) => ({
                  flexDirection: 'row', alignItems: 'center', gap: 12, padding: 14,
                  borderRadius: 14, borderWidth: 2,
                  borderColor: selected ? colors.accent : colors.border,
                  backgroundColor: selected ? `${colors.accent}12` : colors.card,
                  opacity: pressed ? 0.8 : 1,
                })}
              >
                <View style={{
                  width: 22, height: 22, borderRadius: 11, borderWidth: 2,
                  borderColor: selected ? colors.accent : colors.border,
                  backgroundColor: selected ? colors.accent : 'transparent',
                  justifyContent: 'center', alignItems: 'center',
                }} accessibilityElementsHidden>
                  {selected && <Ionicons name="checkmark" size={13} color="#fff" />}
                </View>
                <Text style={{ flex: 1, fontSize: 14, fontWeight: selected ? '700' : '400', color: selected ? colors.accent : colors.text, lineHeight: 20 }}>
                  {option}
                </Text>
              </Pressable>
            );
          })}
        </View>

        {/* Submit */}
        <Pressable
          onPress={() => void handleSubmit()}
          disabled={!canSubmit || submitting}
          accessible
          accessibilityRole="button"
          accessibilityLabel={submitting ? 'Submitting your bug report…' : 'Submit bug report to AppleVis'}
          accessibilityState={{ disabled: !canSubmit || submitting }}
          style={({ pressed }) => ({
            backgroundColor: canSubmit ? colors.accent : colors.border,
            borderRadius: 16, paddingVertical: 16,
            alignItems: 'center', flexDirection: 'row', justifyContent: 'center', gap: 8,
            opacity: pressed || submitting ? 0.85 : 1,
          })}
        >
          {submitting
            ? <ActivityIndicator color="#fff" />
            : <>
                <Ionicons name="send-outline" size={20} color={canSubmit ? '#fff' : colors.textSecondary} accessibilityElementsHidden />
                <Text style={{ fontSize: 17, fontWeight: '700', color: canSubmit ? '#fff' : colors.textSecondary }}>Submit Report</Text>
              </>
          }
        </Pressable>

        <Text style={{ fontSize: 12, color: colors.textSecondary, textAlign: 'center', marginTop: 10, lineHeight: 18 }}>
          Your report will be reviewed by the AppleVis community team.
        </Text>

      </Animated.View>
    </ScrollView>
  );
}

function ReviewRow({ label, value, icon, divider }: { label: string; value: string; icon: string; divider?: boolean }) {
  const { colors } = useTheme();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12, padding: 16, borderTopWidth: divider ? 1 : 0, borderTopColor: colors.border }}
      accessible accessibilityLabel={`${label}: ${value}`}>
      <View style={{ width: 36, height: 36, borderRadius: 10, backgroundColor: `${colors.accent}18`, justifyContent: 'center', alignItems: 'center' }} accessibilityElementsHidden>
        <Ionicons name={icon as any} size={18} color={colors.accent} />
      </View>
      <View style={{ flex: 1 }}>
        <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</Text>
        <Text style={{ fontSize: 15, color: colors.text, marginTop: 2, lineHeight: 21 }}>{value}</Text>
      </View>
    </View>
  );
}

function FieldLabel({ text, required }: { text: string; required?: boolean }) {
  const { colors } = useTheme();
  return (
    <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8 }}>
      {text}{required && <Text style={{ color: colors.accent }}> *</Text>}
    </Text>
  );
}
