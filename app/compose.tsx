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
import { useAlert } from '../src/contexts/AccessibleAlertContext';
import { ALERTS } from '../src/data/alertMessages';
import { useGuidelinesCheck } from '../src/hooks/useGuidelinesCheck';
import { useLanguageDetection } from '../src/hooks/useLanguageDetection';
import { translateContent } from '../src/services/intelligenceService';
import { api } from '../src/services/api';

const MIN_BODY_LENGTH = 10;
const MIN_SUBJECT_LENGTH = 3;
const MAX_BODY_LENGTH = 10_000;

export default function Compose() {
  const { topicId, topicTitle, episodeId, episodeTitle, mode, replyToAuthor, replyToQuote } =
    useLocalSearchParams<{
      topicId: string; topicTitle: string;
      episodeId?: string; episodeTitle?: string;
      mode?: string;
      replyToAuthor?: string; replyToQuote?: string;
    }>();
  const isNewTopic        = mode === 'newTopic';
  const isEpisodeComment  = !isNewTopic && !!episodeId;
  const isResourceComment = mode === 'resourceComment';
  const isBlogComment     = mode === 'blogComment';
  const isReplyToComment  = !isNewTopic && !isEpisodeComment && !isResourceComment && !isBlogComment && !!replyToAuthor;
  const router        = useRouter();
  const { colors }    = useTheme();
  const auth          = useAuth();
  const { showToast } = useToast();
  const { showAlert } = useAlert();

  const [subject, setSubject] = useState(() => {
    if (replyToAuthor && topicTitle) {
      const t = topicTitle.length > 40 ? topicTitle.slice(0, 40) + '…' : topicTitle;
      return `@${replyToAuthor} re: ${t}`;
    }
    return '';
  });
  const [body, setBody] = useState(() => {
    if (replyToAuthor && replyToQuote) {
      return `Replying to ${replyToAuthor}:\n"${replyToQuote.trim()}"\n\n`;
    }
    return '';
  });
  const [submitting,      setSubmitting]      = useState(false);
  const [bannerDismissed, setBannerDismissed] = useState(false);
  const subjectRef = useRef<TextInput>(null);
  const bodyRef    = useRef<TextInput>(null);

  const { topWarning, dismiss } = useGuidelinesCheck(body);
  const { isNonEnglish, isConfident } = useLanguageDetection(body);

  useEffect(() => {
    if (!isNonEnglish) setBannerDismissed(false);
  }, [isNonEnglish]);

  // Focus subject (new topic) or body (reply) on mount
  useEffect(() => {
    const ref = isNewTopic ? subjectRef : bodyRef;
    const t = setTimeout(() => {
      const node = ref.current ? findNodeHandle(ref.current) : null;
      if (node) AccessibilityInfo.setAccessibilityFocus(node);
    }, 400);
    return () => clearTimeout(t);
  }, [isNewTopic]);

  const canSubmit = isNewTopic
    ? subject.trim().length >= MIN_SUBJECT_LENGTH && body.trim().length >= MIN_BODY_LENGTH && !submitting
    : body.trim().length >= MIN_BODY_LENGTH && !submitting;
  const remaining = MAX_BODY_LENGTH - body.length;

  const handleSubmit = useCallback(async () => {
    if (!canSubmit || !auth.user) return;
    const token = await api.account.getSessionToken();
    setSubmitting(true);
    if (isNewTopic) {
      const res = await api.forums.submitNewTopic(subject.trim(), body.trim(), token);
      setSubmitting(false);
      if (res.ok) {
        showToast('Topic posted! It will appear after moderation.', 'success');
        router.back();
      } else {
        (res.error.includes('403') || res.error.includes('401'))
          ? showAlert(ALERTS.auth.sessionExpired())
          : showAlert(ALERTS.compose.postFailed(res.error));
      }
    } else if (isEpisodeComment) {
      const res = await api.podcasts.submitComment(episodeId!, body.trim(), token);
      setSubmitting(false);
      if (res.ok) { showToast('Comment posted successfully.', 'success'); router.back(); }
      else if (res.error.includes('403') || res.error.includes('401')) { showAlert(ALERTS.auth.sessionExpired()); }
      else { showAlert(ALERTS.compose.commentFailed(res.error)); }
    } else if (isResourceComment) {
      const res = await api.resources.submitComment(topicId, body.trim(), token);
      setSubmitting(false);
      if (res.ok) { showToast('Comment posted successfully.', 'success'); router.back(); }
      else if (res.error.includes('403') || res.error.includes('401')) { showAlert(ALERTS.auth.sessionExpired()); }
      else { showAlert(ALERTS.compose.commentFailed(res.error)); }
    } else if (isBlogComment) {
      const res = await api.blogs.submitComment(topicId, body.trim(), token);
      setSubmitting(false);
      if (res.ok) { showToast('Comment posted successfully.', 'success'); router.back(); }
      else if (res.error.includes('403') || res.error.includes('401')) { showAlert(ALERTS.auth.sessionExpired()); }
      else { showAlert(ALERTS.compose.commentFailed(res.error)); }
    } else {
      const res = await api.forums.submitReply(
        topicId, body.trim(), token,
        isReplyToComment ? (subject.trim() || 'Reply') : undefined,
      );
      setSubmitting(false);
      if (res.ok) { showToast('Comment posted successfully.', 'success'); router.back(); }
      else if (res.error.includes('403') || res.error.includes('401')) { showAlert(ALERTS.auth.sessionExpired()); }
      else { showAlert(ALERTS.compose.commentFailed(res.error)); }
    }
  }, [canSubmit, auth.user, topicId, episodeId, subject, body, isNewTopic, isEpisodeComment, isResourceComment, isBlogComment, isReplyToComment, router, showToast]);

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
    textAlignVertical: 'top' as const,
  };

  return (
    <Screen
        title={
          isNewTopic        ? 'New Topic'         :
          isReplyToComment  ? 'Reply to Comment'  :
          isResourceComment ? 'Add Guide Comment' :
          isBlogComment     ? 'Add Blog Comment'  :
          'Add New Comment'
        }
        showSettings={false}
        showSearch={false}
      >
      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        keyboardVerticalOffset={88}
      >
        <ScrollView
          showsVerticalScrollIndicator={false}
          keyboardShouldPersistTaps="handled"
        >
          {/* Context card */}
          {isNewTopic ? (
            <View
              style={{ backgroundColor: colors.card, borderRadius: 12, padding: 14,
                borderWidth: 1, borderColor: colors.border, marginBottom: 16 }}
              accessible
              accessibilityLabel="Post a new topic to AppleVis Forums"
            >
              <Text style={{ fontSize: 12, fontWeight: '700', color: colors.textSecondary,
                textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 4 }}
                accessibilityElementsHidden>
                Posting to
              </Text>
              <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>
                AppleVis Forums
              </Text>
            </View>
          ) : isReplyToComment ? (
            <View
              style={{ backgroundColor: colors.card, borderRadius: 12, padding: 14,
                borderWidth: 1, borderColor: colors.border, marginBottom: 16 }}
              accessible
              accessibilityLabel={`Replying to ${replyToAuthor}${replyToQuote ? `: ${replyToQuote}` : ''}`}
            >
              <Text style={{ fontSize: 12, fontWeight: '700', color: colors.textSecondary,
                textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 4 }}
                accessibilityElementsHidden>
                Replying to
              </Text>
              <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text, marginBottom: replyToQuote ? 6 : 0 }}>
                {replyToAuthor}
              </Text>
              {!!replyToQuote && (
                <Text
                  style={{ fontSize: 13, color: colors.textSecondary, fontStyle: 'italic', lineHeight: 18 }}
                  numberOfLines={2}
                  accessibilityElementsHidden
                >
                  {`"${replyToQuote}"`}
                </Text>
              )}
            </View>
          ) : isEpisodeComment ? (
            <View
              style={{ backgroundColor: colors.card, borderRadius: 12, padding: 14,
                borderWidth: 1, borderColor: colors.border, marginBottom: 16 }}
              accessible
              accessibilityLabel={`Adding new comment to episode: ${episodeTitle}`}
            >
              <Text style={{ fontSize: 12, fontWeight: '700', color: colors.textSecondary,
                textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 4 }}
                accessibilityElementsHidden>
                Adding comment to
              </Text>
              <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>
                {episodeTitle}
              </Text>
            </View>
          ) : isResourceComment ? (
            <View
              style={{ backgroundColor: colors.card, borderRadius: 12, padding: 14,
                borderWidth: 1, borderColor: colors.border, marginBottom: 16 }}
              accessible
              accessibilityLabel={`Adding comment to guide: ${topicTitle}`}
            >
              <Text style={{ fontSize: 12, fontWeight: '700', color: colors.textSecondary,
                textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 4 }}
                accessibilityElementsHidden>
                Commenting on guide
              </Text>
              <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>{topicTitle}</Text>
            </View>
          ) : isBlogComment ? (
            <View
              style={{ backgroundColor: colors.card, borderRadius: 12, padding: 14,
                borderWidth: 1, borderColor: colors.border, marginBottom: 16 }}
              accessible
              accessibilityLabel={`Adding comment to blog post: ${topicTitle}`}
            >
              <Text style={{ fontSize: 12, fontWeight: '700', color: colors.textSecondary,
                textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 4 }}
                accessibilityElementsHidden>
                Commenting on blog post
              </Text>
              <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>{topicTitle}</Text>
            </View>
          ) : (
            <View
              style={{ backgroundColor: colors.card, borderRadius: 12, padding: 14,
                borderWidth: 1, borderColor: colors.border, marginBottom: 16 }}
              accessible
              accessibilityLabel={`Adding new comment to: ${topicTitle}`}
            >
              <Text style={{ fontSize: 12, fontWeight: '700', color: colors.textSecondary,
                textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 4 }}
                accessibilityElementsHidden>
                Adding comment to
              </Text>
              <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>
                {topicTitle}
              </Text>
            </View>
          )}

          {/* Subject field — new topic and direct replies */}
          {(isNewTopic || isReplyToComment) && (
            <View style={{ marginBottom: 12 }}>
              <TextInput
                ref={subjectRef}
                value={subject}
                onChangeText={setSubject}
                placeholder={isNewTopic ? 'Topic subject…' : 'Subject…'}
                placeholderTextColor={colors.textSecondary}
                maxLength={200}
                accessible
                accessibilityLabel={isNewTopic ? 'Topic subject' : 'Subject'}
                accessibilityHint={isNewTopic ? `Minimum ${MIN_SUBJECT_LENGTH} characters` : 'You can edit the pre-filled subject'}
                style={[inputStyle, { minHeight: 0, height: 52, lineHeight: 24 }]}
                returnKeyType="next"
                onSubmitEditing={() => bodyRef.current?.focus()}
              />
              {isNewTopic && subject.length > 0 && subject.trim().length < MIN_SUBJECT_LENGTH && (
                <Text style={{ fontSize: 13, color: '#D97706', marginTop: 6 }}>
                  Subject must be at least {MIN_SUBJECT_LENGTH} characters.
                </Text>
              )}
            </View>
          )}

          {/* Non-English detection */}
          {isNonEnglish && isConfident && !bannerDismissed && (
            <TranslationBanner
              onTranslate={() => translateContent(body)}
              onDismiss={() => setBannerDismissed(true)}
            />
          )}

          {/* Guidelines reminder */}
          {topWarning && (
            <GuidelinesReminder warning={topWarning} onDismiss={dismiss} />
          )}

          {/* Writing Tools tip */}
          <WritingToolsTip />

          {/* Body input */}
          <View style={{ marginBottom: 8 }}>
            <TextInput
              ref={bodyRef}
              value={body}
              onChangeText={setBody}
              placeholder={isNewTopic ? 'Write your topic here…' : 'Write your comment here…'}
              placeholderTextColor={colors.textSecondary}
              multiline
              maxLength={MAX_BODY_LENGTH}
              accessible
              accessibilityLabel={isNewTopic ? 'Topic body' : 'Comment text'}
              accessibilityHint={`Minimum ${MIN_BODY_LENGTH} characters. ${remaining} characters remaining.`}
              style={[inputStyle, { minHeight: 160 }]}
            />
          </View>

          {/* Character count */}
          <Text
            style={{ fontSize: 12, color: remaining < 200 ? '#D97706' : colors.textSecondary,
              textAlign: 'right', marginBottom: 16 }}
            accessible
            accessibilityLabel={`${remaining} characters remaining`}
          >
            {remaining} characters remaining
          </Text>

          {/* Too short message */}
          {body.length > 0 && body.trim().length < MIN_BODY_LENGTH && (
            <Text style={{ fontSize: 13, color: '#D97706', marginBottom: 12 }}>
              {isNewTopic ? 'Topic body' : 'Comment'} must be at least {MIN_BODY_LENGTH} characters.
            </Text>
          )}

          {/* Submit / Cancel */}
          <View style={{ gap: 10 }}>
            <Pressable
              onPress={handleSubmit}
              disabled={!canSubmit}
              accessible
              accessibilityRole="button"
              accessibilityLabel={
                submitting
                  ? (isNewTopic ? 'Posting topic, please wait' : 'Posting comment, please wait')
                  : (isNewTopic ? 'Post topic' : 'Post comment')
              }
              accessibilityState={{ disabled: !canSubmit }}
              style={{
                backgroundColor: canSubmit ? colors.accent : colors.border,
                borderRadius: 14, paddingVertical: 16, alignItems: 'center',
              }}
            >
              {submitting
                ? <ActivityIndicator color={colors.accentText} />
                : <Text style={{ color: colors.accentText, fontWeight: '700', fontSize: 16 }}>
                    {isNewTopic ? 'Post Topic' : 'Post Comment'}
                  </Text>
              }
            </Pressable>

            <Pressable
              onPress={() => router.back()}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Cancel and go back"
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
                {isNewTopic
                  ? `DEV NOTE: submitNewTopic → POST /jsonapi/node/forum (type: node--forum). Topic ID: ${topicId ?? 'N/A'}`
                  : `DEV NOTE: submitReply → POST /jsonapi/comment/comment_forum (type: comment--comment_forum). Topic ID: ${topicId}`
                }
              </Text>
            </View>
          )}

          <View style={{ height: 48 }} />
        </ScrollView>
      </KeyboardAvoidingView>
    </Screen>
  );
}
