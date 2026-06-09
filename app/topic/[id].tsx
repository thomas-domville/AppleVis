import { useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActionSheetIOS, ActivityIndicator, Clipboard,
  findNodeHandle, Linking, Platform, Pressable, ScrollView, Share, StyleSheet, Text, View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { Screen } from '../../src/components/Screen';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { useAuth } from '../../src/contexts/AuthContext';
import { useToast } from '../../src/contexts/ToastContext';
import { useSavedItems } from '../../src/hooks/useSavedItems';
import { useHandoff } from '../../src/hooks/useHandoff';
import {
  readAloud, isAppleIntelligenceAvailable, summariseText,
} from '../../src/services/intelligenceService';
import { api } from '../../src/services/api';
import { relativeTime } from '../../src/utils/relativeTime';
import type { ForumTopicDetail, ForumReply } from '../../src/types/content';

// ─── HTML stripper — preserves link text and block structure ──────────────────

function stripHtml(html: string): string {
  return html
    .replace(/<a[^>]*href="([^"]*)"[^>]*>(.*?)<\/a>/gis, (_, href, inner) => {
      const t = inner.replace(/<[^>]*>/g, '').trim();
      return t ? `${t} (${href})` : href;
    })
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n\n')
    .replace(/<\/li>/gi, '\n')
    .replace(/<\/h[1-6]>/gi, '\n\n')
    .replace(/<[^>]*>/g, '')
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&#039;/g, "'").replace(/&apos;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

// Split stripped HTML into discrete paragraphs for braille-friendly rendering
function bodyParagraphs(html: string): string[] {
  return stripHtml(html)
    .split('\n\n')
    .map(p => p.replace(/\n/g, ' ').trim())
    .filter(Boolean);
}

// ─── Bottom toolbar button ────────────────────────────────────────────────────

function ToolbarButton({
  icon, activeIcon, label, onPress, active, accent,
}: {
  icon: string; activeIcon?: string; label: string; onPress: () => void;
  active?: boolean; accent?: boolean;
}) {
  const { colors } = useTheme();
  const resolvedIcon = (active && activeIcon) ? activeIcon : icon;
  const color = accent ? colors.accent : active ? colors.accent : colors.textSecondary;
  return (
    <Pressable
      onPress={onPress}
      accessible
      accessibilityRole="button"
      accessibilityLabel={label.replace(/\n/g, ' ')}
      accessibilityState={{ selected: active }}
      style={({ pressed }) => ({
        flex: 1, alignItems: 'center', justifyContent: 'center',
        gap: 4, opacity: pressed ? 0.55 : 1, paddingVertical: 10,
      })}
    >
      <Ionicons name={resolvedIcon as any} size={23} color={color} accessibilityElementsHidden />
      <Text
        style={{ fontSize: 10, fontWeight: '600', color, textAlign: 'center', lineHeight: 13 }}
        accessibilityElementsHidden
      >
        {label}
      </Text>
    </Pressable>
  );
}

// ─── Section divider ──────────────────────────────────────────────────────────

function SectionDivider({ label }: { label: string }) {
  const { colors } = useTheme();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginVertical: 16 }}>
      <View style={{ flex: 1, height: 1, backgroundColor: colors.border }} accessibilityElementsHidden />
      <Text
        style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
          textTransform: 'uppercase', letterSpacing: 0.7 }}
        accessibilityRole="header"
      >
        {label}
      </Text>
      <View style={{ flex: 1, height: 1, backgroundColor: colors.border }} accessibilityElementsHidden />
    </View>
  );
}

// ─── Coming-soon shell ────────────────────────────────────────────────────────

