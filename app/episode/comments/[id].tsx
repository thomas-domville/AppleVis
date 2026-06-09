import { useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActionSheetIOS, Clipboard,
  Linking, Platform, Pressable, ScrollView, Share, Text, View,
} from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../../../src/components/Screen';
import { useTheme } from '../../../src/contexts/ThemeContext';
import { useToast } from '../../../src/contexts/ToastContext';
import { useAuth } from '../../../src/contexts/AuthContext';
import { isAppleIntelligenceAvailable, summariseText } from '../../../src/services/intelligenceService';
import { relativeTime } from '../../../src/utils/relativeTime';

// ─── Types ────────────────────────────────────────────────────────────────────
type EpisodeComment = {
  id: string;
  authorName: string;
  body: string;
  createdAt: string;
  isNew?: boolean;
};

// ─── SectionDivider ───────────────────────────────────────────────────────────
function SectionDivider({ label }: { label: string }) {
  const { colors } = useTheme();
  return (
    <View accessible accessibilityRole="header" accessibilityLabel={label}
      style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 14 }}>
      <View style={{ flex: 1, height: 1, backgroundColor: colors.border }} accessibilityElementsHidden />
      <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary,
        letterSpacing: 1.2, textTransform: 'uppercase' }} accessibilityElementsHidden>
        {label}
      </Text>
      <View style={{ flex: 1, height: 1, backgroundColor: colors.border }} accessibilityElementsHidden />
    </View>
  );
}

// ─── ComingSoonShell ──────────────────────────────────────────────────────────
function ComingSoonShell({ icon, message, url }: { icon: string; message: string; url?: string }) {
  const { colors } = useTheme();
  return (
    <View style={{
      borderRadius: 14, padding: 20, marginBottom: 20,
      backgroundColor: colors.inputBackground,
      borderWidth: 1.5, borderColor: `${colors.accent}44`,
      alignItems: 'center',
    }}>
      <Ionicons name={icon as any} size={36} color={colors.accent}
        style={{ marginBottom: 10 }} accessibilityElementsHidden />

      <Text accessible style={{ fontSize: 14, color: colors.textSecondary,
        textAlign: 'center', lineHeight: 20, marginBottom: 12 }}>
        {message}
      </Text>

      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
        <View style={{
          paddingHorizontal: 10, paddingVertical: 4,
          backgroundColor: colors.accent, borderRadius: 8,
        }}>
          <Text style={{ fontSize: 11, fontWeight: '700', color: '#FFF', letterSpacing: 1 }}
            accessibilityElementsHidden>
            COMING SOON
          </Text>
        </View>

        {url && (
          <Pressable
            onPress={() => Linking.openURL(url).catch(() => {})}
            accessible
            accessibilityRole="link"
            accessibilityLabel="View on AppleVis website"
            accessibilityHint="Opens this episode's page in the browser to read comments now"
            style={{ paddingHorizontal: 12, paddingVertical: 4,
              backgroundColor: colors.inputBackground,
              borderWidth: 1, borderColor: colors.border, borderRadius: 8 }}
          >
            <Text style={{ fontSize: 11, fontWeight: '600', color: colors.accent }}>
              View on Web
            </Text>
          </Pressable>
        )}
      </View>
    </View>
  );
}

