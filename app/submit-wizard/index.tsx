import { useEffect, useRef } from 'react';
import {
  AccessibilityInfo, Animated, findNodeHandle,
  Pressable, ScrollView, Text, View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useWizard } from '../../src/contexts/SubmitWizardContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { sounds } from '../../src/services/sounds';

// ─── Step 1: Before You Begin ─────────────────────────────────────────────────

const GUIDELINES_URL = 'https://www.applevis.com/submitting-app-applevis-community-app-directory-guidelines';

type CheckRowProps = {
  checked:   boolean;
  onToggle:  () => void;
  title:     string;
  body:      string;
  iconName:  string;
  accentColor: string;
};

function CheckRow({ checked, onToggle, title, body, iconName, accentColor }: CheckRowProps) {
  const { colors }        = useTheme();
  const { reduceMotion }  = useAccessibilityPreferences();
  const scaleAnim         = useRef(new Animated.Value(1)).current;

  function handlePress() {
    if (!reduceMotion) {
      Animated.sequence([
        Animated.timing(scaleAnim, { toValue: 0.95, duration: 80,  useNativeDriver: true }),
        Animated.timing(scaleAnim, { toValue: 1,    duration: 120, useNativeDriver: true }),
      ]).start();
    }
    sounds.pickerTick().catch(() => {});
    onToggle();
  }

  return (
    <Pressable
      onPress={handlePress}
      accessible
      accessibilityRole="checkbox"
      accessibilityLabel={title}
      accessibilityHint={body}
      accessibilityState={{ checked }}
      style={({ pressed }) => ({ opacity: pressed ? 0.85 : 1 })}
    >
      <Animated.View
        style={[
          {
            flexDirection: 'row',
            alignItems: 'flex-start',
            gap: 14,
            backgroundColor: colors.card,
            borderRadius: 14,
            padding: 16,
            marginBottom: 10,
            borderWidth: 2,
            borderColor: checked ? accentColor : colors.border,
          },
          { transform: [{ scale: scaleAnim }] },
        ]}
      >
        <View
          style={{
            width: 40, height: 40, borderRadius: 20,
            backgroundColor: checked ? accentColor : colors.border,
            justifyContent: 'center', alignItems: 'center',
            flexShrink: 0,
          }}
          accessibilityElementsHidden
        >
          <Ionicons name={checked ? 'checkmark' : iconName as any} size={20} color="#fff" />
        </View>
        <View style={{ flex: 1 }}>
          <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text, marginBottom: 3 }}>{title}</Text>
          <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>{body}</Text>
        </View>
      </Animated.View>
    </Pressable>
  );
}

export default function BeforeYouBeginScreen() {
  const { colors }                     = useTheme();
  const router                         = useRouter();
  const { state, update }              = useWizard();
  const { screenReaderEnabled, reduceMotion } = useAccessibilityPreferences();

  const headingRef   = useRef<Text>(null);
  const contentAnim  = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    if (reduceMotion || screenReaderEnabled) {
      contentAnim.setValue(1);
    } else {
      Animated.timing(contentAnim, { toValue: 1, duration: 420, useNativeDriver: true }).start();
    }
    if (screenReaderEnabled) {
      const id = setTimeout(() => {
        const node = findNodeHandle(headingRef.current);
        if (node) AccessibilityInfo.setAccessibilityFocus(node);
      }, 350);
      return () => clearTimeout(id);
    }
  }, []);

  const canContinue = state.agreedPersonalUse && state.agreedNotDeveloper;
  const accent      = colors.accent;

  function handleContinue() {
    if (!canContinue) return;
    sounds.articleOpen().catch(() => {});
    router.push('/submit-wizard/platform' as any);
  }

  return (
    <ScrollView
      contentContainerStyle={{ padding: 20, paddingBottom: 48 }}
      showsVerticalScrollIndicator={false}
      keyboardShouldPersistTaps="handled"
    >
      <Animated.View style={{ opacity: contentAnim, transform: [{ translateY: contentAnim.interpolate({ inputRange: [0, 1], outputRange: [18, 0] }) }] }}>

        {/* ── Heading ─────────────────────────────────────────────────────── */}
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 8 }}>
          <View
            style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: accent, justifyContent: 'center', alignItems: 'center' }}
            accessibilityElementsHidden
          >
            <Ionicons name="shield-checkmark-outline" size={24} color="#fff" />
          </View>
          <Text
            ref={headingRef}
            style={{ fontSize: 26, fontWeight: '800', color: colors.text, flex: 1, lineHeight: 32 }}
            accessibilityRole="header"
          >
            Before You Submit
          </Text>
        </View>

        <Text style={{ fontSize: 16, color: colors.textSecondary, lineHeight: 24, marginBottom: 24 }}>
          The AppleVis App Directory is a community resource. Please read and confirm the following before adding an app.
        </Text>

        {/* ── Checkboxes ──────────────────────────────────────────────────── */}
        <CheckRow
          checked={state.agreedPersonalUse}
          onToggle={() => update({ agreedPersonalUse: !state.agreedPersonalUse })}
          title="I have used this app"
          body="I have personally used this app and can describe its accessibility — I am not submitting based on the App Store description alone."
          iconName="hand-right-outline"
          accentColor={accent}
        />
        <CheckRow
          checked={state.agreedNotDeveloper}
          onToggle={() => update({ agreedNotDeveloper: !state.agreedNotDeveloper })}
          title="I am not the developer"
          body="I am not the developer, publisher, or otherwise affiliated with this app. Developers may not submit their own apps per AppleVis guidelines."
          iconName="person-outline"
          accentColor={accent}
        />

        {/* ── Guidelines link ──────────────────────────────────────────────── */}
        <Pressable
          accessible
          accessibilityRole="link"
          accessibilityLabel="Read the full AppleVis submission guidelines"
          accessibilityHint="Opens in Safari"
          onPress={() => void import('expo-linking').then(({ default: L }) => L.openURL(GUIDELINES_URL))}
          style={({ pressed }) => ({
            flexDirection: 'row', alignItems: 'center', gap: 6,
            marginBottom: 28, opacity: pressed ? 0.7 : 1,
          })}
        >
          <Ionicons name="open-outline" size={14} color={accent} />
          <Text style={{ fontSize: 14, color: accent, fontWeight: '600' }}>Read submission guidelines</Text>
        </Pressable>

        {/* ── Continue button ──────────────────────────────────────────────── */}
        <Pressable
          onPress={handleContinue}
          disabled={!canContinue}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Continue to platform selection"
          accessibilityHint={canContinue ? '' : 'Confirm both checkboxes to continue'}
          accessibilityState={{ disabled: !canContinue }}
          style={({ pressed }) => ({
            backgroundColor: canContinue ? accent : colors.border,
            borderRadius: 16,
            paddingVertical: 16,
            alignItems: 'center',
            flexDirection: 'row',
            justifyContent: 'center',
            gap: 8,
            opacity: pressed ? 0.85 : 1,
          })}
        >
          <Text style={{ color: canContinue ? '#fff' : colors.textSecondary, fontSize: 17, fontWeight: '700' }}>
            Continue
          </Text>
          <Ionicons name="arrow-forward" size={18} color={canContinue ? '#fff' : colors.textSecondary} accessibilityElementsHidden />
        </Pressable>

        {!canContinue && (
          <Text
            style={{ fontSize: 13, color: colors.textSecondary, textAlign: 'center', marginTop: 10 }}
            accessibilityLiveRegion="polite"
          >
            Confirm both checkboxes to continue
          </Text>
        )}
      </Animated.View>
    </ScrollView>
  );
}
