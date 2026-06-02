import { useCallback, useEffect, useRef, useState } from 'react';
import { AccessibilityInfo, ActivityIndicator, findNodeHandle, KeyboardAvoidingView,
  Platform, Pressable, ScrollView, Text, TextInput, View } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Screen } from '../src/components/Screen';
import { GuidelinesReminder } from '../src/components/GuidelinesReminder';
import { WritingToolsTip } from '../src/components/WritingToolsTip';
import { TranslationBanner } from '../src/components/TranslationBanner';
import { useTheme } from '../src/contexts/ThemeContext';
import { useAuth } from '../src/contexts/AuthContext';
import { useToast } from '../src/contexts/ToastContext';
import { useGuidelinesCheck } from '../src/hooks/useGuidelinesCheck';
import { useLanguageDetection } from '../src/hooks/useLanguageDetection';
import { translateContent } from '../src/services/intelligenceService';
import { api } from '../src/services/api';

const MIN_REPLY_LENGTH = 10;
const MAX_REPLY_LENGTH = 10_000;

export default function Compose() {
  const { topicId, topicTitle } = useLocalSearchParams<{ topicId: string; topicTitle: string }>();
  const router        = useRouter();
  const { colors }    = useTheme();
  const auth          = useAuth();
  const { showToast } = useToast();

  const [body,       setBody]       = useState('');
  const [submitting, setSubmitting] = useState(false);
  const inputRef = useRef<TextInput>(null);

  const { topWarning, dismiss } = useGuidelinesCheck(body);
  const { isNonEnglish, isConfident } = useLanguageDetection(body);

  // Focus text input on mount
  useEffect(() => {
    const t = setTimeout(() => {
      const node = inputRef.current ? findNodeHandle(inputRef.current) : null;
      if (node) AccessibilityInfo.setAccessibilityFocus(node);
    }, 400);
    return () => clearTimeout(t);
  }, []);

  const canSubmit = body.trim().length >= MIN_REPLY_LENGTH && !submitting;
  const remaining = MAX_REPLY_LENGTH - body.length;

  const handleSubmit = useCallback(async () => {
    if (!canSubmit || !auth.user) return;
    const token = await api.account.getSessionToken();
    setSubmitting(true);
    const res = await api.forums.submitReply(topicId, body.trim(), token);
    setSubmitting(false);
    if (res.ok) {
      showToast('Reply posted successfully.', 'success');
      router.back();
    } else {
      showToast(
        res.error.includes('403') || res.error.includes('401')
          ? 'Your session expired. Please sign in again.'
          : `Could not post reply: ${res.error}`,
        'error',
      );
    }
  }, [canSubmit, auth.user, topicId, body, router, showToast]);

  const inputStyle = {
    borderWidth: 1.5,
    borderColor: colors.inputBorder,
    borderRadius: 12,
    paddingHorizontal: 14,
    paddingVertical: 12,
    fontSize: 16,
    lineHeight: 24,
    color: colors.text,
    backgroundColor: colors.inputBackground,
    minHeight: 160,
    textAlignVertical: 'top' as const,
  };

  return (
    <Screen title="Reply" showSettings={false} showSearch={false}>
      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        keyboardVerticalOffset={88}
      >
        <ScrollView
          showsVerticalScrollIndicator={false}
          keyboardShouldPersistTaps="handled"
        >
          {/* Topic context */}
          <View style={{ backgroundColor: colors.card, borderRadius: 12, padding: 14,
            borderWidth: 1, borderColor: colors.border, marginBottom: 16 }}
            accessible accessibilityLabel={`Replying to: ${topicTitle}`}>
            <Text style={{ fontSize: 12, fontWeight: '700', color: colors.textSecondary,
              textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 4 }}
              accessibilityElementsHidden>Replying to</Text>
            <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>{topicTitle}</Text>
          </View>

          {/* Non-English detection */}
          {isNonEnglish && isConfident && (
            <TranslationBanner
              onTranslate={() => translateContent(body, 'Reply')}
              onDismiss={() => {}}
            />
          )}

          {/* Guidelines reminder */}
          {topWarning && (
            <GuidelinesReminder warning={topWarning} onDismiss={dismiss} />
          )}

          {/* Writing Tools tip */}
          <WritingToolsTip />

          {/* Text input */}
          <View style={{ marginBottom: 8 }}>
            <TextInput
              ref={inputRef}
              value={body}
              onChangeText={setBody}
              placeholder="Write your reply here..."
              placeholderTextColor={colors.textSecondary}
              multiline
              maxLength={MAX_REPLY_LENGTH}
              accessible
              accessibilityLabel="Reply text"
              accessibilityHint={`Minimum ${MIN_REPLY_LENGTH} characters. ${remaining} characters remaining.`}
              style={inputStyle}
            />
          </View>

          {/* Character count */}
          <Text style={{ fontSize: 12, color: remaining < 200 ? '#D97706' : colors.textSecondary,
            textAlign: 'right', marginBottom: 16 }}
            accessible accessibilityLabel={`${remaining} characters remaining`}>
            {remaining} characters remaining
          </Text>

          {/* Too short message */}
          {body.length > 0 && body.trim().length < MIN_REPLY_LENGTH && (
            <Text style={{ fontSize: 13, color: '#D97706', marginBottom: 12 }}>
              Reply must be at least {MIN_REPLY_LENGTH} characters.
            </Text>
          )}

          {/* Submit / Cancel */}
          <View style={{ gap: 10 }}>
            <Pressable
              onPress={handleSubmit}
              disabled={!canSubmit}
              accessible
              accessibilityRole="button"
              accessibilityLabel={submitting ? 'Posting reply, please wait' : 'Post reply'}
              accessibilityState={{ disabled: !canSubmit }}
              style={{
                backgroundColor: canSubmit ? colors.accent : colors.border,
                borderRadius: 14, paddingVertical: 16, alignItems: 'center',
              }}
            >
              {submitting
                ? <ActivityIndicator color={colors.accentText} />
                : <Text style={{ color: colors.accentText, fontWeight: '700', fontSize: 16 }}>Post Reply</Text>
              }
            </Pressable>

            <Pressable
              onPress={() => router.back()}
              accessible accessibilityRole="button" accessibilityLabel="Cancel and go back"
              style={{ borderRadius: 14, paddingVertical: 14, alignItems: 'center',
                backgroundColor: colors.card, borderWidth: 1, borderColor: colors.border }}
            >
              <Text style={{ color: colors.text, fontWeight: '600', fontSize: 15 }}>Cancel</Text>
            </Pressable>
          </View>

          {/* API note shown in dev mode */}
          {__DEV__ && (
            <View style={{ marginTop: 16, padding: 12, backgroundColor: colors.pill,
              borderRadius: 8, borderWidth: 1, borderColor: colors.border }}>
              <Text style={{ fontSize: 12, color: colors.textSecondary }}>
                DEV NOTE: submitReply posts to /jsonapi/comment/comment.
                Confirm comment type name and relationship fields with Drupal developer.
                Topic ID: {topicId}
              </Text>
            </View>
          )}

          <View style={{ height: 48 }} />
        </ScrollView>
      </KeyboardAvoidingView>
    </Screen>
  );
}
