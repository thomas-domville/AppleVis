import { useState } from 'react';
import { AccessibilityInfo, Pressable, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { WizardLayout } from '../../src/components/WizardLayout';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useBugWizard, RECOGNITION_OPTIONS, type BugRecognition } from '../../src/contexts/BugWizardContext';
import { useAuth } from '../../src/contexts/AuthContext';
import { useAlert } from '../../src/contexts/AccessibleAlertContext';
import { submitBugForm } from '../../src/services/drupalForm';
import { ThankYouScreen } from '../submit-blog/review';
import { sounds } from '../../src/services/sounds';

// ─── Step 4: Recognition + Review + Submit ────────────────────────────────────

export default function BugStep4() {
  const { colors }     = useTheme();
  const { state, update, reset } = useBugWizard();
  const { user }       = useAuth();
  const { showAlert }  = useAlert();

  const [submitting, setSubmitting] = useState(false);
  const [submitted, setSubmitted]   = useState(false);

  const canSubmit = !!state.recognition;

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

  async function handleSubmit() {
    if (!user || !state.recognition) return;
    setSubmitting(true);
    AccessibilityInfo.announceForAccessibility('Submitting your bug report…');
    try {
      const result = await submitBugForm({
        name:            user.name,
        email:           '',
        title:           state.title,
        appleFeedback:   state.appleFeedback,
        platform:        state.platform as 'iOS' | 'iPadOS' | 'macOS',
        softwareVersion: state.softwareVersion,
        canReproduce:    state.canReproduce as 'Yes, always' | 'Yes, sometimes' | 'No',
        description:     state.description,
        recognition:     state.recognition,
      });

      sounds.bookmarkSaved().catch(() => {});

      if (result.ok) {
        setSubmitted(true);
        AccessibilityInfo.announceForAccessibility('Bug report submitted successfully.');
      } else {
        showAlert({
          title: 'Submission Failed',
          message: result.error + '\n\nPlease try again or visit applevis.com/form/community-bug-report-form to submit via the web.',
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
        <ThankYouScreen type="bug" onDone={() => { reset(); router.replace('/(tabs)/discover' as any); }} />
      </SafeAreaView>
    );
  }

  return (
    <WizardLayout
      step={4}
      totalSteps={4}
      title="Recognition & review"
      description="Review your report and choose how you'd like to be credited if your bug is featured."
      onNext={() => void handleSubmit()}
      nextLabel={submitting ? 'Submitting…' : 'Submit Report'}
      nextDisabled={!canSubmit || submitting}
      hideSkip
      onCancel={handleCancel}
    >
      {/* Summary card */}
      <View style={{ backgroundColor: colors.card, borderRadius: 16, overflow: 'hidden', borderWidth: 1, borderColor: colors.border, marginBottom: 24 }}>
        <ReviewRow label="Platform"    value={state.platform}        icon="layers-outline" />
        <ReviewRow label="OS version"  value={state.softwareVersion} icon="code-slash-outline" divider />
        <ReviewRow label="Bug title"   value={state.title}           icon="bug-outline" divider />
        {state.appleFeedback ? (
          <ReviewRow label="Apple Feedback" value={state.appleFeedback} icon="logo-apple" divider />
        ) : null}
        <ReviewRow label="Reproducible" value={state.canReproduce}  icon="repeat-outline" divider />
        <View style={{ padding: 16, borderTopWidth: 1, borderTopColor: colors.border }}
          accessible accessibilityLabel={`Description: ${state.description.slice(0, 240)}`}>
          <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8 }}>
            Description
          </Text>
          <Text style={{ fontSize: 14, color: colors.text, lineHeight: 22 }} numberOfLines={5}>
            {state.description.length > 240 ? state.description.slice(0, 240) + '…' : state.description}
          </Text>
          {state.description.length > 240 && (
            <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 4 }}>
              {state.description.length} characters total
            </Text>
          )}
        </View>
      </View>

      {/* Recognition picker */}
      <FieldLabel text="Recognition" required />
      <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 19, marginBottom: 12 }}>
        If your bug is featured in AppleVis content, how would you like to be credited?
      </Text>
      <View style={{ gap: 8 }}
        accessibilityRole="radiogroup" accessibilityLabel="Recognition options">
        {RECOGNITION_OPTIONS.map((option: BugRecognition) => {
          const selected = state.recognition === option;
          return (
            <Pressable
              key={option}
              onPress={() => { sounds.pickerTick().catch(() => {}); update({ recognition: option }); }}
              accessible
              accessibilityRole="radio"
              accessibilityLabel={option}
              accessibilityState={{ selected }}
              style={({ pressed }) => ({
                flexDirection: 'row', alignItems: 'center', gap: 12, padding: 14,
                borderRadius: 14, borderWidth: 2,
                borderColor: selected ? colors.accent : colors.border,
                backgroundColor: selected ? `${colors.accent}12` : colors.card,
                opacity: pressed ? 0.8 : 1,
              })}
            >
              <View style={{
                width: 22, height: 22, borderRadius: 11, borderWidth: 2,
                borderColor: selected ? colors.accent : colors.border,
                backgroundColor: selected ? colors.accent : 'transparent',
                justifyContent: 'center', alignItems: 'center',
              }} accessibilityElementsHidden>
                {selected && <Ionicons name="checkmark" size={13} color="#fff" />}
              </View>
              <Text style={{ flex: 1, fontSize: 14, fontWeight: selected ? '700' : '400', color: selected ? colors.accent : colors.text, lineHeight: 20 }}>
                {option}
              </Text>
            </Pressable>
          );
        })}
      </View>
    </WizardLayout>
  );
}

function ReviewRow({ label, value, icon, divider }: { label: string; value: string; icon: string; divider?: boolean }) {
  const { colors } = useTheme();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12, padding: 16, borderTopWidth: divider ? 1 : 0, borderTopColor: colors.border }}
      accessible accessibilityLabel={`${label}: ${value}`}>
      <View style={{ width: 36, height: 36, borderRadius: 10, backgroundColor: `${colors.accent}18`, justifyContent: 'center', alignItems: 'center' }} accessibilityElementsHidden>
        <Ionicons name={icon as any} size={18} color={colors.accent} />
      </View>
      <View style={{ flex: 1 }}>
        <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</Text>
        <Text style={{ fontSize: 15, color: colors.text, marginTop: 2, lineHeight: 21 }}>{value}</Text>
      </View>
    </View>
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
