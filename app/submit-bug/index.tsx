import { useEffect, useRef } from 'react';
import {
  AccessibilityInfo, Animated, findNodeHandle,
  KeyboardAvoidingView, Platform, Pressable, ScrollView,
  Text, TextInput, View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useBugWizard, PLATFORM_OPTIONS, type BugPlatform } from '../../src/contexts/BugWizardContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { sounds } from '../../src/services/sounds';

const PLATFORM_ICONS: Record<BugPlatform, string> = {
  iOS:     'phone-portrait-outline',
  iPadOS:  'tablet-portrait-outline',
  macOS:   'laptop-outline',
};

const PLATFORM_DESCRIPTIONS: Record<BugPlatform, string> = {
  iOS:     'iPhone, iPod touch',
  iPadOS:  'iPad',
  macOS:   'Mac computers',
};

export default function BugStep1() {
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

  const canContinue = !!state.platform && !!state.softwareVersion.trim();

  function handleContinue() {
    sounds.articleOpen().catch(() => {});
    router.push('/submit-bug/details' as any);
  }

  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined} keyboardVerticalOffset={100}>
      <ScrollView
        contentContainerStyle={{ padding: 20, paddingBottom: 60 }}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
      >
        <Animated.View style={{ opacity: fadeAnim, transform: [{ translateY: fadeAnim.interpolate({ inputRange: [0,1], outputRange: [16,0] }) }] }}>

          {/* Heading */}
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 8, marginTop: 8 }}>
            <View style={{ width: 52, height: 52, borderRadius: 26, backgroundColor: colors.accent, justifyContent: 'center', alignItems: 'center' }} accessibilityElementsHidden>
              <Ionicons name="bug-outline" size={28} color="#fff" />
            </View>
            <Text ref={headingRef} accessibilityRole="header" style={{ fontSize: 26, fontWeight: '800', color: colors.text, flex: 1, lineHeight: 32 }}>
              Report a bug
            </Text>
          </View>

          <Text style={{ fontSize: 15, color: colors.textSecondary, lineHeight: 23, marginBottom: 28 }}>
            Help improve accessibility by reporting bugs in Apple's platforms. Your report will be reviewed by the AppleVis community team.
          </Text>

          {/* Platform selection */}
          <FieldLabel text="Platform" required />
          <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 19, marginBottom: 12 }}>
            Which Apple platform does this bug affect?
          </Text>

          <View style={{ gap: 10, marginBottom: 28 }}>
            {PLATFORM_OPTIONS.map(platform => {
              const selected = state.platform === platform;
              return (
                <Pressable
                  key={platform}
                  onPress={() => { sounds.pickerTick().catch(() => {}); update({ platform }); }}
                  accessible
                  accessibilityRole="radio"
                  accessibilityLabel={`${platform} — ${PLATFORM_DESCRIPTIONS[platform]}`}
                  accessibilityState={{ selected }}
                  style={({ pressed }) => ({
                    flexDirection: 'row', alignItems: 'center', gap: 14, padding: 16,
                    borderRadius: 16, borderWidth: 2,
                    borderColor: selected ? colors.accent : colors.border,
                    backgroundColor: selected ? `${colors.accent}12` : colors.card,
                    opacity: pressed ? 0.8 : 1,
                  })}
                >
                  <View style={{
                    width: 44, height: 44, borderRadius: 12,
                    backgroundColor: selected ? colors.accent : `${colors.accent}18`,
                    justifyContent: 'center', alignItems: 'center',
                  }} accessibilityElementsHidden>
                    <Ionicons name={PLATFORM_ICONS[platform] as any} size={22} color={selected ? '#fff' : colors.accent} />
                  </View>
                  <View style={{ flex: 1 }}>
                    <Text style={{ fontSize: 17, fontWeight: selected ? '700' : '500', color: selected ? colors.accent : colors.text }}>
                      {platform}
                    </Text>
                    <Text style={{ fontSize: 13, color: colors.textSecondary, marginTop: 2 }}>
                      {PLATFORM_DESCRIPTIONS[platform]}
                    </Text>
                  </View>
                  {selected && (
                    <Ionicons name="checkmark-circle" size={22} color={colors.accent} accessibilityElementsHidden />
                  )}
                </Pressable>
              );
            })}
          </View>

          {/* Software version */}
          <FieldLabel text="Software version" required />
          <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 19, marginBottom: 8 }}>
            Which OS version are you running? e.g. "iOS 18.4", "macOS 15.2"
          </Text>
          <TextInput
            value={state.softwareVersion}
            onChangeText={v => update({ softwareVersion: v })}
            placeholder={state.platform === 'macOS' ? 'e.g. macOS 15.2 Sequoia' : 'e.g. iOS 18.4'}
            placeholderTextColor={colors.textSecondary}
            style={{
              backgroundColor: colors.card, borderRadius: 12,
              paddingHorizontal: 14, paddingVertical: 12,
              fontSize: 17, color: colors.text,
              borderWidth: 1.5, borderColor: state.softwareVersion.trim() ? colors.accent : colors.border,
            }}
            accessible
            accessibilityLabel="Software version"
            accessibilityHint="Required. Enter the operating system version where the bug occurs."
            returnKeyType="done"
          />

          {/* Continue */}
          <Pressable
            onPress={handleContinue}
            disabled={!canContinue}
            accessible
            accessibilityRole="button"
            accessibilityLabel={canContinue ? 'Continue to bug details' : 'Continue — select a platform and enter software version to proceed'}
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
