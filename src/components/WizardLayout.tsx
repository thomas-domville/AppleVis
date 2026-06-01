import { ReactNode, useEffect, useRef } from 'react';
import { AccessibilityInfo, findNodeHandle, Pressable, SafeAreaView, ScrollView, Text, View } from 'react-native';
import { useTheme } from '../contexts/ThemeContext';
import { onboarding } from '../services/onboarding';
import { router } from 'expo-router';

type Props = {
  step: number;
  totalSteps: number;
  title: string;
  description: string;
  children: ReactNode;
  onNext: () => void;
  nextLabel?: string;
  nextDisabled?: boolean;
  /** Hide the skip link (e.g. on the final ready screen). */
  hideSkip?: boolean;
};

export function WizardLayout({
  step, totalSteps, title, description, children,
  onNext, nextLabel = 'Next', nextDisabled = false, hideSkip = false,
}: Props) {
  const { colors } = useTheme();
  const headingRef = useRef<Text>(null);

  // Move VoiceOver focus to the step heading whenever the step changes.
  useEffect(() => {
    const timer = setTimeout(() => {
      const node = headingRef.current ? findNodeHandle(headingRef.current) : null;
      if (node) AccessibilityInfo.setAccessibilityFocus(node);
    }, 350);
    return () => clearTimeout(timer);
  }, [step]);

  async function handleSkip() {
    await onboarding.markComplete();
    router.replace('/(tabs)');
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: colors.background }}>
      <ScrollView
        contentContainerStyle={{ flexGrow: 1, paddingHorizontal: 24, paddingTop: 16, paddingBottom: 48 }}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
      >
        {/* ── Progress dots ──────────────────────────────────────────────── */}
        <View
          style={{ flexDirection: 'row', justifyContent: 'center', gap: 8, marginBottom: 32 }}
          accessible
          accessibilityLabel={`Step ${step} of ${totalSteps}`}
        >
          {Array.from({ length: totalSteps }).map((_, i) => (
            <View
              key={i}
              style={{
                width: i + 1 === step ? 24 : 8,
                height: 8,
                borderRadius: 4,
                backgroundColor: i + 1 === step ? colors.accent : colors.border,
              }}
            />
          ))}
        </View>

        {/* ── Step heading ────────────────────────────────────────────────── */}
        <Text
          ref={headingRef}
          accessibilityRole="header"
          accessible
          accessibilityLabel={`${title}. Step ${step} of ${totalSteps}.`}
          style={{ fontSize: 30, fontWeight: '800', color: colors.text, marginBottom: 10, lineHeight: 36 }}
        >
          {title}
        </Text>
        <Text style={{ fontSize: 17, lineHeight: 25, color: colors.textSecondary, marginBottom: 28 }}>
          {description}
        </Text>

        {/* ── Step content ────────────────────────────────────────────────── */}
        <View style={{ flex: 1 }}>
          {children}
        </View>

        {/* ── Actions ─────────────────────────────────────────────────────── */}
        <View style={{ marginTop: 32, gap: 12 }}>
          <Pressable
            onPress={onNext}
            disabled={nextDisabled}
            accessible
            accessibilityRole="button"
            accessibilityLabel={nextLabel}
            accessibilityState={{ disabled: nextDisabled }}
            style={{
              backgroundColor: nextDisabled ? colors.border : colors.accent,
              borderRadius: 14,
              paddingVertical: 16,
              alignItems: 'center',
            }}
          >
            <Text style={{ color: colors.accentText, fontWeight: '700', fontSize: 17 }}>
              {nextLabel}
            </Text>
          </Pressable>

          {!hideSkip && (
            <Pressable
              onPress={handleSkip}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Skip setup and go straight to the app"
              accessibilityHint="You can change all these settings later in the Settings tab."
              style={{ alignItems: 'center', paddingVertical: 12 }}
            >
              <Text style={{ color: colors.textSecondary, fontSize: 15 }}>Skip setup</Text>
            </Pressable>
          )}
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}
