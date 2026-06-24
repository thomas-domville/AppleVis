import { useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo, Animated, findNodeHandle,
  Platform, Pressable, ScrollView, Text, View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../src/contexts/ThemeContext';
import { usePodcastWizard, AUDIO_MIME_TYPES, type AudioFileInfo } from '../../src/contexts/PodcastWizardContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { sounds } from '../../src/services/sounds';

const SUPPORTED_FORMATS = ['MP3', 'AAC / M4A', 'WAV', 'AIFF'];

function formatBytes(bytes: number): string {
  if (bytes < 1024)       return `${bytes} B`;
  if (bytes < 1048576)    return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1073741824) return `${(bytes / 1048576).toFixed(1)} MB`;
  return `${(bytes / 1073741824).toFixed(1)} GB`;
}

export default function PodcastStep2() {
  const { colors }                            = useTheme();
  const router                                = useRouter();
  const { state, update }                     = usePodcastWizard();
  const { screenReaderEnabled, reduceMotion } = useAccessibilityPreferences();

  const headingRef = useRef<Text>(null);
  const fadeAnim   = useRef(new Animated.Value(reduceMotion || screenReaderEnabled ? 1 : 0)).current;
  const [importing, setImporting] = useState(false);

  useEffect(() => {
    if (!reduceMotion && !screenReaderEnabled) {
      Animated.timing(fadeAnim, { toValue: 1, duration: 350, useNativeDriver: true }).start();
    }
    if (screenReaderEnabled) {
      const id = setTimeout(() => {
        const node = findNodeHandle(headingRef.current);
        if (node) AccessibilityInfo.setAccessibilityFocus(node);
      }, 350);
      return () => clearTimeout(id);
    }
  }, []);

  const canContinue = !!state.audioFile;

  async function handlePickFile() {
    setImporting(true);
    try {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const { getDocumentAsync } = await import('expo-document-picker') as any;
      const result = await getDocumentAsync({
        type: AUDIO_MIME_TYPES,
        copyToCacheDirectory: true,
      });
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

  function handleContinue() {
    sounds.articleOpen().catch(() => {});
    router.push('/submit-podcast/review' as any);
  }

  return (
    <ScrollView contentContainerStyle={{ padding: 20, paddingBottom: 60 }} showsVerticalScrollIndicator={false}>
      <Animated.View style={{ opacity: fadeAnim, transform: [{ translateY: fadeAnim.interpolate({ inputRange: [0,1], outputRange: [16,0] }) }] }}>

        {/* Back */}
        <Pressable onPress={() => router.back()} accessible accessibilityRole="button" accessibilityLabel="Back to podcast description"
          style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', gap: 4, marginBottom: 20, opacity: pressed ? 0.7 : 1 })}>
          <Ionicons name="chevron-back" size={18} color={colors.accent} />
          <Text style={{ fontSize: 15, color: colors.accent, fontWeight: '600' }}>Back</Text>
        </Pressable>

        {/* Heading */}
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 8 }}>
          <View style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: colors.accent, justifyContent: 'center', alignItems: 'center' }} accessibilityElementsHidden>
            <Ionicons name="musical-notes-outline" size={24} color="#fff" />
          </View>
          <Text ref={headingRef} accessibilityRole="header" style={{ fontSize: 24, fontWeight: '800', color: colors.text, flex: 1 }}>
            Attach your audio
          </Text>
        </View>
        <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 21, marginBottom: 24 }}>
          Upload the audio file for your podcast episode. Choose a file from Files, iCloud Drive, or any document provider.
        </Text>

        {/* Supported formats */}
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: 24 }} accessibilityElementsHidden>
          {SUPPORTED_FORMATS.map(fmt => (
            <View key={fmt} style={{ backgroundColor: `${colors.accent}18`, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 5 }}>
              <Text style={{ fontSize: 13, fontWeight: '600', color: colors.accent }}>{fmt}</Text>
            </View>
          ))}
        </View>
        <Text style={{ fontSize: 12, color: colors.textSecondary, marginBottom: 24 }} accessibilityLabel="Supported audio formats: MP3, AAC, M4A, WAV, AIFF">
          Supported formats: {SUPPORTED_FORMATS.join(', ')}
        </Text>

        {/* File picker area */}
        {state.audioFile ? (
          /* File selected state */
          <View
            style={{
              backgroundColor: `${colors.accent}0F`, borderRadius: 20,
              borderWidth: 2, borderColor: colors.accent, borderStyle: 'solid',
              padding: 20, marginBottom: 20, alignItems: 'center', gap: 12,
            }}
            accessible
            accessibilityLabel={`Audio file selected: ${state.audioFile.name}. Size: ${formatBytes(state.audioFile.size)}.`}
          >
            <View style={{ width: 64, height: 64, borderRadius: 32, backgroundColor: colors.accent, justifyContent: 'center', alignItems: 'center' }} accessibilityElementsHidden>
              <Ionicons name="checkmark-circle" size={36} color="#fff" />
            </View>
            <View style={{ alignItems: 'center' }}>
              <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text, textAlign: 'center' }}>
                {state.audioFile.name}
              </Text>
              <Text style={{ fontSize: 13, color: colors.textSecondary, marginTop: 4 }}>
                {formatBytes(state.audioFile.size)}
              </Text>
            </View>
            <Pressable
              onPress={() => void handlePickFile()}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Replace audio file"
              style={({ pressed }) => ({
                flexDirection: 'row', alignItems: 'center', gap: 6,
                borderRadius: 12, paddingVertical: 10, paddingHorizontal: 16,
                borderWidth: 1.5, borderColor: colors.border, backgroundColor: colors.card,
                opacity: pressed ? 0.8 : 1,
              })}
            >
              <Ionicons name="refresh-outline" size={16} color={colors.accent} accessibilityElementsHidden />
              <Text style={{ fontSize: 14, fontWeight: '600', color: colors.accent }}>Replace file</Text>
            </Pressable>
          </View>
        ) : (
          /* Empty state */
          <View
            style={{
              borderRadius: 20, borderWidth: 2, borderColor: colors.border, borderStyle: 'dashed',
              padding: 32, marginBottom: 20, alignItems: 'center', gap: 14,
            }}
            accessible={false}
          >
            <View style={{ width: 72, height: 72, borderRadius: 36, backgroundColor: `${colors.accent}18`, justifyContent: 'center', alignItems: 'center' }} accessibilityElementsHidden>
              <Ionicons name="folder-open-outline" size={36} color={colors.accent} />
            </View>
            <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text, textAlign: 'center' }}>
              No file selected
            </Text>
            <Text style={{ fontSize: 14, color: colors.textSecondary, textAlign: 'center', lineHeight: 20, maxWidth: 260 }}>
              Tap below to browse your device, iCloud Drive, or any connected storage.
            </Text>
          </View>
        )}

        {/* Pick file button */}
        <Pressable
          onPress={() => void handlePickFile()}
          disabled={importing}
          accessible
          accessibilityRole="button"
          accessibilityLabel={importing ? 'Opening file picker…' : 'Browse for audio file'}
          accessibilityState={{ disabled: importing }}
          style={({ pressed }) => ({
            backgroundColor: state.audioFile ? colors.card : colors.accent,
            borderRadius: 16, paddingVertical: 16,
            alignItems: 'center', flexDirection: 'row', justifyContent: 'center', gap: 8,
            borderWidth: state.audioFile ? 1.5 : 0, borderColor: colors.border,
            opacity: pressed || importing ? 0.85 : 1, marginBottom: 20,
          })}
        >
          <Ionicons
            name="document-attach-outline"
            size={20}
            color={state.audioFile ? colors.accent : '#fff'}
            accessibilityElementsHidden
          />
          <Text style={{ fontSize: 17, fontWeight: '700', color: state.audioFile ? colors.accent : '#fff' }}>
            {importing ? 'Opening…' : state.audioFile ? 'Replace file' : 'Browse Files'}
          </Text>
        </Pressable>

        {/* iOS note */}
        {Platform.OS === 'ios' && (
          <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 8, marginBottom: 24 }}>
            <Ionicons name="information-circle-outline" size={16} color={colors.textSecondary} style={{ marginTop: 1 }} accessibilityElementsHidden />
            <Text style={{ flex: 1, fontSize: 13, color: colors.textSecondary, lineHeight: 19 }}>
              You can also share an audio file to AppleVis from the Files app using the Share menu.
            </Text>
          </View>
        )}

        {/* Continue */}
        <Pressable
          onPress={handleContinue}
          disabled={!canContinue}
          accessible
          accessibilityRole="button"
          accessibilityLabel={canContinue ? 'Continue to review and submit' : 'Continue — select an audio file to proceed'}
          accessibilityState={{ disabled: !canContinue }}
          style={({ pressed }) => ({
            backgroundColor: canContinue ? colors.accent : colors.border,
            borderRadius: 16, paddingVertical: 16,
            alignItems: 'center', flexDirection: 'row', justifyContent: 'center', gap: 8,
            opacity: pressed ? 0.85 : 1,
          })}
        >
          <Text style={{ fontSize: 17, fontWeight: '700', color: canContinue ? '#fff' : colors.textSecondary }}>
            Continue
          </Text>
          <Ionicons name="arrow-forward" size={18} color={canContinue ? '#fff' : colors.textSecondary} accessibilityElementsHidden />
        </Pressable>

      </Animated.View>
    </ScrollView>
  );
}
