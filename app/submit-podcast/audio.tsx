import { useState } from 'react';
import { AccessibilityInfo, Platform, Pressable, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { WizardLayout } from '../../src/components/WizardLayout';
import { useTheme } from '../../src/contexts/ThemeContext';
import { usePodcastWizard, AUDIO_MIME_TYPES, type AudioFileInfo } from '../../src/contexts/PodcastWizardContext';
import { useAlert } from '../../src/contexts/AccessibleAlertContext';
import { sounds } from '../../src/services/sounds';

// ─── Step 2: Attach audio file ────────────────────────────────────────────────

const SUPPORTED_FORMATS = ['MP3', 'AAC / M4A', 'WAV', 'AIFF'];

function formatBytes(bytes: number): string {
  if (bytes < 1024)       return `${bytes} B`;
  if (bytes < 1048576)    return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1073741824) return `${(bytes / 1048576).toFixed(1)} MB`;
  return `${(bytes / 1073741824).toFixed(1)} GB`;
}

export default function PodcastStep2() {
  const { colors }    = useTheme();
  const { state, update, reset } = usePodcastWizard();
  const { showAlert } = useAlert();
  const [importing, setImporting] = useState(false);

  const canContinue = !!state.audioFile;

  async function handlePickFile() {
    setImporting(true);
    try {
      const { getDocumentAsync } = await import('expo-document-picker');
      const result = await getDocumentAsync({ type: AUDIO_MIME_TYPES, copyToCacheDirectory: true });
      if (result.canceled || !result.assets?.length) return;
      const asset = result.assets[0];
      const fileInfo: AudioFileInfo = {
        uri:  asset.uri,
        name: asset.name,
        type: asset.mimeType ?? 'audio/mpeg',
        size: asset.size ?? 0,
      };
      update({ audioFile: fileInfo });
      sounds.bookmarkSaved().catch(() => {});
      AccessibilityInfo.announceForAccessibility(
        `Audio file selected: ${asset.name}. ${asset.size ? formatBytes(asset.size) : 'Size unknown'}.`
      );
    } catch {
      AccessibilityInfo.announceForAccessibility('Could not select audio file. Please try again.');
    } finally {
      setImporting(false);
    }
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

  function handleNext() {
    sounds.articleOpen().catch(() => {});
    router.push('/submit-podcast/review' as any);
  }

  return (
    <WizardLayout
      step={2}
      totalSteps={3}
      title="Attach your audio"
      description="Upload the audio file for your podcast episode. You can choose from Files, iCloud Drive, or any document provider."
      onNext={handleNext}
      nextLabel="Continue to Review"
      nextDisabled={!canContinue}
      hideSkip
      onCancel={handleCancel}
    >
      {/* Supported formats */}
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: 8 }} accessibilityElementsHidden>
        {SUPPORTED_FORMATS.map(fmt => (
          <View key={fmt} style={{ backgroundColor: `${colors.accent}18`, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 5 }}>
            <Text style={{ fontSize: 13, fontWeight: '600', color: colors.accent }}>{fmt}</Text>
          </View>
        ))}
      </View>
      <Text style={{ fontSize: 12, color: colors.textSecondary, marginBottom: 24 }}
        accessibilityLabel="Supported audio formats: MP3, AAC, M4A, WAV, AIFF">
        Supported formats: {SUPPORTED_FORMATS.join(', ')}
      </Text>

      {/* File state */}
      {state.audioFile ? (
        <View
          style={{ backgroundColor: `${colors.accent}0F`, borderRadius: 20, borderWidth: 2, borderColor: colors.accent, padding: 20, marginBottom: 20, alignItems: 'center', gap: 12 }}
          accessible
          accessibilityLabel={`Audio file selected: ${state.audioFile.name}. Size: ${formatBytes(state.audioFile.size)}.`}
        >
          <View style={{ width: 64, height: 64, borderRadius: 32, backgroundColor: colors.accent, justifyContent: 'center', alignItems: 'center' }} accessibilityElementsHidden>
            <Ionicons name="checkmark-circle" size={36} color="#fff" />
          </View>
          <View style={{ alignItems: 'center' }}>
            <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text, textAlign: 'center' }}>{state.audioFile.name}</Text>
            <Text style={{ fontSize: 13, color: colors.textSecondary, marginTop: 4 }}>{formatBytes(state.audioFile.size)}</Text>
          </View>
          <Pressable
            onPress={() => void handlePickFile()}
            accessible accessibilityRole="button" accessibilityLabel="Replace audio file"
            style={({ pressed }) => ({
              flexDirection: 'row', alignItems: 'center', gap: 6, borderRadius: 12,
              paddingVertical: 10, paddingHorizontal: 16,
              borderWidth: 1.5, borderColor: colors.border, backgroundColor: colors.card,
              opacity: pressed ? 0.8 : 1,
            })}
          >
            <Ionicons name="refresh-outline" size={16} color={colors.accent} accessibilityElementsHidden />
            <Text style={{ fontSize: 14, fontWeight: '600', color: colors.accent }}>Replace file</Text>
          </Pressable>
        </View>
      ) : (
        <View
          style={{ borderRadius: 20, borderWidth: 2, borderColor: colors.border, borderStyle: 'dashed', padding: 32, marginBottom: 20, alignItems: 'center', gap: 14 }}
          accessible={false}
        >
          <View style={{ width: 72, height: 72, borderRadius: 36, backgroundColor: `${colors.accent}18`, justifyContent: 'center', alignItems: 'center' }} accessibilityElementsHidden>
            <Ionicons name="folder-open-outline" size={36} color={colors.accent} />
          </View>
          <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text, textAlign: 'center' }}>No file selected</Text>
          <Text style={{ fontSize: 14, color: colors.textSecondary, textAlign: 'center', lineHeight: 20, maxWidth: 260 }}>
            Tap below to browse your device, iCloud Drive, or any connected storage.
          </Text>
        </View>
      )}

      {/* Browse button */}
      <Pressable
        onPress={() => void handlePickFile()}
        disabled={importing}
        accessible accessibilityRole="button"
        accessibilityLabel={importing ? 'Opening file picker…' : 'Browse for audio file'}
        accessibilityState={{ disabled: importing }}
        style={({ pressed }) => ({
          backgroundColor: state.audioFile ? colors.card : colors.accent,
          borderRadius: 16, paddingVertical: 16,
          alignItems: 'center', flexDirection: 'row', justifyContent: 'center', gap: 8,
          borderWidth: state.audioFile ? 1.5 : 0, borderColor: colors.border,
          opacity: pressed || importing ? 0.85 : 1, marginBottom: 16,
        })}
      >
        <Ionicons name="document-attach-outline" size={20} color={state.audioFile ? colors.accent : '#fff'} accessibilityElementsHidden />
        <Text style={{ fontSize: 17, fontWeight: '700', color: state.audioFile ? colors.accent : '#fff' }}>
          {importing ? 'Opening…' : state.audioFile ? 'Replace file' : 'Browse Files'}
        </Text>
      </Pressable>

      {/* iOS share tip */}
      {Platform.OS === 'ios' && (
        <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 8 }}>
          <Ionicons name="information-circle-outline" size={16} color={colors.textSecondary} style={{ marginTop: 1 }} accessibilityElementsHidden />
          <Text style={{ flex: 1, fontSize: 13, color: colors.textSecondary, lineHeight: 19 }}>
            You can also share an audio file to AppleVis from the Files app using the Share menu.
          </Text>
        </View>
      )}
    </WizardLayout>
  );
}
