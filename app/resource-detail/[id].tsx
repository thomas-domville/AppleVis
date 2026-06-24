import { useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActionSheetIOS, ActivityIndicator, Animated, Clipboard,
  findNodeHandle, Linking, Platform,
  Pressable, ScrollView, Share, StyleSheet, Text, View,
} from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { Screen } from '../../src/components/Screen';
import { AuthorProfileModal } from '../../src/components/AuthorProfileModal';
import { EditContentModal } from '../../src/components/EditContentModal';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useAuth } from '../../src/contexts/AuthContext';
import { useToast } from '../../src/contexts/ToastContext';
import { useAlert } from '../../src/contexts/AccessibleAlertContext';
import { usePreferences } from '../../src/contexts/PreferencesContext';
import { ALERTS } from '../../src/data/alertMessages';
import { useSavedItems } from '../../src/hooks/useSavedItems';
import { useHandoff } from '../../src/hooks/useHandoff';
import { isAppleIntelligenceAvailable, readAloud, summariseText } from '../../src/services/intelligenceService';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { api } from '../../src/services/api';
import { cachedApi } from '../../src/services/cachedApi';
import { persistence } from '../../src/services/persistence';
import { relativeTime } from '../../src/utils/relativeTime';
import {
  bodySegments, readingTime, extractToc, extractLinks, stripHtml,
} from '../../src/utils/articleHelpers';
import { displayCommentSubject, subjectLabel } from '../../src/utils/commentSubject';
import type { ResourceDetail, ForumReply } from '../../src/types/content';

// ─── Toolbar button ───────────────────────────────────────────────────────────

