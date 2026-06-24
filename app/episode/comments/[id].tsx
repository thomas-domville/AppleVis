import { useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActivityIndicator, ActionSheetIOS, Clipboard,
  findNodeHandle, Linking, Platform, Pressable, ScrollView, Share, Text, View,
} from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { Screen } from '../../../src/components/Screen';
import { useTheme } from '../../../src/contexts/ThemeContext';
import { useToast } from '../../../src/contexts/ToastContext';
import { useAlert } from '../../../src/contexts/AccessibleAlertContext';
import { ALERTS } from '../../../src/data/alertMessages';
import { useAuth } from '../../../src/contexts/AuthContext';
import { EditContentModal } from '../../../src/components/EditContentModal';
import { usePreferences } from '../../../src/contexts/PreferencesContext';
import { isAppleIntelligenceAvailable, summariseText } from '../../../src/services/intelligenceService';
import { api } from '../../../src/services/api';
import { persistence } from '../../../src/services/persistence';
import { relativeTime } from '../../../src/utils/relativeTime';
import { displayCommentSubject, subjectLabel } from '../../../src/utils/commentSubject';
import type { ForumReply } from '../../../src/types/content';

type EpisodeComment = ForumReply;

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

// ─── CommentCard ─────────────────────────────────────────────────────────────
function CommentCard({
  comment, index, total, episodeTitle, onReply, currentUserUuid, onEdit, onDelete,
}: {
  comment: EpisodeComment;
  index: number;
  total: number;
  episodeTitle: string;
  onReply: () => void;
  currentUserUuid?: string;
  onEdit: (c: EpisodeComment) => void;
  onDelete: (c: EpisodeComment) => void;
}) {
  const { colors, styles } = useTheme();
  const { showToast } = useToast();
  const timeStr        = relativeTime(comment.createdAt);
  const commentSubject = displayCommentSubject(comment.subject, episodeTitle);
  const isOwnComment   = !!currentUserUuid && currentUserUuid === comment.authorId;

  const headerLabel = [
    `Comment ${index + 1} of ${total}.`,
    subjectLabel(comment.subject, episodeTitle),
    comment.authorName + '.',
    timeStr + '.',
    comment.isNew ? 'New.' : '',
    'Hold for options.',
  ].filter(Boolean).join(' ');

  function showActions() {
    if (Platform.OS === 'ios') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
      const baseOptions = ['Cancel', 'Reply to this Comment', 'Copy Comment Text', 'Share Comment', 'Report Comment'];
      const ownOptions  = isOwnComment ? ['Edit Comment', 'Delete Comment'] : [];
      const allOptions  = [...baseOptions, ...ownOptions];
      ActionSheetIOS.showActionSheetWithOptions(
        {
          title: `Comment by ${comment.authorName}`,
          options: allOptions,
          cancelButtonIndex: 0,
          destructiveButtonIndex: isOwnComment ? allOptions.length - 1 : 4,
        },
        (idx) => {
          if (idx === 1) onReply();
          if (idx === 2) { Clipboard.setString(comment.body); showToast('Comment text copied.'); AccessibilityInfo.announceForAccessibility('Comment text copied'); }
          if (idx === 3) {
            Share.share({
              message: [
                commentSubject ? `Subject: ${commentSubject}` : null,
                comment.body,
              ].filter(Boolean).join('\n\n'),
            }).catch(() => {});
          }
          if (idx === 4) { showToast('Report sent — thank you.'); AccessibilityInfo.announceForAccessibility('Report sent'); }
          if (isOwnComment && idx === 5) onEdit(comment);
          if (isOwnComment && idx === 6) onDelete(comment);
        },
      );
    }
  }

  return (
    <View style={[styles.card, { marginBottom: 12, padding: 0 }]}>
    <Pressable
      onLongPress={showActions}
      delayLongPress={400}
      accessible
      accessibilityRole="header"
      accessibilityLabel={headerLabel}
      accessibilityActions={[
        { name: 'reply',  label: 'Reply to this Comment' },
        { name: 'copy',   label: 'Copy Comment Text' },
        { name: 'share',  label: 'Share Comment' },
        { name: 'report', label: 'Report Comment' },
      ]}
      onAccessibilityAction={({ nativeEvent }) => {
        if (nativeEvent.actionName === 'reply') onReply();
        if (nativeEvent.actionName === 'copy') {
          Clipboard.setString(comment.body);
          showToast('Comment text copied.');
          AccessibilityInfo.announceForAccessibility('Comment text copied');
        }
        if (nativeEvent.actionName === 'share') {
          Share.share({
            message: [
              commentSubject ? `Subject: ${commentSubject}` : null,
              comment.body,
            ].filter(Boolean).join('\n\n'),
          }).catch(() => {});
        }
        if (nativeEvent.actionName === 'report') {
          showToast('Report sent — thank you.');
          AccessibilityInfo.announceForAccessibility('Report sent');
        }
      }}
      style={({ pressed }) => ({
        padding: 14,
        paddingBottom: 8,
        opacity: pressed ? 0.85 : 1,
      })}
    >
      {/* Header: author + date + new badge */}
      <View style={{ flexDirection: 'row', alignItems: 'center',
        justifyContent: 'space-between' }}
        accessibilityElementsHidden
        importantForAccessibility="no-hide-descendants">
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, flex: 1 }}>
          <View style={{
            width: 32, height: 32, borderRadius: 16,
            backgroundColor: `${colors.accent}22`,
            alignItems: 'center', justifyContent: 'center',
          }}>
            <Text style={{ fontSize: 13, fontWeight: '700', color: colors.accent }}>
              {comment.authorName.slice(0, 1).toUpperCase()}
            </Text>
          </View>
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: 14, fontWeight: '600', color: colors.text }}>
              {comment.authorName}
            </Text>
            {!!commentSubject && (
              <Text style={{ fontSize: 13, color: colors.text, marginTop: 2 }} numberOfLines={2}>
                {commentSubject}
              </Text>
            )}
          </View>
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
    </Pressable>

      {/* Body */}
      <View style={{ paddingHorizontal: 14, paddingBottom: 14 }}>
        <Text
          accessible
          accessibilityRole="text"
          accessibilityLabel={comment.body}
          style={{ fontSize: 15, lineHeight: 22, color: colors.textSecondary }}
        >
          {comment.body}
        </Text>
      </View>
    </View>
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
  const { aiSummariesEnabled } = usePreferences();
  const { showToast } = useToast();
  const { showAlert } = useAlert();
  const aiAvailable = aiSummariesEnabled && isAppleIntelligenceAvailable();

  // ── State ────────────────────────────────────────────────────────────────
  const [comments,        setComments]        = useState<EpisodeComment[]>([]);
  const [loading,         setLoading]         = useState(true);
  const [fetchError,      setFetchError]      = useState<string | null>(null);
  const [aiWorking,       setAiWorking]       = useState(false);
  const [aiSummary,       setAiSummary]       = useState<string | null>(null);
  const [editingComment,  setEditingComment]  = useState<EpisodeComment | null>(null);

  const scrollRef          = useRef<ScrollView>(null);
  const headingRef         = useRef<View>(null);
  const hasInitialFocusRef = useRef(false);
  const commentsY          = useRef<number>(0);
  const firstNewCommentRef = useRef<View | null>(null);
  const commentOffsets     = useRef<Record<string, number>>({});

  // VoiceOver: focus the episode heading immediately on open (content is available from params).
  useEffect(() => {
    if (hasInitialFocusRef.current) return;
    hasInitialFocusRef.current = true;
    setTimeout(() => {
      const handle = findNodeHandle(headingRef.current);
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, 200);
  }, []);

  useEffect(() => {
    if (!params.id) return;
    setLoading(true);
    setFetchError(null);
    Promise.all([
      api.podcasts.comments(params.id),
      persistence.getItemVisit(params.id),
    ]).then(([res, visit]) => {
      setLoading(false);
      if (res.ok) {
        const seenAt = visit?.seenAt ?? null;
        const marked = seenAt
          ? res.data.map(c => ({ ...c, isNew: c.createdAt > seenAt }))
          : res.data;
        setComments(marked);
        persistence.stampItemVisit(params.id, res.data.length);
      } else {
        setFetchError(res.error);
      }
    }).catch((err: unknown) => {
      setLoading(false);
      setFetchError(err instanceof Error ? err.message : 'Unexpected error');
    });
  }, [params.id]);

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

  const firstNewComment  = comments.find(c => c.isNew) ?? null;
  const newCommentCount  = comments.filter(c => c.isNew).length;

  function handleJumpToNewComment(firstNewId: string) {
    const offset = commentOffsets.current[firstNewId] ?? 0;
    const y = Math.max(0, commentsY.current + offset - 20);
    scrollRef.current?.scrollTo({ y, animated: true });
    setTimeout(() => {
      const handle = findNodeHandle(firstNewCommentRef.current);
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, 400);
  }

  // ── Post comment ─────────────────────────────────────────────────────────
  function handlePostComment() {
    if (!auth.isSignedIn) {
      showAlert({ ...ALERTS.auth.signInRequired('post a comment'), onConfirm: () => router.push('/settings-account' as any) });
      return;
    }
    router.push({
      pathname: '/compose' as any,
      params: { episodeId: params.id, episodeTitle: params.title },
    });
  }

  return (
    <Screen title="Discussion" showSettings={false} titleAccessible={false}>
      <ScrollView ref={scrollRef} showsVerticalScrollIndicator contentContainerStyle={{ paddingBottom: 40 }}>

        {/* ── Episode header ───────────────────────────────────────────── */}
        <View
          ref={headingRef}
          accessible
          accessibilityRole="header"
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
        <View onLayout={(e) => { commentsY.current = e.nativeEvent.layout.y; }}>
          <SectionDivider label={
            loading ? 'Community Discussion' :
            fetchError ? 'Community Discussion' :
            comments.length > 0
              ? `Community Discussion - ${comments.length} comment${comments.length === 1 ? '' : 's'}` +
                (newCommentCount > 0 ? ` - ${newCommentCount} new` : '')
              : 'Community Discussion'
          } />
          {firstNewComment && (
            <Pressable
              onPress={() => handleJumpToNewComment(firstNewComment.id)}
              accessible
              accessibilityRole="button"
              accessibilityLabel={`Jump to first new comment. ${newCommentCount} new since your last visit.`}
              style={[styles.card, {
                flexDirection: 'row', alignItems: 'center', gap: 10,
                marginBottom: 12, paddingVertical: 12,
              }]}
            >
              <Ionicons name="flag-outline" size={18} color={colors.accent} accessibilityElementsHidden />
              <View style={{ flex: 1 }}>
                <Text style={{ fontSize: 14, fontWeight: '700', color: colors.accent }}>
                  Jump to First New Comment
                </Text>
                <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2 }}>
                  {newCommentCount} new since your last visit
                </Text>
              </View>
              <Ionicons name="arrow-down-outline" size={16} color={colors.accent} accessibilityElementsHidden />
            </Pressable>
          )}
        </View>

        {loading ? (
          <View
            accessible
            accessibilityLiveRegion="polite"
            accessibilityLabel="Loading comments, please wait"
            style={{ alignItems: 'center', paddingVertical: 32 }}
          >
            <ActivityIndicator size="large" color={colors.accent} />
            <Text style={{ fontSize: 14, color: colors.textSecondary, marginTop: 10 }}>
              Loading comments…
            </Text>
          </View>
        ) : fetchError ? (
          <View style={[styles.card, { borderColor: '#FCA5A5', borderWidth: 1, alignItems: 'center', paddingVertical: 20 }]}>
            <Ionicons name="alert-circle-outline" size={28} color="#B91C1C" accessibilityElementsHidden />
            <Text style={{ fontSize: 14, color: '#B91C1C', fontWeight: '600', marginTop: 8 }}>
              Could not load comments
            </Text>
            <Text style={{ fontSize: 13, color: colors.textSecondary, marginTop: 4, textAlign: 'center' }}>
              {fetchError}
            </Text>
          </View>
        ) : comments.length > 0 ? (
          comments.map((comment, i) => {
            const isFirstNew = comment.isNew && comment.id === firstNewComment?.id;
            return (
              <View
                key={comment.id}
                ref={isFirstNew ? (v) => { firstNewCommentRef.current = v; } : undefined}
                onLayout={(e) => { commentOffsets.current[comment.id] = e.nativeEvent.layout.y; }}
              >
                <CommentCard
                  comment={comment}
                  index={i}
                  total={comments.length}
                  episodeTitle={params.title}
                  currentUserUuid={auth.user?.uuid}
                  onEdit={(c) => setEditingComment(c)}
                  onDelete={(c) => {
                    showAlert({
                      title: 'Delete Comment?',
                      message: 'This cannot be undone.',
                      buttons: [
                        { label: 'Delete', style: 'destructive', onPress: async () => {
                          if (!auth.user?.csrfToken) return;
                          const res = await api.content.deleteComment('comment_node_podcast', c.id, auth.user.csrfToken);
                          if (res.ok) {
                            setComments(prev => prev.filter(x => x.id !== c.id));
                            showToast('Comment deleted.', 'success');
                          } else {
                            showToast('Could not delete comment.', 'error');
                          }
                        }},
                        { label: 'Cancel' },
                      ],
                    });
                  }}
                  onReply={() => {
                    if (!auth.isSignedIn) { showAlert({ ...ALERTS.auth.signInRequired('reply to comments'), onConfirm: () => router.push('/settings-account' as any) }); return; }
                    const plain = comment.body.slice(0, 150).trimEnd() + (comment.body.length > 150 ? '…' : '');
                    router.push({
                      pathname: '/compose' as any,
                      params: { episodeId: params.id, episodeTitle: params.title, replyToAuthor: comment.authorName, replyToQuote: plain },
                    });
                  }}
                />
              </View>
            );
          })
        ) : (
          <View style={[styles.card, { alignItems: 'center', paddingVertical: 24 }]}
            accessible accessibilityLabel="No comments yet. Be the first to share your thoughts.">
            <Ionicons name="chatbubbles-outline" size={32} color={colors.textSecondary}
              style={{ marginBottom: 8 }} accessibilityElementsHidden />
            <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text, marginBottom: 6 }}
              accessibilityElementsHidden>
              No comments yet
            </Text>
            <Text style={{ fontSize: 14, color: colors.textSecondary, textAlign: 'center' }}
              accessibilityElementsHidden>
              Be the first to share your thoughts about this episode.
            </Text>
          </View>
        )}

        {/* ── View on AppleVis ─────────────────────────────────────────── */}
        {episodeUrl && (
          <Pressable
            onPress={() => Linking.openURL(episodeUrl).catch(() => {})}
            accessible accessibilityRole="link"
            accessibilityLabel={`View ${params.title} on AppleVis — opens in browser`}
            style={[styles.cardSmall, { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 20 }]}
          >
            <Ionicons name={"safari-outline" as any} size={22} color={colors.accent} accessibilityElementsHidden />
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

      {editingComment && auth.user?.csrfToken && (
        <EditContentModal
          visible={!!editingComment}
          onClose={() => setEditingComment(null)}
          onSaved={(newBody) => {
            setComments(prev => prev.map(c => c.id === editingComment.id ? { ...c, body: newBody } : c));
            showToast('Comment updated.', 'success');
          }}
          commentId={editingComment.id}
          commentType="comment_node_podcast"
          csrfToken={auth.user.csrfToken}
          initialBody={editingComment.body}
          label="Comment"
        />
      )}
    </Screen>
  );
}
