import { useState } from 'react';
import { AccessibilityInfo, SafeAreaView, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { WizardLayout } from '../../src/components/WizardLayout';
import { useTheme } from '../../src/contexts/ThemeContext';
import { usePodcastWizard } from '../../src/contexts/PodcastWizardContext';
import { useAuth } from '../../src/contexts/AuthContext';
import { useAlert } from '../../src/contexts/AccessibleAlertContext';
import { submitPodcastForm } from '../../src/services/drupalForm';
import { ThankYouScreen } from '../submit-blog/review';
import { sounds } from '../../src/services/sounds';
import { routeForContentDestination } from '../../src/navigation/routeResolver';

// ─── Step 3: Review + Submit ──────────────────────────────────────────────────

function formatBytes(bytes: number): string {
  if (bytes < 1048576)    return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1073741824) return `${(bytes / 1048576).toFixed(1)} MB`;
  return `${(bytes / 1073741824).toFixed(1)} GB`;
}

export default function PodcastStep3() {
  const { colors }    = useTheme();
  const { state, reset } = usePodcastWizard();
  const { user }      = useAuth();
  const { showAlert } = useAlert();

  const [submitting, setSubmitting] = useState(false);
  const [submitted, setSubmitted]   = useState(false);

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

  async function handleSubmit() {
    if (!user || !state.audioFile) return;
    setSubmitting(true);
    AccessibilityInfo.announceForAccessibility('Uploading and submitting your podcast…');
    try {
      const result = await submitPodcastForm({
        name:        user.name,
        email:       '',
        description: state.description,
        audioFile:   state.audioFile,
      });

      sounds.bookmarkSaved().catch(() => {});

      if (result.ok) {
        setSubmitted(true);
        AccessibilityInfo.announceForAccessibility('Podcast submitted successfully.');
      } else {
        showAlert({
          title: 'Submission Failed',
          message: result.error + '\n\nPlease try again or visit applevis.com/podcasts/upload to submit via the web.',
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
        <ThankYouScreen type="podcast" onDone={() => { reset(); router.replace(routeForContentDestination('podcasts') as any); }} />
      </SafeAreaView>
    );
  }

  const previewText = state.description.length > 200
    ? state.description.slice(0, 200) + '…'
    : state.description;

  const formatBadge = state.audioFile?.type.includes('mp4') || state.audioFile?.type.includes('m4a') ? 'AAC'
    : state.audioFile?.type.includes('mpeg') ? 'MP3'
    : state.audioFile?.type.includes('wav') ? 'WAV'
    : 'AUDIO';

  return (
    <WizardLayout
      step={3}
      totalSteps={3}
      title="Review your submission"
      description="Check your podcast details before submitting to the AppleVis editorial team."
      onNext={() => void handleSubmit()}
      nextLabel={submitting ? 'Uploading…' : 'Submit to AppleVis'}
      nextDisabled={submitting}
      hideSkip
      onCancel={handleCancel}
    >
      {/* Summary card */}
      <View style={{ backgroundColor: colors.card, borderRadius: 16, overflow: 'hidden', borderWidth: 1, borderColor: colors.border, marginBottom: 24 }}>

        {/* Audio file row */}
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12, padding: 16 }}
          accessible accessibilityLabel={`Audio file: ${state.audioFile?.name ?? 'None selected'}. Size: ${state.audioFile ? formatBytes(state.audioFile.size) : 'Unknown'}`}>
          <View style={{ width: 36, height: 36, borderRadius: 10, backgroundColor: `${colors.accent}18`, justifyContent: 'center', alignItems: 'center' }} accessibilityElementsHidden>
            <Ionicons name="musical-notes-outline" size={18} color={colors.accent} />
          </View>
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.5 }}>Audio file</Text>
            <Text style={{ fontSize: 15, color: colors.text, marginTop: 2 }} numberOfLines={1}>{state.audioFile?.name ?? '—'}</Text>
            {state.audioFile && (
              <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2 }}>{formatBytes(state.audioFile.size)}</Text>
            )}
          </View>
          <View style={{ backgroundColor: `${colors.accent}18`, borderRadius: 8, paddingHorizontal: 8, paddingVertical: 4 }} accessibilityElementsHidden>
            <Text style={{ fontSize: 11, fontWeight: '700', color: colors.accent }}>{formatBadge}</Text>
          </View>
        </View>

        {/* Description */}
        <View style={{ padding: 16, borderTopWidth: 1, borderTopColor: colors.border }}
          accessible accessibilityLabel={`Description: ${previewText}`}>
          <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8 }}>
            Description
          </Text>
          <Text style={{ fontSize: 14, color: colors.text, lineHeight: 22 }}>{previewText}</Text>
          {state.description.length > 200 && (
            <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 6 }}>
              {state.description.length} characters total
            </Text>
          )}
        </View>
      </View>

      {/* Info note */}
      <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 10, backgroundColor: `${colors.accent}0A`, borderRadius: 12, padding: 14, marginBottom: 8, borderWidth: 1, borderColor: `${colors.accent}20` }}>
        <Ionicons name="information-circle-outline" size={18} color={colors.accent} style={{ marginTop: 1 }} accessibilityElementsHidden />
        <Text style={{ flex: 1, fontSize: 13, color: colors.textSecondary, lineHeight: 20 }}>
          Your audio file will be uploaded to AppleVis. The editorial team will review your podcast and contact you within 2–3 days.
        </Text>
      </View>
      <Text style={{ fontSize: 12, color: colors.textSecondary, textAlign: 'center', lineHeight: 18, marginBottom: 8 }}>
        Large audio files may take a moment to upload. Please keep the app open.
      </Text>
    </WizardLayout>
  );
}
