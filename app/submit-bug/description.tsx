import { KeyboardAvoidingView, Platform, Text, TextInput, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { WizardLayout } from '../../src/components/WizardLayout';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useBugWizard } from '../../src/contexts/BugWizardContext';
import { useAlert } from '../../src/contexts/AccessibleAlertContext';
import { sounds } from '../../src/services/sounds';

// ─── Step 3: Describe the bug ─────────────────────────────────────────────────

const TIPS = [
  { icon: 'footsteps-outline',      text: 'Steps to reproduce the bug' },
  { icon: 'checkmark-done-outline', text: 'Expected vs. actual behavior' },
  { icon: 'apps-outline',           text: 'Which app or feature is affected' },
  { icon: 'repeat-outline',         text: 'How often it happens' },
];

export default function BugStep3() {
  const { colors }      = useTheme();
  const { state, update, reset } = useBugWizard();
  const { showAlert }   = useAlert();

  const charCount   = state.description.trim().length;
  const canContinue = charCount >= 30;

  function handleNext() {
    sounds.articleOpen().catch(() => {});
    router.push('/submit-bug/review' as any);
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
        step={3}
        totalSteps={4}
        title="Describe the bug"
        description="Describe what happens in as much detail as possible. The more context you provide, the more useful your report will be."
        onNext={handleNext}
        nextLabel="Continue to Review"
        nextDisabled={!canContinue}
        hideSkip
        onCancel={handleCancel}
      >
        {/* Tips card */}
        <View style={{ backgroundColor: `${colors.accent}0F`, borderRadius: 14, padding: 14, marginBottom: 20, borderWidth: 1, borderColor: `${colors.accent}30` }}>
          <Text style={{ fontSize: 12, fontWeight: '700', color: colors.accent, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 10 }}
            accessibilityRole="header">
            Tips for a helpful bug report
          </Text>
          {TIPS.map(tip => (
            <View key={tip.icon} style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 8, marginBottom: 6 }} accessible accessibilityLabel={tip.text}>
              <Ionicons name={tip.icon as any} size={14} color={colors.accent} style={{ marginTop: 2 }} accessibilityElementsHidden />
              <Text style={{ flex: 1, fontSize: 13, color: colors.textSecondary, lineHeight: 19 }}>{tip.text}</Text>
            </View>
          ))}
        </View>

        {/* Description textarea */}
        <FieldLabel text="Description" required />
        <TextInput
          value={state.description}
          onChangeText={v => update({ description: v })}
          placeholder={'1. Open the Mail app\n2. Enable VoiceOver (Settings > Accessibility > VoiceOver)\n3. Navigate to the Inbox\n\nExpected: VoiceOver reads each button\nActual: VoiceOver skips past the toolbar'}
          placeholderTextColor={colors.textSecondary}
          multiline
          style={{
            backgroundColor: colors.card, borderRadius: 14, padding: 14,
            fontSize: 15, color: colors.text, lineHeight: 24,
            borderWidth: 1.5, borderColor: canContinue ? colors.accent : colors.border,
            minHeight: 260, textAlignVertical: 'top',
          }}
          accessible
          accessibilityLabel="Bug description"
          accessibilityHint="Required. Describe the bug in detail, including steps to reproduce it."
        />
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginTop: 6 }} accessibilityElementsHidden>
          <Text style={{ fontSize: 12, color: colors.textSecondary }}>
            {charCount < 30 ? `${30 - charCount} more characters needed` : 'Good detail ✓'}
          </Text>
          <Text style={{ fontSize: 12, color: canContinue ? colors.accent : colors.textSecondary, fontWeight: '600' }}>
            {charCount} chars
          </Text>
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
