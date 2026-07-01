import { useCallback, useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActionSheetIOS, ActivityIndicator, Animated, Clipboard,
  findNodeHandle, Linking, Platform, Pressable, ScrollView,
  Share, StyleSheet, Text, View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useFocusEffect, useLocalSearchParams, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { Screen } from '../../src/components/Screen';
import { AuthorProfileModal } from '../../src/components/AuthorProfileModal';
import { EditContentModal } from '../../src/components/EditContentModal';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { useAuth } from '../../src/contexts/AuthContext';
import { useToast } from '../../src/contexts/ToastContext';
import { useAlert } from '../../src/contexts/AccessibleAlertContext';
import { confirmDestructiveAction } from '../../src/utils/confirmDestructiveAction';
import { usePreferences } from '../../src/contexts/PreferencesContext';
import { ALERTS } from '../../src/data/alertMessages';
import { useTip, TIP_KEYS, TIPS } from '../../src/contexts/ContextualTipContext';
import { useSavedItems } from '../../src/hooks/useSavedItems';
import { useHandoff } from '../../src/hooks/useHandoff';
import {
  readAloud, isAppleIntelligenceAvailable, summariseText,
} from '../../src/services/intelligenceService';
import { api } from '../../src/services/api';
import { cachedApi } from '../../src/services/cachedApi';
import { contentCache } from '../../src/services/contentCache';
import { persistence } from '../../src/services/persistence';
import { relativeTime } from '../../src/utils/relativeTime';
import { displayCommentSubject, subjectLabel } from '../../src/utils/commentSubject';
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

type BodySegment = { text: string; kind: 'prose' | 'quote' | 'code' };

// Split body HTML into typed segments.
// <pre>/<code> → kind:'code'; <blockquote> → kind:'quote'; remainder → kind:'prose'.
// Each element is a separate accessible node for braille-display swipe navigation.
function bodySegments(html: string): BodySegment[] {
  const result: BodySegment[] = [];
  const re = /(<pre[^>]*>[\s\S]*?<\/pre>|<blockquote[^>]*>[\s\S]*?<\/blockquote>)/gi;
  let cursor = 0;
  let m: RegExpExecArray | null;

  const pushProse = (raw: string) =>
    stripHtml(raw)
      .split('\n\n')
      .map(p => p.replace(/\n/g, ' ').trim())
      .filter(Boolean)
      .forEach(p => result.push({ text: p, kind: 'prose' }));

  while ((m = re.exec(html)) !== null) {
    pushProse(html.slice(cursor, m.index));
    const block = m[1];
    if (/^<pre/i.test(block)) {
      const code = block
        .replace(/<pre[^>]*>/gi, '').replace(/<\/pre>/gi, '')
        .replace(/<code[^>]*>/gi, '').replace(/<\/code>/gi, '')
        .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&')
        .replace(/&quot;/g, '"').replace(/&#039;/g, "'").replace(/&apos;/g, "'")
        .replace(/<[^>]*>/g, '').trim();
      if (code) result.push({ text: code, kind: 'code' });
    } else {
      const inner = block.replace(/<\/?blockquote[^>]*>/gi, '');
      const q = stripHtml(inner).replace(/\n+/g, ' ').trim();
      if (q) result.push({ text: q, kind: 'quote' });
    }
    cursor = m.index + m[0].length;
  }
  pushProse(html.slice(cursor));

  return result;
}

// Word-count based reading estimate across the full thread
function readingTime(bodyHtml: string, replies: ForumReply[]): string {
  const allHtml = [bodyHtml, ...replies.map(r => r.body)];
  const words   = allHtml.reduce(
    (n, h) => n + stripHtml(h).split(/\s+/).filter(Boolean).length, 0,
  );
  const minutes = Math.max(1, Math.ceil(words / 200));
  return `About a ${minutes} minute read`;
}

// ─── Category colour + author avatar colour ───────────────────────────────────

function categoryColor(category: string | undefined): string {
  if (!category) return '#6366f1';
  const cat = category.toLowerCase();
  if (cat.includes('ios') || cat.includes('ipad') || cat.includes('iphone')) return '#3b82f6';
  if (cat.includes('macos') || cat.includes('mac '))                          return '#8b5cf6';
  if (cat.includes('android') || cat.includes('google'))                      return '#22c55e';
  if (cat.includes('podcast') || cat.includes('audio'))                       return '#f59e0b';
  if (cat.includes('guide') || cat.includes('how-to') || cat.includes('tutorial')) return '#10b981';
  if (cat.includes('advocacy') || cat.includes('news'))                       return '#ef4444';
  if (cat.includes('windows') || cat.includes('pc'))                          return '#0ea5e9';
  if (cat.includes('watch') || cat.includes('tv') || cat.includes('homepod')) return '#ec4899';
  if (cat.includes('game') || cat.includes('gaming'))                         return '#f97316';
  return '#6366f1';
}

function hashAuthorColor(name: string): string {
  const PALETTE = ['#3b82f6', '#8b5cf6', '#10b981', '#f59e0b', '#ef4444', '#ec4899', '#06b6d4', '#84cc16'];
  let h = 0;
  for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) & 0xffff;
  return PALETTE[h % PALETTE.length];
}

// ─── Bottom toolbar button ────────────────────────────────────────────────────

function ToolbarButton({
  icon, activeIcon, label, a11yLabel, onPress, active, accent,
}: {
  icon: string; activeIcon?: string; label: string; onPress: () => void;
  a11yLabel?: string; active?: boolean; accent?: boolean;
}) {
  const { colors } = useTheme();
  const resolvedIcon = (active && activeIcon) ? activeIcon : icon;
  const color = accent ? colors.accent : active ? colors.accent : colors.textSecondary;
  return (
    <Pressable
      onPress={onPress}
      accessible
      accessibilityRole="button"
      accessibilityLabel={a11yLabel ?? label.replace(/\n/g, ' ')}
      accessibilityState={{ selected: active }}
      style={({ pressed }) => ({
        flex: 1, alignItems: 'center', justifyContent: 'center',
        gap: 4, opacity: pressed ? 0.55 : 1, paddingVertical: 10,
      })}
    >
      <Ionicons name={resolvedIcon as any} size={23} color={color} accessibilityElementsHidden />
      <Text
        style={{ fontSize: 12, fontWeight: '600', color, textAlign: 'center', lineHeight: 15 }}
        accessibilityElementsHidden
      >
        {label}
      </Text>
    </Pressable>
  );
}

// ─── Section divider ──────────────────────────────────────────────────────────

function SectionDivider({
  label,
  accessibilityActions,
  onAccessibilityAction,
}: {
  label: string;
  accessibilityActions?: { name: string; label: string }[];
  onAccessibilityAction?: (event: { nativeEvent: { actionName: string } }) => void;
}) {
  const { colors } = useTheme();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginVertical: 16 }}>
      <View style={{ flex: 1, height: 1, backgroundColor: colors.border }} accessibilityElementsHidden />
      <Text
        style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
          textTransform: 'uppercase', letterSpacing: 0.7 }}
        accessibilityRole="header"
        accessibilityActions={accessibilityActions}
        onAccessibilityAction={onAccessibilityAction}
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
  topicAuthorId, topicTitle, textSize, onReplyTo, categoryAccent, reduceMotion,
  currentUserUuid, onEdit, onDelete,
}: {
  reply: ForumReply;
  index: number;
  total: number;
  colors: ReturnType<typeof useTheme>['colors'];
  styles: ReturnType<typeof useTheme>['styles'];
  screenReaderEnabled: boolean;
  showToast: (msg: string, type?: 'success' | 'warning' | 'error') => void;
  topicAuthorId?: string;
  topicTitle?: string;
  textSize: number;
  onReplyTo: () => void;
  categoryAccent: string;
  reduceMotion: boolean;
  currentUserUuid?: string;
  onEdit: (reply: ForumReply) => void;
  onDelete: (reply: ForumReply) => void;
}) {
  const [collapsed, setCollapsed]   = useState(false);
  const pulseAnim                   = useRef(new Animated.Value(1)).current;
  const replyBodySegs               = bodySegments(reply.body);
  const timeStr                     = relativeTime(reply.createdAt);
  const isOP                        = !!topicAuthorId && topicAuthorId === reply.authorId;
  const isOwnReply                  = !!currentUserUuid && currentUserUuid === reply.authorId;
  const commentSubject              = displayCommentSubject(reply.subject, topicTitle);
  const commentFontSize             = Math.max(13, textSize - 1);
  const avatarBg                    = isOP ? categoryAccent : hashAuthorColor(reply.authorName);

  useEffect(() => {
    if (!reply.isNew || reduceMotion) return;
    Animated.sequence([
      Animated.timing(pulseAnim, { toValue: 1.25, duration: 200, useNativeDriver: true }),
      Animated.timing(pulseAnim, { toValue: 1,    duration: 200, useNativeDriver: true }),
      Animated.timing(pulseAnim, { toValue: 1.15, duration: 150, useNativeDriver: true }),
      Animated.timing(pulseAnim, { toValue: 1,    duration: 150, useNativeDriver: true }),
    ]).start();
  }, []);

  const replyActions = [
    { label: 'Reply to this Comment', action: onReplyTo },
    ...(!screenReaderEnabled
      ? [{ label: 'Read Aloud', action: () => {
            const spoken = replyBodySegs
              .map(s => s.kind === 'quote' ? `Quoted: ${s.text}` : s.text)
              .join(' ');
            readAloud(`Comment by ${reply.authorName}. ${subjectLabel(reply.subject, topicTitle)}${spoken}`);
          },
        }]
      : []),
    { label: 'Copy Comment Text', action: () => {
        Clipboard.setString(replyBodySegs.map(s => s.text).join('\n\n'));
        showToast('Comment text copied.', 'success');
      },
    },
    { label: 'Share Comment', action: () => {
        Share.share({
          message: [
            `${reply.authorName} on AppleVis`,
            commentSubject ? `Subject: ${commentSubject}` : null,
            replyBodySegs.map(s => s.text).join('\n\n'),
          ].filter(Boolean).join(':\n\n'),
        }).catch(() => {});
      },
    },
    { label: 'Mark as Helpful', action: () => showToast('Helpful votes — coming once the Drupal Flags API is confirmed.', 'warning') },
    { label: 'Report Comment',  action: () => showToast('Reporting coming once the Drupal Flags API is confirmed.', 'warning') },
    ...(isOwnReply ? [
      { label: 'Edit Comment',   action: () => onEdit(reply) },
      { label: 'Delete Comment', action: () => onDelete(reply) },
    ] : []),
  ];

  function handleLongPress() {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    if (Platform.OS === 'ios') {
      ActionSheetIOS.showActionSheetWithOptions(
        {
          title: `Comment by ${reply.authorName}${isOP ? ' (Original Poster)' : ''}`,
          options: ['Cancel', ...replyActions.map(a => a.label)],
          cancelButtonIndex: 0,
        },
        (i) => { if (i > 0) replyActions[i - 1].action(); },
      );
    }
  }

  return (
    <View
      style={[
        styles.card,
        { marginBottom: 8, padding: 0, overflow: 'hidden' },
        reply.isNew && { borderLeftWidth: 4, borderLeftColor: categoryAccent },
      ]}
    >
      {/* Comment header — accessibilityRole="header" lets braille users jump reply-to-reply via heading rotor */}
      <Pressable
        onLongPress={handleLongPress}
        onPress={() => {
          Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
          setCollapsed(c => !c);
        }}
        delayLongPress={400}
        accessible
        accessibilityRole="header"
        accessibilityLabel={
          `Comment ${index + 1} of ${total}. ` +
          `${reply.authorName}${isOP ? ', Original Poster' : ''}. ${timeStr}.` +
          (commentSubject ? ` Subject: ${commentSubject}.` : '') +
          (reply.isNew ? ' New.' : '') +
          ' Hold for options.'
        }
        accessibilityActions={replyActions.map(a => ({ name: a.label, label: a.label }))}
        onAccessibilityAction={({ nativeEvent }) => {
          replyActions.find(a => a.label === nativeEvent.actionName)?.action();
        }}
        style={({ pressed }) => ({
          flexDirection: 'row', alignItems: 'center', gap: 8,
          padding: 14, paddingBottom: collapsed ? 14 : 10,
          opacity: pressed ? 0.75 : 1,
        })}
      >
        {/* Visual content hidden from VoiceOver — covered by the label above */}
        <View
          style={{ flexDirection: 'row', alignItems: 'center', gap: 8, flex: 1 }}
          accessibilityElementsHidden
          importantForAccessibility="no-hide-descendants"
        >
          <View style={{ width: 34, height: 34, borderRadius: 17, backgroundColor: avatarBg,
            alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <Text style={{ fontSize: 15, fontWeight: '700', color: '#ffffff' }}>
              {reply.authorName.charAt(0).toUpperCase()}
            </Text>
          </View>
          <View style={{ flex: 1 }}>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
              <Text style={{ fontSize: 14, fontWeight: '700', color: colors.text }}>{reply.authorName}</Text>
              {isOP && (
                <View style={{ backgroundColor: categoryAccent, borderRadius: 5,
                  paddingHorizontal: 5, paddingVertical: 1 }}>
                  <Text style={{ color: '#ffffff', fontSize: 12, fontWeight: '700' }}>OP</Text>
                </View>
              )}
            </View>
              <Text style={{ fontSize: 12, color: colors.textSecondary }}>{timeStr}</Text>
              {!!commentSubject && (
                <Text style={{ fontSize: 13, color: colors.text, marginTop: 2 }} numberOfLines={2}>
                  {commentSubject}
                </Text>
              )}
            </View>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
            {reply.isNew && (
              <Animated.View
                style={{
                  backgroundColor: categoryAccent, borderRadius: 6,
                  paddingHorizontal: 6, paddingVertical: 2,
                  transform: [{ scale: pulseAnim }],
                }}
              >
                <Text style={{ color: '#ffffff', fontSize: 12, fontWeight: '700' }}>NEW</Text>
              </Animated.View>
            )}
            <Text style={{ fontSize: 11, color: colors.textSecondary, fontWeight: '500' }}>
              {index + 1}/{total}
            </Text>
            <Ionicons name={collapsed ? 'chevron-down' : 'chevron-up'} size={14} color={colors.textSecondary} />
          </View>
        </View>
      </Pressable>

      {/* Body — each paragraph/quote/code block is its own accessible node for braille navigation */}
      {!collapsed && (
        <View style={{ paddingHorizontal: 14, paddingBottom: 14 }}>
          {replyBodySegs.map((seg, si) => {
            if (seg.kind === 'code') return (
              <View
                key={si}
                accessible
                accessibilityLabel={`Code: ${seg.text}`}
                style={{ backgroundColor: '#1a1a2e', borderRadius: 8, padding: 10, marginBottom: 8 }}
              >
                <View
                  style={{ flexDirection: 'row', justifyContent: 'flex-end', marginBottom: 4 }}
                  accessibilityElementsHidden
                  importantForAccessibility="no-hide-descendants"
                >
                  <View style={{ backgroundColor: colors.accent, borderRadius: 4,
                    paddingHorizontal: 6, paddingVertical: 1 }}>
                    <Text style={{ color: '#fff', fontSize: 9, fontWeight: '700', letterSpacing: 0.4 }}>CODE</Text>
                  </View>
                </View>
                <Text
                  style={{
                    fontSize: commentFontSize - 1, lineHeight: (commentFontSize - 1) * 1.55,
                    color: '#e5e7eb',
                    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
                  }}
                  accessibilityElementsHidden
                >
                  {seg.text}
                </Text>
              </View>
            );
            if (seg.kind === 'quote') return (
              <View
                key={si}
                accessible
                accessibilityLabel={`Quoted: ${seg.text}`}
                style={{
                  borderLeftWidth: 3, borderLeftColor: '#f59e0b',
                  backgroundColor: 'rgba(245, 158, 11, 0.08)',
                  paddingLeft: 12, paddingVertical: 8, paddingRight: 8,
                  marginBottom: 8, borderRadius: 6,
                }}
              >
                <Text
                  style={{
                    fontSize: commentFontSize - 1, lineHeight: (commentFontSize - 1) * 1.55,
                    color: colors.textSecondary, fontStyle: 'italic',
                  }}
                  accessibilityElementsHidden
                >
                  {seg.text}
                </Text>
              </View>
            );
            return (
              <Text
                key={si}
                accessible
                style={{
                  fontSize: commentFontSize, lineHeight: commentFontSize * 1.65,
                  color: colors.text, marginBottom: si < replyBodySegs.length - 1 ? 6 : 0,
                }}
              >
                {seg.text}
              </Text>
            );
          })}
        </View>
      )}
    </View>
  );
}

// ─── Main screen ──────────────────────────────────────────────────────────────

const TOOLBAR_H = 58;

export default function TopicDetail() {
  const { id, title: paramTitle } = useLocalSearchParams<{ id: string; title?: string }>();
  const router                    = useRouter();
  const { colors, styles }        = useTheme();
  const { aiSummariesEnabled }    = usePreferences();
  const { screenReaderEnabled, reduceMotion, reduceTransparency } = useAccessibilityPreferences();
  const auth                      = useAuth();
  const { showToast }             = useToast();
  const { showAlert }             = useAlert();
  const { showTip }               = useTip();
  const saved                     = useSavedItems('forumTopic');
  const aiAvailable               = aiSummariesEnabled && isAppleIntelligenceAvailable();
  const insets                    = useSafeAreaInsets();

  const [topic,        setTopic]        = useState<ForumTopicDetail | null>(null);
  const [loading,      setLoading]      = useState(true);
  const [error,        setError]        = useState<string | null>(null);
  const [fromCache,    setFromCache]    = useState(false);
  const [isFollowing,  setIsFollowing]  = useState(false);
  const [summarising,           setSummarising]           = useState(false);
  const [summarisingDiscussion, setSummarisingDiscussion] = useState(false);
  const [bodyExpanded,    setBodyExpanded]    = useState(false);
  const [authorProfile,   setAuthorProfile]   = useState(false);
  const [textSize,             setTextSize]             = useState(16);
  const [loadingMoreReplies,  setLoadingMoreReplies]  = useState(false);
  const [editingReply,        setEditingReply]        = useState<ForumReply | null>(null);
  const [editingTopic,        setEditingTopic]        = useState(false);

  const isOwnTopic = (!!auth.user?.uuid && !!topic?.authorId && auth.user.uuid === topic.authorId) || !!auth.user?.isAdmin;

  const scrollRef      = useRef<ScrollView>(null);
  const repliesY       = useRef<number>(0);
  const replyRefs      = useRef<Record<string, View | null>>({});
  const replyOffsets   = useRef<Record<string, number>>({});
  const progressAnim         = useRef(new Animated.Value(0)).current;
  const heroAnim             = useRef(new Animated.Value(0)).current;
  const contentAnim          = useRef(new Animated.Value(0)).current;
  const preLoadCount         = useRef(0);
  const firstNewAfterLoadRef = useRef<View | null>(null);
  const needsRefresh         = useRef(false);
  const heroRef        = useRef<Text>(null);
  const hasInitialFocus = useRef(false);

  useHandoff(topic ? {
    activityType: 'com.applevis.app.viewTopic',
    title: topic.title,
    webpageURL: topic.url,
  } : null);

  function loadTopic() {
    if (!id) return;
    setLoading(true);
    setError(null);
    Promise.all([
      cachedApi.forums.topicDetail(id),
      persistence.getTopicLastSeen(id),
    ]).then(([res, lastSeenAt]) => {
      setLoading(false);
      if (res.ok) {
        const data: ForumTopicDetail = {
          ...res.data,
          replies: lastSeenAt
            ? res.data.replies.map(r => ({ ...r, isNew: r.createdAt > lastSeenAt }))
            : res.data.replies,
        };
        setTopic(data);
        setFromCache(res.fromCache);
        setIsFollowing(data.isFollowing);
        persistence.stampTopicSeen(id);
        persistence.stampItemVisit(id, data.replyCount);
        setTimeout(() => showTip(TIP_KEYS.forumRotorActions, TIPS.forumRotorActions), 1200);
      } else {
        setError(res.error);
      }
    }).catch((err: unknown) => {
      setLoading(false);
      setError(err instanceof Error ? err.message : 'Unexpected error');
    });
  }

  useEffect(() => { loadTopic(); }, [id]);

  useEffect(() => {
    if (!topic) return;
    if (reduceMotion || screenReaderEnabled) {
      heroAnim.setValue(1);
      contentAnim.setValue(1);
      return;
    }
    Animated.parallel([
      Animated.timing(heroAnim,    { toValue: 1, duration: 380, useNativeDriver: true }),
      Animated.timing(contentAnim, { toValue: 1, duration: 450, delay: 180, useNativeDriver: true }),
    ]).start();
  }, [topic]);

  // VoiceOver: focus to title on first load.
  useEffect(() => {
    if (!topic || hasInitialFocus.current) return;
    hasInitialFocus.current = true;
    setTimeout(() => {
      const handle = findNodeHandle(heroRef.current);
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, 200);
  }, [topic]);

  // Invalidate detail cache and reload when returning from compose (after posting a reply).
  useFocusEffect(useCallback(() => {
    if (!needsRefresh.current || !id) return;
    needsRefresh.current = false;
    contentCache.clear(`forums:detail:${id}`).then(() => loadTopic());
  }, [id]));

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

  async function handleFollow() {
    if (!auth.isSignedIn) {
      showAlert({ ...ALERTS.auth.signInRequired('follow this topic'), onConfirm: () => router.push('/settings-account' as any) });
      return;
    }
    if (!id) return;
    const token = await api.account.getSessionToken();
    if (!token) { showAlert(ALERTS.auth.sessionExpired()); return; }
    if (isFollowing) {
      const res = await api.forums.unfollow(id, token);
      if (res.ok) { setIsFollowing(false); showToast('No longer following this topic.', 'success'); }
      else showToast(`Could not unfollow: ${res.error}`, 'error');
    } else {
      const res = await api.forums.follow(id, token);
      if (res.ok) {
        setIsFollowing(true);
        showToast('Now following this topic.', 'success');
        setTimeout(() => showTip(TIP_KEYS.followTopicNotifications, TIPS.followTopicNotifications), 1500);
      }
      else showToast(`Could not follow: ${res.error}`, 'error');
    }
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

  function handleTopicOptions() {
    if (!topic) return;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    if (Platform.OS === 'ios') {
      if (auth.user?.isAdmin) {
        ActionSheetIOS.showActionSheetWithOptions(
          { title: topic.title, options: ['Cancel', 'Edit Topic', 'Unpublish Topic', 'Delete Topic'],
            cancelButtonIndex: 0, destructiveButtonIndex: 3 },
          (index) => {
            if (index === 1) setEditingTopic(true);
            if (index === 2) handleUnpublishTopic();
            if (index === 3) handleDeleteTopic();
          },
        );
      } else {
        ActionSheetIOS.showActionSheetWithOptions(
          { title: topic.title, options: ['Cancel', 'Edit Topic', 'Delete Topic'],
            cancelButtonIndex: 0, destructiveButtonIndex: 2 },
          (index) => {
            if (index === 1) setEditingTopic(true);
            if (index === 2) handleDeleteTopic();
          },
        );
      }
    } else {
      setEditingTopic(true);
    }
  }

  function handleDeleteTopic() {
    if (!topic || !auth.user?.csrfToken) return;
    showAlert({
      title: 'Delete Topic?',
      message: 'This will permanently delete your topic and all its comments. This cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      type: 'warning',
      onConfirm: async () => {
        const res = await api.content.deleteForumPost(topic.id, auth.user!.csrfToken);
        if (res.ok) {
          showToast('Topic deleted.', 'success');
          router.back();
        } else {
          showToast(res.error ?? 'Could not delete topic. Please try again.', 'error');
        }
      },
    });
  }

  function handleUnpublishTopic() {
    if (!topic || !auth.user?.csrfToken) return;
    showAlert({
      title: 'Unpublish Topic',
      message: `"${topic.title}" will be hidden from all users but not deleted.`,
      confirmLabel: 'Unpublish', cancelLabel: 'Cancel', type: 'warning',
      onConfirm: async () => {
        const res = await api.content.unpublishNode(topic.id, 'forum', auth.user!.csrfToken);
        if (res.ok) { showToast('Topic unpublished.', 'success'); router.back(); }
        else showToast(res.error ?? 'Could not unpublish. Please try again.', 'error');
      },
    });
  }

  function handleAddComment() {
    if (!auth.isSignedIn) {
      showAlert({ ...ALERTS.auth.signInRequired('post in this topic'), onConfirm: () => router.push('/settings-account' as any) });
      return;
    }
    if (!topic) return;
    needsRefresh.current = true;
    router.push({
      pathname: '/compose' as any,
      params: { topicId: id, topicTitle: topic.title },
    });
  }

  function handleReplyToComment(reply: ForumReply) {
    if (!auth.isSignedIn) {
      showAlert({ ...ALERTS.auth.signInRequired('reply to posts'), onConfirm: () => router.push('/settings-account' as any) });
      return;
    }
    if (!topic) return;
    const plain = stripHtml(reply.body);
    const quote = plain.length > 150 ? plain.slice(0, 150).trimEnd() + '…' : plain;
    needsRefresh.current = true;
    router.push({
      pathname: '/compose' as any,
      params: { topicId: id, topicTitle: topic.title, replyToAuthor: reply.authorName, replyToQuote: quote },
    });
  }

  async function handleLoadMoreReplies() {
    if (!topic || !id || loadingMoreReplies) return;
    preLoadCount.current = topic.replies.length;
    setLoadingMoreReplies(true);
    const res = await api.forums.moreReplies(id, topic.replies.length);
    setLoadingMoreReplies(false);
    if (res.ok && res.data.length > 0) {
      setTopic(t => t ? { ...t, replies: [...t.replies, ...res.data] } : t);
      showToast(`${res.data.length} more comment${res.data.length === 1 ? '' : 's'} loaded.`, 'success');
      setTimeout(() => {
        const handle = findNodeHandle(firstNewAfterLoadRef.current);
        if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
      }, 400);
    } else if (!res.ok) {
      showToast(`Could not load more comments: ${res.error}`, 'error');
    }
  }

  function handleReadFullThread() {
    if (!topic) return;
    const parts = [
      `Topic: ${topic.title}.`,
      topic.authorName ? `Posted by ${topic.authorName}.` : null,
      stripHtml(topic.body),
      ...topic.replies.map((r, i) =>
        `Comment ${i + 1} by ${r.authorName}. ${stripHtml(r.body)}`),
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

  async function handleSummariseDiscussion() {
    if (!topic) return;
    setSummarisingDiscussion(true);
    const discussionText = topic.replies
      .map((r, i) => `Comment ${i + 1} by ${r.authorName}: ${stripHtml(r.body)}`)
      .join('\n\n');
    const result = await summariseText(`Forum discussion on: ${topic.title}\n\n${discussionText}`);
    setSummarisingDiscussion(false);
    if (result) showToast(result, 'success');
    else showToast('Summarisation requires Apple Intelligence Foundation Models (iOS 18.1+).', 'warning');
  }

  function handleJumpToReplies() {
    scrollRef.current?.scrollTo({ y: repliesY.current, animated: true });
  }

  function handleBackToTop() {
    scrollRef.current?.scrollTo({ y: 0, animated: true });
  }

  function jumpToComment(sortedIndex: number, sortedList: ForumReply[]) {
    if (!topic || sortedIndex < 0 || sortedIndex >= sortedList.length) return;
    const replyId = sortedList[sortedIndex].id;
    const y = Math.max(0, repliesY.current + (replyOffsets.current[replyId] ?? 0) - 20);
    scrollRef.current?.scrollTo({ y, animated: true });
    setTimeout(() => {
      const ref = replyRefs.current[replyId];
      if (!ref) return;
      const handle = findNodeHandle(ref);
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, 400);
  }

  function handleScroll(e: { nativeEvent: { contentOffset: { y: number }; contentSize: { height: number }; layoutMeasurement: { height: number } } }) {
    const { contentOffset, contentSize, layoutMeasurement } = e.nativeEvent;
    const total = contentSize.height - layoutMeasurement.height;
    if (total <= 0) return;
    progressAnim.setValue(Math.min(1, Math.max(0, contentOffset.y / total)));
  }

  const displayTitle  = topic?.title ?? paramTitle ?? 'Topic';
  const catColor      = categoryColor(topic?.category);

  // Derived from topic — recalculated each render (fast for a single post)
  const bodySegs          = topic ? bodySegments(topic.body) : [];
  const needsBodyCollapse = bodySegs.length > 5;
  const visibleBodySegs   = needsBodyCollapse && !bodyExpanded ? bodySegs.slice(0, 4) : bodySegs;
  const hiddenSegCount    = bodySegs.length - visibleBodySegs.length;
  const newReplyCount     = topic?.replies.filter(r => r.isNew).length ?? 0;
  const sortedReplies     = topic?.replies ?? [];

  return (
    <Screen title={displayTitle} showSettings={false} showSearch={false} titleAccessible={false}>
      {/* Reading progress bar — purely visual, hidden from VoiceOver/braille */}
      {topic && (
        <View
          style={{ height: 5, backgroundColor: colors.border }}
          accessibilityElementsHidden
          importantForAccessibility="no-hide-descendants"
        >
          <Animated.View
            style={{
              height: 5,
              backgroundColor: colors.accent,
              width: progressAnim.interpolate({
                inputRange: [0, 1],
                outputRange: ['0%', '100%'],
                extrapolate: 'clamp',
              }),
            }}
          />
        </View>
      )}
      <View style={{ flex: 1 }}>
      <ScrollView
        ref={scrollRef}
        showsVerticalScrollIndicator
        style={{ flex: 1 }}
        contentContainerStyle={{ paddingBottom: TOOLBAR_H + 16 }}
        onScroll={handleScroll}
        scrollEventThrottle={16}
      >

        {/* ── Loading ────────────────────────────────────────────────────── */}
        {loading && (
          <View
            accessible
            accessibilityLiveRegion="polite"
            accessibilityLabel="Loading topic, please wait"
            style={{ alignItems: 'center', paddingVertical: 48 }}
          >
            <ActivityIndicator size="large" color={colors.accent} />
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
            {/* ── Hero card with category colour accent ──────────────────── */}
            <Animated.View
              style={{
                opacity: heroAnim,
                transform: [{ translateY: heroAnim.interpolate({ inputRange: [0, 1], outputRange: [14, 0] }) }],
              }}
            >
              <View
                style={[styles.card, {
                  marginBottom: 12, overflow: 'hidden', padding: 0,
                  borderLeftWidth: 4, borderLeftColor: catColor,
                }]}
              >
                {!reduceTransparency && (
                  <View
                    style={{ ...StyleSheet.absoluteFillObject, backgroundColor: catColor, opacity: 0.06 }}
                    accessibilityElementsHidden
                    importantForAccessibility="no-hide-descendants"
                  />
                )}
                <View style={{ padding: 16 }}>
                  {/* Hero title row — VoiceOver auto-focuses here on load (swipe 1) */}
                  <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 8, marginBottom: 12 }}>
                    <Text
                      ref={heroRef}
                      accessible
                      accessibilityRole="header"
                      accessibilityLabel={displayTitle}
                      style={{ flex: 1, fontSize: 20, fontWeight: '800', color: colors.text, lineHeight: 27 }}
                    >
                      {displayTitle}
                    </Text>
                    {isOwnTopic && (
                      <Pressable
                        onPress={handleTopicOptions}
                        accessible
                        accessibilityRole="button"
                        accessibilityLabel="Topic options"
                        accessibilityHint="Edit or delete this topic"
                        style={({ pressed }) => ({ padding: 6, opacity: pressed ? 0.55 : 1, marginTop: 2 })}
                      >
                        <Ionicons name="ellipsis-horizontal" size={20} color={colors.textSecondary}
                          accessibilityElementsHidden />
                      </Pressable>
                    )}
                  </View>

                  {/* Author / submitter — swipe 2 */}
                  <Pressable
                    onPress={() => topic.authorId ? setAuthorProfile(true) : undefined}
                    accessible
                    accessibilityRole="button"
                    accessibilityLabel={`Submitted by ${topic.authorName || 'Unknown'}${topic.authorId ? '. Double tap to view profile.' : '.'}`}
                    accessibilityHint={[
                      `Posted ${relativeTime(topic.createdAt)}`,
                      topic.replyCount > 0 ? `Last comment ${relativeTime(topic.lastActivityAt)}` : null,
                      `${topic.replyCount} ${topic.replyCount === 1 ? 'comment' : 'comments'}`,
                      topic.viewCount != null ? `${topic.viewCount} views` : null,
                      readingTime(topic.body, topic.replies),
                    ].filter(Boolean).join('. ')}
                    style={({ pressed }) => ({
                      flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 12,
                      opacity: pressed ? 0.65 : 1,
                    })}
                  >
                    <View style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: catColor,
                      alignItems: 'center', justifyContent: 'center' }}>
                      <Text style={{ fontSize: 20, fontWeight: '800', color: '#ffffff' }}
                        accessibilityElementsHidden>
                        {(topic.authorName || '?').charAt(0).toUpperCase()}
                      </Text>
                    </View>
                    <View style={{ flex: 1 }}>
                      <Text style={{ fontSize: 15, fontWeight: '700', color: colors.text }}>
                        Submitted by {topic.authorName || 'Unknown'}
                      </Text>
                      <Text style={{ fontSize: 12, color: colors.textSecondary }}>
                        {`Posted ${relativeTime(topic.createdAt)}`}
                        {topic.replyCount > 0 ? ` · Last comment ${relativeTime(topic.lastActivityAt)}` : ''}
                      </Text>
                    </View>
                    {topic.authorId && (
                      <Ionicons name="chevron-forward" size={16} color={colors.textSecondary}
                        accessibilityElementsHidden />
                    )}
                  </Pressable>

                  {/* Forum type (category) — swipe 3 */}
                  <Pressable
                    onPress={() => router.push('/(tabs)/discover' as any)}
                    accessible
                    accessibilityRole="button"
                    accessibilityLabel={
                      topic.category
                        ? `Forums, ${topic.category}. Double tap to browse forums.`
                        : 'Forums. Double tap to browse forums.'
                    }
                    style={({ pressed }) => ({
                      flexDirection: 'row', alignItems: 'center', gap: 4,
                      opacity: pressed ? 0.55 : 1, alignSelf: 'flex-start',
                    })}
                  >
                    <Text style={{ fontSize: 13, color: catColor, fontWeight: '600' }}>Forums</Text>
                    <Ionicons name="chevron-forward" size={12} color={colors.textSecondary} accessibilityElementsHidden />
                    <Text style={{ fontSize: 13, color: topic.category ? colors.text : colors.textSecondary,
                      fontWeight: topic.category ? '600' : '400',
                      fontStyle: topic.category ? 'normal' : 'italic' }}>
                      {topic.category ?? '—'}
                    </Text>
                  </Pressable>
                </View>
              </View>
            </Animated.View>

            {/* ── Animated content area ──────────────────────────────────── */}
            <Animated.View
              style={{
                opacity: contentAnim,
                transform: [{ translateY: contentAnim.interpolate({ inputRange: [0, 1], outputRange: [10, 0] }) }],
              }}
            >

            {/* Stats row — visual only; stats are spoken via the author hint above */}
            <View style={{ flexDirection: 'row', gap: 8, flexWrap: 'wrap', marginBottom: 12 }}
              accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 6 }}>
                <Ionicons name="chatbubbles-outline" size={14} color={colors.textSecondary} />
                <Text style={{ fontSize: 13, fontWeight: '600', color: colors.textSecondary }}>
                  {topic.replyCount} {topic.replyCount === 1 ? 'comment' : 'comments'}
                </Text>
              </View>

              {topic.viewCount != null && (
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                  backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 6 }}>
                  <Ionicons name="eye-outline" size={14} color={colors.textSecondary} />
                  <Text style={{ fontSize: 13, fontWeight: '600', color: colors.textSecondary }}>
                    {topic.viewCount} views
                  </Text>
                </View>
              )}

              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 6 }}>
                <Ionicons name="calendar-outline" size={14} color={colors.textSecondary} />
                <Text style={{ fontSize: 13, fontWeight: '600', color: colors.textSecondary }}>
                  {'Posted ' + relativeTime(topic.createdAt)}
                </Text>
              </View>

              {topic.replyCount > 0 && (
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                  backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 6 }}>
                  <Ionicons name="time-outline" size={14} color={colors.textSecondary} />
                  <Text style={{ fontSize: 13, fontWeight: '600', color: colors.textSecondary }}>
                    {'Last comment ' + relativeTime(topic.lastActivityAt)}
                  </Text>
                </View>
              )}

              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 6 }}>
                <Ionicons name="book-outline" size={14} color={colors.textSecondary} />
                <Text style={{ fontSize: 13, fontWeight: '600', color: colors.textSecondary }}>
                  {readingTime(topic.body, topic.replies)}
                </Text>
              </View>
            </View>

            {/* Offline banner */}
            {fromCache && (
              <View
                accessible
                accessibilityLabel="Viewing offline content. Some information may be out of date."
                style={{
                  flexDirection: 'row', alignItems: 'center', gap: 8,
                  backgroundColor: colors.pill, borderRadius: 10,
                  paddingHorizontal: 12, paddingVertical: 8, marginBottom: 10,
                }}>
                <Ionicons name="cloud-offline-outline" size={16} color={colors.textSecondary}
                  accessibilityElementsHidden />
                <Text style={{ flex: 1, fontSize: 13, color: colors.textSecondary }}>
                  Viewing offline content · some comments may be out of date
                </Text>
                <Pressable onPress={loadTopic} accessible accessibilityRole="button"
                  accessibilityLabel="Refresh"
                  style={{ paddingHorizontal: 8, paddingVertical: 4 }}>
                  <Text style={{ fontSize: 13, fontWeight: '700', color: colors.accent }}>Refresh</Text>
                </Pressable>
              </View>
            )}

            {/* Topic body */}
            {topic.body ? (
              <View style={[styles.card, { marginBottom: 12 }]}>

                {/* Heading row — landmark + A−/A+ text-size controls side by side */}
                <View style={{ flexDirection: 'row', alignItems: 'center', marginBottom: 12 }}>
                  <Text
                    accessible
                    accessibilityRole="header"
                    accessibilityLabel="Original Post"
                    accessibilityActions={[
                      { name: 'save',                  label: isSaved     ? 'Remove from Saved' : 'Save Topic'  },
                      { name: 'follow',                label: isFollowing ? 'Unfollow Topic'     : 'Follow Topic' },
                      { name: 'share',                 label: 'Share Topic'                                       },
                      ...(aiAvailable ? [
                        { name: 'summarise',           label: 'Summarise Original Post'                          },
                        { name: 'summariseDiscussion', label: 'Summarise Discussion'                             },
                      ] : []),
                      { name: 'increaseText',          label: 'Increase text size'                                },
                      { name: 'decreaseText',          label: 'Decrease text size'                                },
                    ]}
                    onAccessibilityAction={({ nativeEvent }) => {
                      switch (nativeEvent.actionName) {
                        case 'save':                  handleSave();               break;
                        case 'follow':                handleFollow();             break;
                        case 'share':                 handleShare();              break;
                        case 'summarise':             handleSummarise();          break;
                        case 'summariseDiscussion':   handleSummariseDiscussion(); break;
                        case 'increaseText': setTextSize(s => Math.min(22, s + 1)); break;
                        case 'decreaseText': setTextSize(s => Math.max(13, s - 1)); break;
                      }
                    }}
                    style={{ flex: 1, fontSize: 11, fontWeight: '700', color: colors.textSecondary,
                      textTransform: 'uppercase', letterSpacing: 0.6 }}
                  >
                    Original Post
                  </Text>

                  {/* A−/A+ size controls — visual only; VoiceOver uses the actions above */}
                  <View
                    style={{ flexDirection: 'row', gap: 2 }}
                    accessibilityElementsHidden
                    importantForAccessibility="no-hide-descendants"
                  >
                    <Pressable
                      onPress={() => setTextSize(s => Math.max(13, s - 1))}
                      style={({ pressed }) => ({ padding: 6, opacity: pressed ? 0.55 : 1 })}
                    >
                      <Text style={{ fontSize: 14, fontWeight: '700', color: colors.accent }}>A−</Text>
                    </Pressable>
                    <Pressable
                      onPress={() => setTextSize(s => Math.min(22, s + 1))}
                      style={({ pressed }) => ({ padding: 6, opacity: pressed ? 0.55 : 1 })}
                    >
                      <Text style={{ fontSize: 18, fontWeight: '700', color: colors.accent }}>A+</Text>
                    </Pressable>
                  </View>
                </View>

                {/* Body segments — prose, quotes, and code blocks.
                    Each element is a separate accessible node for braille-display navigation. */}
                {visibleBodySegs.map((seg, i) => {
                  if (seg.kind === 'code') return (
                    <View
                      key={i}
                      accessible
                      accessibilityLabel={`Code: ${seg.text}`}
                      style={{ backgroundColor: '#1a1a2e', borderRadius: 8, padding: 12, marginBottom: 10 }}
                    >
                      <View
                        style={{ flexDirection: 'row', justifyContent: 'flex-end', marginBottom: 6 }}
                        accessibilityElementsHidden
                        importantForAccessibility="no-hide-descendants"
                      >
                        <View style={{ backgroundColor: colors.accent, borderRadius: 4,
                          paddingHorizontal: 6, paddingVertical: 1 }}>
                          <Text style={{ color: '#fff', fontSize: 9, fontWeight: '700', letterSpacing: 0.4 }}>
                            CODE
                          </Text>
                        </View>
                      </View>
                      <Text
                        style={{
                          fontSize: textSize - 1, lineHeight: (textSize - 1) * 1.55,
                          color: '#e5e7eb',
                          fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
                        }}
                        accessibilityElementsHidden
                      >
                        {seg.text}
                      </Text>
                    </View>
                  );
                  if (seg.kind === 'quote') return (
                    <View
                      key={i}
                      accessible
                      accessibilityLabel={`Quoted: ${seg.text}`}
                      style={{
                        borderLeftWidth: 3, borderLeftColor: '#f59e0b',
                        backgroundColor: 'rgba(245, 158, 11, 0.08)',
                        paddingLeft: 12, paddingVertical: 8, paddingRight: 8,
                        marginBottom: 10, borderRadius: 6,
                      }}
                    >
                      <Text
                        style={{ fontSize: textSize - 1, lineHeight: (textSize - 1) * 1.55,
                          color: colors.textSecondary, fontStyle: 'italic' }}
                        accessibilityElementsHidden
                      >
                        {seg.text}
                      </Text>
                    </View>
                  );
                  return (
                    <Text
                      key={i}
                      accessible
                      style={{ fontSize: textSize, lineHeight: textSize * 1.7, color: colors.text, marginBottom: 8 }}
                    >
                      {seg.text}
                    </Text>
                  );
                })}

                {/* Expand / collapse button — only shown when post is long */}
                {needsBodyCollapse && hiddenSegCount > 0 && (
                  <Pressable
                    onPress={() => {
                      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                      setBodyExpanded(v => !v);
                    }}
                    accessible
                    accessibilityRole="button"
                    accessibilityLabel={
                      bodyExpanded
                        ? 'Show less'
                        : `Show full post — ${hiddenSegCount} more section${hiddenSegCount === 1 ? '' : 's'}`
                    }
                    style={({ pressed }) => ({
                      flexDirection: 'row', alignItems: 'center', gap: 6,
                      marginTop: 4, paddingVertical: 8, opacity: pressed ? 0.55 : 1,
                    })}
                  >
                    <Ionicons
                      name={bodyExpanded ? 'chevron-up-outline' : 'chevron-down-outline'}
                      size={16}
                      color={colors.accent}
                      accessibilityElementsHidden
                    />
                    <Text style={{ fontSize: 14, fontWeight: '600', color: colors.accent }}>
                      {bodyExpanded ? 'Show less' : `Show full post (${hiddenSegCount} more)`}
                    </Text>
                  </Pressable>
                )}
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
                  accessibilityHint="Reads the original post and all comments in order"
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
              {topic.replyCount > 0 && newReplyCount > 0 && (
                <Pressable
                  onPress={() => {
                    const idx = sortedReplies.findIndex(r => r.isNew);
                    if (idx >= 0) jumpToComment(idx, sortedReplies);
                  }}
                  accessible
                  accessibilityRole="button"
                  accessibilityLabel={`Jump to first new comment. ${newReplyCount} new since your last visit.`}
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                    backgroundColor: colors.pill, borderRadius: 10,
                    paddingHorizontal: 14, paddingVertical: 10 }}
                >
                  <Ionicons name="arrow-down-outline" size={16} color={colors.pillText} accessibilityElementsHidden />
                  <Text style={{ fontSize: 14, fontWeight: '600', color: colors.pillText }}>
                    Jump to First New
                  </Text>
                </Pressable>
              )}
            </View>

            {/* Apple Intelligence — only shown when available on this device */}
            {aiAvailable && (
              <View style={[styles.card, { marginBottom: 12 }]}>
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 10 }}
                  accessibilityElementsHidden>
                  <Ionicons name="sparkles-outline" size={16} color={colors.accent} />
                  <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
                    textTransform: 'uppercase', letterSpacing: 0.6 }}>
                    Apple Intelligence
                  </Text>
                </View>
                <View style={{ flexDirection: 'row', gap: 8, flexWrap: 'wrap' }}>
                  <Pressable
                    onPress={handleSummarise}
                    disabled={summarising}
                    accessible
                    accessibilityRole="button"
                    accessibilityLabel={summarising ? 'Summarising post, please wait' : 'Summarise original post'}
                    accessibilityHint="Uses on-device AI to create a brief summary of the original post"
                    style={{ flexDirection: 'row', alignItems: 'center', gap: 8,
                      backgroundColor: colors.accent, borderRadius: 10,
                      paddingHorizontal: 16, paddingVertical: 12 }}
                  >
                    {summarising
                      ? <ActivityIndicator size="small" color={colors.accentText} accessibilityElementsHidden />
                      : <Ionicons name="sparkles" size={16} color={colors.accentText} accessibilityElementsHidden />
                    }
                    <Text style={{ fontSize: 14, fontWeight: '700', color: colors.accentText }}>
                      {summarising ? 'Summarising…' : 'Summarise Post'}
                    </Text>
                  </Pressable>
                  {topic.replyCount > 0 && (
                    <Pressable
                      onPress={handleSummariseDiscussion}
                      disabled={summarisingDiscussion}
                      accessible
                      accessibilityRole="button"
                      accessibilityLabel={summarisingDiscussion ? 'Summarising discussion, please wait' : 'Summarise discussion'}
                      accessibilityHint="Uses on-device AI to summarise all comments in this topic"
                      style={{ flexDirection: 'row', alignItems: 'center', gap: 8,
                        backgroundColor: colors.pill, borderRadius: 10,
                        paddingHorizontal: 16, paddingVertical: 12 }}
                    >
                      {summarisingDiscussion
                        ? <ActivityIndicator size="small" color={colors.pillText} accessibilityElementsHidden />
                        : <Ionicons name="chatbubbles-outline" size={16} color={colors.pillText} accessibilityElementsHidden />
                      }
                      <Text style={{ fontSize: 14, fontWeight: '700', color: colors.pillText }}>
                        {summarisingDiscussion ? 'Summarising…' : 'Summarise Discussion'}
                      </Text>
                    </Pressable>
                  )}
                </View>
              </View>
            )}

            {/* ── Replies section ────────────────────────────────────────── */}
            <View onLayout={(e) => { repliesY.current = e.nativeEvent.layout.y; }}>
              <SectionDivider
                label={
                  `Community Discussion - ${topic.replyCount} ${topic.replyCount === 1 ? 'comment' : 'comments'}` +
                  (newReplyCount > 0 ? ` - ${newReplyCount} new` : '')
                }
                accessibilityActions={[{ name: 'threadSummary', label: 'Thread overview' }]}
                onAccessibilityAction={({ nativeEvent }) => {
                  if (nativeEvent.actionName === 'threadSummary') {
                    const mostRecent = topic.replies.length > 0
                      ? [...topic.replies].sort((a, b) =>
                          new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
                        )[0]
                      : null;
                    showToast(
                      `Thread has ${topic.replyCount} comment${topic.replyCount === 1 ? '' : 's'}.` +
                      (newReplyCount > 0 ? ` ${newReplyCount} new since your last visit.` : '') +
                      (mostRecent ? ` Most recent comment by ${mostRecent.authorName}, ${relativeTime(mostRecent.createdAt)}.` : '') +
                      ` Original post by ${topic.authorName || 'Unknown'}.`,
                      'success',
                    );
                  }
                }}
              />

              {/* Jump to first new comment */}
              {sortedReplies.some(r => r.isNew) && (
                <Pressable
                  onPress={() => {
                    const idx = sortedReplies.findIndex(r => r.isNew);
                    if (idx >= 0) jumpToComment(idx, sortedReplies);
                  }}
                  accessible
                  accessibilityRole="button"
                  accessibilityLabel={`Jump to first new comment. ${sortedReplies.filter(r => r.isNew).length} new since your last visit.`}
                  style={[styles.card, {
                    flexDirection: 'row', alignItems: 'center', gap: 10,
                    marginBottom: 12, paddingVertical: 12,
                  }]}
                >
                  <Ionicons name="flag-outline" size={18} color={colors.accent}
                    accessibilityElementsHidden />
                  <View style={{ flex: 1 }}>
                    <Text style={{ fontSize: 14, fontWeight: '700', color: colors.accent }}>
                      Jump to First New Comment
                    </Text>
                    <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2 }}>
                      {sortedReplies.filter(r => r.isNew).length} new since your last visit
                    </Text>
                  </View>
                  <Ionicons name="arrow-down-outline" size={16} color={colors.accent}
                    accessibilityElementsHidden />
                </Pressable>
              )}

              {/* Empty state when comments failed to load */}
              {topic.replyCount > 0 && topic.replies.length === 0 && (
                <View
                  style={[styles.card, { alignItems: 'center', paddingVertical: 20, marginBottom: 8 }]}
                  accessible
                  accessibilityLabel="Comments could not be loaded. Pull to refresh."
                >
                  <Ionicons name="chatbubble-outline" size={24} color={colors.textSecondary}
                    accessibilityElementsHidden style={{ marginBottom: 8 }} />
                  <Text style={{ fontSize: 14, color: colors.textSecondary, textAlign: 'center' }}>
                    Comments could not be loaded. Pull to refresh.
                  </Text>
                </View>
              )}

              {/* Loaded replies — rendered in sortedReplies order */}
              {sortedReplies.map((reply, i) => {
                const isFirstAfterLoad = preLoadCount.current > 0 && i === preLoadCount.current;
                return (
                  <View
                    key={reply.id}
                    ref={(el) => {
                      replyRefs.current[reply.id] = el;
                      if (isFirstAfterLoad) firstNewAfterLoadRef.current = el;
                    }}
                    onLayout={(e) => { replyOffsets.current[reply.id] = e.nativeEvent.layout.y; }}
                  >
                    <ReplyCard
                      reply={reply}
                      index={i}
                      total={sortedReplies.length}
                      colors={colors}
                      styles={styles}
                      screenReaderEnabled={screenReaderEnabled}
                      showToast={showToast}
                      topicAuthorId={topic.authorId}
                      topicTitle={topic.title}
                      textSize={textSize}
                      onReplyTo={() => handleReplyToComment(reply)}
                      categoryAccent={catColor}
                      reduceMotion={reduceMotion}
                      currentUserUuid={auth.user?.uuid}
                      onEdit={(r) => setEditingReply(r)}
                      onDelete={(r) => {
                        confirmDestructiveAction(showAlert, {
                          title: 'Delete Comment?',
                          message: 'This cannot be undone.',
                          confirmLabel: 'Delete',
                          onConfirm: async () => {
                            if (!auth.user?.csrfToken) return;
                            const res = await api.content.deleteComment('comment_forum', r.id, auth.user.csrfToken);
                            if (res.ok) {
                              setTopic(t => t ? { ...t, replies: t.replies.filter(x => x.id !== r.id) } : t);
                              showToast('Comment deleted.', 'success');
                            } else {
                              showToast('Could not delete comment.', 'error');
                            }
                          },
                        });
                      }}
                    />
                  </View>
                );
              })}

              {/* Load more replies */}
              {topic.replies.length > 0 && topic.replies.length < topic.replyCount && (
                <Pressable
                  onPress={handleLoadMoreReplies}
                  disabled={loadingMoreReplies}
                  accessible
                  accessibilityRole="button"
                  accessibilityLabel={
                    loadingMoreReplies
                      ? 'Loading more comments'
                      : `Load ${topic.replyCount - topic.replies.length} more comment${topic.replyCount - topic.replies.length === 1 ? '' : 's'}`
                  }
                  accessibilityState={{ disabled: loadingMoreReplies }}
                  style={[styles.card, {
                    alignItems: 'center', paddingVertical: 14, marginBottom: 8,
                    flexDirection: 'row', justifyContent: 'center', gap: 8,
                  }]}
                >
                  {loadingMoreReplies
                    ? <ActivityIndicator size="small" color={colors.accent} />
                    : <>
                        <Ionicons name="ellipsis-horizontal-outline" size={18} color={colors.accent}
                          accessibilityElementsHidden />
                        <Text style={{ fontSize: 14, fontWeight: '700', color: colors.accent }}>
                          Load {topic.replyCount - topic.replies.length} More Comment{topic.replyCount - topic.replies.length === 1 ? '' : 's'}
                        </Text>
                      </>
                  }
                </Pressable>
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
            </Animated.View>
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
            label={isSaved ? 'Saved\nTopic' : 'Save this\nTopic'}
            active={isSaved}
            onPress={handleSave}
          />
          <ToolbarButton
            icon="share-outline"
            label="Share this\nTopic"
            a11yLabel="Share this Topic"
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

      {/* ── Edit comment modal ────────────────────────────────────────────── */}
      {editingReply && auth.user?.csrfToken && (
        <EditContentModal
          visible={!!editingReply}
          onClose={() => setEditingReply(null)}
          onSaved={(newBody) => {
            setTopic(t => t ? {
              ...t,
              replies: t.replies.map(r => r.id === editingReply.id ? { ...r, body: newBody } : r),
            } : t);
            showToast('Comment updated.', 'success');
          }}
          commentId={editingReply.id}
          commentType="comment_forum"
          csrfToken={auth.user.csrfToken}
          initialBody={editingReply.body}
          label="Comment"
        />
      )}

      {/* ── Edit topic modal (own topics only) ───────────────────────────── */}
      {editingTopic && topic && auth.user?.csrfToken && (
        <EditContentModal
          visible={editingTopic}
          onClose={() => setEditingTopic(false)}
          onSaved={(newBody, newTitle) => {
            setTopic(t => t ? { ...t, body: newBody, title: newTitle ?? t.title } : t);
            showToast('Topic updated.', 'success');
          }}
          nodeId={topic.id}
          initialTitle={topic.title}
          initialBody={topic.body}
          csrfToken={auth.user.csrfToken}
          label="Topic"
        />
      )}

      {/* ── Author profile modal ──────────────────────────────────────────── */}
      {topic?.authorId && (
        <AuthorProfileModal
          visible={authorProfile}
          onClose={() => setAuthorProfile(false)}
          authorId={topic.authorId}
          authorName={topic.authorName}
          isSignedIn={auth.isSignedIn}
          showToast={showToast}
        />
      )}
    </Screen>
  );
}