// ─── CommentCard ─────────────────────────────────────────────────────────────
function CommentCard({
  comment, index, total,
}: {
  comment: EpisodeComment;
  index: number;
  total: number;
}) {
  const { colors, styles } = useTheme();
  const { showToast } = useToast();
  const timeStr = relativeTime(comment.createdAt);

  const compoundLabel = [
    `Comment ${index + 1} of ${total}.`,
    comment.authorName + '.',
    timeStr + '.',
    comment.isNew ? 'New.' : '',
    comment.body.slice(0, 280) + (comment.body.length > 280 ? '…' : '') + '.',
    'Hold for options.',
  ].filter(Boolean).join(' ');

  function showActions() {
    const options = ['Copy Comment Text', 'Share Comment', 'Report Comment', 'Cancel'];
    const destructiveIdx = 2;
    const cancelIdx = 3;

    if (Platform.OS === 'ios') {
      ActionSheetIOS.showActionSheetWithOptions(
        { options, cancelButtonIndex: cancelIdx, destructiveButtonIndex: destructiveIdx },
        (idx) => {
          if (idx === 0) {
            Clipboard.setString(comment.body);
            showToast('Comment text copied.');
            AccessibilityInfo.announceForAccessibility('Comment text copied');
          }
          if (idx === 1) {
            Share.share({ message: comment.body }).catch(() => {});
          }
          if (idx === 2) {
            showToast('Report sent — thank you.');
            AccessibilityInfo.announceForAccessibility('Report sent');
          }
        },
      );
    }
  }

  return (
    <Pressable
      onLongPress={showActions}
      accessible
      accessibilityLabel={compoundLabel}
      accessibilityActions={[
        { name: 'copy',   label: 'Copy Comment Text' },
        { name: 'share',  label: 'Share Comment' },
        { name: 'report', label: 'Report Comment' },
      ]}
      onAccessibilityAction={({ nativeEvent }) => {
        if (nativeEvent.actionName === 'copy') {
          Clipboard.setString(comment.body);
          showToast('Comment text copied.');
          AccessibilityInfo.announceForAccessibility('Comment text copied');
        }
        if (nativeEvent.actionName === 'share') {
          Share.share({ message: comment.body }).catch(() => {});
        }
        if (nativeEvent.actionName === 'report') {
          showToast('Report sent — thank you.');
          AccessibilityInfo.announceForAccessibility('Report sent');
        }
      }}
      style={({ pressed }) => [styles.card, {
        marginBottom: 12, opacity: pressed ? 0.85 : 1,
      }]}
    >
      {/* Header: author + date + new badge */}
      <View style={{ flexDirection: 'row', alignItems: 'center',
        justifyContent: 'space-between', marginBottom: 10 }}
        accessibilityElementsHidden>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
          <View style={{
            width: 32, height: 32, borderRadius: 16,
            backgroundColor: `${colors.accent}22`,
            alignItems: 'center', justifyContent: 'center',
          }}>
            <Text style={{ fontSize: 13, fontWeight: '700', color: colors.accent }}>
              {comment.authorName.slice(0, 1).toUpperCase()}
            </Text>
          </View>
          <Text style={{ fontSize: 14, fontWeight: '600', color: colors.text }}>
            {comment.authorName}
          </Text>
        </View>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
          {comment.isNew && (
            <View style={{ paddingHorizontal: 8, paddingVertical: 2,
              backgroundColor: `${colors.accent}22`, borderRadius: 8 }}>
              <Text style={{ fontSize: 11, fontWeight: '700', color: colors.accent }}>NEW</Text>
            </View>
          )}
          <Text style={{ fontSize: 12, color: colors.textSecondary }}>{timeStr}</Text>
        </View>
      </View>

      {/* Body */}
      <Text style={{ fontSize: 15, lineHeight: 22, color: colors.textSecondary }}
        accessibilityElementsHidden>
        {comment.body}
      </Text>
    </Pressable>
  );
}