function ComingSoonShell({ icon, message }: { icon: string; message: string }) {
  const { colors } = useTheme();
  return (
    <View
      style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 12,
        backgroundColor: colors.pill, borderRadius: 12, padding: 14,
        borderWidth: 1, borderColor: colors.border, opacity: 0.7, marginBottom: 12 }}
      accessible
      accessibilityLabel={`${message} — coming soon.`}
    >
      <Ionicons name={icon as any} size={20} color={colors.textSecondary}
        accessibilityElementsHidden style={{ marginTop: 1 }} />
      <View style={{ flex: 1 }}>
        <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>{message}</Text>
        <View style={{ flexDirection: 'row', marginTop: 6 }}>
          <View style={{ paddingHorizontal: 8, paddingVertical: 2,
            backgroundColor: colors.card, borderRadius: 6, borderWidth: 1, borderColor: colors.border }}>
            <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary }}>COMING SOON</Text>
          </View>
        </View>
      </View>
    </View>
  );
}

// ─── Reply card ───────────────────────────────────────────────────────────────

function ReplyCard({
  reply, index, total, colors, styles, screenReaderEnabled, showToast,
}: {
  reply: ForumReply;
  index: number;
  total: number;
  colors: ReturnType<typeof useTheme>['colors'];
  styles: ReturnType<typeof useTheme>['styles'];
  screenReaderEnabled: boolean;
  showToast: (msg: string, type?: 'success' | 'warning' | 'error') => void;
}) {
  const plain   = stripHtml(reply.body);
  const timeStr = relativeTime(reply.createdAt);

  const replyActions = [
    ...(!screenReaderEnabled
      ? [{ label: 'Read Aloud', action: () => readAloud(`Reply by ${reply.authorName}. ${plain}`) }]
      : []),
    { label: 'Copy Comment Text', action: () => { Clipboard.setString(plain); showToast('Comment text copied.', 'success'); } },
    { label: 'Share Comment', action: () => Share.share({ message: `${reply.authorName} on AppleVis: ${plain}` }).catch(() => {}) },
    { label: 'Report Comment',  action: () => showToast('Reporting coming once the Drupal Flags API is confirmed.', 'warning') },
  ];

  function handleLongPress() {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    if (Platform.OS === 'ios') {
      ActionSheetIOS.showActionSheetWithOptions(
        {
          title: `Comment by ${reply.authorName}`,
          options: ['Cancel', ...replyActions.map(a => a.label)],
          cancelButtonIndex: 0,
        },
        (i) => { if (i > 0) replyActions[i - 1].action(); },
      );
    }
  }

  return (
    <Pressable
      onLongPress={handleLongPress}
      delayLongPress={400}
      accessible
      accessibilityLabel={
        `Comment ${index + 1} of ${total}. ${reply.authorName}. ${timeStr}.` +
        (reply.isNew ? ' New.' : '') +
        ` ${plain}. Hold for options.`
      }
      accessibilityActions={replyActions.map(a => ({ name: a.label, label: a.label }))}
      onAccessibilityAction={({ nativeEvent }) => {
        replyActions.find(a => a.label === nativeEvent.actionName)?.action();
      }}
      style={[
        styles.card,
        { marginBottom: 8 },
        reply.isNew && { borderLeftWidth: 3, borderLeftColor: colors.accent },
      ]}
    >
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 10 }}
        accessibilityElementsHidden>
        <View style={{ width: 32, height: 32, borderRadius: 16, backgroundColor: colors.pill,
          alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
          <Text style={{ fontSize: 14, fontWeight: '700', color: colors.pillText }}>
            {reply.authorName.charAt(0).toUpperCase()}
          </Text>
        </View>
        <View style={{ flex: 1 }}>
          <Text style={{ fontSize: 14, fontWeight: '700', color: colors.text }}>{reply.authorName}</Text>
          <Text style={{ fontSize: 12, color: colors.textSecondary }}>{timeStr}</Text>
        </View>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
          {reply.isNew && (
            <View style={{ backgroundColor: colors.accent, borderRadius: 6,
              paddingHorizontal: 6, paddingVertical: 2 }}>
              <Text style={{ color: colors.accentText, fontSize: 10, fontWeight: '700' }}>NEW</Text>
            </View>
          )}
          <Text style={{ fontSize: 11, color: colors.textSecondary, fontWeight: '500' }}>
            {index + 1}/{total}
          </Text>
        </View>
      </View>
      <Text style={{ fontSize: 15, lineHeight: 23, color: colors.text }} accessibilityElementsHidden>
        {plain}
      </Text>
    </Pressable>
  );
}

