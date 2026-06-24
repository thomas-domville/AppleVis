import { useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActivityIndicator, Alert, Animated,
  findNodeHandle, Pressable, ScrollView, Text, View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useBlogWizard } from '../../src/contexts/BlogWizardContext';
import { useAuth } from '../../src/contexts/AuthContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { submitBlogForm } from '../../src/services/drupalForm';
import { sounds } from '../../src/services/sounds';

// ─── Step 3: Review + Submit ──────────────────────────────────────────────────

export default function BlogStep3() {
  const { colors }                            = useTheme();
  const router                                = useRouter();
  const { state, reset }                      = useBlogWizard();
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
    if (!user) return;
    setSubmitting(true);
    try {
      // Format the message field: title + category + optional cover note
      const message = [
        `Blog Title: ${state.title}`,
        `Category: ${state.category}`,
        state.coverNote ? `\nNote to editors:\n${state.coverNote}` : '',
      ].filter(Boolean).join('\n');

      const result = await submitBlogForm({
        name:      user.name,
        email:     '',
        message,
        blogDraft: state.blogContent,
      });

      sounds.bookmarkSaved().catch(() => {});

      if (result.ok) {
        setSubmitted(true);
        AccessibilityInfo.announceForAccessibility('Blog post submitted successfully.');
      } else {
        Alert.alert(
          'Submission Failed',
          `${result.error}\n\nPlease try again or visit applevis.com to submit via the web form.`,
          [{ text: 'OK' }],
        );
      }
    } finally {
      setSubmitting(false);
    }
  }

  // ── Thank-you screen ────────────────────────────────────────────────────────
  if (submitted) {
    return <ThankYouScreen type="blog" onDone={() => { reset(); router.replace('/(tabs)/discover' as any); }} />;
  }

  const previewText = state.blogContent.length > 280
    ? state.blogContent.slice(0, 280) + '…'
    : state.blogContent;

  return (
    <ScrollView contentContainerStyle={{ padding: 20, paddingBottom: 60 }} showsVerticalScrollIndicator={false}>
      <Animated.View style={{ opacity: fadeAnim, transform: [{ translateY: fadeAnim.interpolate({ inputRange: [0,1], outputRange: [16,0] }) }] }}>

        {/* Back */}
        <Pressable onPress={() => router.back()} accessible accessibilityRole="button" accessibilityLabel="Back to blog content"
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
          Check your post details before submitting to the AppleVis editorial team.
        </Text>

        {/* Summary card */}
        <View style={{ backgroundColor: colors.card, borderRadius: 16, overflow: 'hidden', borderWidth: 1, borderColor: colors.border, marginBottom: 24 }}>
          <ReviewRow label="Title"    value={state.title}    icon="text-outline" />
          <ReviewRow label="Category" value={state.category} icon="pricetag-outline" divider />
          <View style={{ padding: 16, borderTopWidth: 1, borderTopColor: colors.border }}>
            <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8 }}>
              Post preview
            </Text>
            <Text style={{ fontSize: 14, color: colors.text, lineHeight: 22 }} numberOfLines={6}>
              {previewText}
            </Text>
            {state.blogContent.length > 280 && (
              <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 6 }}>
                {state.blogContent.length} characters total
              </Text>
            )}
          </View>
          {state.coverNote ? (
            <View style={{ padding: 16, borderTopWidth: 1, borderTopColor: colors.border }}>
              <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 6 }}>
                Note to editors
              </Text>
              <Text style={{ fontSize: 14, color: colors.text, lineHeight: 21 }} numberOfLines={4}>
                {state.coverNote}
              </Text>
            </View>
          ) : null}
        </View>

        {/* Submit */}
        <Pressable
          onPress={() => void handleSubmit()}
          disabled={submitting}
          accessible
          accessibilityRole="button"
          accessibilityLabel={submitting ? 'Submitting your blog post…' : 'Submit blog post to AppleVis'}
          accessibilityState={{ disabled: submitting }}
          style={({ pressed }) => ({
            backgroundColor: colors.accent, borderRadius: 16, paddingVertical: 16,
            alignItems: 'center', flexDirection: 'row', justifyContent: 'center', gap: 8,
            opacity: pressed || submitting ? 0.85 : 1,
          })}
        >
          {submitting
            ? <ActivityIndicator color="#fff" />
            : <>
                <Ionicons name="send-outline" size={20} color="#fff" accessibilityElementsHidden />
                <Text style={{ fontSize: 17, fontWeight: '700', color: '#fff' }}>Submit to AppleVis</Text>
              </>
          }
        </Pressable>

        <Text style={{ fontSize: 12, color: colors.textSecondary, textAlign: 'center', marginTop: 10, lineHeight: 18 }}>
          Your post will be reviewed by the editorial team before publishing.
        </Text>

      </Animated.View>
    </ScrollView>
  );
}

