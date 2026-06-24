import { useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActivityIndicator, Alert, Animated,
  findNodeHandle, Pressable, ScrollView, Text, TextInput, View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useContactWizard } from '../../src/contexts/ContactWizardContext';
import { useAuth } from '../../src/contexts/AuthContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { submitContactForm } from '../../src/services/drupalForm';
import { sounds } from '../../src/services/sounds';
import { ThankYouScreen } from '../submit-blog/review';

const TYPE_COLOR: Record<string, string> = {
  bug:            '#EF4444',
  feedback:       '#0A84FF',
  suggestion:     '#10B981',
  recommendation: '#F59E0B',
};

const TYPE_LABEL: Record<string, string> = {
  bug:            'Bug Report',
  feedback:       'Feedback',
  suggestion:     'Suggestion',
  recommendation: 'Recommendation',
};

const SYS_INFO_SUFFIX = (appVersion: string, platform: string) =>
  `\n\n--- App Info ---\nApp Version: AppleVis ${appVersion}\nPlatform: ${platform}`;

// ── Step 3: Review + Send ─────────────────────────────────────────────────────

export default function ContactStep3() {
  const { colors }                            = useTheme();
  const router                                = useRouter();
  const { state, set, reset }                 = useContactWizard();
  const { user }                              = useAuth();
  const { screenReaderEnabled, reduceMotion } = useAccessibilityPreferences();

  const headingRef   = useRef<Text>(null);
  const fadeAnim     = useRef(new Animated.Value(reduceMotion || screenReaderEnabled ? 1 : 0)).current;
  const [submitting, setSubmitting] = useState(false);
  const [submitted,  setSubmitted]  = useState(false);
  const [nameFocus,  setNameFocus]  = useState(false);
  const [emailFocus, setEmailFocus] = useState(false);

  // Pre-fill name from auth on first mount
  useEffect(() => {
    if (user?.name && !state.name) set({ name: user.name });
  }, []);

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
  const typeLabel  = TYPE_LABEL[type];
  const previewMsg = state.message.length > 220
    ? state.message.slice(0, 220) + '…'
    : state.message;

  const canSend = state.name.trim().length > 0
    && state.email.trim().length > 0
    && state.declaration;

  async function handleSend() {
    if (!canSend) return;
    setSubmitting(true);
    try {
      const { Platform } = require('react-native') as typeof import('react-native');
      const Constants    = require('expo-constants').default as typeof import('expo-constants').default;
      const appVer  = Constants.expoConfig?.version ?? '2026';
      const platStr = Platform.OS === 'ios' ? `iOS ${Platform.Version}` : `Android ${Platform.Version}`;

      const finalMessage = state.includeSysInfo && type === 'bug'
        ? state.message + SYS_INFO_SUFFIX(appVer, platStr)
        : state.message;

      const result = await submitContactForm({
        name:    state.name.trim(),
        email:   state.email.trim(),
        subject: state.subject.trim(),
        message: finalMessage,
      });

      if (result.ok) {
        sounds.success().catch(() => {});
        setSubmitted(true);
        AccessibilityInfo.announceForAccessibility('Message sent successfully.');
      } else {
        Alert.alert(
          'Message Not Sent',
          `${result.error}\n\nYou can also contact us at applevis.com/contact.`,
          [{ text: 'OK' }],
        );
      }
    } finally {
      setSubmitting(false);
    }
  }

  if (submitted) {
    return (
      <ThankYouScreen
        type="contact"
        onDone={() => { reset(); router.replace('/profile' as any); }}
      />
    );
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
          accessibilityLabel="Back to compose message"
          style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', gap: 4, marginBottom: 20, opacity: pressed ? 0.7 : 1 })}
        >
          <Ionicons name="chevron-back" size={18} color={colors.accent} />
          <Text style={{ fontSize: 15, color: colors.accent, fontWeight: '600' }}>Back</Text>
        </Pressable>

        {/* Heading */}
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 8 }}>
          <View
            style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: typeColor, justifyContent: 'center', alignItems: 'center' }}
            accessibilityElementsHidden
          >
            <Ionicons name="send-outline" size={22} color="#fff" />
          </View>
          <Text
            ref={headingRef}
            accessibilityRole="header"
            style={{ fontSize: 24, fontWeight: '800', color: colors.text, flex: 1 }}
          >
            Review and send
          </Text>
        </View>
        <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 21, marginBottom: 24 }}>
          Check your details, then tap Send Message.
        </Text>

        {/* Message summary card */}
        <View
          style={{ backgroundColor: colors.card, borderRadius: 16, overflow: 'hidden',
            borderWidth: 1, borderColor: colors.border, marginBottom: 24 }}
        >
          {/* Type row */}
          <View
            style={{ flexDirection: 'row', alignItems: 'center', gap: 12, padding: 14,
              borderBottomWidth: 1, borderBottomColor: colors.border }}
            accessible
            accessibilityLabel={`Contact type: ${typeLabel}`}
          >
            <View
              style={{ width: 32, height: 32, borderRadius: 8, backgroundColor: `${typeColor}20`,
                justifyContent: 'center', alignItems: 'center' }}
              accessibilityElementsHidden
            >
              <Ionicons name="radio-button-on" size={16} color={typeColor} />
            </View>
            <View>
              <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.5 }}>
                Type
              </Text>
              <Text style={{ fontSize: 15, fontWeight: '700', color: typeColor, marginTop: 2 }}>
                {typeLabel}
              </Text>
            </View>
          </View>

          {/* Subject row */}
          <View
            style={{ flexDirection: 'row', alignItems: 'center', gap: 12, padding: 14,
              borderBottomWidth: 1, borderBottomColor: colors.border }}
            accessible
            accessibilityLabel={`Subject: ${state.subject}`}
          >
            <View
              style={{ width: 32, height: 32, borderRadius: 8, backgroundColor: `${colors.accent}18`,
                justifyContent: 'center', alignItems: 'center' }}
              accessibilityElementsHidden
            >
              <Ionicons name="text-outline" size={16} color={colors.accent} />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.5 }}>
                Subject
              </Text>
              <Text style={{ fontSize: 15, color: colors.text, marginTop: 2 }}>{state.subject}</Text>
            </View>
          </View>

          {/* Message preview */}
          <View style={{ padding: 14 }}>
            <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8 }}>
              Message preview
            </Text>
            <Text style={{ fontSize: 14, color: colors.text, lineHeight: 21 }} numberOfLines={5}>
              {previewMsg}
            </Text>
            {state.message.length > 220 && (
              <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 6 }}>
                {state.message.length} characters total
              </Text>
            )}
            {state.includeSysInfo && type === 'bug' && (
              <View
                style={{ marginTop: 10, paddingTop: 10, borderTopWidth: 1, borderTopColor: colors.border }}
                accessible
                accessibilityLabel="App and device info will be appended automatically."
              >
                <Text style={{ fontSize: 12, color: colors.accent, fontWeight: '600' }}>
                  + App and device info will be appended
                </Text>
              </View>
            )}
          </View>
        </View>

        {/* Your details */}
        <Text
          accessibilityRole="header"
          style={{ fontSize: 17, fontWeight: '700', color: colors.text, marginBottom: 14 }}
        >
          Your details
        </Text>

        {/* Name */}
        <Text
          style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8 }}
          accessibilityElementsHidden
        >
          Your Name
        </Text>
        <TextInput
          value={state.name}
          onChangeText={v => set({ name: v })}
          placeholder="Your full name or username…"
          placeholderTextColor={colors.textSecondary}
          autoCapitalize="words"
          returnKeyType="next"
          accessible
          accessibilityLabel="Your name"
          accessibilityHint="Required."
          onFocus={() => setNameFocus(true)}
          onBlur={() => setNameFocus(false)}
          style={{
            backgroundColor: colors.card, borderRadius: 12,
            borderWidth: nameFocus ? 2 : 1,
            borderColor: nameFocus ? colors.accent : colors.border,
            paddingHorizontal: 14, paddingVertical: 12,
            fontSize: 16, color: colors.text, marginBottom: 16,
          }}
        />

        {/* Email */}
        <Text
          style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8 }}
          accessibilityElementsHidden
        >
          Email Address
        </Text>
        <TextInput
          value={state.email}
          onChangeText={v => set({ email: v })}
          placeholder="your@email.com"
          placeholderTextColor={colors.textSecondary}
          keyboardType="email-address"
          autoCapitalize="none"
          autoCorrect={false}
          returnKeyType="done"
          accessible
          accessibilityLabel="Email address"
          accessibilityHint="Required. Used to send you a reply."
          onFocus={() => setEmailFocus(true)}
          onBlur={() => setEmailFocus(false)}
          style={{
            backgroundColor: colors.card, borderRadius: 12,
            borderWidth: emailFocus ? 2 : 1,
            borderColor: emailFocus ? colors.accent : colors.border,
            paddingHorizontal: 14, paddingVertical: 12,
            fontSize: 16, color: colors.text, marginBottom: 24,
          }}
        />

        {/* Declaration checkbox */}
        <Pressable
          onPress={() => set({ declaration: !state.declaration })}
          accessible
          accessibilityRole="checkbox"
          accessibilityState={{ checked: state.declaration }}
          accessibilityLabel="Declaration: I understand that AppleVis does not accept sponsored posts or content, advertising, SEO, or any other type of paid proposals."
          style={({ pressed }) => ({
            flexDirection: 'row', alignItems: 'flex-start', gap: 12, padding: 16,
            backgroundColor: state.declaration ? `${colors.accent}10` : colors.card,
            borderRadius: 14, borderWidth: state.declaration ? 2 : 1,
            borderColor: state.declaration ? colors.accent : colors.border,
            marginBottom: 24, opacity: pressed ? 0.85 : 1,
          })}
        >
          <View
            style={{
              width: 22, height: 22, borderRadius: 6, flexShrink: 0, marginTop: 1,
              borderWidth: state.declaration ? 0 : 2,
              borderColor: state.declaration ? colors.accent : colors.textSecondary,
              backgroundColor: state.declaration ? colors.accent : 'transparent',
              justifyContent: 'center', alignItems: 'center',
            }}
            accessibilityElementsHidden
          >
            {state.declaration && <Ionicons name="checkmark" size={14} color="#fff" />}
          </View>
          <Text style={{ flex: 1, fontSize: 14, color: colors.text, lineHeight: 21 }}>
            I understand that AppleVis does not accept sponsored posts/content, advertising, SEO, or any other type of paid proposals.
          </Text>
        </Pressable>

        {/* Send button */}
        <Pressable
          onPress={() => void handleSend()}
          disabled={submitting || !canSend}
          accessible
          accessibilityRole="button"
          accessibilityLabel={submitting ? 'Sending your message…' : 'Send message to AppleVis'}
          accessibilityState={{ disabled: submitting || !canSend }}
          accessibilityHint={canSend ? undefined : 'Fill in your name, email, and check the declaration to send.'}
          style={({ pressed }) => ({
            backgroundColor: canSend ? colors.accent : colors.border,
            borderRadius: 16, paddingVertical: 16,
            alignItems: 'center', flexDirection: 'row', justifyContent: 'center', gap: 8,
            opacity: pressed || submitting ? 0.85 : 1,
          })}
        >
          {submitting
            ? <ActivityIndicator color="#fff" />
            : <>
                <Ionicons name="send-outline" size={20} color={canSend ? '#fff' : colors.textSecondary} accessibilityElementsHidden />
                <Text style={{ fontSize: 17, fontWeight: '700', color: canSend ? '#fff' : colors.textSecondary }}>
                  Send Message
                </Text>
              </>
          }
        </Pressable>

        <Text style={{ fontSize: 12, color: colors.textSecondary, textAlign: 'center', marginTop: 10, lineHeight: 18 }}>
          Urgent issues are typically answered same day. Routine enquiries within one business day.
        </Text>

      </Animated.View>
    </ScrollView>
  );
}
