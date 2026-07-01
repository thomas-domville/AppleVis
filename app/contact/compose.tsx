import { useRef, useState } from 'react';
import { AccessibilityInfo, Pressable, Switch, Text, TextInput, View } from 'react-native';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { WizardLayout } from '../../src/components/WizardLayout';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useContactWizard } from '../../src/contexts/ContactWizardContext';
import { useAuth } from '../../src/contexts/AuthContext';
import { useAlert } from '../../src/contexts/AccessibleAlertContext';
import { sounds } from '../../src/services/sounds';
import { TYPE_COLOR, TYPE_LABEL, TYPE_ICON, MESSAGE_PLACEHOLDER } from './index';

// ── Step 2 (signed-in) / Step 3 (guest): Write your message ──────────────────

export default function ContactCompose() {
  const { colors }           = useTheme();
  const auth                 = useAuth();
  const { state, set, reset } = useContactWizard();
  const { showAlert }        = useAlert();

  const messageRef       = useRef<TextInput>(null);
  const charAnnouncedRef = useRef(false);
  const [msgFocus, setMsgFocus] = useState(false);

  const isSignedIn = auth.isSignedIn;
  const step       = isSignedIn ? 2 : 3;
  const totalSteps = isSignedIn ? 3 : 4;

  const type       = state.contactType ?? 'feedback';
  const typeColor  = TYPE_COLOR[type];
  const typeLabel  = TYPE_LABEL[type];
  const typeIcon   = TYPE_ICON[type];
  const placeholder = MESSAGE_PLACEHOLDER[type];
  const msgLen     = state.message.trim().length;
  const canContinue = msgLen >= 20;

  function handleMessageChange(v: string) {
    set({ message: v });
    const len = v.trim().length;
    if (!charAnnouncedRef.current && len >= 20) {
      charAnnouncedRef.current = true;
      AccessibilityInfo.announceForAccessibility('Minimum length reached. You can now continue.');
    } else if (charAnnouncedRef.current && len < 20) {
      charAnnouncedRef.current = false;
    }
  }

  function handleNext() {
    if (!canContinue) return;
    sounds.articleOpen().catch(() => {});
    router.push('/contact/review' as any);
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
      step={step}
      totalSteps={totalSteps}
      title="Write your message"
      description={`You're sending a ${typeLabel}. Write as much detail as you like.`}
      onNext={handleNext}
      nextLabel="Continue to Review"
      nextDisabled={!canContinue}
      hideSkip
      accentColor={typeColor}
      onCancel={handleCancel}
    >
      {/* Type badge */}
      <View
        style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 20 }}
        accessible
        accessibilityLabel={`Contact type: ${typeLabel}`}
      >
        <View
          style={{ width: 32, height: 32, borderRadius: 10, backgroundColor: `${typeColor}20`,
            justifyContent: 'center', alignItems: 'center' }}
          accessibilityElementsHidden
        >
          <Ionicons name={typeIcon as any} size={17} color={typeColor} />
        </View>
        <Text style={{ fontSize: 14, fontWeight: '700', color: typeColor }}>
          {typeLabel}
        </Text>
        <Pressable
          onPress={() => router.back()}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Change contact type"
          accessibilityHint="Goes back to step 1 to change your selection."
          style={({ pressed }) => ({ opacity: pressed ? 0.6 : 1 })}
        >
          <Text style={{ fontSize: 13, color: colors.textSecondary, textDecorationLine: 'underline' }}>
            Change
          </Text>
        </Pressable>
      </View>

      {/* Message */}
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 8 }}>
        <Text
          style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.5 }}
          accessibilityElementsHidden
        >
          Message
        </Text>
        <Text
          style={{ fontSize: 13, color: msgLen >= 20 ? colors.textSecondary : '#EF4444',
            fontWeight: msgLen >= 20 ? '400' : '700' }}
          accessible
          accessibilityLabel={msgLen >= 20
            ? `${msgLen} characters`
            : `${msgLen} of 20 minimum characters`}
        >
          {msgLen < 20 ? `${msgLen} / 20 min` : `${msgLen} chars`}
        </Text>
      </View>

      <TextInput
        ref={messageRef}
        value={state.message}
        onChangeText={handleMessageChange}
        placeholder={placeholder}
        placeholderTextColor={colors.textSecondary}
        multiline
        textAlignVertical="top"
        onFocus={() => setMsgFocus(true)}
        onBlur={() => setMsgFocus(false)}
        accessible
        accessibilityLabel="Message"
        accessibilityHint={`Required. Minimum 20 characters. ${placeholder}`}
        style={{
          backgroundColor: colors.card, borderRadius: 12,
          borderWidth: msgFocus ? 2 : 1,
          borderColor: msgFocus ? typeColor : colors.border,
          paddingHorizontal: 14, paddingVertical: 12,
          fontSize: 16, color: colors.text, minHeight: 180,
          marginBottom: 16,
        }}
      />

      {/* Bug: include sysinfo toggle */}
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
            borderColor: state.includeSysInfo ? typeColor : colors.border,
            marginBottom: 20, opacity: pressed ? 0.85 : 1,
          })}
        >
          <View
            style={{ width: 36, height: 36, borderRadius: 10, backgroundColor: `${typeColor}18`,
              justifyContent: 'center', alignItems: 'center', flexShrink: 0 }}
            accessibilityElementsHidden
          >
            <Ionicons name="phone-portrait-outline" size={18} color={typeColor} />
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
            trackColor={{ false: colors.border, true: typeColor }}
            accessible={false}
          />
        </Pressable>
      )}

      {/* Bug tips */}
      {type === 'bug' && (
        <View
          style={{ backgroundColor: `${typeColor}10`, borderRadius: 12, padding: 14,
            borderLeftWidth: 3, borderLeftColor: typeColor }}
          accessible
          accessibilityLabel="Tips for a helpful bug report: describe the exact steps to reproduce the issue, what you expected to happen, and what actually happened. Turn on Include app and device info above to automatically attach your version details."
        >
          <Text style={{ fontSize: 13, fontWeight: '700', color: typeColor, marginBottom: 8 }}>
            Tips for a helpful bug report
          </Text>
          {[
            'Describe the exact steps to reproduce the issue.',
            'State what you expected versus what actually happened.',
            'Turn on "Include app and device info" above to attach your version details.',
          ].map(tip => (
            <View key={tip} style={{ flexDirection: 'row', gap: 8, marginBottom: 5 }} accessibilityElementsHidden>
              <Text style={{ color: typeColor }}>•</Text>
              <Text style={{ flex: 1, fontSize: 13, color: colors.textSecondary, lineHeight: 18 }}>{tip}</Text>
            </View>
          ))}
        </View>
      )}
    </WizardLayout>
  );
}
