import { useEffect, useRef, useState } from 'react';
import { AccessibilityInfo, Text, TextInput, View } from 'react-native';
import { router } from 'expo-router';
import { WizardLayout } from '../../src/components/WizardLayout';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useContactWizard } from '../../src/contexts/ContactWizardContext';
import { useAuth } from '../../src/contexts/AuthContext';
import { useAlert } from '../../src/contexts/AccessibleAlertContext';
import { sounds } from '../../src/services/sounds';
import { TYPE_COLOR } from './index';

// ── Step 2 (guests only): Your Details ───────────────────────────────────────

export default function ContactDetails() {
  const { colors }           = useTheme();
  const auth                 = useAuth();
  const { state, set, reset } = useContactWizard();
  const { showAlert }        = useAlert();

  const emailRef = useRef<TextInput>(null);
  const [nameFocus,  setNameFocus]  = useState(false);
  const [emailFocus, setEmailFocus] = useState(false);

  // Signed-in users should not land here — redirect forward.
  useEffect(() => {
    if (auth.isSignedIn) router.replace('/contact/compose' as any);
  }, [auth.isSignedIn]);

  const typeColor  = state.contactType ? TYPE_COLOR[state.contactType] : colors.accent;
  const canContinue = state.name.trim().length > 0 && state.email.trim().includes('@');

  function handleNext() {
    if (!canContinue) return;
    sounds.articleOpen().catch(() => {});
    router.push('/contact/compose' as any);
  }

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

  return (
    <WizardLayout
      step={2}
      totalSteps={4}
      title="Your Details"
      description="We need your name and email address so we can reply to you."
      onNext={handleNext}
      nextLabel="Next"
      nextDisabled={!canContinue}
      hideSkip
      accentColor={typeColor}
      onCancel={handleCancel}
    >
      {/* Name */}
      <Text
        style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
          textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8 }}
        accessibilityElementsHidden
      >
        Full Name or Username
      </Text>
      <TextInput
        value={state.name}
        onChangeText={v => set({ name: v })}
        placeholder="Your name or username…"
        placeholderTextColor={colors.textSecondary}
        autoCapitalize="words"
        returnKeyType="next"
        onSubmitEditing={() => emailRef.current?.focus()}
        accessible
        accessibilityLabel="Full name or username"
        accessibilityHint="Required. Used to address our reply."
        onFocus={() => setNameFocus(true)}
        onBlur={() => setNameFocus(false)}
        style={{
          backgroundColor: colors.card, borderRadius: 12,
          borderWidth: nameFocus ? 2 : 1,
          borderColor: nameFocus ? typeColor : colors.border,
          paddingHorizontal: 14, paddingVertical: 12,
          fontSize: 16, color: colors.text, marginBottom: 20,
        }}
      />

      {/* Email */}
      <Text
        style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
          textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8 }}
        accessibilityElementsHidden
      >
        Email Address
      </Text>
      <TextInput
        ref={emailRef}
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
          borderColor: emailFocus ? typeColor : colors.border,
          paddingHorizontal: 14, paddingVertical: 12,
          fontSize: 16, color: colors.text, marginBottom: 8,
        }}
      />
      <Text style={{ fontSize: 12, color: colors.textSecondary, lineHeight: 17, marginBottom: 24 }}>
        We only use your email to reply to this message and will not add you to any mailing list.
      </Text>

      {/* Privacy note */}
      <View
        style={{ backgroundColor: `${typeColor}10`, borderRadius: 12, padding: 14,
          borderLeftWidth: 3, borderLeftColor: typeColor }}
        accessible
        accessibilityLabel="Your details are only used to reply to this message. AppleVis does not sell or share your personal information."
      >
        <Text style={{ fontSize: 13, color: colors.text, lineHeight: 19 }}>
          Your details are only used to reply to this message. AppleVis does not sell or share your personal information.
        </Text>
      </View>
    </WizardLayout>
  );
}