function ToolbarButton({
  icon, activeIcon, label, a11yLabel, onPress, active, accent,
}: {
  icon: string; activeIcon?: string; label: string; a11yLabel?: string; onPress: () => void;
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
  label, accessibilityActions, onAccessibilityAction,
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

// ─── Kind-colour utilities ────────────────────────────────────────────────────

function kindColor(kind: string | undefined): string {
  switch (kind) {
    case 'guide':     return '#10b981';
    case 'tutorial':  return '#8b5cf6';
    case 'article':   return '#6366f1';
    case 'event':     return '#f59e0b';
    case 'developer': return '#0ea5e9';
    default:          return '#6366f1';
  }
}

function hashAuthorColor(name: string): string {
  const PALETTE = ['#3b82f6', '#8b5cf6', '#10b981', '#f59e0b', '#ef4444', '#ec4899', '#06b6d4', '#84cc16'];
  let h = 0;
  for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) & 0xffff;
  return PALETTE[h % PALETTE.length];
}

const TOOLBAR_H = 58;

const KIND_ICON: Record<string, string> = {
  guide:     'book-outline',
  tutorial:  'play-circle-outline',
  article:   'newspaper-outline',
  event:     'calendar-outline',
  developer: 'code-slash-outline',
};

// ─── Main screen ──────────────────────────────────────────────────────────────

export default function ResourceDetailScreen() {
  const { id, title: paramTitle, url: paramUrl } = useLocalSearchParams<{
    id: string; title?: string; url?: string;
  }>();
  const router             = useRouter();
  const { colors, styles } = useTheme();
  const { aiSummariesEnabled } = usePreferences();
  const auth               = useAuth();
  const { showToast }      = useToast();
  const { showAlert }      = useAlert();
  const saved              = useSavedItems('resource');
  const aiAvailable        = aiSummariesEnabled && isAppleIntelligenceAvailable();
  const { reduceMotion, reduceTransparency, screenReaderEnabled } = useAccessibilityPreferences();

  const [resource,              setResource]              = useState<ResourceDetail | null>(null);
  const [loading,               setLoading]               = useState(true);
  const [error,                 setError]                 = useState<string | null>(null);
  const [fromCache,             setFromCache]             = useState(false);
  const [textSize,              setTextSize]              = useState(16);
  const [bodyExpanded,          setBodyExpanded]          = useState(false);
  const [authorProfile,         setAuthorProfile]         = useState(false);
  const [tocExpanded,           setTocExpanded]           = useState(false);
  const [summarising,           setSummarising]           = useState(false);
  const [summarisingDiscussion, setSummarisingDiscussion] = useState(false);
  const [comments,              setComments]              = useState<ForumReply[]>([]);
  const [commentsLoading,       setCommentsLoading]       = useState(false);
  const [lastSeenAt,            setLastSeenAt]            = useState<string | null>(null);
  const [collapsedComments,     setCollapsedComments]     = useState<Record<string, boolean>>({});
  const [editingComment,        setEditingComment]        = useState<ForumReply | null>(null);

  const scrollRef          = useRef<ScrollView>(null);
  const heroRef            = useRef<Text>(null);
  const heroAnim           = useRef(new Animated.Value(0)).current;
  const contentAnim        = useRef(new Animated.Value(0)).current;
  const progressAnim       = useRef(new Animated.Value(0)).current;
  const newBadgeAnims      = useRef<Record<string, Animated.Value>>({}).current;
  const hasInitialFocusRef = useRef(false);
  const commentsY          = useRef<number>(0);
  const firstNewCommentRef = useRef<View | null>(null);
  const commentOffsets     = useRef<Record<string, number>>({});

  useHandoff(resource ? {
    activityType: 'com.applevis.app.viewResource',
    title: resource.title,
    webpageURL: resource.url,
  } : null);

  function loadResource() {
    if (!id) return;
    setLoading(true);
    setError(null);
    Promise.all([
      cachedApi.resources.detail(id),
      api.resources.comments(id),
      persistence.getItemVisit(id),
    ]).then(([detailRes, commentsRes, visit]) => {
      setLastSeenAt(visit?.seenAt ?? null);
      setLoading(false);
      if (detailRes.ok) { setResource(detailRes.data); setFromCache(detailRes.fromCache); }
      else setError(detailRes.error);
      if (commentsRes.ok) {
        setComments(commentsRes.data);
        persistence.stampItemVisit(id, commentsRes.data.length);
      }
    }).catch((err: unknown) => {
      setLoading(false);
      setError(err instanceof Error ? err.message : 'Unexpected error');
    });
  }

  useEffect(() => { loadResource(); }, [id]);

  useEffect(() => {
    if (!resource) return;
    if (reduceMotion || screenReaderEnabled) {
      heroAnim.setValue(1); contentAnim.setValue(1); return;
    }
    Animated.parallel([
      Animated.timing(heroAnim,    { toValue: 1, duration: 380, useNativeDriver: true }),
      Animated.timing(contentAnim, { toValue: 1, duration: 450, delay: 180, useNativeDriver: true }),
    ]).start();
  }, [resource]);

  useEffect(() => {
    if (!resource || hasInitialFocusRef.current) return;
    hasInitialFocusRef.current = true;
    setTimeout(() => {
      const handle = findNodeHandle(heroRef.current);
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, 200);
  }, [resource]);

  function handleJumpToNewComment(firstNewId: string) {
    const offset = commentOffsets.current[firstNewId] ?? 0;
    const y = Math.max(0, commentsY.current + offset - 20);
    scrollRef.current?.scrollTo({ y, animated: true });
    setTimeout(() => {
      const handle = findNodeHandle(firstNewCommentRef.current);
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, 400);
  }

  function handleAddComment() {
    if (!auth.isSignedIn) { showAlert({ ...ALERTS.auth.signInRequired('add a comment'), onConfirm: () => router.push('/settings-account' as any) }); return; }
    if (!resource || !id) return;
    router.push({
      pathname: '/compose' as any,
      params: { topicId: id, topicTitle: resource.title, mode: 'resourceComment' },
    });
  }

  const isSaved   = saved.isSaved(id ?? '');
  const kindLabel = resource
    ? resource.kind.charAt(0).toUpperCase() + resource.kind.slice(1)
    : 'Resource';
  const kindIconName = resource ? (KIND_ICON[resource.kind] ?? 'document-outline') : 'document-outline';

  function handleSave() {
    if (!resource) return;
    if (isSaved) { saved.unsave(id!); showToast('Removed from saved.', 'success'); }
    else { saved.save({ id: id!, kind: 'resource', title: resource.title, savedAt: new Date().toISOString() }); showToast(`${kindLabel} saved.`, 'success'); }
  }

  function handleShare() {
    if (!resource) return;
    Share.share({ title: resource.title, message: `${resource.title} — ${resource.url}` }).catch(() => {});
  }

  async function handleSummarise() {
    if (!resource) return;
    if (!aiAvailable) {
      showToast('Apple Intelligence is not available on this device or has not been enabled in Settings → Apple Intelligence & Siri.', 'warning');
      return;
    }
    setSummarising(true);
    const result = await summariseText(`${resource.title}\n\n${stripHtml(resource.body)}`);
    setSummarising(false);
    if (result) showToast(result, 'success');
    else showToast('Summarisation requires Apple Intelligence Foundation Models (iOS 18.1+).', 'warning');
  }

  async function handleSummariseDiscussion() {
    if (!resource) return;
    setSummarisingDiscussion(true);
    const discussionText = comments
      .map((c, i) => `Comment ${i + 1} by ${c.authorName}: ${stripHtml(c.body)}`)
      .join('\n\n');
    const result = await summariseText(`${kindLabel} discussion on: ${resource.title}\n\n${discussionText}`);
    setSummarisingDiscussion(false);
    if (result) showToast(result, 'success');
    else showToast('Summarisation requires Apple Intelligence Foundation Models (iOS 18.1+).', 'warning');
  }

  const openInBrowser = () => {
    const url = resource?.url ?? paramUrl;
    if (url) Linking.openURL(url).catch(() => showToast('Could not open Safari.', 'error'));
  };

  function handleScroll(e: { nativeEvent: { contentOffset: { y: number }; contentSize: { height: number }; layoutMeasurement: { height: number } } }) {
    const { contentOffset, contentSize, layoutMeasurement } = e.nativeEvent;
    const total = contentSize.height - layoutMeasurement.height;
    if (total <= 0) return;
    progressAnim.setValue(Math.min(1, Math.max(0, contentOffset.y / total)));
  }

  const displayTitle    = resource?.title ?? paramTitle ?? 'Resource';
  const typeAcc         = kindColor(resource?.kind);
  const firstNewComment = lastSeenAt ? comments.find(c => c.createdAt > lastSeenAt) ?? null : null;
  const newCommentCount = lastSeenAt ? comments.filter(c => c.createdAt > lastSeenAt).length : 0;
  const mostRecentComment = comments.length > 0 ? comments[comments.length - 1] : null;

  const segs           = resource ? bodySegments(resource.body) : [];
  const toc            = resource ? extractToc(resource.body) : [];
  const links          = resource ? extractLinks(resource.body) : [];
  const needsCollapse  = segs.length > 5;
  const visibleSegs    = needsCollapse && !bodyExpanded ? segs.slice(0, 4) : segs;
  const hiddenSegCount = segs.length - visibleSegs.length;
  const readingTimeStr = resource ? readingTime(resource.body) : '';

  return (
    <Screen title={displayTitle} showSettings={false} showSearch={false} titleAccessible={false}>
      {/* Reading progress bar */}
      {resource && (
        <View
          style={{ height: 5, backgroundColor: colors.border }}
          accessibilityElementsHidden
          importantForAccessibility="no-hide-descendants"
        >
          <Animated.View
            style={{
              height: 5, backgroundColor: colors.accent,
              width: progressAnim.interpolate({ inputRange: [0, 1], outputRange: ['0%', '100%'], extrapolate: 'clamp' }),
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

          {/* Loading */}
          {loading && (
            <View
              accessible
              accessibilityLiveRegion="polite"
              accessibilityLabel={`Loading ${kindLabel.toLowerCase()}, please wait`}
              style={{ alignItems: 'center', paddingVertical: 48 }}
            >
              <ActivityIndicator size="large" color={colors.accent} />
              <Text style={[styles.cardMeta, { marginTop: 12, textAlign: 'center' }]}>Loading…</Text>
            </View>
          )}

          {/* Error */}
          {!loading && error && (
            <View style={[styles.card, { borderColor: '#FCA5A5', borderWidth: 1 }]}>
              <Text style={[styles.cardTitle, { color: '#B91C1C' }]}>Could not load {kindLabel.toLowerCase()}</Text>
              <Text style={styles.cardMeta}>{error}</Text>
              <Pressable onPress={loadResource} accessible accessibilityRole="button" accessibilityLabel="Retry" style={{ marginTop: 12 }}>
                <Text style={{ color: colors.accent, fontWeight: '700' }}>Retry</Text>
              </Pressable>
              <Pressable onPress={openInBrowser} accessible accessibilityRole="button" accessibilityLabel="Open in Safari instead" style={{ marginTop: 8 }}>
                <Text style={{ color: colors.accent, fontWeight: '700' }}>Open in Safari</Text>
              </Pressable>
            </View>
          )}

          {resource && (
            <>
              {/* ── Hero card with kind-colour accent ── */}
              <Animated.View style={{
                opacity: heroAnim,
                transform: [{ translateY: heroAnim.interpolate({ inputRange: [0, 1], outputRange: [14, 0] }) }],
              }}>
                <View style={[styles.card, {
                  marginBottom: 12, overflow: 'hidden', padding: 0,
                  borderLeftWidth: 4, borderLeftColor: typeAcc,
                }]}>
                  {!reduceTransparency && (
                    <View
                      style={{ ...StyleSheet.absoluteFillObject, backgroundColor: typeAcc, opacity: 0.06 }}
                      accessibilityElementsHidden importantForAccessibility="no-hide-descendants"
                    />
                  )}
                  <View style={{ padding: 16 }}>
                    {/* Title — VoiceOver auto-focuses here on load */}
                    <Text
                      ref={heroRef}
                      accessible
                      accessibilityRole="header"
                      accessibilityLabel={displayTitle}
                      style={{ fontSize: 20, fontWeight: '800', color: colors.text, lineHeight: 27, marginBottom: 12 }}
                    >
                      {displayTitle}
                    </Text>

                    {/* Author / submitter */}
                    <Pressable
                      onPress={() => resource.authorId ? setAuthorProfile(true) : undefined}
                      accessible
                      accessibilityRole="button"
                      accessibilityLabel={
                        resource.authorName
                          ? `Submitted by ${resource.authorName}${resource.authorId ? '. Double tap to view profile.' : '.'}`
                          : `${kindLabel}.`
                      }
                      accessibilityHint={[
                        resource.createdAt ? `Posted ${relativeTime(resource.createdAt)}` : null,
                        mostRecentComment ? `Last comment ${relativeTime(mostRecentComment.createdAt)}` : null,
                        resource.commentCount > 0 ? `${resource.commentCount} ${resource.commentCount === 1 ? 'comment' : 'comments'}` : null,
                        readingTimeStr,
                      ].filter(Boolean).join('. ')}
                      style={({ pressed }) => ({
                        flexDirection: 'row', alignItems: 'center', gap: 10,
                        marginBottom: 12, opacity: pressed ? 0.65 : 1,
                      })}
                    >
                      <View style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: typeAcc,
                        alignItems: 'center', justifyContent: 'center' }}>
                        <Text style={{ fontSize: 20, fontWeight: '800', color: '#ffffff' }} accessibilityElementsHidden>
                          {(resource.authorName || kindLabel).charAt(0).toUpperCase()}
                        </Text>
                      </View>
                      <View style={{ flex: 1 }}>
                        <Text style={{ fontSize: 15, fontWeight: '700', color: colors.text }}>
                          Submitted by {resource.authorName || 'AppleVis'}
                        </Text>
                        <Text style={{ fontSize: 12, color: colors.textSecondary }}>
                          {resource.createdAt ? `Posted ${relativeTime(resource.createdAt)}` : `Updated ${relativeTime(resource.updatedAt)}`}
                          {mostRecentComment ? ` · Last comment ${relativeTime(mostRecentComment.createdAt)}` : ''}
                        </Text>
                      </View>
                      {resource.authorId && (
                        <Ionicons name="chevron-forward" size={16} color={colors.textSecondary} accessibilityElementsHidden />
                      )}
                    </Pressable>

                    {/* Kind breadcrumb */}
                    <View
                      accessible
                      accessibilityLabel={kindLabel}
                      style={{ flexDirection: 'row', alignItems: 'center', gap: 4, alignSelf: 'flex-start' }}
                    >
                      <Ionicons name={kindIconName as any} size={13} color={typeAcc} accessibilityElementsHidden />
                      <Text style={{ fontSize: 13, fontWeight: '600', color: typeAcc }} accessibilityElementsHidden>
                        {kindLabel}
                      </Text>
                    </View>
                  </View>
                </View>
              </Animated.View>

              {/* ── Animated content area ── */}
              <Animated.View style={{
                opacity: contentAnim,
                transform: [{ translateY: contentAnim.interpolate({ inputRange: [0, 1], outputRange: [10, 0] }) }],
              }}>

              {/* Stats row — visual only; stats are spoken via the author hint above */}
              <View style={{ flexDirection: 'row', gap: 8, flexWrap: 'wrap', marginBottom: 12 }}
                accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                  backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 6 }}>
                  <Ionicons name="book-outline" size={14} color={colors.textSecondary} />
                  <Text style={{ fontSize: 13, fontWeight: '600', color: colors.textSecondary }}>{readingTimeStr}</Text>
                </View>
                {resource.createdAt && (
                  <View style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                    backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 6 }}>
                    <Ionicons name="calendar-outline" size={14} color={colors.textSecondary} />
                    <Text style={{ fontSize: 13, fontWeight: '600', color: colors.textSecondary }}>
                      {'Posted ' + relativeTime(resource.createdAt)}
                    </Text>
                  </View>
                )}
                {resource.commentCount > 0 && (
                  <View style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                    backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 6 }}>
                    <Ionicons name="chatbubble-outline" size={14} color={colors.textSecondary} />
                    <Text style={{ fontSize: 13, fontWeight: '600', color: colors.textSecondary }}>
                      {resource.commentCount} {resource.commentCount === 1 ? 'comment' : 'comments'}
                    </Text>
                  </View>
                )}
                {mostRecentComment ? (
                  <View style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                    backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 6 }}>
                    <Ionicons name="time-outline" size={14} color={colors.textSecondary} />
                    <Text style={{ fontSize: 13, fontWeight: '600', color: colors.textSecondary }}>
                      {'Last comment ' + relativeTime(mostRecentComment.createdAt)}
                    </Text>
                  </View>
                ) : (
                  <View style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                    backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 6 }}>
                    <Ionicons name="refresh-outline" size={14} color={colors.textSecondary} />
                    <Text style={{ fontSize: 13, fontWeight: '600', color: colors.textSecondary }}>
                      {'Updated ' + relativeTime(resource.updatedAt)}
                    </Text>
                  </View>
                )}
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
                    Viewing offline content · some details may be out of date
                  </Text>
                  <Pressable onPress={loadResource} accessible accessibilityRole="button"
                    accessibilityLabel="Refresh"
                    style={{ paddingHorizontal: 8, paddingVertical: 4 }}>
                    <Text style={{ fontSize: 13, fontWeight: '700', color: colors.accent }}>Refresh</Text>
                  </Pressable>
                </View>
              )}

              {/* Summary */}
              {!!resource.summary && !!stripHtml(resource.summary) && (
                <View
                  style={[styles.card, { marginBottom: 10 }]}
                  accessible
                  accessibilityLabel={`Summary: ${stripHtml(resource.summary)}`}
                >
                  <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary,
                    textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 6 }}
                    accessibilityElementsHidden>
                    Summary
                  </Text>
                  <Text style={{ fontSize: 15, lineHeight: 23, color: colors.textSecondary }}
                    accessibilityElementsHidden>
                    {stripHtml(resource.summary)}
                  </Text>
                </View>
              )}

              {/* Table of contents — shown when 3+ headings found in the body */}
              {toc.length >= 3 && (
                <View style={[styles.card, { marginBottom: 12 }]}>
                  <Pressable
                    onPress={() => {
                      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                      setTocExpanded(v => !v);
                    }}
                    accessible
                    accessibilityRole="button"
                    accessibilityLabel={tocExpanded ? 'Collapse contents' : `Contents — ${toc.length} sections. Double tap to expand.`}
                    style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}
                  >
                    <Ionicons name="list-outline" size={16} color={colors.accent} accessibilityElementsHidden />
                    <Text style={{ flex: 1, fontSize: 13, fontWeight: '700', color: colors.textSecondary,
                      textTransform: 'uppercase', letterSpacing: 0.6 }} accessibilityElementsHidden>
                      Contents
                    </Text>
                    <Ionicons
                      name={tocExpanded ? 'chevron-up' : 'chevron-down'}
                      size={16} color={colors.textSecondary}
                      accessibilityElementsHidden
                    />
                  </Pressable>
                  {tocExpanded && (
                    <View style={{ marginTop: 12, gap: 2 }}>
                      {toc.map((entry) => (
                        <View
                          key={entry.id}
                          accessible
                          accessibilityRole="text"
                          accessibilityLabel={entry.text}
                          style={{
                            paddingVertical: 5,
                            paddingLeft: entry.level === 3 ? 16 : 0,
                            borderLeftWidth: entry.level === 2 ? 2 : 0,
                            borderLeftColor: colors.accent,
                            paddingHorizontal: entry.level === 2 ? 10 : 0,
                          }}
                        >
                          <Text
                            style={{
                              fontSize: entry.level === 2 ? 14 : 13,
                              color: entry.level === 2 ? colors.text : colors.textSecondary,
                              fontWeight: entry.level === 2 ? '600' : '400',
                            }}
                            accessibilityElementsHidden
                          >
                            {entry.text}
                          </Text>
                        </View>
                      ))}
                    </View>
                  )}
                </View>
              )}

              {/* Body */}
              {segs.length > 0 ? (
                <View style={[styles.card, { marginBottom: 12 }]}>

                  {/* Heading row — landmark + A−/A+ */}
                  <View style={{ flexDirection: 'row', alignItems: 'center', marginBottom: 12 }}>
                    <Text
                      accessible
                      accessibilityRole="header"
                      accessibilityLabel={`Full ${kindLabel.toLowerCase()} by ${resource.authorName || 'AppleVis'}`}
                      accessibilityActions={[
                        { name: 'save',         label: isSaved ? 'Remove from Saved' : `Save ${kindLabel}` },
                        { name: 'share',        label: `Share ${kindLabel}`                                  },
                        { name: 'summarise',    label: 'Summarise with Apple Intelligence'                   },
                        { name: 'increaseText', label: 'Increase text size'                                  },
                        { name: 'decreaseText', label: 'Decrease text size'                                  },
                      ]}
                      onAccessibilityAction={({ nativeEvent }) => {
                        switch (nativeEvent.actionName) {
                          case 'save':         handleSave();                                break;
                          case 'share':        handleShare();                               break;
                          case 'summarise':    handleSummarise();                           break;
                          case 'increaseText': setTextSize(s => Math.min(22, s + 1));       break;
                          case 'decreaseText': setTextSize(s => Math.max(13, s - 1));       break;
                        }
                      }}
                      style={{ flex: 1, fontSize: 11, fontWeight: '700', color: colors.textSecondary,
                        textTransform: 'uppercase', letterSpacing: 0.6 }}
                    >
                      {`Full ${kindLabel} by ${resource.authorName || 'AppleVis'}`}
                    </Text>

                    {/* A−/A+ size controls — visual only */}
                    <View
                      style={{ flexDirection: 'row', gap: 2 }}
                      accessibilityElementsHidden
                      importantForAccessibility="no-hide-descendants"
                    >
                      <Pressable onPress={() => setTextSize(s => Math.max(13, s - 1))}
                        style={({ pressed }) => ({ padding: 6, opacity: pressed ? 0.55 : 1 })}>
                        <Text style={{ fontSize: 14, fontWeight: '700', color: colors.accent }}>A−</Text>
                      </Pressable>
                      <Pressable onPress={() => setTextSize(s => Math.min(22, s + 1))}
                        style={({ pressed }) => ({ padding: 6, opacity: pressed ? 0.55 : 1 })}>
                        <Text style={{ fontSize: 18, fontWeight: '700', color: colors.accent }}>A+</Text>
                      </Pressable>
                    </View>
                  </View>

                  {/* Body segments */}
                  {visibleSegs.map((seg, i) => {
                    if (seg.kind === 'code') return (
                      <View key={i} accessible accessibilityLabel={`Code: ${seg.text}`}
                        style={{ backgroundColor: '#1a1a2e', borderRadius: 8, padding: 12, marginBottom: 10 }}>
                        <View style={{ flexDirection: 'row', justifyContent: 'flex-end', marginBottom: 6 }}
                          accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
                          <View style={{ backgroundColor: colors.accent, borderRadius: 4, paddingHorizontal: 6, paddingVertical: 1 }}>
                            <Text style={{ color: '#fff', fontSize: 9, fontWeight: '700', letterSpacing: 0.4 }}>CODE</Text>
                          </View>
                        </View>
                        <Text style={{ fontSize: textSize - 1, lineHeight: (textSize - 1) * 1.55,
                          color: '#e5e7eb', fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace' }}
                          accessibilityElementsHidden>
                          {seg.text}
                        </Text>
                      </View>
                    );
                    if (seg.kind === 'quote') return (
                      <View key={i} accessible accessibilityLabel={`Quoted: ${seg.text}`}
                        style={{ borderLeftWidth: 3, borderLeftColor: '#f59e0b',
                          backgroundColor: 'rgba(245, 158, 11, 0.08)',
                          paddingLeft: 12, paddingVertical: 8, paddingRight: 8,
                          marginBottom: 10, borderRadius: 6 }}>
                        <Text style={{ fontSize: textSize - 1, lineHeight: (textSize - 1) * 1.55,
                          color: colors.textSecondary, fontStyle: 'italic' }}
                          accessibilityElementsHidden>
                          {seg.text}
                        </Text>
                      </View>
                    );
                    return (
                      <Text key={i} accessible
                        style={{ fontSize: textSize, lineHeight: textSize * 1.7, color: colors.text, marginBottom: 8 }}>
                        {seg.text}
                      </Text>
                    );
                  })}

                  {/* Expand / collapse */}
                  {needsCollapse && hiddenSegCount > 0 && (
                    <Pressable
                      onPress={() => { Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light); setBodyExpanded(v => !v); }}
                      accessible
                      accessibilityRole="button"
                      accessibilityLabel={
                        bodyExpanded
                          ? 'Show less'
                          : `Show full ${kindLabel.toLowerCase()} — ${hiddenSegCount} more section${hiddenSegCount === 1 ? '' : 's'}`
                      }
                      style={({ pressed }) => ({
                        flexDirection: 'row', alignItems: 'center', gap: 6,
                        marginTop: 4, paddingVertical: 8, opacity: pressed ? 0.55 : 1,
                      })}
                    >
                      <Ionicons
                        name={bodyExpanded ? 'chevron-up-outline' : 'chevron-down-outline'}
                        size={16} color={colors.accent} accessibilityElementsHidden
                      />
                      <Text style={{ fontSize: 14, fontWeight: '600', color: colors.accent }}>
                        {bodyExpanded ? 'Show less' : `Show full ${kindLabel.toLowerCase()} (${hiddenSegCount} more)`}
                      </Text>
                    </Pressable>
                  )}
                </View>
              ) : (
                <View style={[styles.card, { alignItems: 'center', paddingVertical: 24, marginBottom: 12 }]}>
                  <Text style={styles.cardMeta}>Full article content not available yet.</Text>
                  <Pressable onPress={openInBrowser} accessible accessibilityRole="button"
                    accessibilityLabel={`Read full ${kindLabel.toLowerCase()} on applevis.com`}
                    style={{ marginTop: 12 }}>
                    <Text style={{ color: colors.accent, fontWeight: '700' }}>Read on applevis.com →</Text>
                  </Pressable>
                </View>
              )}

              {/* Quick nav row */}
              <View style={{ flexDirection: 'row', gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
                {!screenReaderEnabled && segs.length > 0 && (
                  <Pressable
                    onPress={() => readAloud(stripHtml(resource.body))}
                    accessible
                    accessibilityRole="button"
                    accessibilityLabel={`Read ${kindLabel.toLowerCase()} aloud`}
                    style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                      backgroundColor: colors.pill, borderRadius: 10,
                      paddingHorizontal: 14, paddingVertical: 10 }}
                  >
                    <Ionicons name="volume-medium-outline" size={16} color={colors.pillText} accessibilityElementsHidden />
                    <Text style={{ fontSize: 14, fontWeight: '600', color: colors.pillText }}>Read {kindLabel}</Text>
                  </Pressable>
                )}
                {firstNewComment && (
                  <Pressable
                    onPress={() => handleJumpToNewComment(firstNewComment.id)}
                    accessible
                    accessibilityRole="button"
                    accessibilityLabel={`Jump to first new comment. ${newCommentCount} new since your last visit.`}
                    style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                      backgroundColor: colors.pill, borderRadius: 10,
                      paddingHorizontal: 14, paddingVertical: 10 }}
                  >
                    <Ionicons name="arrow-down-outline" size={16} color={colors.pillText} accessibilityElementsHidden />
                    <Text style={{ fontSize: 14, fontWeight: '600', color: colors.pillText }}>Jump to First New</Text>
                  </Pressable>
                )}
              </View>

              {/* Apple Intelligence — only shown when available */}
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
                      accessibilityLabel={summarising ? 'Summarising, please wait' : `Summarise this ${kindLabel.toLowerCase()}`}
                      accessibilityHint="Uses on-device AI to create a brief summary"
                      style={{ flexDirection: 'row', alignItems: 'center', gap: 8,
                        backgroundColor: colors.accent, borderRadius: 10,
                        paddingHorizontal: 16, paddingVertical: 12 }}
                    >
                      {summarising
                        ? <ActivityIndicator size="small" color={colors.accentText} accessibilityElementsHidden />
                        : <Ionicons name="sparkles" size={16} color={colors.accentText} accessibilityElementsHidden />
                      }
                      <Text style={{ fontSize: 14, fontWeight: '700', color: colors.accentText }}>
                        {summarising ? 'Summarising…' : `Summarise ${kindLabel}`}
                      </Text>
                    </Pressable>
                    {comments.length > 0 && (
                      <Pressable
                        onPress={handleSummariseDiscussion}
                        disabled={summarisingDiscussion}
                        accessible
                        accessibilityRole="button"
                        accessibilityLabel={summarisingDiscussion ? 'Summarising discussion, please wait' : 'Summarise discussion'}
                        accessibilityHint="Uses on-device AI to summarise all comments"
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

              {/* Referenced links — extracted from body HTML */}
              {links.length > 0 && (
                <>
                  <SectionDivider label={`${links.length} Referenced ${links.length === 1 ? 'Link' : 'Links'}`} />
                  <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: 16 }}>
                    {links.map((link, i) => (
                      <Pressable
                        key={i}
                        onPress={() => Linking.openURL(link.href).catch(() => showToast('Could not open link.', 'error'))}
                        accessible
                        accessibilityRole="link"
                        accessibilityLabel={`${link.text}. Opens in Safari.`}
                        style={({ pressed }) => ({
                          flexDirection: 'row', alignItems: 'center', gap: 6,
                          backgroundColor: colors.pill, borderRadius: 10,
                          paddingHorizontal: 12, paddingVertical: 8,
                          opacity: pressed ? 0.65 : 1, maxWidth: '100%',
                        })}
                      >
                        <Ionicons name="open-outline" size={14} color={colors.accent} accessibilityElementsHidden />
                        <Text style={{ fontSize: 13, color: colors.accent, fontWeight: '600', flex: 1 }}
                          numberOfLines={1}>
                          {link.text}
                        </Text>
                      </Pressable>
                    ))}
                  </View>
                </>
              )}

              {/* Comments */}
              <View onLayout={(e) => { commentsY.current = e.nativeEvent.layout.y; }}>
                <SectionDivider
                  label={
                    `Community Discussion - ${comments.length} ${comments.length === 1 ? 'comment' : 'comments'}` +
                    (newCommentCount > 0 ? ` - ${newCommentCount} new` : '')
                  }
                  accessibilityActions={[{ name: 'overview', label: 'Comments overview' }]}
                  onAccessibilityAction={({ nativeEvent }) => {
                    if (nativeEvent.actionName === 'overview') {
                      const parts = [
                        `${comments.length} ${comments.length === 1 ? 'comment' : 'comments'}.`,
                        newCommentCount > 0 ? `${newCommentCount} new since your last visit.` : null,
                        comments.length > 0 ? `Most recent by ${comments[comments.length - 1].authorName}, ${relativeTime(comments[comments.length - 1].createdAt)}.` : null,
                      ].filter(Boolean).join(' ');
                      AccessibilityInfo.announceForAccessibility(parts);
                    }
                  }}
                />
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

              {comments.length === 0 && !commentsLoading && (
                <View style={[styles.card, { alignItems: 'center', paddingVertical: 24, marginBottom: 8 }]}
                  accessible accessibilityLabel="No comments yet. Be the first to add one.">
                  <Ionicons name="chatbubble-outline" size={28} color={colors.textSecondary}
                    accessibilityElementsHidden style={{ marginBottom: 8 }} />
                  <Text style={[styles.cardMeta, { textAlign: 'center' }]}>
                    No comments yet. Be the first to add a new comment.
                  </Text>
                </View>
              )}

              {comments.map((c, idx) => {
                const segsComment    = bodySegments(c.body);
                const plain          = c.body.replace(/<[^>]*>/g, '').trim();
                const quote          = plain.length > 150 ? plain.slice(0, 150).trimEnd() + '…' : plain;
                const commentSubject = displayCommentSubject(c.subject, resource.title);
                const isNewComment   = lastSeenAt != null && c.createdAt > lastSeenAt;
                const isFirstNew     = isNewComment && c.id === firstNewComment?.id;
                const avatarColor    = hashAuthorColor(c.authorName);
                const isCollapsed    = collapsedComments[c.id] ?? false;
                const commentFontSize = Math.max(13, textSize - 1);
                const isOwnComment   = !!auth.user?.uuid && auth.user.uuid === c.authorId;

                if (isNewComment && !newBadgeAnims[c.id]) {
                  newBadgeAnims[c.id] = new Animated.Value(1);
                  if (!reduceMotion) {
                    Animated.sequence([
                      Animated.timing(newBadgeAnims[c.id], { toValue: 1.25, duration: 200, useNativeDriver: true }),
                      Animated.timing(newBadgeAnims[c.id], { toValue: 1,    duration: 200, useNativeDriver: true }),
                      Animated.timing(newBadgeAnims[c.id], { toValue: 1.15, duration: 150, useNativeDriver: true }),
                      Animated.timing(newBadgeAnims[c.id], { toValue: 1,    duration: 150, useNativeDriver: true }),
                    ]).start();
                  }
                }

                function handleReply() {
                  if (!auth.isSignedIn) { showAlert({ ...ALERTS.auth.signInRequired('reply to comments'), onConfirm: () => router.push('/settings-account' as any) }); return; }
                  router.push({
                    pathname: '/compose' as any,
                    params: { topicId: id, mode: 'resourceComment', replyToAuthor: c.authorName, replyToQuote: quote },
                  });
                }
                function showCommentActions() {
                  Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
                  if (Platform.OS === 'ios') {
                    const baseOptions = ['Cancel', 'Reply to this Comment', 'Copy Comment Text', 'Share Comment'];
                    const ownOptions  = isOwnComment ? ['Edit Comment', 'Delete Comment'] : [];
                    const allOptions  = [...baseOptions, ...ownOptions];
                    ActionSheetIOS.showActionSheetWithOptions(
                      {
                        title: `Comment by ${c.authorName}`,
                        options: allOptions,
                        cancelButtonIndex: 0,
                        destructiveButtonIndex: isOwnComment ? allOptions.length - 1 : undefined,
                      },
                      (buttonIdx) => {
                        if (buttonIdx === 1) handleReply();
                        if (buttonIdx === 2) { Clipboard.setString(plain); showToast('Comment text copied.', 'success'); AccessibilityInfo.announceForAccessibility('Comment text copied'); }
                        if (buttonIdx === 3) {
                          Share.share({
                            message: [
                              `${c.authorName} on AppleVis`,
                              commentSubject ? `Subject: ${commentSubject}` : null,
                              plain,
                            ].filter(Boolean).join('\n\n'),
                          }).catch(() => {});
                        }
                        if (isOwnComment && buttonIdx === 4) setEditingComment(c);
                        if (isOwnComment && buttonIdx === 5) {
                          showAlert({
                            title: 'Delete Comment?',
                            message: 'This cannot be undone.',
                            buttons: [
                              { label: 'Delete', style: 'destructive', onPress: async () => {
                                if (!auth.user?.csrfToken) return;
                                const res = await api.content.deleteComment('comment_node_guides', c.id, auth.user.csrfToken);
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
                        }
                      },
                    );
                  }
                }
                return (
                  <View
                    key={c.id}
                    ref={isFirstNew ? (v) => { firstNewCommentRef.current = v; } : undefined}
                    onLayout={(e) => { commentOffsets.current[c.id] = e.nativeEvent.layout.y; }}
                  >
                    <View style={[styles.card, { marginBottom: 8, padding: 0, overflow: 'hidden' },
                      isNewComment && { borderLeftWidth: 4, borderLeftColor: avatarColor }]}>

                      {/* Comment header — role=header enables braille H-key navigation */}
                      <Pressable
                        onPress={() => {
                          Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                          setCollapsedComments(prev => ({ ...prev, [c.id]: !prev[c.id] }));
                        }}
                        onLongPress={showCommentActions}
                        delayLongPress={400}
                        accessible
                        accessibilityRole="header"
                        accessibilityLabel={
                          (isNewComment ? 'New comment. ' : '') +
                          `Comment ${idx + 1} of ${comments.length} by ${c.authorName}, ${relativeTime(c.createdAt)}. ` +
                          subjectLabel(c.subject, resource.title) +
                          'Hold for options.'
                        }
                        accessibilityActions={[
                          { name: 'reply', label: 'Reply to this Comment' },
                          { name: 'copy',  label: 'Copy Comment Text' },
                          { name: 'share', label: 'Share Comment' },
                        ]}
                        onAccessibilityAction={({ nativeEvent }) => {
                          if (nativeEvent.actionName === 'reply') handleReply();
                          if (nativeEvent.actionName === 'copy') { Clipboard.setString(plain); showToast('Comment text copied.', 'success'); AccessibilityInfo.announceForAccessibility('Comment text copied'); }
                          if (nativeEvent.actionName === 'share') {
                            Share.share({
                              message: [
                                `${c.authorName} on AppleVis`,
                                commentSubject ? `Subject: ${commentSubject}` : null,
                                plain,
                              ].filter(Boolean).join('\n\n'),
                            }).catch(() => {});
                          }
                        }}
                        style={({ pressed }) => ({
                          flexDirection: 'row', alignItems: 'center', gap: 8,
                          padding: 14, paddingBottom: isCollapsed ? 14 : 10,
                          opacity: pressed ? 0.75 : 1,
                        })}
                      >
                        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, flex: 1 }}
                          accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
                          <View style={{ width: 34, height: 34, borderRadius: 17, backgroundColor: avatarColor,
                            alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                            <Text style={{ fontSize: 15, fontWeight: '700', color: '#ffffff' }}>
                              {c.authorName.charAt(0).toUpperCase()}
                            </Text>
                          </View>
                          <View style={{ flex: 1 }}>
                            <Text style={{ fontSize: 14, fontWeight: '700', color: colors.text }}>{c.authorName}</Text>
                            {!!commentSubject && (
                              <Text style={{ fontSize: 13, color: colors.text, marginTop: 2 }} numberOfLines={2}>
                                {commentSubject}
                              </Text>
                            )}
                            <Text style={{ fontSize: 12, color: colors.textSecondary }}>{relativeTime(c.createdAt)}</Text>
                          </View>
                          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
                            {isNewComment && newBadgeAnims[c.id] && (
                              <Animated.View style={{
                                backgroundColor: avatarColor, borderRadius: 6,
                                paddingHorizontal: 6, paddingVertical: 2,
                                transform: [{ scale: newBadgeAnims[c.id] }],
                              }}>
                                <Text style={{ color: '#ffffff', fontSize: 12, fontWeight: '700' }}>NEW</Text>
                              </Animated.View>
                            )}
                            <Text style={{ fontSize: 11, color: colors.textSecondary, fontWeight: '500' }}>
                              {idx + 1}/{comments.length}
                            </Text>
                            <Ionicons name={isCollapsed ? 'chevron-down' : 'chevron-up'} size={14} color={colors.textSecondary} />
                          </View>
                        </View>
                      </Pressable>

                      {/* Comment body — each paragraph separately swipeable */}
                      {!isCollapsed && (
                        <View style={{ paddingHorizontal: 14, paddingBottom: 14 }}>
                          {segsComment.map((seg, si) => {
                            if (seg.kind === 'code') return (
                              <View key={si} accessible accessibilityLabel={`Code: ${seg.text}`}
                                style={{ backgroundColor: '#1a1a2e', borderRadius: 8, padding: 10, marginBottom: 8 }}>
                                <View style={{ flexDirection: 'row', justifyContent: 'flex-end', marginBottom: 4 }}
                                  accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
                                  <View style={{ backgroundColor: colors.accent, borderRadius: 4, paddingHorizontal: 6, paddingVertical: 1 }}>
                                    <Text style={{ color: '#fff', fontSize: 9, fontWeight: '700', letterSpacing: 0.4 }}>CODE</Text>
                                  </View>
                                </View>
                                <Text style={{ fontSize: commentFontSize - 1, lineHeight: (commentFontSize - 1) * 1.55,
                                  color: '#e5e7eb', fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace' }}
                                  accessibilityElementsHidden>
                                  {seg.text}
                                </Text>
                              </View>
                            );
                            if (seg.kind === 'quote') return (
                              <View key={si} accessible accessibilityLabel={`Quoted: ${seg.text}`}
                                style={{ borderLeftWidth: 3, borderLeftColor: '#f59e0b', paddingLeft: 12,
                                  paddingVertical: 8, paddingRight: 8, marginBottom: 8,
                                  backgroundColor: 'rgba(245, 158, 11, 0.08)', borderRadius: 6 }}>
                                <Text style={{ fontSize: commentFontSize - 1, lineHeight: (commentFontSize - 1) * 1.55,
                                  color: colors.textSecondary, fontStyle: 'italic' }}
                                  accessibilityElementsHidden>
                                  {seg.text}
                                </Text>
                              </View>
                            );
                            return (
                              <Text key={si} accessible
                                style={{ fontSize: commentFontSize, lineHeight: commentFontSize * 1.65,
                                  color: colors.text, marginBottom: si < segsComment.length - 1 ? 6 : 0 }}>
                                {seg.text}
                              </Text>
                            );
                          })}
                        </View>
                      )}
                    </View>
                  </View>
                );
              })}

              {/* Back to top */}
              <Pressable
                onPress={() => scrollRef.current?.scrollTo({ y: 0, animated: true })}
                accessible
                accessibilityRole="button"
                accessibilityLabel="Back to top"
                accessibilityHint={`Scrolls back to the start of this ${kindLabel.toLowerCase()}`}
                style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center',
                  gap: 6, paddingVertical: 16 }}
              >
                <Ionicons name="arrow-up-outline" size={16} color={colors.textSecondary} accessibilityElementsHidden />
                <Text style={{ fontSize: 14, color: colors.textSecondary, fontWeight: '500' }}>Back to Top</Text>
              </Pressable>

              </Animated.View>{/* end contentAnim */}
            </>
          )}
        </ScrollView>

        {/* Fixed bottom toolbar */}
        {resource && (
          <View
            style={{
              flexDirection: 'row', height: TOOLBAR_H, paddingHorizontal: 4,
              backgroundColor: colors.card,
              borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: colors.border,
              alignItems: 'center',
            }}
            accessibilityRole="toolbar"
            accessibilityLabel={`${kindLabel} actions`}
          >
            <ToolbarButton
              icon="bookmark-outline" activeIcon="bookmark"
              label={isSaved ? 'Saved' : `Save\n${kindLabel}`}
              a11yLabel={isSaved ? `Saved ${kindLabel.toLowerCase()}` : `Save this ${kindLabel.toLowerCase()}`}
              active={isSaved} onPress={handleSave}
            />
            <ToolbarButton icon="share-outline" label="Share" a11yLabel={`Share this ${kindLabel.toLowerCase()}`} onPress={handleShare} />
            <ToolbarButton icon="safari-outline" label={'Open in\nSafari'} onPress={openInBrowser} />
            <ToolbarButton icon="pencil-outline" label={'Add New\nComment'} onPress={handleAddComment} accent />
          </View>
        )}
      </View>

      {/* Author profile modal */}
      {resource?.authorId && (
        <AuthorProfileModal
          visible={authorProfile}
          onClose={() => setAuthorProfile(false)}
          authorId={resource.authorId}
          authorName={resource.authorName ?? ''}
          isSignedIn={auth.isSignedIn}
          showToast={showToast}
        />
      )}

      {editingComment && auth.user?.csrfToken && (
        <EditContentModal
          visible={!!editingComment}
          onClose={() => setEditingComment(null)}
          onSaved={(newBody) => {
            setComments(prev => prev.map(c => c.id === editingComment.id ? { ...c, body: newBody } : c));
            showToast('Comment updated.', 'success');
          }}
          commentId={editingComment.id}
          commentType="comment_node_guides"
          csrfToken={auth.user.csrfToken}
          initialBody={editingComment.body}
          label="Comment"
        />
      )}
    </Screen>
  );
}
