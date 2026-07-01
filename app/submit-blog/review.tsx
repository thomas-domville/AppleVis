import { useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo, Animated, findNodeHandle,
  Pressable, Text, View,
} from 'react-native';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { SafeAreaView } from 'react-native-safe-area-context';
import { WizardLayout } from '../../src/components/WizardLayout';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useBlogWizard } from '../../src/contexts/BlogWizardContext';
import { useAuth } from '../../src/contexts/AuthContext';
import { useAlert } from '../../src/contexts/AccessibleAlertContext';
import { submitBlogForm } from '../../src/services/drupalForm';
import { sounds } from '../../src/services/sounds';

// ─── Step 3: Review + Submit ──────────────────────────────────────────────────

export default function BlogStep3() {
  const { colors }     = useTheme();
  const { state, reset } = useBlogWizard();
  const { user }       = useAuth();
  const { showAlert }  = useAlert();

  const [submitting, setSubmitting] = useState(false);
  const [submitted, setSubmitted]   = useState(false);

  const previewText = state.blogContent.length > 280
    ? state.blogContent.slice(0, 280) + '…'
    : state.blogContent;

  function handleCancel() {
    showAlert({
      title: 'Discard this submission?',
      message: 'Your blog post will be discarded.',
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
    if (!user) return;
    setSubmitting(true);
    AccessibilityInfo.announceForAccessibility('Submitting your blog post…');
    try {
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
        showAlert({
          title: 'Submission Failed',
          message: result.error + '\n\nPlease try again or visit applevis.com to submit via the web form.',
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
        <ThankYouScreen type="blog" onDone={() => { reset(); router.replace('/(tabs)/discover' as any); }} />
      </SafeAreaView>
    );
  }

  return (
    <WizardLayout
      step={3}
      totalSteps={3}
      title="Review your submission"
      description="Check everything looks right, then submit. Our editorial team will review your post within 2–3 days."
      onNext={() => void handleSubmit()}
      nextLabel={submitting ? 'Submitting…' : 'Submit Blog Post'}
      nextDisabled={submitting}
      hideSkip
      onCancel={handleCancel}
    >
      {/* Summary card */}
      <View style={{ backgroundColor: colors.card, borderRadius: 16, overflow: 'hidden', borderWidth: 1, borderColor: colors.border, marginBottom: 24 }}>
        <ReviewRow label="Title"    value={state.title}    icon="newspaper-outline" />
        <ReviewRow label="Category" value={state.category} icon="folder-outline" divider />
        <View style={{ padding: 16, borderTopWidth: 1, borderTopColor: colors.border }}
          accessible accessibilityLabel={`Post preview: ${previewText}`}>
          <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8 }}>
            Post preview
          </Text>
          <Text style={{ fontSize: 14, color: colors.text, lineHeight: 22 }} numberOfLines={6}>
            {previewText}
          </Text>
          {state.blogContent.length > 280 && (
            <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 4 }}>
              {state.blogContent.length} characters total
            </Text>
          )}
        </View>
        {state.coverNote ? (
          <View style={{ padding: 16, borderTopWidth: 1, borderTopColor: colors.border }}
            accessible accessibilityLabel={`Note to editors: ${state.coverNote}`}>
            <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8 }}>
              Note to editors
            </Text>
            <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20 }} numberOfLines={3}>
              {state.coverNote}
            </Text>
          </View>
        ) : null}
      </View>

      {/* Edit reminder */}
      <View
        style={{ flexDirection: 'row', alignItems: 'center', gap: 10, padding: 14,
          backgroundColor: `${colors.accent}10`, borderRadius: 12 }}
        accessible
        accessibilityLabel="You can go back to edit any step before submitting."
      >
        <Ionicons name="information-circle-outline" size={18} color={colors.accent} accessibilityElementsHidden />
        <Text style={{ flex: 1, fontSize: 13, color: colors.text, lineHeight: 19 }}>
          Go back to edit any step before submitting.
        </Text>
      </View>
    </WizardLayout>
  );
}

// ─── Shared ReviewRow ─────────────────────────────────────────────────────────

function ReviewRow({ label, value, icon, divider }: { label: string; value: string; icon: string; divider?: boolean }) {
  const { colors } = useTheme();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12, padding: 16,
      borderTopWidth: divider ? 1 : 0, borderTopColor: colors.border }}
      accessible accessibilityLabel={`${label}: ${value}`}>
      <View style={{ width: 36, height: 36, borderRadius: 10, backgroundColor: `${colors.accent}18`,
        justifyContent: 'center', alignItems: 'center' }} accessibilityElementsHidden>
        <Ionicons name={icon as any} size={18} color={colors.accent} />
      </View>
      <View style={{ flex: 1 }}>
        <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</Text>
        <Text style={{ fontSize: 15, color: colors.text, marginTop: 2 }}>{value}</Text>
      </View>
    </View>
  );
}

// ─── ThankYouScreen (shared by all submission wizards) ────────────────────────

export function ThankYouScreen({
  type,
  onDone,
}: {
  type: 'blog' | 'podcast' | 'bug' | 'app' | 'contact';
  onDone: () => void;
}) {
  const { colors }  = useTheme();
  const headingRef  = useRef<Text>(null);
  const scaleAnim   = useRef(new Animated.Value(0.8)).current;
  const fadeAnim    = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.parallel([
      Animated.spring(scaleAnim, { toValue: 1, useNativeDriver: true, tension: 80, friction: 8 }),
      Animated.timing(fadeAnim, { toValue: 1, duration: 400, useNativeDriver: true }),
    ]).start();
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
    contact: {
      icon:    'mail-outline' as const,
      heading: 'Message sent!',
      body:    'The AppleVis team has received your message. We typically reply to urgent issues as soon as possible and routine enquiries within one business day.',
      done:    'Back to Profile',
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
            backgroundColor: colors.accent, borderRadius: 14,
            paddingVertical: 16, paddingHorizontal: 32, opacity: pressed ? 0.85 : 1,
          })}
        >
          <Text style={{ fontSize: 17, fontWeight: '700', color: colors.accentText }}>{config.done}</Text>
        </Pressable>
      </Animated.View>
    </View>
  );
}
