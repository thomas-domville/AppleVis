import { useState } from 'react';
import {
  ActivityIndicator, KeyboardAvoidingView, Modal, Platform,
  Pressable, ScrollView, Text, TextInput, View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../contexts/ThemeContext';
import { useToast } from '../contexts/ToastContext';

const PLATFORMS = ['iOS', 'macOS', 'watchOS', 'Apple TV', 'Vision Pro'] as const;

type Props = {
  visible: boolean;
  appId: string;
  appName: string;
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

export function WriteReviewModal({ visible, appId, appName, onClose, onSubmitted }: Props) {
  const { colors, styles } = useTheme();
  const { showToast }      = useToast();

  const [rating,      setRating]      = useState(0);
  const [platform,    setPlatform]    = useState<string>('iOS');
  const [version,     setVersion]     = useState('');
  const [body,        setBody]        = useState('');
  const [submitting,  setSubmitting]  = useState(false);

  function reset() {
    setRating(0);
    setPlatform('iOS');
    setVersion('');
    setBody('');
    setSubmitting(false);
  }

  function handleClose() {
    reset();
    onClose();
  }

  async function handleSubmit() {
    if (rating === 0) {
      showToast('Please choose an accessibility rating before submitting.', 'warning');
      return;
    }
    if (body.trim().length < 20) {
      showToast('Please write at least 20 characters in your review.', 'warning');
      return;
    }

    setSubmitting(true);

    // TODO: wire to api.apps.submitReview once the Drupal comment endpoint
    // for ios_app_directory is confirmed (see Drupal Brief v2).
    // The payload will be:
    //   { appId, rating, platform, appVersion: version, body }
    // using the same JSON:API comment POST pattern as forum replies.
    if (__DEV__) {
      console.log('[WriteReview] Would submit:', { appId, rating, platform, version, body });
    }

    // Simulate network delay in the shell
    await new Promise((r) => setTimeout(r, 800));

    setSubmitting(false);
    reset();
    showToast('Review submitted! It will appear after moderation.', 'success');
    onSubmitted();
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
      >
        {/* Header */}
        <View style={{
          flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
          padding: 16, borderBottomWidth: 1, borderBottomColor: colors.border,
        }}>
          <Text style={{ fontSize: 17, fontWeight: '700', color: colors.text, flex: 1 }}
            accessibilityRole="header">
            Write a Review
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

          {/* Platform */}
          <View style={{ gap: 8 }}>
            <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
              textTransform: 'uppercase', letterSpacing: 0.8 }}>
              Platform
            </Text>
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
              {PLATFORMS.map((p) => {
                const isSelected = platform === p;
                return (
                  <Pressable
                    key={p}
                    onPress={() => setPlatform(p)}
                    accessible accessibilityRole="radio"
                    accessibilityLabel={p}
                    accessibilityState={{ checked: isSelected }}
                    style={{
                      paddingHorizontal: 12, paddingVertical: 7,
                      borderRadius: 20, borderWidth: isSelected ? 0 : 1,
                      borderColor: colors.border,
                      backgroundColor: isSelected ? colors.accent : colors.inputBackground,
                    }}
                  >
                    <Text style={{
                      fontSize: 14, fontWeight: '600',
                      color: isSelected ? '#FFF' : colors.text,
                    }}>{p}</Text>
                  </Pressable>
                );
              })}
            </View>
          </View>

          {/* App version */}
          <View style={{ gap: 8 }}>
            <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
              textTransform: 'uppercase', letterSpacing: 0.8 }}>
              App Version (optional)
            </Text>
            <TextInput
              value={version}
              onChangeText={setVersion}
              placeholder="e.g. 3.2.1"
              placeholderTextColor={colors.textSecondary}
              style={[styles.card, { fontSize: 16, color: colors.text, paddingVertical: 12 }]}
              accessible accessibilityLabel="App version"
              accessibilityHint="Enter the version of the app you are reviewing"
              keyboardType="default"
              returnKeyType="next"
            />
          </View>

          {/* Review body */}
          <View style={{ gap: 8 }}>
            <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
              textTransform: 'uppercase', letterSpacing: 0.8 }}>
              Your Review *
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
              accessible accessibilityLabel="Review text"
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
            accessibilityLabel={submitting ? 'Submitting review' : 'Submit review'}
            accessibilityState={{ disabled: submitting }}
            style={({ pressed }) => ({
              backgroundColor: submitting ? colors.textSecondary : colors.accent,
              borderRadius: 12, paddingVertical: 16, alignItems: 'center',
              opacity: pressed ? 0.85 : 1,
            })}
          >
            {submitting
              ? <ActivityIndicator color="#FFF" />
              : <Text style={{ fontSize: 16, fontWeight: '700', color: '#FFF' }}>Submit Review</Text>
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
