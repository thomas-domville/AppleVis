import { useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActivityIndicator, Alert, Animated,
  findNodeHandle, Pressable, ScrollView, Text, View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../src/contexts/ThemeContext';
import { usePodcastWizard } from '../../src/contexts/PodcastWizardContext';
import { useAuth } from '../../src/contexts/AuthContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { submitPodcastForm } from '../../src/services/drupalForm';
import { ThankYouScreen } from '../submit-blog/review';
import { sounds } from '../../src/services/sounds';

function formatBytes(bytes: number): string {
  if (bytes < 1048576)    return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1073741824) return `${(bytes / 1048576).toFixed(1)} MB`;
  return `${(bytes / 1073741824).toFixed(1)} GB`;
}

export default function PodcastStep3() {
  const { colors }                            = useTheme();
  const router                                = useRouter();
  const { state, reset }                      = usePodcastWizard();
  const { user }                              = useAuth();
  const { screenReaderEnabled, reduceMotion } = useAccessibilityPreferences();

  const headingRef  = useRef<Text>(null);
  const fadeAnim    = useRef(new Animated.Value(reduceMotion || screenReaderEnabled ? 1 : 0)).current;
  const [submitting, setSubmitting] = useState(false);
  const [submitted, setSubmitted]   = useState(false);

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

  async function handleSubmit() {
    if (!user || !state.audioFile) return;
    setSubmitting(true);
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
        Alert.alert(
          'Submission Failed',
          `${result.error}\n\nPlease try again or visit applevis.com/podcasts/upload to submit via the web.`,
          [{ text: 'OK' }],
        );
      }
    } finally {
      setSubmitting(false);
    }
  }

  if (submitted) {
    return <ThankYouScreen type="podcast" onDone={() => { reset(); router.replace('/(tabs)/podcasts' as any); }} />;
  }

  const previewText = state.description.length > 200
    ? state.description.slice(0, 200) + '…'
    : state.description;

  return (
    <ScrollView contentContainerStyle={{ padding: 20, paddingBottom: 60 }} showsVerticalScrollIndicator={false}>
      <Animated.View style={{ opacity: fadeAnim, transform: [{ translateY: fadeAnim.interpolate({ inputRange: [0,1], outputRange: [16,0] }) }] }}>

        {/* Back */}
        <Pressable onPress={() => router.back()} accessible accessibilityRole="button" accessibilityLabel="Back to audio file selection"
          style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', gap: 4, marginBottom: 20, opacity: pressed ? 0.7 : 1 })}>
          <Ionicons name="chevron-back" size={18} color={colors.accent} />
          <Text style={{ fontSize: 15, color: colors.accent, fontWeight: '600' }}>Back</Text>
        </Pressable>

        {/* Heading */}
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 8 }}>
          <View style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: colors.accent, justifyContent: 'center', alignItems: 'center' }} accessibilityElementsHidden>
            <Ionicons name="checkmark-circle-outline" size={24} color="#fff" />
          </View>
          <Text ref={headingRef} accessibilityRole="header" style={{ fontSize: 24, fontWeight: '800', color: colors.text, flex: 1 }}>
            Review your submission
          </Text>
        </View>
        <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 21, marginBottom: 24 }}>
          Check your podcast details before submitting to the AppleVis editorial team.
        </Text>

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
              <Text style={{ fontSize: 15, color: colors.text, marginTop: 2 }} numberOfLines={1}>
                {state.audioFile?.name ?? '—'}
              </Text>
              {state.audioFile && (
                <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2 }}>
                  {formatBytes(state.audioFile.size)}
                </Text>
              )}
            </View>
            <View style={{ backgroundColor: `${colors.accent}18`, borderRadius: 8, paddingHorizontal: 8, paddingVertical: 4 }} accessibilityElementsHidden>
              <Text style={{ fontSize: 11, fontWeight: '700', color: colors.accent }}>
                {state.audioFile?.type.includes('mp4') || state.audioFile?.type.includes('m4a') ? 'AAC' :
                 state.audioFile?.type.includes('mpeg') ? 'MP3' :
                 state.audioFile?.type.includes('wav') ? 'WAV' : 'AUDIO'}
              </Text>
            </View>
          </View>

          {/* Description */}
          <View style={{ padding: 16, borderTopWidth: 1, borderTopColor: colors.border }}>
            <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8 }}>
              Description
            </Text>
            <Text style={{ fontSize: 14, color: colors.text, lineHeight: 22 }}>
              {previewText}
            </Text>
            {state.description.length > 200 && (
              <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 6 }}>
                {state.description.length} characters total
              </Text>
            )}
          </View>
        </View>

        {/* Info note */}
        <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 10, backgroundColor: `${colors.accent}0A`, borderRadius: 12, padding: 14, marginBottom: 24, borderWidth: 1, borderColor: `${colors.accent}20` }}>
          <Ionicons name="information-circle-outline" size={18} color={colors.accent} style={{ marginTop: 1 }} accessibilityElementsHidden />
          <Text style={{ flex: 1, fontSize: 13, color: colors.textSecondary, lineHeight: 20 }}>
            Your audio file will be uploaded directly to AppleVis. The editorial team will review your podcast and contact you within 2–3 days.
          </Text>
        </View>

        {/* Submit */}
        <Pressable
          onPress={() => void handleSubmit()}
          disabled={submitting}
          accessible
          accessibilityRole="button"
          accessibilityLabel={submitting ? 'Uploading and submitting your podcast…' : 'Submit podcast to AppleVis'}
          accessibilityState={{ disabled: submitting }}
          style={({ pressed }) => ({
            backgroundColor: colors.accent, borderRadius: 16, paddingVertical: 16,
            alignItems: 'center', flexDirection: 'row', justifyContent: 'center', gap: 8,
            opacity: pressed || submitting ? 0.85 : 1,
          })}
        >
          {submitting
            ? <>
                <ActivityIndicator color="#fff" />
                <Text style={{ fontSize: 17, fontWeight: '700', color: '#fff', marginLeft: 8 }}>Uploading…</Text>
              </>
            : <>
                <Ionicons name="cloud-upload-outline" size={20} color="#fff" accessibilityElementsHidden />
                <Text style={{ fontSize: 17, fontWeight: '700', color: '#fff' }}>Submit to AppleVis</Text>
              </>
          }
        </Pressable>

        <Text style={{ fontSize: 12, color: colors.textSecondary, textAlign: 'center', marginTop: 10, lineHeight: 18 }}>
          Large audio files may take a moment to upload. Please keep the app open.
        </Text>

      </Animated.View>
    </ScrollView>
  );
}
