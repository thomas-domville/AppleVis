import { useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo, Animated, findNodeHandle,
  Pressable, ScrollView, Switch, Text, TextInput, View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import Constants from 'expo-constants';
import { Platform } from 'react-native';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useContactWizard } from '../../src/contexts/ContactWizardContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { sounds } from '../../src/services/sounds';

const APP_VERSION = Constants.expoConfig?.version ?? '2026';
const PLATFORM    = Platform.OS === 'ios' ? `iOS ${Platform.Version}` : `Android ${Platform.Version}`;

const TYPE_COLOR: Record<string, string> = {
  bug:            '#EF4444',
  feedback:       '#0A84FF',
  suggestion:     '#10B981',
  recommendation: '#F59E0B',
};

const TYPE_ICON: Record<string, string> = {
  bug:            'bug-outline',
  feedback:       'chatbubble-ellipses-outline',
  suggestion:     'bulb-outline',
  recommendation: 'star-outline',
};

const MESSAGE_PLACEHOLDER: Record<string, string> = {
  bug:            'Describe what happened, what you expected, and the steps to reproduce it…',
  feedback:       'Share your thoughts about the AppleVis app…',
  suggestion:     'Describe your idea and why it would improve the app…',
  recommendation: 'Tell us what you would like to see in AppleVis…',
};

function buildSysInfo(): string {
  return [
    '\n\n--- App Info ---',
    `App Version: AppleVis ${APP_VERSION}`,
    `Platform: ${PLATFORM}`,
  ].join('\n');
}

// ── Step 2: Compose ───────────────────────────────────────────────────────────

