import { KeyboardAvoidingView, Platform, Pressable, Text, TextInput, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { WizardLayout } from '../../src/components/WizardLayout';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useBugWizard, REPRODUCIBLE_OPTIONS, type BugReproducible } from '../../src/contexts/BugWizardContext';
import { useAlert } from '../../src/contexts/AccessibleAlertContext';
import { sounds } from '../../src/services/sounds';

// ─── Step 2: Bug title + Apple Feedback # + Reproducibility ──────────────────

const REPRODUCE_ICONS: Record<string, string> = {
  'Yes, always':    'alert-circle-outline',
  'Yes, sometimes': 'help-circle-outline',
  'No':             'close-circle-outline',
};

const REPRODUCE_COLORS: Record<string, string> = {
  'Yes, always':    '#ef4444',
  'Yes, sometimes': '#f59e0b',
  'No':             '#6b7280',
};

export default function BugStep2() {
  const { colors }      = useTheme();
  const { state, update, reset } = useBugWizard();
  const { showAlert }   = useAlert();

  const canContinue = !!state.title.trim() && !!state.canReproduce;

  function handleNext() {
    sounds.articleOpen().catch(() => {});
    router.push('/submit-bug/description' as any);
  }

  function handleCancel() {
    showAlert({
      title: 'Discard this report?',
      message: 'Your bug report details will be discarded.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep Editing',
      type: 'warning',
      onConfirm: () => {
        reset();
        router.replace('/(tabs)/discover' as any);
      },
    });
  }

  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined} keyboardVerticalOffset={60}>
      <WizardLayout
        step={2}
        totalSteps={4}
        title="Bug details"
        description="Give the bug a clear title and tell us if you can reliably reproduce it."
        onNext={handleNext}
        nextLabel="Next: Describe the Bug"
        nextDisabled={!canContinue}
        hideSkip
        onCancel={handleCancel}
      >
        {/* Bug title */}
        <FieldLabel text="Bug title" required />
        <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 19, marginBottom: 8 }}>
          A short, specific description of the issue. e.g. "VoiceOver skips toolbar buttons in Mail app"
        </Text>
        <TextInput
          value={state.title}
          onChangeText={v => update({ title: v })}
          placeholder="e.g. VoiceOver stops reading after video playback"
          placeholderTextColor={colors.textSecondary}
          style={{
            backgroundColor: colors.card, borderRadius: 12,
            paddingHorizontal: 14, paddingVertical: 12,
            fontSize: 17, color: colors.text, marginBottom: 24,
            borderWidth: 1.5, borderColor: state.title.trim() ? colors.accent : colors.border,
          }}
          accessible
          accessibilityLabel="Bug title"
          accessibilityHint="Required. A short, clear description of the bug."
          returnKeyType="done"
        />

        {/* Apple Feedback # */}
        <FieldLabel text="Apple Feedback number" />
        <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 19, marginBottom: 8 }}>
          If you have already submitted this bug to Apple Feedback, enter the FB number here.
        </Text>
        <TextInput
          value={state.appleFeedback}
          onChangeText={v => update({ appleFeedback: v })}
          placeholder="e.g. FB123456789"
          placeholderTextColor={colors.textSecondary}
          style={{
            backgroundColor: colors.card, borderRadius: 12,
            paddingHorizontal: 14, paddingVertical: 12,
            fontSize: 17, color: colors.text, marginBottom: 6,
            borderWidth: 1.5, borderColor: state.appleFeedback.trim() ? colors.accent : colors.border,
          }}
          accessible
          accessibilityLabel="Apple Feedback number"
          accessibilityHint="Optional. The FB number from Apple's Feedback Assistant app."
          returnKeyType="done"
        />
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, marginBottom: 28 }}>
          <Ionicons name="information-circle-outline" size={14} color={colors.textSecondary} accessibilityElementsHidden />
          <Text style={{ fontSize: 12, color: colors.textSecondary, flex: 1, lineHeight: 17 }}>
            Submit your bug to Apple Feedback at feedbackassistant.apple.com before reporting here.
          </Text>
        </View>

        {/* Reproducibility */}
        <FieldLabel text="Can you reproduce this bug?" required />
        <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 19, marginBottom: 12 }}>
          How reliably does this bug occur?
        </Text>
        <View style={{ gap: 8 }}
          accessibilityRole="radiogroup" accessibilityLabel="Reproducibility options">
          {REPRODUCIBLE_OPTIONS.map((option: BugReproducible) => {
            const selected   = state.canReproduce === option;
            const iconColor  = REPRODUCE_COLORS[option] ?? colors.accent;
            return (
              <Pressable
                key={option}
                onPress={() => { sounds.pickerTick().catch(() => {}); update({ canReproduce: option }); }}
                accessible
                accessibilityRole="radio"
                accessibilityLabel={option}
                accessibilityState={{ selected }}
                style={({ pressed }) => ({
                  flexDirection: 'row', alignItems: 'center', gap: 12, padding: 14,
                  borderRadius: 14, borderWidth: 2,
                  borderColor: selected ? iconColor : colors.border,
                  backgroundColor: selected ? `${iconColor}12` : colors.card,
                  opacity: pressed ? 0.8 : 1,
                })}
              >
                <Ionicons name={REPRODUCE_ICONS[option] as any} size={22} color={selected ? iconColor : colors.textSecondary} accessibilityElementsHidden />
                <Text style={{ flex: 1, fontSize: 15, fontWeight: selected ? '700' : '400', color: selected ? iconColor : colors.text }}>
                  {option}
                </Text>
                {selected && (
                  <View style={{ width: 20, height: 20, borderRadius: 10, backgroundColor: iconColor, justifyContent: 'center', alignItems: 'center' }} accessibilityElementsHidden>
                    <Ionicons name="checkmark" size={13} color="#fff" />
                  </View>
                )}
              </Pressable>
            );
          })}
        </View>
      </WizardLayout>
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
