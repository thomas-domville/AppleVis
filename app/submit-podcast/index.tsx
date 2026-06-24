import { useEffect, useRef } from 'react';
import {
  AccessibilityInfo, Animated, findNodeHandle,
  KeyboardAvoidingView, Platform, Pressable, ScrollView,
  Text, TextInput, View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../src/contexts/ThemeContext';
import { usePodcastWizard } from '../../src/contexts/PodcastWizardContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { sounds } from '../../src/services/sounds';

export default function PodcastStep1() {
  const { colors }                            = useTheme();
  const router                                = useRouter();
  const { state, update }                     = usePodcastWizard();
  const { screenReaderEnabled, reduceMotion } = useAccessibilityPreferences();

  const headingRef = useRef<Text>(null);
  const fadeAnim   = useRef(new Animated.Value(reduceMotion || screenReaderEnabled ? 1 : 0)).current;

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

  const charCount   = state.description.trim().length;
  const canContinue = charCount >= 20;

  function handleContinue() {
    sounds.articleOpen().catch(() => {});
    router.push('/submit-podcast/audio' as any);
  }

  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined} keyboardVerticalOffset={100}>
      <ScrollView
        contentContainerStyle={{ padding: 20, paddingBottom: 60 }}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
      >
        <Animated.View style={{ opacity: fadeAnim, transform: [{ translateY: fadeAnim.interpolate({ inputRange: [0,1], outputRange: [16,0] }) }] }}>

          {/* Heading */}
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 8, marginTop: 8 }}>
            <View style={{ width: 52, height: 52, borderRadius: 26, backgroundColor: colors.accent, justifyContent: 'center', alignItems: 'center' }} accessibilityElementsHidden>
              <Ionicons name="radio-outline" size={28} color="#fff" />
            </View>
            <Text ref={headingRef} accessibilityRole="header" style={{ fontSize: 26, fontWeight: '800', color: colors.text, flex: 1, lineHeight: 32 }}>
              Submit a podcast
            </Text>
          </View>

          <Text style={{ fontSize: 15, color: colors.textSecondary, lineHeight: 23, marginBottom: 28 }}>
            Share your podcast about accessibility, Apple products, or blindness with the AppleVis community. All submissions are reviewed by our editorial team.
          </Text>

          {/* What makes a great podcast card */}
          <View style={{ backgroundColor: `${colors.accent}0F`, borderRadius: 14, padding: 14, marginBottom: 24, borderWidth: 1, borderColor: `${colors.accent}30` }}>
            <Text style={{ fontSize: 12, fontWeight: '700', color: colors.accent, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 10 }}
              accessibilityRole="header">
              What we look for
            </Text>
            {[
              { icon: 'mic-outline', text: 'Clear audio quality, ideally recorded in a quiet space' },
              { icon: 'accessibility-outline', text: 'Accessibility focus — VoiceOver tips, blind tech, community stories' },
              { icon: 'time-outline', text: 'Any length, but 5–60 minutes is ideal' },
              { icon: 'language-outline', text: 'English preferred, though other languages are welcome' },
            ].map(tip => (
              <View key={tip.icon} style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 8, marginBottom: 6 }} accessible accessibilityLabel={tip.text}>
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

          {/* Continue */}
          <Pressable
            onPress={handleContinue}
            disabled={!canContinue}
            accessible
            accessibilityRole="button"
            accessibilityLabel={canContinue ? 'Continue to attach your audio file' : `Continue — ${20 - charCount} more characters needed`}
            accessibilityState={{ disabled: !canContinue }}
            style={({ pressed }) => ({
              marginTop: 32,
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