export default function ContactStep2() {
  const { colors }                            = useTheme();
  const router                                = useRouter();
  const { state, set }                        = useContactWizard();
  const { screenReaderEnabled, reduceMotion } = useAccessibilityPreferences();

  const headingRef   = useRef<Text>(null);
  const messageRef   = useRef<TextInput>(null);
  const fadeAnim     = useRef(new Animated.Value(reduceMotion || screenReaderEnabled ? 1 : 0)).current;
  const [charFocus, setCharFocus] = useState(false);

  useEffect(() => {
    if (!reduceMotion && !screenReaderEnabled) {
      Animated.timing(fadeAnim, { toValue: 1, duration: 300, useNativeDriver: true }).start();
    }
    if (screenReaderEnabled) {
      const id = setTimeout(() => {
        const node = findNodeHandle(headingRef.current);
        if (node) AccessibilityInfo.setAccessibilityFocus(node);
      }, 350);
      return () => clearTimeout(id);
    }
  }, []);

  const type       = state.contactType ?? 'feedback';
  const typeColor  = TYPE_COLOR[type];
  const typeIcon   = TYPE_ICON[type];
  const typeLabelMap: Record<string, string> = {
    bug: 'Bug Report', feedback: 'Feedback',
    suggestion: 'Suggestion', recommendation: 'Recommendation',
  };
  const typeLabel = typeLabelMap[type];
  const msgLen    = state.message.trim().length;
  const canContinue = state.subject.trim().length > 0 && msgLen >= 20;

  function handleContinue() {
    sounds.articleOpen().catch(() => {});
    router.push('/contact/review' as any);
  }

  return (
    <ScrollView
      contentContainerStyle={{ padding: 20, paddingBottom: 80 }}
      showsVerticalScrollIndicator={false}
      keyboardShouldPersistTaps="handled"
    >
      <Animated.View style={{ opacity: fadeAnim, transform: [{ translateY: fadeAnim.interpolate({ inputRange: [0,1], outputRange: [12,0] }) }] }}>

        {/* Back */}
        <Pressable
          onPress={() => router.back()}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Back to contact type"
          style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', gap: 4, marginBottom: 20, opacity: pressed ? 0.7 : 1 })}
        >
          <Ionicons name="chevron-back" size={18} color={colors.accent} />
          <Text style={{ fontSize: 15, color: colors.accent, fontWeight: '600' }}>Back</Text>
        </Pressable>

        {/* Type badge + heading */}
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 6 }}>
          <View
            style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: typeColor, justifyContent: 'center', alignItems: 'center' }}
            accessibilityElementsHidden
          >
            <Ionicons name={typeIcon as any} size={24} color="#fff" />
          </View>
          <Text
            ref={headingRef}
            accessibilityRole="header"
            style={{ fontSize: 24, fontWeight: '800', color: colors.text, flex: 1 }}
          >
            Write your message
          </Text>
        </View>

        {/* Type badge */}
        <View
          style={{ alignSelf: 'flex-start', backgroundColor: `${typeColor}18`, borderRadius: 8,
            paddingHorizontal: 10, paddingVertical: 4, marginBottom: 20 }}
          accessible
          accessibilityLabel={`Contact type: ${typeLabel}`}
        >
          <Text style={{ fontSize: 13, fontWeight: '700', color: typeColor }}>{typeLabel}</Text>
        </View>

        {/* Subject */}
        <Text
          style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8 }}
          accessibilityElementsHidden
        >
          Subject
        </Text>
        <TextInput
          value={state.subject}
          onChangeText={v => set({ subject: v })}
          placeholder="Enter a subject…"
          placeholderTextColor={colors.textSecondary}
          returnKeyType="next"
          onSubmitEditing={() => messageRef.current?.focus()}
          accessible
          accessibilityLabel="Subject"
          accessibilityHint="Required. Briefly describe your message."
          style={{
            backgroundColor: colors.card, borderRadius: 12, borderWidth: 1,
            borderColor: colors.border, paddingHorizontal: 14, paddingVertical: 12,
            fontSize: 16, color: colors.text, marginBottom: 20,
          }}
        />

        {/* Message */}
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 8 }}>
          <Text
            style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.5 }}
            accessibilityElementsHidden
          >
            Message
          </Text>
          <Text
            style={{ fontSize: 13, color: msgLen >= 20 ? colors.textSecondary : '#EF4444', fontWeight: msgLen >= 20 ? '400' : '700' }}
            accessibilityLiveRegion="polite"
            accessibilityLabel={`${msgLen} character${msgLen !== 1 ? 's' : ''}, 20 minimum`}
          >
            {msgLen} {msgLen < 20 ? `/ 20 min` : 'chars'}
          </Text>
        </View>

        <TextInput
          ref={messageRef}
          value={state.message}
          onChangeText={v => set({ message: v })}
          placeholder={MESSAGE_PLACEHOLDER[type]}
          placeholderTextColor={colors.textSecondary}
          multiline
          textAlignVertical="top"
          onFocus={() => setCharFocus(true)}
          onBlur={() => setCharFocus(false)}
          accessible
          accessibilityLabel="Message"
          accessibilityHint={`Required. Minimum 20 characters. ${MESSAGE_PLACEHOLDER[type]}`}
          style={{
            backgroundColor: colors.card, borderRadius: 12,
            borderWidth: charFocus ? 2 : 1,
            borderColor: charFocus ? colors.accent : colors.border,
            paddingHorizontal: 14, paddingVertical: 12,
            fontSize: 16, color: colors.text, minHeight: 160,
            marginBottom: 16,
          }}
        />

        {/* Bug-only: include sysinfo toggle */}
        {type === 'bug' && (
          <Pressable
            onPress={() => set({ includeSysInfo: !state.includeSysInfo })}
            accessible
            accessibilityRole="switch"
            accessibilityState={{ checked: state.includeSysInfo }}
            accessibilityLabel="Include app and device info"
            accessibilityHint="Automatically appends your app version and iOS version to help diagnose the issue."
            style={({ pressed }) => ({
              flexDirection: 'row', alignItems: 'center', gap: 14, padding: 16,
              backgroundColor: colors.card, borderRadius: 14, borderWidth: 1,
              borderColor: state.includeSysInfo ? colors.accent : colors.border,
              marginBottom: 20, opacity: pressed ? 0.85 : 1,
            })}
          >
            <View
              style={{ width: 36, height: 36, borderRadius: 10, backgroundColor: `${colors.accent}18`,
                justifyContent: 'center', alignItems: 'center', flexShrink: 0 }}
              accessibilityElementsHidden
            >
              <Ionicons name="phone-portrait-outline" size={18} color={colors.accent} />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text, marginBottom: 2 }}>
                Include app and device info
              </Text>
              <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 18 }}>
                Appends your app version and iOS version to help diagnose the issue.
              </Text>
            </View>
            <Switch
              value={state.includeSysInfo}
              onValueChange={v => set({ includeSysInfo: v })}
              trackColor={{ false: colors.border, true: colors.accent }}
              accessible={false}
            />
          </Pressable>
        )}

        {/* Tips */}
        {type === 'bug' && (
          <View
            style={{ backgroundColor: `${colors.accent}10`, borderRadius: 12, padding: 14,
              borderLeftWidth: 3, borderLeftColor: colors.accent, marginBottom: 20 }}
            accessible
            accessibilityLabel="Tips for a helpful bug report: describe the exact steps to reproduce the issue, what you expected to happen, and what actually happened. Include your device model and iOS version."
          >
            <Text style={{ fontSize: 13, fontWeight: '700', color: colors.accent, marginBottom: 8 }}>
              Tips for a helpful bug report
            </Text>
            {[
              'Describe the exact steps to reproduce the issue.',
              'State what you expected versus what actually happened.',
              'Include your device model and iOS version if relevant.',
              'Turn on "Include app and device info" above to add this automatically.',
            ].map(tip => (
              <View key={tip} style={{ flexDirection: 'row', gap: 8, marginBottom: 5 }} accessibilityElementsHidden>
                <Text style={{ color: colors.accent }}>•</Text>
                <Text style={{ flex: 1, fontSize: 13, color: colors.textSecondary, lineHeight: 18 }}>{tip}</Text>
              </View>
            ))}
          </View>
        )}

        {/* Continue */}
        <Pressable
          onPress={handleContinue}
          disabled={!canContinue}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Continue to review"
          accessibilityState={{ disabled: !canContinue }}
          accessibilityHint={canContinue ? 'Opens the review and send step.' : 'Enter a subject and at least 20 characters in your message to continue.'}
          style={({ pressed }) => ({
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
  );
}
