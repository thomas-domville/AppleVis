import { useRef, useState } from 'react';
import { AccessibilityInfo, Pressable, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import Constants from 'expo-constants';
import { Platform } from 'react-native';
import { WizardLayout } from '../../src/components/WizardLayout';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useContactWizard } from '../../src/contexts/ContactWizardContext';
import { useAuth } from '../../src/contexts/AuthContext';
import { useAlert } from '../../src/contexts/AccessibleAlertContext';
import { submitContactForm } from '../../src/services/drupalForm';
import { sounds } from '../../src/services/sounds';
import { ThankYouScreen } from '../submit-blog/review';
import { TYPE_COLOR, TYPE_LABEL, TYPE_ICON } from './index';

const SYS_SUFFIX = () => {
  const ver  = Constants.expoConfig?.version ?? '2026';
  const plat = Platform.OS === 'ios' ? `iOS ${Platform.Version}` : `Android ${Platform.Version}`;
  return `\n\n--- App Info ---\nApp Version: AppleVis ${ver}\nPlatform: ${plat}`;
};

// ── Final step: Review + Send ─────────────────────────────────────────────────

export default function ContactReview() {
  const { colors }            = useTheme();
  const auth                  = useAuth();
  const { state, set, reset } = useContactWizard();
  const { showAlert }         = useAlert();

  const [emailFocus, setEmailFocus] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [submitted,  setSubmitted]  = useState(false);

  const isSignedIn = auth.isSignedIn;
  const step       = isSignedIn ? 3 : 4;
  const totalSteps = isSignedIn ? 3 : 4;

  const type      = state.contactType ?? 'feedback';
  const typeColor = TYPE_COLOR[type];
  const typeLabel = TYPE_LABEL[type];
  const typeIcon  = TYPE_ICON[type];

  // Signed-in users: name from auth, email must be entered here.
  // Guests: both were entered in details.tsx.
  const displayName  = isSignedIn ? (auth.user?.name ?? '') : state.name;
  const canSend      = displayName.trim().length > 0
    && state.email.trim().includes('@')
    && state.declaration
    && !submitting;

  const previewMsg = state.message.length > 200
    ? state.message.slice(0, 200) + '…'
    : state.message;

  function handleCancel() {
    showAlert({
      title: 'Discard this message?',
      message: 'Your contact support message will be discarded.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep Editing',
      type: 'warning',
      onConfirm: () => {
        reset();
        router.replace({ pathname: '/profile' as any, params: { focus: 'contactSupport' } });
      },
    });
  }

  async function handleSend() {
    if (!canSend) return;
    setSubmitting(true);
    AccessibilityInfo.announceForAccessibility('Sending your message…');
    try {
      const finalMessage = state.includeSysInfo && type === 'bug'
        ? state.message + SYS_SUFFIX()
        : state.message;

      const result = await submitContactForm({
        name:    displayName.trim(),
        email:   state.email.trim(),
        subject: state.subject,
        message: finalMessage,
      });

      if (result.ok) {
        sounds.success().catch(() => {});
        setSubmitted(true);
        AccessibilityInfo.announceForAccessibility('Message sent successfully.');
      } else {
        showAlert({
          title: 'Message Not Sent',
          message: result.error + '\n\nYou can also contact us at applevis.com/contact.',
          type: 'error',
        });
      }
    } finally {
      setSubmitting(false);
    }
  }

  if (submitted) {
    return (
      <SafeAreaView style={{ flex: 1 }}>
        <ThankYouScreen
          type="contact"
          onDone={() => {
            reset();
            router.replace({ pathname: '/profile' as any, params: { focus: 'contactSupport' } });
          }}
        />
      </SafeAreaView>
    );
  }

  return (
    <WizardLayout
      step={step}
      totalSteps={totalSteps}
      title="Review and send"
      description="Check your message, then tap Send Message."
      onNext={() => void handleSend()}
      nextLabel={submitting ? 'Sending…' : 'Send Message'}
      nextDisabled={!canSend}
      hideSkip
      hideStepIndicator={false}
      accentColor={typeColor}
      onCancel={handleCancel}
    >
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
            <Ionicons name={typeIcon as any} size={16} color={typeColor} />
          </View>
          <View>
            <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary,
              textTransform: 'uppercase', letterSpacing: 0.5 }}>
              Type
            </Text>
            <Text style={{ fontSize: 15, fontWeight: '700', color: typeColor, marginTop: 2 }}>
              {typeLabel}
            </Text>
          </View>
          <Pressable
            onPress={() => router.back()}
            accessible
            accessibilityRole="button"
            accessibilityLabel="Edit message"
            accessibilityHint="Goes back to edit your message."
            style={({ pressed }) => ({ marginLeft: 'auto', opacity: pressed ? 0.6 : 1 })}
          >
            <Ionicons name="pencil-outline" size={18} color={colors.textSecondary} />
          </Pressable>
        </View>

        {/* Subject row (auto-generated) */}
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
            <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary,
              textTransform: 'uppercase', letterSpacing: 0.5 }}>
              Subject
            </Text>
            <Text style={{ fontSize: 15, color: colors.text, marginTop: 2 }}>
              {state.subject}
            </Text>
          </View>
        </View>

        {/* Message preview */}
        <View style={{ padding: 14 }}>
          <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8 }}>
            Message preview
          </Text>
          <Text style={{ fontSize: 14, color: colors.text, lineHeight: 21 }}>
            {previewMsg}
          </Text>
          {state.message.length > 200 && (
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
              <Text style={{ fontSize: 12, color: typeColor, fontWeight: '600' }}>
                + App and device info will be appended
              </Text>
            </View>
          )}
        </View>
      </View>

      {/* From section */}
      <Text
        accessibilityRole="header"
        style={{ fontSize: 17, fontWeight: '700', color: colors.text, marginBottom: 14 }}
      >
        From
      </Text>

      {/* Name — read-only for signed-in, read-only for guests (entered in details step) */}
      <View
        style={{ backgroundColor: colors.card, borderRadius: 12, borderWidth: 1,
          borderColor: colors.border, paddingHorizontal: 14, paddingVertical: 12, marginBottom: 16,
          flexDirection: 'row', alignItems: 'center', gap: 10 }}
        accessible
        accessibilityLabel={`Name: ${displayName}`}
      >
        <Ionicons name="person-outline" size={16} color={colors.textSecondary} accessibilityElementsHidden />
        <Text style={{ fontSize: 16, color: colors.text, flex: 1 }}>
          {displayName || 'No name entered'}
        </Text>
        {isSignedIn && (
          <Text style={{ fontSize: 12, color: colors.textSecondary }}>from account</Text>
        )}
      </View>

      {/* Email — editable for signed-in, read-only for guests */}
      {isSignedIn ? (
        <>
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
            accessibilityHint="Required. We will use this address to reply to you."
            onFocus={() => setEmailFocus(true)}
            onBlur={() => setEmailFocus(false)}
            style={{
              backgroundColor: colors.card, borderRadius: 12,
              borderWidth: emailFocus ? 2 : 1,
              borderColor: emailFocus ? typeColor : colors.border,
              paddingHorizontal: 14, paddingVertical: 12,
              fontSize: 16, color: colors.text, marginBottom: 24,
            }}
          />
        </>
      ) : (
        <View
          style={{ backgroundColor: colors.card, borderRadius: 12, borderWidth: 1,
            borderColor: colors.border, paddingHorizontal: 14, paddingVertical: 12,
            marginBottom: 24, flexDirection: 'row', alignItems: 'center', gap: 10 }}
          accessible
          accessibilityLabel={`Email: ${state.email}`}
        >
          <Ionicons name="mail-outline" size={16} color={colors.textSecondary} accessibilityElementsHidden />
          <Text style={{ fontSize: 16, color: colors.text, flex: 1 }}>
            {state.email || 'No email entered'}
          </Text>
        </View>
      )}

      {/* Declaration */}
      <Pressable
        onPress={() => set({ declaration: !state.declaration })}
        accessible
        accessibilityRole="checkbox"
        accessibilityState={{ checked: state.declaration }}
        accessibilityLabel="Declaration: I understand that AppleVis does not accept sponsored posts or content, advertising, SEO, or any other type of paid proposals."
        style={({ pressed }) => ({
          flexDirection: 'row', alignItems: 'flex-start', gap: 12, padding: 16,
          backgroundColor: state.declaration ? `${typeColor}10` : colors.card,
          borderRadius: 14, borderWidth: state.declaration ? 2 : 1,
          borderColor: state.declaration ? typeColor : colors.border,
          marginBottom: 8, opacity: pressed ? 0.85 : 1,
        })}
      >
        <View
          style={{
            width: 22, height: 22, borderRadius: 6, flexShrink: 0, marginTop: 1,
            borderWidth: state.declaration ? 0 : 2,
            borderColor: state.declaration ? typeColor : colors.textSecondary,
            backgroundColor: state.declaration ? typeColor : 'transparent',
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
    </WizardLayout>
  );
}
