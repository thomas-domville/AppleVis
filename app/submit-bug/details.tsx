import { useEffect, useRef } from 'react';
import {
  AccessibilityInfo, Animated, findNodeHandle,
  KeyboardAvoidingView, Platform, Pressable, ScrollView,
  Text, TextInput, View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useBugWizard, REPRODUCIBLE_OPTIONS, type BugReproducible } from '../../src/contexts/BugWizardContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { sounds } from '../../src/services/sounds';

const REPRODUCE_ICONS: Record<string, string> = {
  'Yes, always':    'alert-circle-outline',
  'Yes, sometimes': 'help-circle-outline',
  'No':             'close-circle-outline',
};

const REPRODUCE_COLORS: Record<string, string> = {
  'Yes, always':    '#ef4444',
  'Yes, sometimes': '#f59e0b',
  'No':             '#6b7280',
};

export default function BugStep2() {
  const { colors }                            = useTheme();
  const router                                = useRouter();
  const { state, update }                     = useBugWizard();
  const { screenReaderEnabled, reduceMotion } = useAccessibilityPreferences();

  const headingRef = useRef<Text>(null);
  const fadeAnim   = useRef(new Animated.Value(reduceMotion || screenReaderEnabled ? 1 : 0)).current;

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

  const canContinue = !!state.title.trim() && !!state.canReproduce;

  function handleContinue() {
    sounds.articleOpen().catch(() => {});
    router.push('/submit-bug/description' as any);
  }

  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined} keyboardVerticalOffset={100}>
      <ScrollView
        contentContainerStyle={{ padding: 20, paddingBottom: 60 }}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
      >
        <Animated.View style={{ opacity: fadeAnim, transform: [{ translateY: fadeAnim.interpolate({ inputRange: [0,1], outputRange: [16,0] }) }] }}>

          {/* Back */}
          <Pressable onPress={() => router.back()} accessible accessibilityRole="button" accessibilityLabel="Back to platform and version"
            style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', gap: 4, marginBottom: 20, opacity: pressed ? 0.7 : 1 })}>
            <Ionicons name="chevron-back" size={18} color={colors.accent} />
            <Text style={{ fontSize: 15, color: colors.accent, fontWeight: '600' }}>Back</Text>
          </Pressable>

          {/* Heading */}
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 8 }}>
            <View style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: colors.accent, justifyContent: 'center', alignItems: 'center' }} accessibilityElementsHidden>
              <Ionicons name="information-circle-outline" size={24} color="#fff" />
            </View>
            <Text ref={headingRef} accessibilityRole="header" style={{ fontSize: 24, fontWeight: '800', color: colors.text, flex: 1 }}>
              Bug details
            </Text>
          </View>
          <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 21, marginBottom: 24 }}>
            Give the bug a clear title and tell us if you can reliably reproduce it.
          </Text>

          {/* Bug title */}
          <FieldLabel text="Bug title" required />
          <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 19, marginBottom: 8 }}>
            A short, specific description of the issue. e.g. "VoiceOver skips toolbar buttons in Mail app"
          </Text>
          <TextInput
            value={state.title}
            onChangeText={v => update({ title: v })}
            placeholder="e.g. VoiceOver stops reading after video playback"
            placeholderTextColor={colors.textSecondary}
            style={{
              backgroundColor: colors.card, borderRadius: 12,
              paddingHorizontal: 14, paddingVertical: 12,
              fontSize: 17, color: colors.text,
              borderWidth: 1.5, borderColor: state.title.trim() ? colors.accent : colors.border,
            }}
            accessible
            accessibilityLabel="Bug title"
            accessibilityHint="Required. A short, clear description of the bug."
            returnKeyType="done"
          />

          {/* Apple Feedback # */}
          <View style={{ marginTop: 24 }}>
            <FieldLabel text="Apple Feedback number" />
            <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 19, marginBottom: 8 }}>
              If you have already submitted this bug to Apple Feedback, enter the FB number here.
            </Text>
            <TextInput
              value={state.appleFeedback}
              onChangeText={v => update({ appleFeedback: v })}
              placeholder="e.g. FB123456789"
              placeholderTextColor={colors.textSecondary}
              keyboardType="default"
              style={{
                backgroundColor: colors.card, borderRadius: 12,
                paddingHorizontal: 14, paddingVertical: 12,
                fontSize: 17, color: colors.text,
                borderWidth: 1.5, borderColor: state.appleFeedback.trim() ? colors.accent : colors.border,
              }}
              accessible
              accessibilityLabel="Apple Feedback number"
              accessibilityHint="Optional. The FB number from Apple's Feedback Assistant app."
              returnKeyType="done"
            />
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, marginTop: 6 }}>
              <Ionicons name="information-circle-outline" size={14} color={colors.textSecondary} accessibilityElementsHidden />
              <Text style={{ fontSize: 12, color: colors.textSecondary, flex: 1, lineHeight: 17 }}>
                Submit your bug to Apple Feedback at feedbackassistant.apple.com before reporting here.
              </Text>
            </View>
          </View>

          {/* Reproducibility */}
          <View style={{ marginTop: 24 }}>
            <FieldLabel text="Can you reproduce this bug?" required />
            <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 19, marginBottom: 12 }}>
              How reliably does this bug occur?
            </Text>
            <View style={{ gap: 8 }}>
              {REPRODUCIBLE_OPTIONS.map((option: BugReproducible) => {
                const selected = state.canReproduce === option;
                const iconColor = REPRODUCE_COLORS[option] ?? colors.accent;
                return (
                  <Pressable
                    key={option}
                    onPress={() => { sounds.pickerTick().catch(() => {}); update({ canReproduce: option }); }}
                    accessible
                    accessibilityRole="radio"
                    accessibilityLabel={option}
                    accessibilityState={{ selected }}
                    style={({ pressed }) => ({
                      flexDirection: 'row', alignItems: 'center', gap: 12, padding: 14,
                      borderRadius: 14, borderWidth: 2,
                      borderColor: selected ? iconColor : colors.border,
                      backgroundColor: selected ? `${iconColor}12` : colors.card,
                      opacity: pressed ? 0.8 : 1,
                    })}
                  >
                    <Ionicons name={REPRODUCE_ICONS[option] as any} size={22} color={selected ? iconColor : colors.textSecondary} accessibilityElementsHidden />
                    <Text style={{ flex: 1, fontSize: 15, fontWeight: selected ? '700' : '400', color: selected ? iconColor : colors.text }}>
                      {option}
                    </Text>
                    {selected && (
                      <View style={{ width: 20, height: 20, borderRadius: 10, backgroundColor: iconColor, justifyContent: 'center', alignItems: 'center' }} accessibilityElementsHidden>
                        <Ionicons name="checkmark" size={13} color="#fff" />
                      </View>
                    )}
                  </Pressable>
                );
              })}
            </View>
          </View>

          {/* Continue */}
          <Pressable
            onPress={handleContinue}
            disabled={!canContinue}
            accessible
            accessibilityRole="button"
            accessibilityLabel={canContinue ? 'Continue to bug description' : 'Continue — add a title and select reproducibility to proceed'}
            accessibilityState={{ disabled: !canContinue }}
            style={({ pressed }) => ({
              marginTop: 32,
              backgroundColor: canContinue ? colors.accent : colors.border,
              borderRadius: 16, paddingVertical: 16,
              alignItems: 'center', flexDirection: 'row', justifyContent: 'center', gap: 8,
              opacity: pressed ? 0.85 : 1,
            })}
          >
            <Text style={{ fontSize: 17, fontWeight: '700', color: canContinue ? '#fff' : colors.textSecondary }}>
              Continue
            </Text>
            <Ionicons name="arrow-forward" size={18} color={canContinue ? '#fff' : colors.textSecondary} accessibilityElementsHidden />
          </Pressable>

        </Animated.View>
      </ScrollView>
    </KeyboardAvoidingView>
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
