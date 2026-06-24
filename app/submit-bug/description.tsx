import { useEffect, useRef } from 'react';
import {
  AccessibilityInfo, Animated, findNodeHandle,
  KeyboardAvoidingView, Platform, Pressable, ScrollView,
  Text, TextInput, View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useBugWizard } from '../../src/contexts/BugWizardContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { sounds } from '../../src/services/sounds';

const TIPS = [
  { icon: 'footsteps-outline', text: 'Steps to reproduce the bug' },
  { icon: 'checkmark-done-outline', text: 'Expected vs. actual behavior' },
  { icon: 'apps-outline', text: 'Which app or feature is affected' },
  { icon: 'repeat-outline', text: 'How often it happens' },
];

export default function BugStep3() {
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

  const charCount    = state.description.trim().length;
  const canContinue  = charCount >= 30;

  function handleContinue() {
    sounds.articleOpen().catch(() => {});
    router.push('/submit-bug/review' as any);
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
          <Pressable onPress={() => router.back()} accessible accessibilityRole="button" accessibilityLabel="Back to bug details"
            style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', gap: 4, marginBottom: 20, opacity: pressed ? 0.7 : 1 })}>
            <Ionicons name="chevron-back" size={18} color={colors.accent} />
            <Text style={{ fontSize: 15, color: colors.accent, fontWeight: '600' }}>Back</Text>
          </Pressable>

          {/* Heading */}
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 8 }}>
            <View style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: colors.accent, justifyContent: 'center', alignItems: 'center' }} accessibilityElementsHidden>
              <Ionicons name="document-text-outline" size={24} color="#fff" />
            </View>
            <Text ref={headingRef} accessibilityRole="header" style={{ fontSize: 24, fontWeight: '800', color: colors.text, flex: 1 }}>
              Describe the bug
            </Text>
          </View>
          <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 21, marginBottom: 20 }}>
            Describe what happens in as much detail as possible. The more context you provide, the more useful your report will be.
          </Text>

          {/* Tips card */}
          <View style={{ backgroundColor: `${colors.accent}0F`, borderRadius: 14, padding: 14, marginBottom: 20, borderWidth: 1, borderColor: `${colors.accent}30` }}>
            <Text style={{ fontSize: 12, fontWeight: '700', color: colors.accent, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 10 }}
              accessibilityRole="header">
              Tips for a helpful bug report
            </Text>
            {TIPS.map(tip => (
              <View key={tip.icon} style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 8, marginBottom: 6 }} accessible accessibilityLabel={tip.text}>
                <Ionicons name={tip.icon as any} size={14} color={colors.accent} style={{ marginTop: 2 }} accessibilityElementsHidden />
                <Text style={{ flex: 1, fontSize: 13, color: colors.textSecondary, lineHeight: 19 }}>{tip.text}</Text>
              </View>
            ))}
          </View>

          {/* Description textarea */}
          <FieldLabel text="Description" required />
          <TextInput
            value={state.description}
            onChangeText={v => update({ description: v })}
            placeholder={'1. Open the Mail app\n2. Enable VoiceOver (Settings > Accessibility > VoiceOver)\n3. Navigate to the Inbox\n4. Swipe right to the toolbar\n\nExpected: VoiceOver reads each toolbar button\nActual: VoiceOver skips past the toolbar entirely'}
            placeholderTextColor={colors.textSecondary}
            multiline
            style={{
              backgroundColor: colors.card, borderRadius: 14, padding: 14,
              fontSize: 15, color: colors.text, lineHeight: 24,
              borderWidth: 1.5, borderColor: canContinue ? colors.accent : colors.border,
              minHeight: 260, textAlignVertical: 'top',
            }}
            accessible
            accessibilityLabel="Bug description"
            accessibilityHint="Required. Describe the bug in detail, including steps to reproduce it."
          />
          <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginTop: 6 }} accessibilityElementsHidden>
            <Text style={{ fontSize: 12, color: colors.textSecondary }}>
              {charCount < 30 ? `${30 - charCount} more characters needed` : 'Good detail ✓'}
            </Text>
            <Text style={{ fontSize: 12, color: canContinue ? colors.accent : colors.textSecondary, fontWeight: '600' }}>
              {charCount} chars
            </Text>
          </View>

          {/* Continue */}
          <Pressable
            onPress={handleContinue}
            disabled={!canContinue}
            accessible
            accessibilityRole="button"
            accessibilityLabel={canContinue ? 'Continue to review and submit' : `Continue — ${30 - charCount} more characters needed`}
            accessibilityState={{ disabled: !canContinue }}
            style={({ pressed }) => ({
              marginTop: 28,
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
