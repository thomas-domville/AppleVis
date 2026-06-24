import { useEffect, useRef } from 'react';
import {
  AccessibilityInfo, Animated, findNodeHandle,
  Pressable, ScrollView, Text, View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useWizard, type WizardPlatform } from '../../src/contexts/SubmitWizardContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { sounds } from '../../src/services/sounds';

// ─── Step 2: Platform ─────────────────────────────────────────────────────────

type PlatformChoice = {
  value:       WizardPlatform;
  label:       string;
  subtitle:    string;
  icon:        string;
  note?:       string;
};

const PLATFORMS: PlatformChoice[] = [
  {
    value:    'ios',
    label:    'iOS / iPadOS',
    subtitle: 'iPhone and iPad apps',
    icon:     'phone-portrait-outline',
    note:     'Watch and Vision Pro companion support detected automatically',
  },
  {
    value:    'macos',
    label:    'macOS',
    subtitle: 'Mac apps from the Mac App Store',
    icon:     'laptop-outline',
  },
  {
    value:    'tvos',
    label:    'Apple TV',
    subtitle: 'tvOS apps from the App Store',
    icon:     'tv-outline',
  },
];

export default function PlatformScreen() {
  const { colors }                     = useTheme();
  const router                         = useRouter();
  const { state, update }              = useWizard();
  const { screenReaderEnabled, reduceMotion } = useAccessibilityPreferences();

  const headingRef  = useRef<Text>(null);
  const contentAnim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    if (reduceMotion || screenReaderEnabled) {
      contentAnim.setValue(1);
    } else {
      Animated.timing(contentAnim, { toValue: 1, duration: 380, useNativeDriver: true }).start();
    }
    if (screenReaderEnabled) {
      const id = setTimeout(() => {
        const node = findNodeHandle(headingRef.current);
        if (node) AccessibilityInfo.setAccessibilityFocus(node);
      }, 350);
      return () => clearTimeout(id);
    }
  }, []);

  function handleSelect(p: WizardPlatform) {
    sounds.pickerTick().catch(() => {});
    update({ platform: p, searchHit: null, fullMeta: null, duplicateStatus: 'idle' });
  }

  function handleContinue() {
    if (!state.platform) return;
    sounds.articleOpen().catch(() => {});
    router.push('/submit-wizard/search' as any);
  }

  const accent = colors.accent;

  return (
    <ScrollView
      contentContainerStyle={{ padding: 20, paddingBottom: 48 }}
      showsVerticalScrollIndicator={false}
    >
      <Animated.View style={{ opacity: contentAnim, transform: [{ translateY: contentAnim.interpolate({ inputRange: [0, 1], outputRange: [18, 0] }) }] }}>

        {/* ── Back + Heading ───────────────────────────────────────────────── */}
        <Pressable
          onPress={() => router.back()}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Back to guidelines"
          style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', gap: 4, marginBottom: 20, opacity: pressed ? 0.7 : 1 })}
        >
          <Ionicons name="chevron-back" size={18} color={accent} />
          <Text style={{ fontSize: 15, color: accent, fontWeight: '600' }}>Back</Text>
        </Pressable>

        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 8 }}>
          <View
            style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: accent, justifyContent: 'center', alignItems: 'center' }}
            accessibilityElementsHidden
          >
            <Ionicons name="grid-outline" size={24} color="#fff" />
          </View>
          <Text
            ref={headingRef}
            style={{ fontSize: 26, fontWeight: '800', color: colors.text, flex: 1, lineHeight: 32 }}
            accessibilityRole="header"
          >
            What platform?
          </Text>
        </View>
        <Text style={{ fontSize: 16, color: colors.textSecondary, lineHeight: 24, marginBottom: 24 }}>
          Choose the primary platform this app runs on.
        </Text>

        {/* ── Platform cards ───────────────────────────────────────────────── */}
        <View
          accessible={false}
          accessibilityRole="radiogroup"
          accessibilityLabel="Platform selection"
        >
          {PLATFORMS.map((p) => {
            const selected = state.platform === p.value;
            return (
              <Pressable
                key={p.value}
                onPress={() => handleSelect(p.value)}
                accessible
                accessibilityRole="radio"
                accessibilityLabel={p.label}
                accessibilityHint={p.subtitle + (p.note ? '. Note: ' + p.note : '')}
                accessibilityState={{ selected }}
                style={({ pressed }) => ({ opacity: pressed ? 0.88 : 1, marginBottom: 10 })}
              >
                <View
                  style={{
                    flexDirection: 'row', alignItems: 'center', gap: 14,
                    backgroundColor: colors.card,
                    borderRadius: 16,
                    padding: 16,
                    borderWidth: 2,
                    borderColor: selected ? accent : colors.border,
                  }}
                >
                  {/* Platform icon */}
                  <View
                    style={{
                      width: 50, height: 50, borderRadius: 14,
                      backgroundColor: selected ? accent : colors.border,
                      justifyContent: 'center', alignItems: 'center', flexShrink: 0,
                    }}
                    accessibilityElementsHidden
                  >
                    <Ionicons name={p.icon as any} size={26} color={selected ? '#fff' : colors.textSecondary} />
                  </View>

                  {/* Text */}
                  <View style={{ flex: 1 }}>
                    <Text style={{ fontSize: 18, fontWeight: '700', color: colors.text }}>{p.label}</Text>
                    <Text style={{ fontSize: 14, color: colors.textSecondary, marginTop: 2 }}>{p.subtitle}</Text>
                    {p.note && (
                      <View
                        style={{ flexDirection: 'row', alignItems: 'center', gap: 4, marginTop: 6 }}
                        accessibilityElementsHidden
                      >
                        <Ionicons name="information-circle-outline" size={13} color={colors.textSecondary} />
                        <Text style={{ fontSize: 12, color: colors.textSecondary, flex: 1, lineHeight: 16 }}>{p.note}</Text>
                      </View>
                    )}
                  </View>

                  {/* Radio indicator */}
                  <View
                    style={{
                      width: 24, height: 24, borderRadius: 12,
                      borderWidth: 2, borderColor: selected ? accent : colors.border,
                      justifyContent: 'center', alignItems: 'center',
                      backgroundColor: selected ? accent : 'transparent',
                    }}
                    accessibilityElementsHidden
                  >
                    {selected && <View style={{ width: 10, height: 10, borderRadius: 5, backgroundColor: '#fff' }} />}
                  </View>
                </View>
              </Pressable>
            );
          })}
        </View>

        {/* ── Continue ─────────────────────────────────────────────────────── */}
        <Pressable
          onPress={handleContinue}
          disabled={!state.platform}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Continue to app search"
          accessibilityState={{ disabled: !state.platform }}
          style={({ pressed }) => ({
            backgroundColor: state.platform ? accent : colors.border,
            borderRadius: 16, paddingVertical: 16,
            alignItems: 'center', flexDirection: 'row', justifyContent: 'center', gap: 8,
            marginTop: 10, opacity: pressed ? 0.85 : 1,
          })}
        >
          <Text style={{ color: state.platform ? '#fff' : colors.textSecondary, fontSize: 17, fontWeight: '700' }}>
            Continue
          </Text>
          <Ionicons name="arrow-forward" size={18} color={state.platform ? '#fff' : colors.textSecondary} accessibilityElementsHidden />
        </Pressable>
      </Animated.View>
    </ScrollView>
  );
}
