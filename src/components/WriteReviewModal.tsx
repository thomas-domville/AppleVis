import { useEffect, useState } from 'react';
import {
  ActivityIndicator, KeyboardAvoidingView, Modal, Platform,
  Pressable, ScrollView, Text, TextInput, View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../contexts/ThemeContext';
import { useToast } from '../contexts/ToastContext';
import { useTip, TIP_KEYS, TIPS } from '../contexts/ContextualTipContext';
import { api } from '../services/api';
import { sounds } from '../services/sounds';


type Props = {
  visible: boolean;
  appId: string;
  appName: string;
  replyToAuthor?: string;
  replyToText?: string;
  onClose: () => void;
  onSubmitted: () => void;
};

function StarPicker({
  value, onChange, colors,
}: {
  value: number;
  onChange: (v: number) => void;
  colors: ReturnType<typeof useTheme>['colors'];
}) {
  return (
    <View
      style={{ flexDirection: 'row', gap: 8 }}
      accessible
      accessibilityRole="adjustable"
      accessibilityLabel={`Accessibility rating: ${value} out of 5 stars`}
      accessibilityValue={{ min: 1, max: 5, now: value }}
      onAccessibilityAction={(e) => {
        if (e.nativeEvent.actionName === 'increment') onChange(Math.min(5, value + 1));
        if (e.nativeEvent.actionName === 'decrement') onChange(Math.max(1, value - 1));
      }}
      accessibilityActions={[{ name: 'increment' }, { name: 'decrement' }]}
    >
      {[1, 2, 3, 4, 5].map((star) => (
        <Pressable
          key={star}
          onPress={() => onChange(star)}
          accessible={false}
          style={{ padding: 4 }}
        >
          <Ionicons
            name={star <= value ? 'star' : 'star-outline'}
            size={28}
            color={star <= value ? '#F5A623' : colors.textSecondary}
          />
        </Pressable>
      ))}
    </View>
  );
}

export function WriteReviewModal({ visible, appId, appName, replyToAuthor, replyToText, onClose, onSubmitted }: Props) {
  const { colors, styles } = useTheme();
  const { showToast }      = useToast();
  const { showTip }        = useTip();

  const [rating,      setRating]      = useState(0);
  const [body,        setBody]        = useState('');
  const [submitting,  setSubmitting]  = useState(false);

  const isReply = !!replyToAuthor;

  // Pre-fill body with reply prefix when modal opens for a reply
  useEffect(() => {
    if (visible && replyToAuthor) {
      setBody(`[Replying to ${replyToAuthor}]\n\n`);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible, replyToAuthor]);

  // Show star-rating tip the first time the review form opens (not for replies).
  useEffect(() => {
    if (visible && !replyToAuthor) {
      const t = setTimeout(() => showTip(TIP_KEYS.reviewStarRating, TIPS.reviewStarRating), 800);
      return () => clearTimeout(t);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible]);

  function reset() {
    setRating(0);
    setBody('');
    setSubmitting(false);
  }

  function handleClose() {
    reset();
    onClose();
  }

  async function handleSubmit() {
    if (!isReply && rating === 0) {
      showToast('Please choose an accessibility rating before submitting.', 'warning');
      return;
    }
    if (body.trim().length < 20) {
      showToast('Please write at least 20 characters in your comment.', 'warning');
      return;
    }

    setSubmitting(true);
    const token = await api.account.getSessionToken();
    if (!token) {
      setSubmitting(false);
      showToast('Your session has expired. Please sign in again.', 'error');
      return;
    }

    const ratingLabel = ['', 'Very poor', 'Poor', 'Average', 'Good', 'Excellent'][rating];
    const fullBody = isReply && rating === 0
      ? body.trim()
      : `Accessibility rating: ${rating}/5 (${ratingLabel})\n\n${body.trim()}`;

    const res = await api.apps.submitReview(appId, fullBody, token);
    setSubmitting(false);
    if (res.ok) {
      reset();
      sounds.reply().catch(() => {});
      showToast('Comment submitted! It will appear after moderation.', 'success');
      onSubmitted();
    } else {
      showToast(
        res.error.includes('403') || res.error.includes('401')
          ? 'Session expired. Please sign in again.'
          : `Could not submit: ${res.error}`,
        'error',
      );
    }
  }

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={handleClose}
      accessibilityViewIsModal
    >
      <KeyboardAvoidingView
        style={{ flex: 1, backgroundColor: colors.background }}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        onAccessibilityEscape={handleClose}
      >
        {/* Header */}
        <View style={{
          flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
          padding: 16, borderBottomWidth: 1, borderBottomColor: colors.border,
        }}>
          <Text style={{ fontSize: 17, fontWeight: '700', color: colors.text, flex: 1 }}
            accessibilityRole="header">
            {isReply ? `Reply to ${replyToAuthor}` : 'Add New Comment'}
          </Text>
          <Pressable
            onPress={handleClose}
            accessible accessibilityRole="button" accessibilityLabel="Close"
            style={{ padding: 4 }}
          >
            <Ionicons name="close" size={24} color={colors.textSecondary} />
          </Pressable>
        </View>

        <ScrollView
          contentContainerStyle={{ padding: 20, gap: 20 }}
          keyboardShouldPersistTaps="handled"
        >
          {/* App name */}
          <Text style={{ fontSize: 15, color: colors.textSecondary, textAlign: 'center' }}
            accessibilityElementsHidden>
            {appName}
          </Text>

          {/* Star rating */}
          <View style={{ gap: 8 }}>
            <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
              textTransform: 'uppercase', letterSpacing: 0.8 }}>
              Accessibility Rating *
            </Text>
            <StarPicker value={rating} onChange={setRating} colors={colors} />
            {rating > 0 && (
              <Text style={{ fontSize: 13, color: colors.textSecondary }}>
                {['', 'Very poor', 'Poor', 'Average', 'Good', 'Excellent'][rating]} accessibility
              </Text>
            )}
          </View>

          {/* Review body */}
          <View style={{ gap: 8 }}>
            <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
              textTransform: 'uppercase', letterSpacing: 0.8 }}>
              Your Comment *
            </Text>
            <TextInput
              value={body}
              onChangeText={setBody}
              placeholder="Share your accessibility experience — what works well, what could be better, any VoiceOver tips…"
              placeholderTextColor={colors.textSecondary}
              multiline
              numberOfLines={6}
              textAlignVertical="top"
              style={[styles.card, {
                fontSize: 15, color: colors.text,
                minHeight: 140, paddingTop: 12,
              }]}
              accessible accessibilityLabel="Comment text"
              accessibilityHint="Describe your accessibility experience with this app"
              returnKeyType="default"
            />
            <Text style={{ fontSize: 12, color: colors.textSecondary, textAlign: 'right' }}>
              {body.length} characters
            </Text>
          </View>

          {/* Submit */}
          <Pressable
            onPress={handleSubmit}
            disabled={submitting}
            accessible accessibilityRole="button"
            accessibilityLabel={submitting ? 'Submitting comment' : 'Submit comment'}
            accessibilityState={{ disabled: submitting }}
            style={({ pressed }) => ({
              backgroundColor: submitting ? colors.textSecondary : colors.accent,
              borderRadius: 12, paddingVertical: 16, alignItems: 'center',
              opacity: pressed ? 0.85 : 1,
            })}
          >
            {submitting
              ? <ActivityIndicator color="#FFF" />
              : <Text style={{ fontSize: 16, fontWeight: '700', color: '#FFF' }}>Submit Comment</Text>
            }
          </Pressable>

          <Text style={{ fontSize: 12, color: colors.textSecondary, textAlign: 'center', lineHeight: 18 }}>
            Reviews are moderated before appearing. Please follow the{' '}
            <Text style={{ color: colors.accent }}>AppleVis community guidelines</Text>.
          </Text>

          <View style={{ height: 40 }} />
        </ScrollView>
      </KeyboardAvoidingView>
    </Modal>
  );
}