// ─── Main screen ──────────────────────────────────────────────────────────────
export default function EpisodeComments() {
  const params = useLocalSearchParams<{
    id: string; title: string; showTitle: string; url?: string;
  }>();

  const router = useRouter();
  const auth   = useAuth();
  const { colors, styles } = useTheme();
  const { showToast } = useToast();
  const aiAvailable = isAppleIntelligenceAvailable();

  // ── State ────────────────────────────────────────────────────────────────
  const [comments]   = useState<EpisodeComment[]>([]);
  // NOTE: Comments API endpoint is not yet confirmed with Drupal developer.
  // When ready, fetch from something like:
  //   /api/v1/podcasts/episodes/${params.id}/comments  (custom endpoint)
  //   or /comment?filter[entity_id]=${params.id}&filter[entity_type]=node (JSON:API)

  const [aiWorking, setAiWorking] = useState(false);
  const [aiSummary, setAiSummary] = useState<string | null>(null);

  const episodeUrl = params.url || undefined;

  // ── AI: Summarise discussion ─────────────────────────────────────────────
  async function handleAiSummarise() {
    if (comments.length === 0 || aiWorking) return;
    if (aiSummary) {
      setAiSummary(null);
      return;
    }
    setAiWorking(true);
    try {
      const allText = comments.map(c => `${c.authorName}: ${c.body}`).join('\n\n');
      const result = await summariseText(allText);
      if (result) {
        setAiSummary(result);
      } else {
        showToast('Could not summarise — try again', 'error');
      }
    } catch {
      showToast('Could not summarise — try again', 'error');
    } finally {
      setAiWorking(false);
    }
  }

  // ── Post comment ─────────────────────────────────────────────────────────
  function handlePostComment() {
    if (!auth.isSignedIn) {
      showToast('Sign in to post a comment');
      AccessibilityInfo.announceForAccessibility('Sign in to post a comment');
      return;
    }
    // Navigate to compose when backend supports episode comments
    showToast('Episode comments are coming soon');
    AccessibilityInfo.announceForAccessibility('Episode comments are coming soon');
  }

  return (
    <Screen title="Discussion" showSettings={false}>
      <ScrollView showsVerticalScrollIndicator contentContainerStyle={{ paddingBottom: 40 }}>

        {/* ── Episode header ───────────────────────────────────────────── */}
        <View
          accessible
          accessibilityLabel={`Community discussion for: ${params.title}. ${params.showTitle}.`}
          style={[styles.card, { marginBottom: 20, flexDirection: 'row', alignItems: 'center', gap: 12 }]}
        >
          <View style={{
            width: 44, height: 44, borderRadius: 22,
            backgroundColor: `${colors.accent}18`,
            alignItems: 'center', justifyContent: 'center',
          }} accessibilityElementsHidden>
            <Ionicons name="mic-outline" size={22} color={colors.accent} accessibilityElementsHidden />
          </View>
          <View style={{ flex: 1 }} accessibilityElementsHidden>
            <Text style={{ fontSize: 15, fontWeight: '700', color: colors.text, lineHeight: 20 }}>
              {params.title}
            </Text>
            <Text style={{ fontSize: 13, color: colors.textSecondary, marginTop: 2 }}>
              {params.showTitle}
            </Text>
          </View>
        </View>

        {/* ── Post comment CTA ─────────────────────────────────────────── */}
        <Pressable
          onPress={handlePostComment}
          accessible accessibilityRole="button"
          accessibilityLabel={auth.isSignedIn ? 'Post a comment' : 'Sign in to post a comment'}
          style={({ pressed }) => ({
            flexDirection: 'row', alignItems: 'center', gap: 14,
            paddingHorizontal: 16, paddingVertical: 14,
            backgroundColor: colors.inputBackground,
            borderRadius: 14, borderWidth: 1, borderColor: colors.border,
            marginBottom: 20, opacity: pressed ? 0.75 : 1,
          })}
        >
          <View style={{
            width: 40, height: 40, borderRadius: 20,
            backgroundColor: `${colors.accent}18`,
            alignItems: 'center', justifyContent: 'center',
          }} accessibilityElementsHidden>
            <Ionicons name="create-outline" size={20} color={colors.accent} accessibilityElementsHidden />
          </View>
          <View style={{ flex: 1 }} accessibilityElementsHidden>
            <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>
              {auth.isSignedIn ? 'Post a comment' : 'Sign in to post a comment'}
            </Text>
            <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2 }}>
              Share your thoughts about this episode
            </Text>
          </View>
          <Ionicons name="chevron-forward" size={18} color={colors.textSecondary} accessibilityElementsHidden />
        </Pressable>

        {/* ── Apple Intelligence ────────────────────────────────────────── */}
        <View style={[styles.card, {
          marginBottom: 20,
          opacity: aiAvailable && comments.length > 0 ? 1 : 0.55,
        }]}>
          <SectionDivider label="Apple Intelligence" />
          <Pressable
            onPress={handleAiSummarise}
            disabled={!aiAvailable || comments.length === 0 || aiWorking}
            accessible accessibilityRole="button"
            accessibilityLabel={aiSummary ? 'Summarise Discussion. Tap to hide.' : 'Summarise Discussion'}
            accessibilityHint={
              !aiAvailable ? 'Requires iPhone 16 or later with Apple Intelligence enabled' :
              comments.length === 0 ? 'No comments to summarise yet' :
              aiWorking ? 'Summarising, please wait' : undefined
            }
            style={({ pressed }) => ({
              flexDirection: 'row', alignItems: 'center', gap: 14,
              paddingVertical: 12, opacity: pressed ? 0.65 : 1,
            })}
          >
            <View style={{
              width: 44, height: 44, borderRadius: 22,
              backgroundColor: aiAvailable ? `${colors.accent}18` : colors.inputBackground,
              alignItems: 'center', justifyContent: 'center',
            }}>
              <Ionicons name={aiWorking ? 'hourglass-outline' : 'sparkles'}
                size={22} color={aiAvailable ? colors.accent : colors.textSecondary}
                accessibilityElementsHidden />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>
                {aiWorking ? 'Summarising…' : 'Summarise Discussion'}
              </Text>
              {!aiAvailable && (
                <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2 }}>
                  Requires iPhone 16 with Apple Intelligence enabled
                </Text>
              )}
              {aiAvailable && comments.length === 0 && (
                <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2 }}>
                  Available once comments have loaded
                </Text>
              )}
            </View>
            <Ionicons name={aiSummary ? 'chevron-up' : 'chevron-down'}
              size={18} color={colors.textSecondary} accessibilityElementsHidden />
          </Pressable>

          {aiSummary && (
            <View style={{ marginTop: 4, paddingTop: 14, borderTopWidth: 1, borderTopColor: colors.border }}>
              <Text accessible style={{ fontSize: 15, lineHeight: 22, color: colors.textSecondary }}>
                {aiSummary}
              </Text>
            </View>
          )}
        </View>

        {/* ── Comments section ─────────────────────────────────────────── */}
        <SectionDivider label={comments.length > 0 ? `${comments.length} Comments` : 'Comments'} />

        {comments.length > 0 ? (
          comments.map((comment, i) => (
            <CommentCard key={comment.id} comment={comment} index={i} total={comments.length} />
          ))
        ) : (
          <ComingSoonShell
            icon="chatbubbles-outline"
            message={
              'Community comments for podcast episodes are on their way. ' +
              'You can read and join the existing discussion on the AppleVis website now.'
            }
            url={episodeUrl}
          />
        )}

        {/* ── View on AppleVis ─────────────────────────────────────────── */}
        {episodeUrl && (
          <Pressable
            onPress={() => Linking.openURL(episodeUrl).catch(() => {})}
            accessible accessibilityRole="link"
            accessibilityLabel={`View ${params.title} on AppleVis — opens in browser`}
            style={[styles.cardSmall, { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 20 }]}
          >
            <Ionicons name="globe-outline" size={22} color={colors.accent} accessibilityElementsHidden />
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>View on AppleVis</Text>
              <Text style={{ fontSize: 13, color: colors.textSecondary }}>Read and post comments on the website</Text>
            </View>
            <Ionicons name="open-outline" size={18} color={colors.textSecondary} accessibilityElementsHidden />
          </Pressable>
        )}

        {/* ── Back to episode ───────────────────────────────────────────── */}
        <Pressable
          onPress={() => router.back()}
          accessible accessibilityRole="button"
          accessibilityLabel="Back to episode"
          style={{ alignItems: 'center', paddingVertical: 16 }}
        >
          <Text style={{ fontSize: 14, fontWeight: '600', color: colors.accent }}>Back to Episode</Text>
        </Pressable>

      </ScrollView>
    </Screen>
  );
}