// ─── Main screen ──────────────────────────────────────────────────────────────

const TOOLBAR_H = 58;

export default function TopicDetail() {
  const { id, title: paramTitle } = useLocalSearchParams<{ id: string; title?: string }>();
  const router                    = useRouter();
  const { colors, styles }        = useTheme();
  const { screenReaderEnabled }   = useAccessibilityPreferences();
  const auth                      = useAuth();
  const { showToast }             = useToast();
  const saved                     = useSavedItems('forumTopic');
  const aiAvailable               = isAppleIntelligenceAvailable();
  const insets                    = useSafeAreaInsets();

  const [topic,       setTopic]       = useState<ForumTopicDetail | null>(null);
  const [loading,     setLoading]     = useState(true);
  const [error,       setError]       = useState<string | null>(null);
  const [isFollowing, setIsFollowing] = useState(false);
  const [summarising, setSummarising] = useState(false);

  const scrollRef  = useRef<ScrollView>(null);
  const headingRef = useRef<View>(null);
  const repliesY   = useRef<number>(0);

  useHandoff(topic ? {
    activityType: 'com.applevis.app.viewTopic',
    title: topic.title,
    webpageURL: topic.url,
  } : null);

  function loadTopic() {
    if (!id) return;
    setLoading(true);
    setError(null);
    api.forums.topicDetail(id).then((res) => {
      setLoading(false);
      if (res.ok) {
        setTopic(res.data);
        setIsFollowing(res.data.isFollowing);
        setTimeout(() => {
          const node = headingRef.current ? findNodeHandle(headingRef.current) : null;
          if (node) AccessibilityInfo.setAccessibilityFocus(node);
        }, 350);
      } else {
        setError(res.error);
      }
    }).catch((err: unknown) => {
      setLoading(false);
      setError(err instanceof Error ? err.message : 'Unexpected error');
    });
  }

  useEffect(() => { loadTopic(); }, [id]);

  // ── Action handlers ─────────────────────────────────────────────────────────

  const isSaved = saved.isSaved(id ?? '');

  function handleSave() {
    if (!topic) return;
    if (isSaved) {
      saved.unsave(id!);
      showToast('Removed from saved.', 'success');
    } else {
      saved.save({ id: id!, kind: 'forumTopic', title: topic.title, savedAt: new Date().toISOString() });
      showToast('Topic saved.', 'success');
    }
  }

  function handleFollow() {
    if (!auth.isSignedIn) {
      showToast('Sign in to follow topics.', 'warning');
      return;
    }
    // Stub — Drupal Flags API NID/UUID path pending confirmation with developer
    showToast('Topic follow notifications — coming once the Drupal Flags API endpoint is confirmed.', 'warning');
  }

  function handleShare() {
    if (!topic) return;
    Share.share({ title: topic.title, message: `${topic.title} — ${topic.url}` }).catch(() => {});
  }

  function handleCopyLink() {
    if (!topic) return;
    Clipboard.setString(topic.url);
    showToast('Link copied.', 'success');
  }

  function handleOpenInBrowser() {
    if (!topic) return;
    Linking.openURL(topic.url).catch(() => showToast('Could not open Safari.', 'error'));
  }

  function handleAddComment() {
    if (!auth.isSignedIn) {
      showToast('Sign in to add a new comment.', 'warning');
      return;
    }
    if (!topic) return;
    router.push({
      pathname: '/compose' as any,
      params: { topicId: id, topicTitle: topic.title },
    });
  }

  function handleReadFullThread() {
    if (!topic) return;
    const parts = [
      `Topic: ${topic.title}.`,
      topic.authorName ? `Posted by ${topic.authorName}.` : null,
      stripHtml(topic.body),
      ...topic.replies.map((r, i) =>
        `Reply ${i + 1} by ${r.authorName}. ${stripHtml(r.body)}`),
    ];
    readAloud(parts.filter(Boolean).join(' '));
  }

  async function handleSummarise() {
    if (!topic) return;
    if (!aiAvailable) {
      showToast(
        'Apple Intelligence is not available on this device or has not been enabled in Settings → Apple Intelligence & Siri.',
        'warning',
      );
      return;
    }
    setSummarising(true);
    const result = await summariseText(`Forum topic: ${topic.title}\n\n${stripHtml(topic.body)}`);
    setSummarising(false);
    if (result) showToast(result, 'success');
    else showToast('Summarisation requires Apple Intelligence Foundation Models (iOS 18.1+).', 'warning');
  }

  function handleJumpToReplies() {
    scrollRef.current?.scrollTo({ y: repliesY.current, animated: true });
  }

  function handleBackToTop() {
    scrollRef.current?.scrollTo({ y: 0, animated: true });
  }

  const displayTitle = topic?.title ?? paramTitle ?? 'Topic';

  return (
    <Screen title={displayTitle} showSettings={false} showSearch={false}>
      <View style={{ flex: 1 }}>
      <ScrollView ref={scrollRef} showsVerticalScrollIndicator style={{ flex: 1 }} contentContainerStyle={{ paddingBottom: TOOLBAR_H + 16 }}>

        {/* ── Loading ────────────────────────────────────────────────────── */}
        {loading && (
          <View style={{ alignItems: 'center', paddingVertical: 48 }}>
            <ActivityIndicator size="large" color={colors.accent} accessibilityLabel="Loading topic" />
            <Text style={[styles.cardMeta, { marginTop: 12, textAlign: 'center' }]}>Loading topic…</Text>
          </View>
        )}

        {/* ── Error ─────────────────────────────────────────────────────── */}
        {!loading && error && (
          <View style={[styles.card, { borderColor: '#FCA5A5', borderWidth: 1 }]}>
            <Text style={[styles.cardTitle, { color: '#B91C1C' }]}>Could not load topic</Text>
            <Text style={styles.cardMeta}>{error}</Text>
            <Text style={[styles.cardMeta, { marginTop: 8 }]}>
              The Drupal developer needs to confirm the comment entity type and filter path.
            </Text>
            <Pressable
              onPress={loadTopic}
              accessible accessibilityRole="button" accessibilityLabel="Retry loading topic"
              style={{ marginTop: 12 }}
            >
              <Text style={{ color: colors.accent, fontWeight: '700' }}>Retry</Text>
            </Pressable>
          </View>
        )}

        {/* ── Content ───────────────────────────────────────────────────── */}
        {topic && (
          <>
            {/* Category breadcrumb
                Shell: will show actual forum category once taxonomy field is confirmed */}
            <View
              ref={headingRef}
              style={{ flexDirection: 'row', alignItems: 'center', gap: 4, marginBottom: 12 }}
              accessible
              accessibilityLabel={
                topic.category
                  ? `Forums, ${topic.category}`
                  : 'Forums — category pending API confirmation'
              }
            >
              <Text style={{ fontSize: 13, color: colors.textSecondary, fontWeight: '500' }}>Forums</Text>
              <Ionicons name="chevron-forward" size={12} color={colors.textSecondary} accessibilityElementsHidden />
              <Text style={{ fontSize: 13, color: topic.category ? colors.accent : colors.textSecondary,
                fontWeight: topic.category ? '600' : '400',
                fontStyle: topic.category ? 'normal' : 'italic' }}>
                {topic.category ?? '—'}
              </Text>
            </View>

            {/* Author / metadata band */}
            <View
              style={[styles.card, { marginBottom: 10 }]}
              accessible
              accessibilityLabel={[
                topic.authorName ? `Posted by ${topic.authorName}` : 'Author unknown',
                `Posted ${new Date(topic.createdAt).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })}`,
                `Last activity ${relativeTime(topic.lastActivityAt)}`,
                `${topic.replyCount} ${topic.replyCount === 1 ? 'comment' : 'comments'}`,
                topic.viewCount ? `${topic.viewCount} views` : null,
              ].filter(Boolean).join('. ')}
            >
              {/* Author row */}
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 12 }}
                accessibilityElementsHidden>
                <View style={{ width: 40, height: 40, borderRadius: 20, backgroundColor: colors.accent,
                  alignItems: 'center', justifyContent: 'center' }}>
                  <Text style={{ fontSize: 18, fontWeight: '700', color: colors.accentText }}>
                    {(topic.authorName || '?').charAt(0).toUpperCase()}
                  </Text>
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={{ fontSize: 15, fontWeight: '700', color: colors.text }}>
                    {topic.authorName || 'Unknown'}
                  </Text>
                  <Text style={{ fontSize: 12, color: colors.textSecondary }}>
                    {new Date(topic.createdAt).toLocaleDateString('en-US', {
                      year: 'numeric', month: 'long', day: 'numeric',
                    })}
                  </Text>
                </View>
              </View>

              {/* Stats row */}
              <View style={{ flexDirection: 'row', gap: 8, flexWrap: 'wrap' }} accessibilityElementsHidden>
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                  backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 6 }}>
                  <Ionicons name="chatbubbles-outline" size={14} color={colors.textSecondary} />
                  <Text style={{ fontSize: 13, fontWeight: '600', color: colors.textSecondary }}>
                    {topic.replyCount} {topic.replyCount === 1 ? 'comment' : 'comments'}
                  </Text>
                </View>

                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                  backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 6 }}>
                  <Ionicons name="eye-outline" size={14} color={colors.textSecondary} />
                  <Text style={{ fontSize: 13, fontWeight: '600', color: colors.textSecondary }}>
                    {topic.viewCount != null ? `${topic.viewCount} views` : '— views'}
                  </Text>
                </View>

                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                  backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 6 }}>
                  <Ionicons name="time-outline" size={14} color={colors.textSecondary} />
                  <Text style={{ fontSize: 13, fontWeight: '600', color: colors.textSecondary }}>
                    {relativeTime(topic.lastActivityAt)}
                  </Text>
                </View>
              </View>
            </View>

            {/* Topic body — each paragraph is its own accessible element for braille navigation */}
            {topic.body ? (
              <View style={[styles.card, { marginBottom: 12 }]}>
                {bodyParagraphs(topic.body).map((para, i) => (
                  <Text
                    key={i}
                    accessible
                    style={{ fontSize: 16, lineHeight: 27, color: colors.text, marginBottom: 8 }}
                  >
                    {para}
                  </Text>
                ))}
              </View>
            ) : null}

            {/* Quick nav row — below body */}
            <View style={{ flexDirection: 'row', gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
              {!screenReaderEnabled && topic.replyCount > 0 && (
                <Pressable
                  onPress={handleReadFullThread}
                  accessible
                  accessibilityRole="button"
                  accessibilityLabel="Read full thread aloud"
                  accessibilityHint="Reads the original post and all replies in order"
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                    backgroundColor: colors.pill, borderRadius: 10,
                    paddingHorizontal: 14, paddingVertical: 10 }}
                >
                  <Ionicons name="volume-medium-outline" size={16} color={colors.pillText} accessibilityElementsHidden />
                  <Text style={{ fontSize: 14, fontWeight: '600', color: colors.pillText }}>
                    Read Full Thread
                  </Text>
                </Pressable>
              )}
              {topic.replyCount > 0 && (
                <Pressable
                  onPress={handleJumpToReplies}
                  accessible
                  accessibilityRole="button"
                  accessibilityLabel={`Jump to ${topic.replyCount} ${topic.replyCount === 1 ? 'comment' : 'comments'}`}
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                    backgroundColor: colors.pill, borderRadius: 10,
                    paddingHorizontal: 14, paddingVertical: 10 }}
                >
                  <Ionicons name="arrow-down-outline" size={16} color={colors.pillText} accessibilityElementsHidden />
                  <Text style={{ fontSize: 14, fontWeight: '600', color: colors.pillText }}>
                    Jump to Comments
                  </Text>
                </Pressable>
              )}
            </View>

            {/* Apple Intelligence — Summarise */}
            <View
              style={[styles.card, { marginBottom: 12,
                opacity: aiAvailable ? 1 : 0.5 }]}
              accessible={!aiAvailable}
              accessibilityLabel={
                aiAvailable
                  ? undefined
                  : 'Summarise with Apple Intelligence — not available on this device or not enabled in Settings'
              }
            >
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 8 }}
                accessibilityElementsHidden>
                <Ionicons name="sparkles-outline" size={16} color={colors.accent} />
                <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
                  textTransform: 'uppercase', letterSpacing: 0.6 }}>
                  Apple Intelligence
                </Text>
              </View>
              <Pressable
                onPress={handleSummarise}
                disabled={summarising}
                accessible
                accessibilityRole="button"
                accessibilityLabel={
                  aiAvailable
                    ? (summarising ? 'Summarising, please wait' : 'Summarise this topic')
                    : 'Summarise — enable Apple Intelligence in Settings to use this'
                }
                accessibilityHint={
                  aiAvailable
                    ? 'Uses on-device AI to create a brief summary of this topic'
                    : 'Go to Settings → Apple Intelligence & Siri to enable'
                }
                style={{ flexDirection: 'row', alignItems: 'center', gap: 8,
                  backgroundColor: aiAvailable ? colors.accent : colors.pill,
                  borderRadius: 10, paddingHorizontal: 16, paddingVertical: 12,
                  alignSelf: 'flex-start' }}
              >
                {summarising
                  ? <ActivityIndicator size="small" color={aiAvailable ? colors.accentText : colors.pillText} accessibilityElementsHidden />
                  : <Ionicons name="sparkles" size={16} color={aiAvailable ? colors.accentText : colors.pillText} accessibilityElementsHidden />
                }
                <Text style={{ fontSize: 14, fontWeight: '700',
                  color: aiAvailable ? colors.accentText : colors.pillText }}>
                  {summarising ? 'Summarising…' : 'Summarise this Topic'}
                </Text>
              </Pressable>
              {!aiAvailable && (
                <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 8, lineHeight: 17 }}
                  accessibilityElementsHidden>
                  Enable Apple Intelligence in Settings → Apple Intelligence & Siri
                </Text>
              )}
            </View>

            {/* ── Replies section ────────────────────────────────────────── */}
            <View onLayout={(e) => { repliesY.current = e.nativeEvent.layout.y; }}>
              <SectionDivider
                label={`${topic.replyCount} ${topic.replyCount === 1 ? 'Comment' : 'Comments'}`}
              />

              {/* Jump to first unread — coming soon */}
              {topic.replyCount > 0 && (
                <ComingSoonShell
                  icon="flag-outline"
                  message={
                    auth.isSignedIn
                      ? "Jump to First Unread — quickly navigate to replies you haven't seen yet"
                      : "Jump to First Unread — sign in to track which replies are new to you"
                  }
                />
              )}

              {/* Replies pending API */}
              {topic.replyCount > 0 && topic.replies.length === 0 && (
                <View
                  style={[styles.card, { borderLeftWidth: 3, borderLeftColor: '#D97706', marginBottom: 12 }]}
                  accessible
                  accessibilityLabel={`${topic.replyCount} ${topic.replyCount === 1 ? 'comment' : 'comments'} exist but are not yet displayed. Full thread view is pending comments API confirmation with the Drupal developer.`}
                >
                  <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 6 }}
                    accessibilityElementsHidden>
                    <Ionicons name="time-outline" size={16} color="#D97706" />
                    <Text style={{ fontSize: 14, fontWeight: '700', color: '#D97706' }}>
                      {topic.replyCount} {topic.replyCount === 1 ? 'comment' : 'comments'} — loading pending
                    </Text>
                  </View>
                  <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}
                    accessibilityElementsHidden>
                    Full thread display is coming once the comments API endpoint is confirmed
                    with the Drupal developer. Visit applevis.com to read the full thread now.
                  </Text>
                  <Pressable
                    onPress={handleOpenInBrowser}
                    accessible
                    accessibilityRole="link"
                    accessibilityLabel="Read full thread on AppleVis website"
                    style={{ marginTop: 10 }}
                  >
                    <Text style={{ fontSize: 14, color: colors.accent, fontWeight: '700' }}>
                      Read on applevis.com →
                    </Text>
                  </Pressable>
                </View>
              )}

              {/* Loaded replies */}
              {topic.replies.map((reply, i) => (
                <ReplyCard
                  key={reply.id}
                  reply={reply}
                  index={i}
                  total={topic.replies.length}
                  colors={colors}
                  styles={styles}
                  screenReaderEnabled={screenReaderEnabled}
                  showToast={showToast}
                />
              ))}

              {/* Load more — coming soon (when server says there are more than loaded) */}
              {topic.replies.length > 0 && topic.replies.length < topic.replyCount && (
                <ComingSoonShell
                  icon="ellipsis-horizontal-outline"
                  message={`Load more comments — ${topic.replyCount - topic.replies.length} more comments pending pagination support`}
                />
              )}

              {/* No replies yet */}
              {topic.replyCount === 0 && (
                <View style={[styles.card, { alignItems: 'center', paddingVertical: 24, marginBottom: 8 }]}>
                  <Ionicons name="chatbubble-outline" size={28} color={colors.textSecondary}
                    accessibilityElementsHidden style={{ marginBottom: 8 }} />
                  <Text style={[styles.cardMeta, { textAlign: 'center' }]}>
                    No comments yet. Be the first to add a new comment.
                  </Text>
                </View>
              )}
            </View>

            {/* ── Related Topics — coming soon ───────────────────────────── */}
            <SectionDivider label="Related Topics" />
            <ComingSoonShell
              icon="git-network-outline"
              message="More from this forum — related topics will appear here once the category API is confirmed with the Drupal developer"
            />

            {/* Back to top */}
            <Pressable
              onPress={handleBackToTop}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Back to top"
              accessibilityHint="Scrolls back to the start of this topic"
              style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center',
                gap: 6, paddingVertical: 16 }}
            >
              <Ionicons name="arrow-up-outline" size={16} color={colors.textSecondary} accessibilityElementsHidden />
              <Text style={{ fontSize: 14, color: colors.textSecondary, fontWeight: '500' }}>Back to Top</Text>
            </Pressable>
          </>
        )}

      </ScrollView>

      {/* ── Fixed bottom toolbar ──────────────────────────────────────────── */}
      {topic && (
        <View
          style={{
            flexDirection: 'row',
            height: TOOLBAR_H,
            paddingHorizontal: 4,
            backgroundColor: colors.card,
            borderTopWidth: StyleSheet.hairlineWidth,
            borderTopColor: colors.border,
            alignItems: 'center',
          }}
          accessibilityRole="toolbar"
          accessibilityLabel="Topic actions"
        >
          <ToolbarButton
            icon="notifications-outline"
            activeIcon="notifications"
            label={isFollowing ? 'Unfollow\nthis Topic' : 'Follow\nthis Topic'}
            active={isFollowing}
            onPress={handleFollow}
          />
          <ToolbarButton
            icon="bookmark-outline"
            activeIcon="bookmark"
            label={isSaved ? 'Saved' : 'Save'}
            active={isSaved}
            onPress={handleSave}
          />
          <ToolbarButton
            icon="share-outline"
            label="Share"
            onPress={handleShare}
          />
          <ToolbarButton
            icon="safari-outline"
            label={'Open in\nSafari'}
            onPress={handleOpenInBrowser}
          />
          <ToolbarButton
            icon="pencil-outline"
            label={'Add New\nComment'}
            onPress={handleAddComment}
            accent
          />
        </View>
      )}
      </View>
    </Screen>
  );
}
