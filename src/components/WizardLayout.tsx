import { ReactNode, useEffect, useRef } from 'react';
import { AccessibilityInfo, Animated, findNodeHandle, Pressable, ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../contexts/ThemeContext';
import { useAccessibilityPreferences } from '../hooks/useAccessibilityPreferences';
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
  /** Hide the step progress dots and step count (e.g. on the summary screen). */
  hideStepIndicator?: boolean;
  /** Override accent colour for stripe, dots, and Next button (e.g. contact wizard type colour). */
  accentColor?: string;
  /** When provided, shows a × Cancel button in the header and calls this instead of the skip link. */
  onCancel?: () => void;
};

export function WizardLayout({
  step, totalSteps, title, description, children,
  onNext, nextLabel = 'Next', nextDisabled = false, hideSkip = false, hideStepIndicator = false,
  accentColor, onCancel,
}: Props) {
  const { colors } = useTheme();
  const resolvedAccent = accentColor ?? colors.accent;
  const { reduceMotion } = useAccessibilityPreferences();
  const headingRef = useRef<Text>(null);

  // Per-dot animated widths (pill ↔ circle morph on step change)
  const dotWidths = useRef<Animated.Value[]>(
    Array.from({ length: totalSteps }, (_, i) => new Animated.Value(i + 1 === step ? 24 : 8))
  ).current;

  // Top progress stripe
  const stripeAnim = useRef(new Animated.Value((step / totalSteps) * 100)).current;

  // Step entrance (fade + slide-up)
  const entranceOpacity     = useRef(new Animated.Value(0)).current;
  const entranceTranslateY  = useRef(new Animated.Value(10)).current;

  // Move VoiceOver focus to the step heading whenever the step changes.
  useEffect(() => {
    const timer = setTimeout(() => {
      const node = headingRef.current ? findNodeHandle(headingRef.current) : null;
      if (node) AccessibilityInfo.setAccessibilityFocus(node);
    }, 350);
    return () => clearTimeout(timer);
  }, [step]);

  // Animate dots on step change.
  useEffect(() => {
    if (reduceMotion) {
      dotWidths.forEach((anim, i) => anim.setValue(i + 1 === step ? 24 : 8));
      return;
    }
    dotWidths.forEach((anim, i) => {
      Animated.spring(anim, { toValue: i + 1 === step ? 24 : 8, useNativeDriver: false }).start();
    });
  }, [step, reduceMotion, dotWidths]);

  // Animate progress stripe on step change.
  useEffect(() => {
    Animated.timing(stripeAnim, {
      toValue: (step / totalSteps) * 100,
      duration: 350,
      useNativeDriver: false,
    }).start();
  }, [step, totalSteps, stripeAnim]);

  // Entrance animation on each step.
  useEffect(() => {
    if (reduceMotion) {
      entranceOpacity.setValue(1);
      entranceTranslateY.setValue(0);
      return;
    }
    entranceOpacity.setValue(0);
    entranceTranslateY.setValue(10);
    Animated.parallel([
      Animated.timing(entranceOpacity,    { toValue: 1, duration: 300, useNativeDriver: true }),
      Animated.timing(entranceTranslateY, { toValue: 0, duration: 300, useNativeDriver: true }),
    ]).start();
  }, [step, reduceMotion, entranceOpacity, entranceTranslateY]);

  async function handleSkip() {
    await onboarding.markComplete();
    router.replace('/(tabs)');
  }

  return (
    <SafeAreaView
      style={{ flex: 1, backgroundColor: colors.background }}
      onAccessibilityEscape={() => { if (router.canGoBack()) router.back(); }}
    >
      {/* ── Header: Back (step > 1) and optional Cancel ─────────────────── */}
      {(step > 1 || onCancel) && (
        <View style={{
          flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
          paddingHorizontal: 16, paddingTop: 12, paddingBottom: 4,
        }}>
          {step > 1 ? (
            <Pressable
              onPress={() => { if (router.canGoBack()) router.back(); }}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Back"
              accessibilityHint="Returns to the previous step."
              hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}
              style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', gap: 2, opacity: pressed ? 0.6 : 1 })}
            >
              <Ionicons name="chevron-back" size={22} color={colors.accent} accessibilityElementsHidden />
              <Text style={{ color: colors.accent, fontSize: 17 }} accessibilityElementsHidden>Back</Text>
            </Pressable>
          ) : <View />}
          {onCancel && (
            <Pressable
              onPress={onCancel}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Cancel"
              accessibilityHint="Cancels and closes this form."
              hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}
              style={({ pressed }) => ({ opacity: pressed ? 0.6 : 1 })}
            >
              <Ionicons name="close-circle" size={28} color={colors.textSecondary} />
            </Pressable>
          )}
        </View>
      )}
      {/* ── Top progress stripe ─────────────────────────────────────────── */}
      <View style={{ height: 4, backgroundColor: colors.border }}>
        <Animated.View style={{
          height: 4,
          backgroundColor: resolvedAccent,
          width: stripeAnim.interpolate({ inputRange: [0, 100], outputRange: ['0%', '100%'] }),
        }} />
      </View>

      <ScrollView
        contentContainerStyle={{ flexGrow: 1, paddingHorizontal: 24, paddingTop: 16, paddingBottom: 48 }}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
      >
        {/* ── Animated progress dots ──────────────────────────────────────── */}
        {!hideStepIndicator && (
          <View
            style={{ flexDirection: 'row', justifyContent: 'center', gap: 8, marginBottom: 32 }}
            accessible
            accessibilityLabel={`Step ${step} of ${totalSteps}`}
          >
            {Array.from({ length: totalSteps }).map((_, i) => (
              <Animated.View
                key={i}
                style={{
                  width: dotWidths[i],
                  height: 8,
                  borderRadius: 4,
                  backgroundColor: i + 1 === step ? resolvedAccent : colors.border,
                }}
              />
            ))}
          </View>
        )}

        {/* ── Animated entrance: heading + description + content ──────────── */}
        <Animated.View
          style={{
            flex: 1,
            opacity: entranceOpacity,
            transform: [{ translateY: entranceTranslateY }],
          }}
        >
          <Text
            ref={headingRef}
            accessibilityRole="header"
            accessible
            accessibilityLabel={hideStepIndicator ? title : `${title}. Step ${step} of ${totalSteps}.`}
            style={{ fontSize: 30, fontWeight: '800', color: colors.text, marginBottom: 10, lineHeight: 36 }}
          >
            {title}
          </Text>
          <Text style={{ fontSize: 17, lineHeight: 25, color: colors.textSecondary, marginBottom: 28 }}>
            {description}
          </Text>

          {/* ── Step content ──────────────────────────────────────────────── */}
          <View style={{ flex: 1 }}>
            {children}
          </View>
        </Animated.View>

        {/* ── Actions (outside entrance anim — always visible) ────────────── */}
        <View style={{ marginTop: 32, gap: 12 }}>
          <Pressable
            onPress={onNext}
            disabled={nextDisabled}
            accessible
            accessibilityRole="button"
            accessibilityLabel={nextLabel}
            accessibilityState={{ disabled: nextDisabled }}
            style={{
              backgroundColor: nextDisabled ? colors.border : resolvedAccent,
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
              accessibilityLabel="Skip setup for now and open AppleVis"
              accessibilityHint="You can change these choices later in Settings."
              style={{ alignItems: 'center', paddingVertical: 12 }}
            >
              <Text style={{ color: colors.textSecondary, fontSize: 15 }}>Maybe Later</Text>
            </Pressable>
          )}
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}