// ── Shared ReviewRow ─────────────────────────────────────────────────────────

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

// ── Shared Thank-You screen ──────────────────────────────────────────────────

export function ThankYouScreen({
  type,
  onDone,
}: {
  type: 'blog' | 'podcast' | 'bug' | 'app';
  onDone: () => void;
}) {
  const { colors }                            = useTheme();
  const { screenReaderEnabled, reduceMotion } = useAccessibilityPreferences();
  const headingRef = useRef<Text>(null);
  const scaleAnim  = useRef(new Animated.Value(reduceMotion || screenReaderEnabled ? 1 : 0.8)).current;
  const fadeAnim   = useRef(new Animated.Value(reduceMotion || screenReaderEnabled ? 1 : 0)).current;

  useEffect(() => {
    if (!reduceMotion && !screenReaderEnabled) {
      Animated.parallel([
        Animated.spring(scaleAnim, { toValue: 1, useNativeDriver: true, tension: 80, friction: 8 }),
        Animated.timing(fadeAnim, { toValue: 1, duration: 400, useNativeDriver: true }),
      ]).start();
    }
    const id = setTimeout(() => {
      const node = findNodeHandle(headingRef.current);
      if (node) AccessibilityInfo.setAccessibilityFocus(node);
    }, 350);
    return () => clearTimeout(id);
  }, []);

  const config = {
    blog: {
      icon:    'newspaper-outline' as const,
      heading: 'Thank you for your submission!',
      body:    'The AppleVis Editorial Team will review your blog post and determine whether it will be published. We will reach out to you with our decision. Please allow 2–3 days for the approval process.',
      done:    'Back to Discover',
    },
    podcast: {
      icon:    'radio-outline' as const,
      heading: 'Thank you for your submission!',
      body:    'The AppleVis Editorial Team will review your podcast and determine whether it will be approved. We will reach out to you with our decision. Please allow 2–3 days for the approval process.',
      done:    'Back to Podcasts',
    },
    bug: {
      icon:    'bug-outline' as const,
      heading: 'Thank you for your report!',
      body:    'Thank you for helping improve accessibility for everyone. We will evaluate your bug report and reach out to you with our decision. Please allow 2–3 days for us to review and respond.',
      done:    'Done',
    },
    app: {
      icon:    'apps-outline' as const,
      heading: 'Thank you for your submission!',
      body:    'The AppleVis Editorial Team will review your app entry and determine whether it will be published. We will reach out to you with our decision. Please allow 2–3 days for the approval process.',
      done:    'Back to Discover',
    },
  }[type];

  return (
    <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center', padding: 32 }}>
      <Animated.View style={{ alignItems: 'center', opacity: fadeAnim, transform: [{ scale: scaleAnim }] }}>
        <View style={{
          width: 88, height: 88, borderRadius: 44,
          backgroundColor: `${colors.accent}18`,
          justifyContent: 'center', alignItems: 'center', marginBottom: 24,
        }} accessibilityElementsHidden>
          <Ionicons name={config.icon} size={44} color={colors.accent} />
        </View>

        <Text
          ref={headingRef}
          accessibilityRole="header"
          style={{ fontSize: 26, fontWeight: '800', color: colors.text, textAlign: 'center', lineHeight: 32, marginBottom: 16 }}
        >
          {config.heading}
        </Text>

        <Text style={{ fontSize: 15, color: colors.textSecondary, textAlign: 'center', lineHeight: 24, marginBottom: 36 }}>
          {config.body}
        </Text>

        <Pressable
          onPress={onDone}
          accessible
          accessibilityRole="button"
          accessibilityLabel={config.done}
          style={({ pressed }) => ({
            backgroundColor: colors.accent, borderRadius: 16,
            paddingVertical: 15, paddingHorizontal: 36,
            opacity: pressed ? 0.85 : 1,
          })}
        >
          <Text style={{ fontSize: 17, fontWeight: '700', color: '#fff' }}>{config.done}</Text>
        </Pressable>
      </Animated.View>
    </View>
  );
}
