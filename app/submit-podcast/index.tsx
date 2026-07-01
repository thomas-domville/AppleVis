import { KeyboardAvoidingView, Platform, Text, TextInput, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { WizardLayout } from '../../src/components/WizardLayout';
import { useTheme } from '../../src/contexts/ThemeContext';
import { usePodcastWizard } from '../../src/contexts/PodcastWizardContext';
import { useAlert } from '../../src/contexts/AccessibleAlertContext';
import { sounds } from '../../src/services/sounds';

// ─── Step 1: Podcast description ──────────────────────────────────────────────

export default function PodcastStep1() {
  const { colors }      = useTheme();
  const { state, update, reset } = usePodcastWizard();
  const { showAlert }   = useAlert();

  const charCount   = state.description.trim().length;
  const canContinue = charCount >= 20;

  function handleNext() {
    sounds.articleOpen().catch(() => {});
    router.push('/submit-podcast/audio' as any);
  }

  function handleCancel() {
    showAlert({
      title: 'Discard this submission?',
      message: 'Your podcast details will be discarded.',
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
        step={1}
        totalSteps={3}
        title="Submit a podcast"
        description="Share your podcast about accessibility, Apple products, or blindness with the AppleVis community."
        onNext={handleNext}
        nextLabel="Next: Attach Audio"
        nextDisabled={!canContinue}
        hideSkip
        onCancel={handleCancel}
      >
        {/* What we look for */}
        <View style={{ backgroundColor: `${colors.accent}0F`, borderRadius: 14, padding: 14, marginBottom: 24, borderWidth: 1, borderColor: `${colors.accent}30` }}>
          <Text style={{ fontSize: 12, fontWeight: '700', color: colors.accent, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 10 }}
            accessibilityRole="header">
            What we look for
          </Text>
          {[
            { icon: 'mic-outline',           text: 'Clear audio quality, ideally recorded in a quiet space' },
            { icon: 'accessibility-outline', text: 'Accessibility focus — VoiceOver tips, blind tech, community stories' },
            { icon: 'time-outline',          text: 'Any length, but 5–60 minutes is ideal' },
            { icon: 'language-outline',      text: 'English preferred, though other languages are welcome' },
          ].map(tip => (
            <View key={tip.icon} style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 8, marginBottom: 6 }}
              accessible accessibilityLabel={tip.text}>
              <Ionicons name={tip.icon as any} size={14} color={colors.accent} style={{ marginTop: 2 }} accessibilityElementsHidden />
              <Text style={{ flex: 1, fontSize: 13, color: colors.textSecondary, lineHeight: 19 }}>{tip.text}</Text>
            </View>
          ))}
        </View>

        {/* Description */}
        <FieldLabel text="Podcast description" required />
        <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 19, marginBottom: 8 }}>
          What is your podcast about? Include the topic, who it is for, and any relevant context.
        </Text>
        <TextInput
          value={state.description}
          onChangeText={v => update({ description: v })}
          placeholder="e.g. A weekly show covering accessibility features in the latest Apple software updates, aimed at VoiceOver users of all skill levels…"
          placeholderTextColor={colors.textSecondary}
          multiline
          style={{
            backgroundColor: colors.card, borderRadius: 14, padding: 14,
            fontSize: 16, color: colors.text, lineHeight: 24,
            borderWidth: 1.5, borderColor: canContinue ? colors.accent : colors.border,
            minHeight: 160, textAlignVertical: 'top',
          }}
          accessible
          accessibilityLabel="Podcast description"
          accessibilityHint="Required. Describe what your podcast is about and who it is for. Minimum 20 characters."
        />
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginTop: 6, marginBottom: 4 }} accessibilityElementsHidden>
          <Text style={{ fontSize: 12, color: colors.textSecondary }}>
            {charCount < 20 ? `${20 - charCount} more characters needed` : 'Looks great ✓'}
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
