import { useCallback, useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActionSheetIOS, ActivityIndicator, Animated, Clipboard,
  findNodeHandle, Image, Linking, Platform, Pressable,
  ScrollView, Share, StyleSheet, Text, View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useLocalSearchParams, useRouter, useFocusEffect } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { Screen } from '../../src/components/Screen';
import { WriteReviewModal } from '../../src/components/WriteReviewModal';
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
import { useSavedItems } from '../../src/hooks/useSavedItems';
import { useHandoff } from '../../src/hooks/useHandoff';
import {
  readAloud, accessibilityConsensus, summariseText, isAppleIntelligenceAvailable,
} from '../../src/services/intelligenceService';
import { api } from '../../src/services/api';
import { cachedApi } from '../../src/services/cachedApi';
import { persistence } from '../../src/services/persistence';
import { contentCache } from '../../src/services/contentCache';
import { fetchItunesMetadata, fetchDeveloperApps } from '../../src/services/itunesApi';
import { relativeTime } from '../../src/utils/relativeTime';
import { displayCommentSubject, subjectLabel } from '../../src/utils/commentSubject';
import type { AppDetail, AppReview } from '../../src/types/content';
import type { ItunesMetadata, DeveloperApp } from '../../src/services/itunesApi';

// ─── HTML stripper ────────────────────────────────────────────────────────────

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

// Converts ISO language codes to full English names (e.g. "EN" → "English").
function languageNames(codes: string[]): string[] {
  if (codes.length === 0) return [];
  let dn: Intl.DisplayNames | null = null;
  try { dn = new Intl.DisplayNames(['en'], { type: 'language' }); } catch { /* */ }
  return codes.map((c) => {
    try { return dn?.of(c) ?? c; }
    catch { return c; }
  });
}

// ─── Toolbar button ──────────────────────────────────────────────────────────

function ToolbarButton({
  icon, activeIcon, label, a11yLabel, onPress, active, accent, disabled,
}: {
  icon: string; activeIcon?: string; label: string; a11yLabel?: string; onPress: () => void;
  active?: boolean; accent?: boolean; disabled?: boolean;
}) {
  const { colors } = useTheme();
  const resolvedIcon = (active && activeIcon) ? activeIcon : icon;
  const color = disabled ? colors.textSecondary
    : accent  ? colors.accent
    : active  ? colors.accent
    : colors.textSecondary;
  return (
    <Pressable
      onPress={disabled ? undefined : onPress}
      accessible
      accessibilityRole="button"
      accessibilityLabel={a11yLabel ?? label.replace(/\n/g, ' ')}
      accessibilityState={{ selected: active, disabled }}
      style={({ pressed }) => ({
        flex: 1, alignItems: 'center', justifyContent: 'center',
        gap: 4, opacity: disabled ? 0.35 : pressed ? 0.55 : 1, paddingVertical: 10,
      })}
    >
      <Ionicons name={resolvedIcon as any} size={23} color={color} accessibilityElementsHidden />
      <Text style={{ fontSize: 12, fontWeight: '600', color, textAlign: 'center', lineHeight: 15 }}
        accessibilityElementsHidden>
        {label}
      </Text>
    </Pressable>
  );
}

// ─── Section divider ─────────────────────────────────────────────────────────

function SectionDivider({ label }: { label: string }) {
  const { colors } = useTheme();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginVertical: 16 }}>
      <View style={{ flex: 1, height: 1, backgroundColor: colors.border }} accessibilityElementsHidden />
      <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
        textTransform: 'uppercase', letterSpacing: 0.7 }}
        accessibilityRole="header">
        {label}
      </Text>
      <View style={{ flex: 1, height: 1, backgroundColor: colors.border }} accessibilityElementsHidden />
    </View>
  );
}

// ─── Accessibility rating config ─────────────────────────────────────────────

type RatingKey = 'excellent' | 'good' | 'fair' | 'poor';

const RATING_CONFIG: Record<RatingKey, {
  value: number;
  color: string;
  descriptions: { voiceOver: string; buttonLabeling: string; usability: string };
}> = {
  excellent: {
    value: 1.0, color: '#22c55e',
    descriptions: {
      voiceOver:      'Works flawlessly with VoiceOver. No workarounds needed.',
      buttonLabeling: 'All interactive elements are clearly and accurately labeled.',
      usability:      'Smooth, intuitive experience for screen reader users.',
    },
  },
  good: {
    value: 0.75, color: '#84cc16',
    descriptions: {
      voiceOver:      'Works well with VoiceOver. Minor issues or inconsistencies.',
      buttonLabeling: 'Most elements are labeled. Occasional unlabeled buttons.',
      usability:      'Generally usable with minor friction points.',
    },
  },
  fair: {
    value: 0.50, color: '#f59e0b',
    descriptions: {
      voiceOver:      'Partially accessible. Some features may require workarounds.',
      buttonLabeling: 'Many interactive elements have poor or missing labels.',
      usability:      'Usable but requires significant effort or workarounds.',
    },
  },
  poor: {
    value: 0.25, color: '#ef4444',
    descriptions: {
      voiceOver:      'Significant accessibility barriers. Most features are difficult or impossible to use with VoiceOver.',
      buttonLabeling: 'Most interactive elements are unlabeled or incorrectly labeled.',
      usability:      'Very difficult or unusable for screen reader users.',
    },
  },
};

function getRatingKey(text: string): RatingKey | null {
  const t = (text || '').trim().toLowerCase();
  if (t === 'excellent') return 'excellent';
  if (t === 'good')      return 'good';
  if (t === 'fair')      return 'fair';
  if (t === 'poor')      return 'poor';
  return null;
}

function ratingDescription(
  text: string,
  category: 'voiceOver' | 'buttonLabeling' | 'usability',
): string {
  const key = getRatingKey(text);
  return key ? RATING_CONFIG[key].descriptions[category] : '';
}

// ─── Accessibility rating gauge ───────────────────────────────────────────────

function RatingGauge({
  label, ratingWord, ratingKey, descriptionKey, colors,
}: {
  label: string;
  ratingWord: string;
  ratingKey: RatingKey;
  descriptionKey: 'voiceOver' | 'buttonLabeling' | 'usability';
  colors: ReturnType<typeof useTheme>['colors'];
}) {
  const config = RATING_CONFIG[ratingKey];
  const fillAnim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.timing(fillAnim, {
      toValue: config.value,
      duration: 700,
      delay: 300,
      useNativeDriver: false,
    }).start();
  }, []);

  return (
    <View style={{ marginBottom: 14 }}>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between',
        alignItems: 'center', marginBottom: 6 }}>
        <Text style={{ fontSize: 12, fontWeight: '700', color: colors.textSecondary,
          textTransform: 'uppercase', letterSpacing: 0.5 }}>
          {label}
        </Text>
        <View style={{ backgroundColor: config.color + '22', borderRadius: 6,
          paddingHorizontal: 8, paddingVertical: 2 }}>
          <Text style={{ fontSize: 12, fontWeight: '800', color: config.color }}>
            {ratingWord}
          </Text>
        </View>
      </View>
      <View style={{ height: 8, backgroundColor: colors.pill, borderRadius: 4, marginBottom: 6 }}>
        <Animated.View style={{
          height: 8, backgroundColor: config.color, borderRadius: 4,
          width: fillAnim.interpolate({ inputRange: [0, 1], outputRange: ['0%', '100%'] }),
        }} />
      </View>
      <Text style={{ fontSize: 12, color: colors.textSecondary, lineHeight: 17 }}>
        {`Rating: ${ratingWord}. ${config.descriptions[descriptionKey]}`}
      </Text>
    </View>
  );
}

// ─── Star row ─────────────────────────────────────────────────────────────────

function StarRow({ rating, size = 14, color = '#F5A623' }: {
  rating: number; size?: number; color?: string;
}) {
  return (
    <View style={{ flexDirection: 'row', gap: 2 }} accessibilityElementsHidden>
      {[1, 2, 3, 4, 5].map((s) => (
        <Ionicons key={s}
          name={s <= Math.round(rating) ? 'star' : 'star-outline'}
          size={size} color={color} />
      ))}
    </View>
  );
}

// ─── Collapsible text card ────────────────────────────────────────────────────
// Each paragraph is its own accessible Text node — braille users can navigate
// paragraph by paragraph without panning through one giant blob.

function AccessibilityField({
  heading, text, colors, styles, collapseAt = 350,
}: {
  heading: string;
  text: string;
  colors: ReturnType<typeof useTheme>['colors'];
  styles: ReturnType<typeof useTheme>['styles'];
  collapseAt?: number;
}) {
  const [expanded, setExpanded] = useState(false);
  const plain = stripHtml(text);
  const paragraphs = plain.split('\n\n').map(p => p.replace(/\n/g, ' ').trim()).filter(Boolean);

  // Show paragraphs up to ~collapseAt total characters when collapsed.
  const collapsedParagraphs = (() => {
    let len = 0;
    const result: string[] = [];
    for (const p of paragraphs) {
      if (len > 0 && len + p.length > collapseAt) break;
      result.push(p);
      len += p.length + 2;
    }
    return result.length > 0 ? result : paragraphs.slice(0, 1);
  })();
  const hasHiddenContent = collapsedParagraphs.length < paragraphs.length;
  const visibleParagraphs = hasHiddenContent && !expanded ? collapsedParagraphs : paragraphs;
  const hiddenCount = paragraphs.length - collapsedParagraphs.length;

  return (
    <>
      <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text, marginBottom: 8 }}
        accessibilityRole="header">
        {heading}
      </Text>
      <View style={[styles.card, { marginBottom: hasHiddenContent ? 4 : 10 }]}>
        {visibleParagraphs.map((para, i) => (
          <Text
            key={i}
            accessible
            style={{
              fontSize: 15, lineHeight: 23, color: colors.text,
              marginBottom: i < visibleParagraphs.length - 1 ? 10 : 0,
            }}
          >
            {para}
          </Text>
        ))}
      </View>
      {hasHiddenContent && (
        <Pressable
          onPress={() => setExpanded(v => !v)}
          accessible accessibilityRole="button"
          accessibilityLabel={
            expanded
              ? `Show less of ${heading}`
              : `Show full ${heading}. ${hiddenCount} more section${hiddenCount === 1 ? '' : 's'}.`
          }
          style={{ marginBottom: 10 }}>
          <Text style={{ fontSize: 14, fontWeight: '700', color: colors.accent }}>
            {expanded ? 'Show less' : `Show full ${heading} (${hiddenCount} more)`}
          </Text>
        </Pressable>
      )}
    </>
  );
}

// ─── Accessibility comment card ───────────────────────────────────────────────

function CommentCard({
  review, index, total, colors, styles, screenReaderEnabled, showToast, onReplyTo, isNew,
  currentUserUuid, onEdit, onDelete,
}: {
  review: AppReview;
  index: number;
  total: number;
  colors: ReturnType<typeof useTheme>['colors'];
  styles: ReturnType<typeof useTheme>['styles'];
  screenReaderEnabled: boolean;
  showToast: (msg: string, type?: 'success' | 'warning' | 'error') => void;
  onReplyTo: () => void;
  isNew?: boolean;
  currentUserUuid?: string;
  onEdit: (review: AppReview) => void;
  onDelete: (review: AppReview) => void;
}) {
  const plain          = stripHtml(review.body);
  const commentSubject = displayCommentSubject(review.subject);
  const isOwnReview    = !!currentUserUuid && currentUserUuid === review.authorId;

  const actions = [
    { label: 'Reply to this Comment', action: onReplyTo },
    ...(!screenReaderEnabled
      ? [{ label: 'Read Aloud', action: () => readAloud(`Comment by ${review.authorName}. ${subjectLabel(review.subject)}${plain}`) }]
      : []),
    { label: 'Copy Comment Text', action: () => { Clipboard.setString(plain); showToast('Comment text copied.', 'success'); } },
    { label: 'Share Comment', action: () => Share.share({
      message: [
        `${review.authorName} on AppleVis`,
        commentSubject ? `Subject: ${commentSubject}` : null,
        plain,
      ].filter(Boolean).join('\n\n'),
    }).catch(() => {}) },
    { label: 'Mark as Helpful', action: () => showToast('Helpful votes — coming once the Drupal Flags API is confirmed.', 'warning') },
    { label: 'Report Comment',  action: () => showToast('Reporting — coming once the Drupal Flags API is confirmed.', 'warning') },
    ...(isOwnReview ? [
      { label: 'Edit Review',   action: () => onEdit(review) },
      { label: 'Delete Review', action: () => onDelete(review) },
    ] : []),
  ];

  function handleLongPress() {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    if (Platform.OS === 'ios') {
      ActionSheetIOS.showActionSheetWithOptions(
        { title: `Comment by ${review.authorName}`, options: ['Cancel', ...actions.map(a => a.label)], cancelButtonIndex: 0 },
        (i) => { if (i > 0) actions[i - 1].action(); },
      );
    }
  }

  const ratingLabel  = review.rating ? `${review.rating} out of 5 stars. ` : '';

  return (
    <View style={[styles.card, { marginBottom: 10, padding: 0 }, isNew && { borderLeftWidth: 3, borderLeftColor: colors.accent }]}>
      <Pressable
        onLongPress={handleLongPress}
        delayLongPress={400}
        accessible
        accessibilityRole="header"
        accessibilityLabel={
          (isNew ? 'New comment. ' : '') +
          `Comment ${index + 1} of ${total} by ${review.authorName}. ` +
          (commentSubject ? `Subject: ${commentSubject}. ` : '') +
          ratingLabel +
          `${relativeTime(review.createdAt)}. Hold for options.`
        }
        accessibilityActions={actions.map(a => ({ name: a.label, label: a.label }))}
        onAccessibilityAction={({ nativeEvent }) => {
          actions.find(a => a.label === nativeEvent.actionName)?.action();
        }}
        style={({ pressed }) => ({
          padding: 14,
          paddingBottom: 8,
          opacity: pressed ? 0.75 : 1,
        })}
      >
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}
          accessibilityElementsHidden
          importantForAccessibility="no-hide-descendants">
          <View style={{ width: 36, height: 36, borderRadius: 18, backgroundColor: colors.accent,
            alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <Text style={{ fontSize: 15, fontWeight: '700', color: colors.accentText }}>
              {review.authorName.charAt(0).toUpperCase()}
            </Text>
          </View>
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: 14, fontWeight: '700', color: colors.text }}>
              {review.authorName}
            </Text>
            {!!commentSubject && (
              <Text style={{ fontSize: 13, color: colors.text, marginTop: 2 }} numberOfLines={2}>
                {commentSubject}
              </Text>
            )}
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, marginTop: 2 }}>
              {review.rating ? <StarRow rating={review.rating} size={12} /> : null}
              <Text style={{ fontSize: 12, color: colors.textSecondary }}>
                {relativeTime(review.createdAt)}
              </Text>
            </View>
          </View>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
            {isNew && (
              <View style={{ backgroundColor: colors.accent, borderRadius: 6, paddingHorizontal: 6, paddingVertical: 2 }}>
                <Text style={{ color: colors.accentText, fontSize: 12, fontWeight: '700' }}>NEW</Text>
              </View>
            )}
            <Text style={{ fontSize: 11, color: colors.textSecondary, fontWeight: '500' }}>{index + 1}/{total}</Text>
          </View>
        </View>
      </Pressable>
      <View style={{ paddingHorizontal: 14, paddingBottom: 14 }}>
        <Text
          accessible
          accessibilityRole="text"
          accessibilityLabel={plain}
          style={{ fontSize: 15, lineHeight: 23, color: colors.text }}
        >
          {plain}
        </Text>
      </View>
    </View>
  );
}

// ─── Main screen ──────────────────────────────────────────────────────────────

const TOOLBAR_H = 58;

export default function AppDetailScreen() {
  const { id, name: paramName } = useLocalSearchParams<{ id: string; name?: string }>();
  const router                   = useRouter();
  const { colors, styles }       = useTheme();
  const { aiSummariesEnabled }   = usePreferences();
  const { screenReaderEnabled, reduceMotion, reduceTransparency } = useAccessibilityPreferences();
  const auth                     = useAuth();
  const { showToast }            = useToast();
  const { showAlert }            = useAlert();
  const saved                    = useSavedItems('appListing');
  const aiAvailable              = aiSummariesEnabled && isAppleIntelligenceAvailable();
  const insets                   = useSafeAreaInsets();

  const [app,           setApp]           = useState<AppDetail | null>(null);
  const [loading,       setLoading]       = useState(true);
  const [error,         setError]         = useState<string | null>(null);
  const [fromCache,     setFromCache]     = useState(false);
  const [showReview,    setShowReview]    = useState(false);
  const [replyingTo,    setReplyingTo]    = useState<AppReview | null>(null);
  const [editingReview, setEditingReview] = useState<AppReview | null>(null);
  const [authorProfile, setAuthorProfile] = useState(false);
  const [itunes,        setItunes]        = useState<ItunesMetadata | 'not-found' | null>(null);
  const [itunesLoading, setItunesLoading] = useState(false);
  const [developerApps, setDeveloperApps] = useState<DeveloperApp[]>([]);
  const [aiWorking,     setAiWorking]     = useState<'accessibility' | 'community' | null>(null);
  const [loadingMoreReviews, setLoadingMoreReviews] = useState(false);

  // Collapsible App Store description & What's New
  const [notesExpanded, setNotesExpanded] = useState(false);

  const itunesMeta     = itunes !== null && itunes !== 'not-found' ? itunes : null;
  const itunesNotFound = itunes === 'not-found';

  const [lastSeenAt,    setLastSeenAt]    = useState<string | null>(null);
  const [editingNode,   setEditingNode]   = useState(false);

  const scrollRef            = useRef<ScrollView>(null);
  const commentsY            = useRef<number>(0);
  const heroRef              = useRef<Text>(null);
  const commentsRef          = useRef<View>(null);
  const hasInitialFocus      = useRef(false);
  const prevShowReview       = useRef(false);
  const commentOffsets       = useRef<Record<string, number>>({});
  const firstNewReviewRef    = useRef<View | null>(null);
  const firstNewAfterLoadRef = useRef<View | null>(null);
  const preLoadCount         = useRef(0);
  const progressAnim = useRef(new Animated.Value(0)).current;
  const heroAnim     = useRef(new Animated.Value(0)).current;
  const contentAnim  = useRef(new Animated.Value(0)).current;

  useHandoff(app ? {
    activityType: 'com.applevis.app.viewApp',
    title: app.name,
    webpageURL: app.url ?? 'https://www.applevis.com/accessibility-apps',
  } : null);

  // VoiceOver: focus to hero card on first load.
  useEffect(() => {
    if (!app || hasInitialFocus.current) return;
    hasInitialFocus.current = true;
    setTimeout(() => {
      const handle = findNodeHandle(heroRef.current);
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, 200);
  }, [app]);

  // VoiceOver: return focus to Community Discussion heading after WriteReviewModal closes.
  useEffect(() => {
    if (prevShowReview.current && !showReview) {
      setTimeout(() => {
        const handle = findNodeHandle(commentsRef.current);
        if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
      }, 400);
    }
    prevShowReview.current = showReview;
  }, [showReview]);

  function loadApp() {
    if (!id) return;
    setLoading(true);
    setError(null);
    Promise.all([
      cachedApi.apps.detail(id),
      persistence.getItemVisit(id),
    ]).then(([res, visit]) => {
      setLastSeenAt(visit?.seenAt ?? null);
      setLoading(false);
      if (res.ok) {
        setApp(res.data);
        setFromCache(res.fromCache);
        persistence.stampItemVisit(id, res.data.reviewCount);
        if (res.data.appStoreUrl) {
          setItunesLoading(true);
          fetchItunesMetadata(res.data.appStoreUrl)
            .then((meta) => {
              setItunes(meta);
              setItunesLoading(false);
              if (meta && meta !== 'not-found' && meta.artistId) {
                fetchDeveloperApps(meta.artistId, meta.appStoreId)
                  .then(setDeveloperApps)
                  .catch(() => {});
              }
            })
            .catch(() => { setItunesLoading(false); });
        }
      } else {
        setError(res.error);
      }
    }).catch((err: unknown) => {
      setLoading(false);
      setError(err instanceof Error ? err.message : 'Unexpected error');
    });
  }

  useEffect(() => { loadApp(); }, [id]);

  // Fade in hero then content when data arrives; skip animation for Reduce Motion / VoiceOver.
  useEffect(() => {
    if (!app) return;
    if (reduceMotion || screenReaderEnabled) {
      heroAnim.setValue(1);
      contentAnim.setValue(1);
      return;
    }
    Animated.parallel([
      Animated.timing(heroAnim,    { toValue: 1, duration: 380, useNativeDriver: true }),
      Animated.timing(contentAnim, { toValue: 1, duration: 450, delay: 180, useNativeDriver: true }),
    ]).start();
  }, [app]);

  function handleScroll(e: { nativeEvent: { contentOffset: { y: number }; contentSize: { height: number }; layoutMeasurement: { height: number } } }) {
    const { contentOffset, contentSize, layoutMeasurement } = e.nativeEvent;
    const total = contentSize.height - layoutMeasurement.height;
    if (total <= 0) return;
    progressAnim.setValue(Math.min(1, Math.max(0, contentOffset.y / total)));
  }

  // ── Handlers ────────────────────────────────────────────────────────────────

  const isSaved = saved.isSaved(id ?? '');

  function handleSave() {
    if (!app) return;
    if (isSaved) {
      saved.unsave(id!);
      showToast('Removed from saved.', 'success');
    } else {
      saved.save({ id: id!, kind: 'appListing', title: app.name, savedAt: new Date().toISOString() });
      showToast('App entry saved.', 'success');
    }
  }

  async function handleLoadMoreComments() {
    if (!app || !id || loadingMoreReviews) return;
    preLoadCount.current = app.reviews.length;
    setLoadingMoreReviews(true);
    const res = await api.apps.moreReviews(id, app.reviews.length);
    setLoadingMoreReviews(false);
    if (res.ok && res.data.length > 0) {
      setApp(a => a ? { ...a, reviews: [...a.reviews, ...res.data] } : a);
      showToast(`${res.data.length} more comment${res.data.length === 1 ? '' : 's'} loaded.`, 'success');
      setTimeout(() => {
        const handle = findNodeHandle(firstNewAfterLoadRef.current);
        if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
      }, 400);
    } else if (!res.ok) {
      showToast(`Could not load more comments: ${res.error}`, 'error');
    }
  }

  function handleOpenAppStore() {
    const url = itunesMeta?.appStoreUrl || app?.appStoreUrl;
    if (!url) return;
    Linking.openURL(url).catch(() => showToast('Could not open the App Store.', 'error'));
  }

  function handleOpenDeveloperPage() {
    if (!itunesMeta?.artistId) return;
    const url = `https://apps.apple.com/developer/id${itunesMeta.artistId}`;
    Linking.openURL(url).catch(() => showToast('Could not open the App Store.', 'error'));
  }

  function handleShare() {
    if (!app) return;
    Share.share({
      title: app.name,
      message: `${app.name} on AppleVis — ${app.url ?? 'https://www.applevis.com/accessibility-apps'}`,
    }).catch(() => {});
  }

  function handleOpenInBrowser() {
    if (!app) return;
    const link = app.url ?? 'https://www.applevis.com/accessibility-apps';
    Linking.openURL(link).catch(() => showToast('Could not open Safari.', 'error'));
  }

  function handleNodeOptions() {
    if (!app || !auth.user?.csrfToken) return;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    if (Platform.OS === 'ios') {
      ActionSheetIOS.showActionSheetWithOptions(
        { title: app.name, options: ['Cancel', 'Edit App Entry', 'Unpublish App Entry', 'Delete App Entry'],
          cancelButtonIndex: 0, destructiveButtonIndex: 3 },
        (index) => {
          if (index === 1) setEditingNode(true);
          if (index === 2) handleAdminUnpublish();
          if (index === 3) handleAdminDelete();
        },
      );
    } else {
      setEditingNode(true);
    }
  }

  function handleAdminDelete() {
    if (!app || !auth.user?.csrfToken) return;
    const token = auth.user.csrfToken;
    showAlert({
      title: 'Delete App Entry',
      message: `Permanently delete "${app.name}"? This cannot be undone.`,
      confirmLabel: 'Delete', cancelLabel: 'Cancel', type: 'error',
      onConfirm: async () => {
        const res = await api.content.deleteNode(app.id, 'ios_app_directory', token);
        if (res.ok) { showToast('App entry deleted.', 'success'); router.back(); }
        else showToast('Could not delete. Please try again.', 'error');
      },
    });
  }

  function handleAdminUnpublish() {
    if (!app || !auth.user?.csrfToken) return;
    const token = auth.user.csrfToken;
    showAlert({
      title: 'Unpublish App Entry',
      message: `"${app.name}" will be hidden from all users but not deleted.`,
      confirmLabel: 'Unpublish', cancelLabel: 'Cancel', type: 'warning',
      onConfirm: async () => {
        const res = await api.content.unpublishNode(app.id, 'ios_app_directory', token);
        if (res.ok) { showToast('App entry unpublished.', 'success'); router.back(); }
        else showToast('Could not unpublish. Please try again.', 'error');
      },
    });
  }

  function handleWriteReview() {
    if (!auth.isSignedIn) {
      showAlert({ ...ALERTS.auth.signInRequired('write a review'), onConfirm: () => router.push('/settings-account' as any) });
      return;
    }
    setShowReview(true);
  }

  async function handleSummariseAccessibility() {
    if (!app || !aiAvailable) return;
    const parts = [
      app.accessibilityComments,
      app.voiceOverPerformance,
      app.buttonLabelling,
      app.usabilityNotes,
      app.otherComments,
    ].filter((v): v is string => !!v).map(stripHtml);
    if (parts.length === 0) {
      showToast('No accessibility notes to summarise.', 'warning');
      return;
    }
    setAiWorking('accessibility');
    const result = await summariseText(
      `Accessibility notes for ${app.name}:\n${parts.join('\n\n')}`,
    );
    setAiWorking(null);
    if (result) showToast(result, 'success');
    else showToast('Summarisation requires Apple Intelligence Foundation Models (iOS 18.1+).', 'warning');
  }

  async function handleSummariseCommunity() {
    if (!app || !aiAvailable) return;
    if (app.reviews.length === 0) {
      showToast('No community comments to summarise.', 'warning');
      return;
    }
    setAiWorking('community');
    const combined = app.reviews.map((r, i) => `Comment ${i + 1}: ${stripHtml(r.body)}`).join('\n');
    const result = await summariseText(`Community comments for ${app.name}:\n${combined}`);
    setAiWorking(null);
    if (result) showToast(result, 'success');
    else showToast('Summarisation requires Apple Intelligence Foundation Models (iOS 18.1+).', 'warning');
  }

  function handleJumpToComments() {
    scrollRef.current?.scrollTo({ y: commentsY.current, animated: true });
  }

  function handleJumpToNewComment(firstNewId: string) {
    const offset = commentOffsets.current[firstNewId] ?? 0;
    const y = Math.max(0, commentsY.current + offset - 20);
    scrollRef.current?.scrollTo({ y, animated: true });
    setTimeout(() => {
      const handle = findNodeHandle(firstNewReviewRef.current);
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, 400);
  }

  function handleBackToTop() {
    scrollRef.current?.scrollTo({ y: 0, animated: true });
  }

  // ── Derived display values ───────────────────────────────────────────────────

  const firstNewReview   = lastSeenAt && app
    ? app.reviews.find(r => r.createdAt > lastSeenAt) ?? null
    : null;
  const newReviewCount   = lastSeenAt && app
    ? app.reviews.filter(r => r.createdAt > lastSeenAt).length
    : 0;

  const displayName      = itunesMeta?.appName      || app?.name      || paramName || 'App';
  const displayDeveloper = itunesMeta?.developerName || app?.developer || '';
  const displayCategory  = itunesMeta?.category      || app?.category  || '';
  const displayIcon      = itunesMeta?.artworkUrl    || app?.iconUrl   || '';
  const displayPrice     = itunesMeta?.price          || '';
  const displayVersion   = itunesMeta?.version       || '';

  // "Title updated" notice: iTunes has a different name than what AppleVis recorded
  const titleUpdated = !!app?.name && !!itunesMeta?.appName &&
    app.name.trim().toLowerCase() !== itunesMeta.appName.trim().toLowerCase();

  // Version staleness: current App Store version differs from the version AppleVis tested
  const versionMismatch = !!app?.reviewedVersion && !!itunesMeta?.version &&
    app.reviewedVersion !== itunesMeta.version;

  const hasComments    = (app?.reviews.length ?? 0) > 0;
  const hasAccessNotes = !!(
    app?.accessibilityComments || app?.voiceOverPerformance ||
    app?.buttonLabelling       || app?.usabilityNotes       || app?.otherComments
  );

  // Collapsible App Store description
  const desc = itunesMeta?.appStoreDescription?.trim() ?? '';

  // Collapsible What's New
  const notes = itunesMeta?.releaseNotes?.trim() ?? '';
  const NOTES_COLLAPSE = 280;
  const notesDisplay = notes.length > NOTES_COLLAPSE && !notesExpanded
    ? notes.slice(0, NOTES_COLLAPSE).trimEnd() + '…' : notes;


  const langs = languageNames(itunesMeta?.languages ?? []);

  return (
    <Screen title={displayName} showSettings={false} showSearch={false} titleAccessible={false}>
      <View style={{ flex: 1, position: 'relative' }}>
      {/* Reading progress bar — purely visual, hidden from VoiceOver/braille */}
      {app && (
        <View style={{ height: 5, backgroundColor: colors.border }}
          accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
          <Animated.View style={{
            height: 5, backgroundColor: colors.accent,
            width: progressAnim.interpolate({
              inputRange: [0, 1], outputRange: ['0%', '100%'], extrapolate: 'clamp',
            }),
          }} />
        </View>
      )}
      <ScrollView
        ref={scrollRef}
        showsVerticalScrollIndicator
        style={{ flex: 1 }}
        contentContainerStyle={{ padding: 16, paddingBottom: TOOLBAR_H + insets.bottom + 24 }}
        onScroll={handleScroll}
        scrollEventThrottle={16}
      >

        {/* ── Loading ─────────────────────────────────────────────────── */}
        {loading && (
          <View
            accessible
            accessibilityLiveRegion="polite"
            accessibilityLabel="Loading app, please wait"
            style={{ alignItems: 'center', paddingVertical: 48 }}
          >
            <ActivityIndicator size="large" color={colors.accent} />
            <Text style={[styles.cardMeta, { marginTop: 12, textAlign: 'center' }]}>Loading app…</Text>
          </View>
        )}

        {/* ── Error ───────────────────────────────────────────────────── */}
        {!loading && error && (
          <View style={[styles.card, { borderColor: '#FCA5A5', borderWidth: 1 }]}>
            <Text style={[styles.cardTitle, { color: '#B91C1C' }]}>Could not load app</Text>
            <Text style={styles.cardMeta}>{error}</Text>
            <Pressable onPress={loadApp} accessible accessibilityRole="button"
              accessibilityLabel="Retry loading app" style={{ marginTop: 12 }}>
              <Text style={{ color: colors.accent, fontWeight: '700' }}>Retry</Text>
            </Pressable>
          </View>
        )}

        {/* ── App content ─────────────────────────────────────────────── */}
        {app && (
          <>
            {/* ── Offline banner ──────────────────────────────────────── */}
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
                <Pressable onPress={loadApp} accessible accessibilityRole="button"
                  accessibilityLabel="Refresh"
                  style={{ paddingHorizontal: 8, paddingVertical: 4 }}>
                  <Text style={{ fontSize: 13, fontWeight: '700', color: colors.accent }}>Refresh</Text>
                </Pressable>
              </View>
            )}

            {/* ── 1. Hero header ──────────────────────────────────────── */}
            <Animated.View style={{
              opacity: heroAnim,
              transform: [{ translateY: heroAnim.interpolate({
                inputRange: [0, 1], outputRange: [12, 0],
              }) }],
            }}>
            <View style={[styles.card, { marginBottom: 10, overflow: 'hidden', padding: 0 }]}>
              {/* Blurred tinted backdrop — purely visual, unique to each app's icon */}
              {displayIcon && !reduceTransparency && (
                <View style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 160 }}
                  accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
                  <Image
                    source={{ uri: displayIcon }}
                    style={{ width: '100%', height: '100%', opacity: 0.28 }}
                    blurRadius={60}
                    accessibilityIgnoresInvertColors
                  />
                  <View style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0,
                    backgroundColor: colors.card, opacity: 0.62 }} />
                </View>
              )}
              <View style={{ padding: 16 }}>
              {/* Icon row — visual only, entirely hidden from VoiceOver */}
              <View
                accessibilityElementsHidden
                importantForAccessibility="no-hide-descendants"
                style={{ flexDirection: 'row', alignItems: 'flex-start' }}>
                {displayIcon ? (
                  <Image source={{ uri: displayIcon }}
                    style={{ width: 72, height: 72, borderRadius: 16 }}
                    accessibilityIgnoresInvertColors />
                ) : (
                  <View style={{ width: 72, height: 72, borderRadius: 16,
                    backgroundColor: colors.pill, alignItems: 'center', justifyContent: 'center' }}>
                    <Ionicons name="apps-outline" size={32} color={colors.textSecondary} />
                  </View>
                )}
              </View>

              {/* Swipe 1: title row — direct child of card */}
              <View style={{ flexDirection: 'row', alignItems: 'flex-start', marginLeft: 86, marginTop: -72, minHeight: 72, marginBottom: 8 }}>
                <Text
                  ref={heroRef}
                  accessible
                  accessibilityRole="header"
                  accessibilityLabel={displayName}
                  style={{
                    flex: 1, fontSize: 21, fontWeight: '800', color: colors.text, lineHeight: 26,
                    textAlignVertical: 'top',
                  }}>
                  {displayName}
                </Text>
                {auth.user?.isAdmin && (
                  <Pressable
                    onPress={handleNodeOptions}
                    accessible
                    accessibilityRole="button"
                    accessibilityLabel="App entry options"
                    accessibilityHint="Edit, unpublish, or delete this app entry"
                    style={({ pressed }) => ({ padding: 6, opacity: pressed ? 0.55 : 1, marginTop: 2 })}
                  >
                    <Ionicons name="ellipsis-horizontal" size={20} color={colors.textSecondary}
                      accessibilityElementsHidden />
                  </Pressable>
                )}
              </View>

              {/* Swipe 2 (only shown when App Store title differs): original AppleVis name */}
              {titleUpdated && (
                <View
                  accessible
                  accessibilityLabel={`App Store title has been updated by the developer since this entry was originally submitted to AppleVis as "${app.name}"`}
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 5, marginBottom: 6 }}>
                  <Ionicons name="pencil-outline" size={12} color={colors.textSecondary}
                    accessibilityElementsHidden />
                  <Text style={{ fontSize: 12, color: colors.textSecondary, fontStyle: 'italic', flex: 1 }}>
                    Title updated on App Store · Original AppleVis title: "{app.name}"
                  </Text>
                </View>
              )}

              {/* Swipe 3: Submitter profile button — tappable like topic detail */}
              <Pressable
                onPress={app.submitterUid ? () => setAuthorProfile(true) : undefined}
                accessible
                accessibilityRole={app.submitterUid ? 'button' : 'text'}
                accessibilityLabel={app.submittedBy ? `Submitted by ${app.submittedBy}` : 'Submitted by AppleVis member'}
                accessibilityHint={[
                  app.createdAt          ? `Posted ${relativeTime(app.createdAt)}`          : null,
                  app.lastUpdatedAt      ? `Last comment ${relativeTime(app.lastUpdatedAt)}` : null,
                  app.submitterUid       ? 'Double tap to view profile'                      : null,
                ].filter(Boolean).join('. ')}
                style={({ pressed }) => ({
                  flexDirection: 'row', alignItems: 'center', gap: 10,
                  marginBottom: 8, opacity: pressed ? 0.65 : 1,
                })}>
                <View
                  style={{ width: 36, height: 36, borderRadius: 18, backgroundColor: colors.accent,
                    alignItems: 'center', justifyContent: 'center' }}
                  accessibilityElementsHidden>
                  <Text style={{ fontSize: 15, fontWeight: '700', color: '#fff' }}>
                    {(app.submittedBy || '?').charAt(0).toUpperCase()}
                  </Text>
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={{ fontSize: 14, fontWeight: '700', color: colors.text }}
                    accessibilityElementsHidden>
                    {app.submittedBy || 'AppleVis member'}
                  </Text>
                  <Text style={{ fontSize: 12, color: colors.textSecondary }}
                    accessibilityElementsHidden>
                    {app.createdAt ? `Posted ${relativeTime(app.createdAt)}` : ''}
                    {app.createdAt ? ' · ' : ''}
                    {`Last comment ${relativeTime(app.lastUpdatedAt)}`}
                  </Text>
                </View>
                {app.submitterUid && (
                  <Ionicons name="chevron-forward" size={16} color={colors.textSecondary}
                    accessibilityElementsHidden />
                )}
              </Pressable>

              {/* Swipe 4: Category */}
              {displayCategory ? (
                <Text
                  accessible
                  style={{ fontSize: 13, color: colors.textSecondary, marginBottom: 6 }}>
                  Category: {displayCategory}
                </Text>
              ) : null}

              {/* Swipe 5: Developer */}
              {displayDeveloper ? (
                <Pressable
                  onPress={itunesMeta?.artistId ? handleOpenDeveloperPage : undefined}
                  accessible
                  accessibilityRole={itunesMeta?.artistId ? 'link' : 'text'}
                  accessibilityLabel={
                    itunesMeta?.artistId
                      ? `Developer: ${displayDeveloper}. Opens developer page in the App Store`
                      : `Developer: ${displayDeveloper}`
                  }
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 4, marginBottom: 6 }}>
                  <Text style={{ fontSize: 13,
                    color: itunesMeta?.artistId ? colors.accent : colors.textSecondary,
                    fontWeight: itunesMeta?.artistId ? '600' : '400' }}>
                    Developer: {displayDeveloper}
                  </Text>
                  {itunesMeta?.artistId && (
                    <Ionicons name="open-outline" size={13} color={colors.accent}
                      accessibilityElementsHidden />
                  )}
                </Pressable>
              ) : null}

              {/* iTunes loading indicator */}
              {itunesLoading && !itunesMeta && !itunesNotFound ? (
                <ActivityIndicator size="small" color={colors.textSecondary}
                  style={{ alignSelf: 'flex-start', marginBottom: 6 }}
                  accessibilityLabel="Loading App Store details" />
              ) : null}

              {/* Swipe 6: Comment count */}
              {app.reviewCount > 0 && (
                <Text
                  accessible
                  style={{ fontSize: 12, color: colors.textSecondary }}>
                  {app.reviewCount} {app.reviewCount === 1 ? 'comment' : 'comments'}
                </Text>
              )}
              </View>{/* end padding wrapper */}
            </View>{/* end hero card */}
            </Animated.View>{/* end hero animation */}

            {/* ── Remaining content fades in after hero ────────────────── */}
            <Animated.View style={{
              opacity: contentAnim,
              transform: [{ translateY: contentAnim.interpolate({
                inputRange: [0, 1], outputRange: [12, 0],
              }) }],
            }}>

            {/* ── 2. App no longer on the App Store ───────────────────── */}
            {itunesNotFound && (
              <View style={[styles.card, {
                marginBottom: 10, flexDirection: 'row', alignItems: 'flex-start', gap: 12,
                borderWidth: 1, borderColor: '#9CA3AF', backgroundColor: colors.pill,
              }]}
                accessible
                accessibilityLabel="This app is no longer available on the App Store. The accessibility record below reflects the community's experience when it was available.">
                <Ionicons name="storefront-outline" size={20} color={colors.textSecondary}
                  accessibilityElementsHidden style={{ marginTop: 2 }} />
                <View style={{ flex: 1 }}>
                  <Text style={{ fontSize: 14, fontWeight: '700', color: colors.text, marginBottom: 4 }}>
                    No longer on the App Store
                  </Text>
                  <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 18 }}>
                    This app is no longer available to download. The accessibility record below reflects the community's experience when it was available.
                  </Text>
                </View>
              </View>
            )}

            {/* ── Quick nav: jump to comments ──────────────────────────── */}
            {app.reviewCount > 0 && (
              <View style={{ marginBottom: 12 }}>
                <Pressable onPress={handleJumpToComments}
                  accessible accessibilityRole="button"
                  accessibilityLabel={`Jump to ${app.reviewCount} ${app.reviewCount === 1 ? 'comment' : 'comments'}`}
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                    backgroundColor: colors.pill, borderRadius: 10, paddingHorizontal: 14, paddingVertical: 10,
                    alignSelf: 'flex-start' }}>
                  <Ionicons name="arrow-down-outline" size={16} color={colors.pillText} accessibilityElementsHidden />
                  <Text style={{ fontSize: 14, fontWeight: '600', color: colors.pillText }}>Jump to Comments</Text>
                </Pressable>
              </View>
            )}

            {/* ── App Store content ────────────────────────────────────── */}
            {itunesLoading && !itunes ? (
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8,
                  paddingVertical: 12, paddingHorizontal: 4, marginBottom: 4 }}>
                  <ActivityIndicator size="small" color={colors.textSecondary} accessibilityElementsHidden />
                  <Text style={{ fontSize: 13, color: colors.textSecondary }}>
                    Loading App Store information…
                  </Text>
                </View>
              ) : null}

              {itunesMeta && (
                <>
                  {/* ── App Store Description ───────────────────────── */}
                  {desc ? (
                    <>
                      <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text,
                        marginBottom: 8 }} accessibilityRole="header">
                        About this App
                      </Text>
                      <View style={[styles.card, { marginBottom: 10 }]}>
                        <Text
                          accessible
                          style={{ fontSize: 15, lineHeight: 23, color: colors.text }}>
                          {desc}
                        </Text>
                      </View>
                    </>
                  ) : null}

                  {/* ── Current Version card (merges iOS review version) ── */}
                  <View
                    style={[styles.card, { marginBottom: 10 }]}
                    accessible
                    accessibilityLabel={[
                      `Current version: ${itunesMeta.version}.`,
                      itunesMeta.versionDate
                        ? `Released ${relativeTime(itunesMeta.versionDate)}.`
                        : null,
                      versionMismatch
                        ? `AppleVis entry reviewed on version ${app.reviewedVersion}.`
                        : null,
                      app.testedOnIOS
                        ? `Reviewed on iOS ${app.testedOnIOS}.`
                        : null,
                    ].filter((v): v is string => !!v).join(' ')}>
                    <Text style={{ fontSize: 12, fontWeight: '700', color: colors.textSecondary,
                      textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 8 }}>
                      Current Version
                    </Text>
                    <View style={{ flexDirection: 'row', alignItems: 'flex-end', gap: 10, marginBottom: (versionMismatch || app.testedOnIOS) ? 10 : 0 }}>
                      <Text style={{ fontSize: 28, fontWeight: '800', color: colors.text }}>
                        {itunesMeta.version}
                      </Text>
                      {itunesMeta.versionDate ? (
                        <Text style={{ fontSize: 13, color: colors.textSecondary, marginBottom: 5 }}>
                          Released {relativeTime(itunesMeta.versionDate)}
                        </Text>
                      ) : null}
                    </View>
                    {(versionMismatch || app.testedOnIOS) ? (
                      <View style={{ flexDirection: 'row', gap: 16, flexWrap: 'wrap' }}
                        accessibilityElementsHidden>
                        {versionMismatch ? (
                          <View>
                            <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary,
                              textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 2 }}>
                              Reviewed on
                            </Text>
                            <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>
                              v{app.reviewedVersion}
                            </Text>
                          </View>
                        ) : null}
                        {app.testedOnIOS ? (
                          <View>
                            <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary,
                              textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 2 }}>
                              Reviewed on iOS
                            </Text>
                            <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>
                              {app.testedOnIOS}
                            </Text>
                          </View>
                        ) : null}
                      </View>
                    ) : null}
                  </View>

                  {/* ── What's New — no standalone heading to avoid duplication ── */}
                  {notes ? (
                    <View style={[styles.card, { marginBottom: 10 }]}
                      accessible accessibilityLabel={`What's new in version ${itunesMeta.version}: ${notes}`}>
                      <Text style={{ fontSize: 12, fontWeight: '700', color: colors.textSecondary,
                        textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 6 }}
                        accessibilityElementsHidden>
                        What's New · v{itunesMeta.version}
                      </Text>
                      <Text style={{ fontSize: 15, lineHeight: 23, color: colors.text }}
                        accessibilityElementsHidden>
                        {notesDisplay}
                      </Text>
                      {notes.length > NOTES_COLLAPSE && (
                        <Pressable onPress={() => setNotesExpanded(v => !v)}
                          accessible accessibilityRole="button"
                          accessibilityLabel={notesExpanded ? 'Show less release notes' : 'Read more release notes'}
                          style={{ marginTop: 10 }}>
                          <Text style={{ fontSize: 14, fontWeight: '700', color: colors.accent }}>
                            {notesExpanded ? 'Show less' : 'Read more'}
                          </Text>
                        </Pressable>
                      )}
                    </View>
                  ) : null}

                  {/* ── Price ───────────────────────────────────────── */}
                  {itunesMeta.price ? (
                    <View style={[styles.card, { marginBottom: 10 }]}
                      accessible
                      accessibilityLabel={`Price: ${itunesMeta.price}`}>
                      <Text style={{ fontSize: 12, fontWeight: '700', color: colors.textSecondary,
                        textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 6 }}>
                        Price
                      </Text>
                      <Text style={{ fontSize: 22, fontWeight: '800', color: colors.text }}>
                        {itunesMeta.price}
                      </Text>
                    </View>
                  ) : null}

                  {/* ── App Store rating ────────────────────────────── */}
                  {itunesMeta.appStoreRating != null && itunesMeta.appStoreRatingCount > 0 ? (
                    <View style={[styles.card, { marginBottom: 10, flexDirection: 'row', alignItems: 'center', gap: 12 }]}
                      accessible
                      accessibilityLabel={`App Store rating: ${itunesMeta.appStoreRating.toFixed(1)} out of 5 from ${itunesMeta.appStoreRatingCount.toLocaleString()} ratings. This is the general App Store rating, separate from the AppleVis accessibility rating.`}>
                      <View style={{ alignItems: 'center', minWidth: 56 }}>
                        <Text style={{ fontSize: 36, fontWeight: '800', color: colors.text, lineHeight: 40 }}>
                          {itunesMeta.appStoreRating.toFixed(1)}
                        </Text>
                        <StarRow rating={itunesMeta.appStoreRating} size={13} />
                      </View>
                      <View style={{ flex: 1 }}>
                        <Text style={{ fontSize: 14, fontWeight: '700', color: colors.text }}>App Store Rating</Text>
                        <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2, lineHeight: 17 }}>
                          {itunesMeta.appStoreRatingCount.toLocaleString()} ratings · General quality, separate from AppleVis accessibility score
                        </Text>
                      </View>
                    </View>
                  ) : null}

                  {/* ── Available on (devices) ──────────────────────── */}
                  {itunesMeta.supportedDevices.length > 0 ? (
                    <View style={[styles.card, { marginBottom: 10 }]}
                      accessible
                      accessibilityLabel={`Available on: ${itunesMeta.supportedDevices.join(', ')}`}>
                      <Text style={{ fontSize: 12, fontWeight: '700', color: colors.textSecondary,
                        textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 8 }}>
                        Available On
                      </Text>
                      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 6 }}
                        accessibilityElementsHidden>
                        {itunesMeta.supportedDevices.map((d) => (
                          <View key={d} style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                            backgroundColor: colors.pill, borderRadius: 10, paddingHorizontal: 12, paddingVertical: 8 }}>
                            <Ionicons
                              name={
                                d === 'iPad'        ? 'tablet-portrait-outline' :
                                d === 'Mac'         ? 'laptop-outline' :
                                d === 'Apple Watch' ? 'watch-outline' :
                                d === 'Apple TV'    ? 'tv-outline' :
                                'phone-portrait-outline'
                              }
                              size={18} color={colors.pillText} />
                            <Text style={{ fontSize: 13, fontWeight: '600', color: colors.pillText }}>{d}</Text>
                          </View>
                        ))}
                      </View>
                    </View>
                  ) : null}

                  {/* ── Screenshots (visual only, hidden from VoiceOver) */}
                  {itunesMeta.screenshotUrls.length > 0 ? (
                    <>
                      <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text,
                        marginTop: 4, marginBottom: 8 }}
                        accessibilityElementsHidden>
                        Screenshots
                      </Text>
                      <ScrollView
                        horizontal
                        showsHorizontalScrollIndicator={false}
                        contentContainerStyle={{ gap: 10, paddingBottom: 4 }}
                        style={{ marginBottom: 10 }}
                        accessibilityElementsHidden
                        importantForAccessibility="no-hide-descendants"
                      >
                        {itunesMeta.screenshotUrls.map((url) => (
                          <Image key={url} source={{ uri: url }}
                            style={{ width: 160, height: 284, borderRadius: 12 }}
                            accessibilityElementsHidden />
                        ))}
                      </ScrollView>
                    </>
                  ) : null}
                </>
              )}

            {/* ── Accessibility notes ──────────────────────────────────── */}

              {/* Accessibility Comments */}
              {app.accessibilityComments ? (
                <AccessibilityField
                  heading="Accessibility Notes"
                  text={app.accessibilityComments}
                  colors={colors}
                  styles={styles}
                />
              ) : null}

              {/* Accessibility Ratings — animated gauges for known ratings,
                  text fallback for free-form values.
                  Single accessible node: VoiceOver/braille reads all three ratings
                  plus their contextual descriptions in one focused element. */}
              {(app.voiceOverPerformance || app.buttonLabelling || app.usabilityNotes) ? (
                <>
                  <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text, marginBottom: 8 }}
                    accessibilityRole="header">
                    Accessibility Ratings
                  </Text>
                  <View
                    style={[styles.card, { marginBottom: 10 }]}
                    accessible
                    accessibilityLabel={[
                      app.voiceOverPerformance
                        ? `VoiceOver Performance: ${app.voiceOverPerformance}.${ratingDescription(app.voiceOverPerformance, 'voiceOver') ? ' ' + ratingDescription(app.voiceOverPerformance, 'voiceOver') : ''}`
                        : null,
                      app.buttonLabelling
                        ? `Button Labeling: ${app.buttonLabelling}.${ratingDescription(app.buttonLabelling, 'buttonLabeling') ? ' ' + ratingDescription(app.buttonLabelling, 'buttonLabeling') : ''}`
                        : null,
                      app.usabilityNotes
                        ? `Usability: ${app.usabilityNotes}.${ratingDescription(app.usabilityNotes, 'usability') ? ' ' + ratingDescription(app.usabilityNotes, 'usability') : ''}`
                        : null,
                    ].filter(Boolean).join(' ')}
                  >
                    <View accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
                      {app.voiceOverPerformance ? (
                        getRatingKey(app.voiceOverPerformance)
                          ? <RatingGauge
                              label="VoiceOver Performance"
                              ratingWord={app.voiceOverPerformance}
                              ratingKey={getRatingKey(app.voiceOverPerformance)!}
                              descriptionKey="voiceOver"
                              colors={colors}
                            />
                          : <View style={{ marginBottom: 14 }}>
                              <Text style={{ fontSize: 12, fontWeight: '700', color: colors.textSecondary,
                                textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 4 }}>
                                VoiceOver Performance
                              </Text>
                              <Text style={{ fontSize: 15, lineHeight: 23, color: colors.text }}>
                                {stripHtml(app.voiceOverPerformance)}
                              </Text>
                            </View>
                      ) : null}
                      {app.buttonLabelling ? (
                        getRatingKey(app.buttonLabelling)
                          ? <RatingGauge
                              label="Button Labeling"
                              ratingWord={app.buttonLabelling}
                              ratingKey={getRatingKey(app.buttonLabelling)!}
                              descriptionKey="buttonLabeling"
                              colors={colors}
                            />
                          : <View style={{ marginBottom: 14 }}>
                              <Text style={{ fontSize: 12, fontWeight: '700', color: colors.textSecondary,
                                textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 4 }}>
                                Button Labeling
                              </Text>
                              <Text style={{ fontSize: 15, lineHeight: 23, color: colors.text }}>
                                {stripHtml(app.buttonLabelling)}
                              </Text>
                            </View>
                      ) : null}
                      {app.usabilityNotes ? (
                        getRatingKey(app.usabilityNotes)
                          ? <RatingGauge
                              label="Usability"
                              ratingWord={app.usabilityNotes}
                              ratingKey={getRatingKey(app.usabilityNotes)!}
                              descriptionKey="usability"
                              colors={colors}
                            />
                          : <View style={{ marginBottom: 14 }}>
                              <Text style={{ fontSize: 12, fontWeight: '700', color: colors.textSecondary,
                                textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 4 }}>
                                Usability
                              </Text>
                              <Text style={{ fontSize: 15, lineHeight: 23, color: colors.text }}>
                                {stripHtml(app.usabilityNotes)}
                              </Text>
                            </View>
                      ) : null}
                    </View>
                  </View>
                </>
              ) : null}

              {/* Other Comments */}
              {app.otherComments ? (
                <AccessibilityField
                  heading="Other Comments"
                  text={app.otherComments}
                  colors={colors}
                  styles={styles}
                />
              ) : null}

              {/* Apple Intelligence — Summarise Accessibility Notes (only if available) */}
              {aiAvailable && hasAccessNotes && (
                <Pressable
                  onPress={handleSummariseAccessibility}
                  disabled={aiWorking === 'accessibility'}
                  accessible accessibilityRole="button"
                  accessibilityLabel={
                    aiWorking === 'accessibility'
                      ? 'Summarising accessibility notes, please wait'
                      : 'Summarise Accessibility Notes with Apple Intelligence'
                  }
                  accessibilityHint="Generates a brief AI summary of the accessibility notes above"
                  style={({ pressed }) => ({
                    flexDirection: 'row', alignItems: 'center', gap: 8,
                    backgroundColor: colors.pill, borderRadius: 10,
                    paddingHorizontal: 14, paddingVertical: 12,
                    alignSelf: 'flex-start', marginBottom: 4,
                    opacity: pressed || aiWorking === 'accessibility' ? 0.6 : 1,
                  })}>
                  {aiWorking === 'accessibility'
                    ? <ActivityIndicator size="small" color={colors.pillText} accessibilityElementsHidden />
                    : <Ionicons name="sparkles-outline" size={16} color={colors.pillText} accessibilityElementsHidden />
                  }
                  <Text style={{ fontSize: 14, fontWeight: '600', color: colors.pillText }}>
                    {aiWorking === 'accessibility' ? 'Summarising…' : 'Summarise Accessibility Notes'}
                  </Text>
                </Pressable>
              )}

            {/* ── Information ──────────────────────────────────────────── */}
            {itunesMeta && (itunesMeta.minimumOsVersion || itunesMeta.ageRating || itunesMeta.fileSizeMb) ? (
              <>
                <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text,
                  marginTop: 12, marginBottom: 8 }}
                  accessibilityRole="header">
                  Information
                </Text>
                <View style={[styles.card, { marginBottom: 10 }]}
                  accessible
                  accessibilityLabel={[
                    itunesMeta.minimumOsVersion ? `Requires iOS ${itunesMeta.minimumOsVersion} or later` : null,
                    itunesMeta.ageRating        ? `Rated ${itunesMeta.ageRating}`                        : null,
                    itunesMeta.fileSizeMb       ? `File size: ${itunesMeta.fileSizeMb}`                  : null,
                  ].filter((v): v is string => !!v).join('. ')}>
                  <View style={{ flexDirection: 'row', flexWrap: 'wrap', rowGap: 14, columnGap: 0 }}>
                    {itunesMeta.minimumOsVersion ? (
                      <View style={{ width: '33.33%', paddingRight: 8 }}>
                        <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary,
                          textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 3 }}>Requires</Text>
                        <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>
                          iOS {itunesMeta.minimumOsVersion}+
                        </Text>
                      </View>
                    ) : null}
                    {itunesMeta.ageRating ? (
                      <View style={{ width: '33.33%', paddingRight: 8 }}>
                        <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary,
                          textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 3 }}>Rated</Text>
                        <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>
                          {itunesMeta.ageRating}
                        </Text>
                      </View>
                    ) : null}
                    {itunesMeta.fileSizeMb ? (
                      <View style={{ width: '33.33%', paddingRight: 8 }}>
                        <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary,
                          textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 3 }}>Size</Text>
                        <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>
                          {itunesMeta.fileSizeMb}
                        </Text>
                      </View>
                    ) : null}
                  </View>
                </View>
              </>
            ) : null}

            {/* ── Languages ────────────────────────────────────────────── */}
            {itunesMeta && langs.length > 0 ? (
              <View style={[styles.card, { marginBottom: 10 }]}
                accessible
                accessibilityLabel={`Supported languages: ${langs.join(', ')}`}>
                <Text style={{ fontSize: 12, fontWeight: '700', color: colors.textSecondary,
                  textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 8 }}>
                  Languages
                </Text>
                <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 6 }}
                  accessibilityElementsHidden>
                  {langs.map((lang) => (
                    <View key={lang} style={{ backgroundColor: colors.pill, borderRadius: 8,
                      paddingHorizontal: 10, paddingVertical: 4 }}>
                      <Text style={{ fontSize: 13, color: colors.pillText, fontWeight: '500' }}>{lang}</Text>
                    </View>
                  ))}
                </View>
              </View>
            ) : null}

            {/* ── View in App Store ─────────────────────────────────────── */}
            {itunesMeta ? (
              <Pressable
                onPress={handleOpenAppStore}
                accessible accessibilityRole="link"
                accessibilityLabel={`Open ${displayName} in the App Store`}
                accessibilityHint="Opens in the App Store app"
                style={({ pressed }) => [styles.card, {
                  flexDirection: 'row', alignItems: 'center', gap: 10,
                  marginBottom: 10, opacity: pressed ? 0.75 : 1,
                }]}>
                <Ionicons name="logo-apple" size={20} color={colors.accent} accessibilityElementsHidden />
                <View style={{ flex: 1 }}>
                  <Text style={{ fontSize: 14, fontWeight: '700', color: colors.accent }}>View in App Store</Text>
                  <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 1 }} numberOfLines={1}>
                    {itunesMeta.appStoreUrl.replace(/^https?:\/\//, '')}
                  </Text>
                </View>
                <Ionicons name="open-outline" size={16} color={colors.textSecondary} accessibilityElementsHidden />
              </Pressable>
            ) : null}

            {/* ── Developer website ─────────────────────────────────────── */}
            {itunesMeta?.developerWebsite ? (
              <Pressable
                onPress={() => Linking.openURL(itunesMeta!.developerWebsite!).catch(() => {})}
                accessible accessibilityRole="link"
                accessibilityLabel={`${displayDeveloper} developer website`}
                accessibilityHint="Opens the developer's website in Safari"
                style={({ pressed }) => [styles.card, {
                  flexDirection: 'row', alignItems: 'center', gap: 10,
                  marginBottom: 10, opacity: pressed ? 0.75 : 1,
                }]}>
                <Ionicons name="globe-outline" size={20} color={colors.accent} accessibilityElementsHidden />
                <View style={{ flex: 1 }}>
                  <Text style={{ fontSize: 14, fontWeight: '700', color: colors.accent }}>Developer Website</Text>
                  <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 1 }} numberOfLines={1}>
                    {itunesMeta.developerWebsite.replace(/^https?:\/\//, '')}
                  </Text>
                </View>
                <Ionicons name="open-outline" size={16} color={colors.textSecondary} accessibilityElementsHidden />
              </Pressable>
            ) : null}

            {/* ── More from this developer ─────────────────────────────── */}
            {developerApps.length > 0 && (() => {
              const devName = itunesMeta?.developerName || app.developer || 'this developer';
              return (
                <>
                  <SectionDivider label={`More from ${devName}`} />
                  <ScrollView
                    horizontal
                    showsHorizontalScrollIndicator={false}
                    contentContainerStyle={{ gap: 14, paddingBottom: 4, paddingHorizontal: 2 }}
                    style={{ marginBottom: 12 }}
                    accessibilityLabel={`${developerApps.length} more apps by ${devName}`}
                  >
                    {developerApps.map((devApp) => (
                      <Pressable
                        key={devApp.id}
                        onPress={() => Linking.openURL(devApp.appStoreUrl).catch(() => {})}
                        accessible accessibilityRole="link"
                        accessibilityLabel={[
                          devApp.name, devApp.category, devApp.price, 'Opens in App Store',
                        ].filter(Boolean).join('. ')}
                        style={({ pressed }) => ({ width: 100, alignItems: 'center', opacity: pressed ? 0.7 : 1 })}>
                        {devApp.iconUrl ? (
                          <Image source={{ uri: devApp.iconUrl }}
                            style={{ width: 64, height: 64, borderRadius: 14 }}
                            accessibilityElementsHidden
                            accessibilityIgnoresInvertColors />
                        ) : (
                          <View style={{ width: 64, height: 64, borderRadius: 14,
                            backgroundColor: colors.pill, alignItems: 'center', justifyContent: 'center' }}>
                            <Ionicons name="apps-outline" size={28} color={colors.textSecondary} />
                          </View>
                        )}
                        <Text style={{ fontSize: 12, fontWeight: '600', color: colors.text,
                          textAlign: 'center', marginTop: 7, lineHeight: 16 }}
                          numberOfLines={2} accessibilityElementsHidden>
                          {devApp.name}
                        </Text>
                        <Text style={{ fontSize: 11, color: colors.accent,
                          textAlign: 'center', marginTop: 3, fontWeight: '500' }}
                          numberOfLines={1} accessibilityElementsHidden>
                          {devApp.price}
                        </Text>
                      </Pressable>
                    ))}
                  </ScrollView>
                </>
              );
            })()}

            {/* ── 10. Community Discussion ──────────────────────────────── */}
            <View
              ref={commentsRef}
              onLayout={(e) => { commentsY.current = e.nativeEvent.layout.y; }}
            >
              <SectionDivider
                label={
                  `Community Discussion - ${app.reviewCount} ${app.reviewCount === 1 ? 'comment' : 'comments'}` +
                  (newReviewCount > 0 ? ` - ${newReviewCount} new` : '')
                }
              />

              {/* Jump to first new comment */}
              {firstNewReview && (
                <Pressable
                  onPress={() => handleJumpToNewComment(firstNewReview.id)}
                  accessible
                  accessibilityRole="button"
                  accessibilityLabel={`Jump to first new comment. ${newReviewCount} new since your last visit.`}
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
                      {newReviewCount} new since your last visit
                    </Text>
                  </View>
                  <Ionicons name="arrow-down-outline" size={16} color={colors.accent} accessibilityElementsHidden />
                </Pressable>
              )}

              {/* Read all aloud — sighted users only */}
              {!screenReaderEnabled && hasComments && (
                <Pressable
                  onPress={() => {
                    const parts = app.reviews.map((r, i) => {
                      const rating = r.rating ? `${r.rating} stars.` : '';
                      return `Comment ${i + 1} by ${r.authorName}. ${rating} ${stripHtml(r.body)}`;
                    });
                    readAloud(parts.join(' '));
                  }}
                  accessible accessibilityRole="button"
                  accessibilityLabel={`Read all ${app.reviews.length} comments aloud`}
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 8,
                    backgroundColor: colors.pill, borderRadius: 10,
                    paddingHorizontal: 14, paddingVertical: 10, alignSelf: 'flex-start', marginBottom: 14 }}>
                  <Ionicons name="volume-medium-outline" size={16} color={colors.pillText} accessibilityElementsHidden />
                  <Text style={{ fontSize: 14, fontWeight: '600', color: colors.pillText }}>Read All Comments</Text>
                </Pressable>
              )}

              {/* No comments state */}
              {!hasComments && (
                <View style={[styles.card, { alignItems: 'center', paddingVertical: 28, marginBottom: 12 }]}>
                  <Ionicons name="chatbubble-outline" size={32} color={colors.textSecondary}
                    accessibilityElementsHidden style={{ marginBottom: 10 }} />
                  <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text, marginBottom: 6 }}>
                    No comments yet
                  </Text>
                  <Text style={{ fontSize: 14, color: colors.textSecondary, textAlign: 'center' }}>
                    Be the first to share your accessibility experience.
                  </Text>
                </View>
              )}

              {/* Comment cards */}
              {app.reviews.map((review, i) => {
                const isNewReview      = lastSeenAt != null && review.createdAt > lastSeenAt;
                const isFirstNew       = isNewReview && review.id === firstNewReview?.id;
                const isFirstAfterLoad = preLoadCount.current > 0 && i === preLoadCount.current;
                return (
                  <View
                    key={review.id}
                    ref={
                      isFirstNew       ? (v) => { firstNewReviewRef.current    = v; } :
                      isFirstAfterLoad ? (v) => { firstNewAfterLoadRef.current = v; } :
                      undefined
                    }
                    onLayout={(e) => { commentOffsets.current[review.id] = e.nativeEvent.layout.y; }}
                  >
                    <CommentCard
                      review={review}
                      index={i}
                      total={app.reviews.length}
                      colors={colors}
                      styles={styles}
                      screenReaderEnabled={screenReaderEnabled}
                      showToast={showToast}
                      isNew={isNewReview}
                      currentUserUuid={auth.user?.uuid}
                      onEdit={(r) => setEditingReview(r)}
                      onDelete={(r) => {
                        confirmDestructiveAction(showAlert, {
                          title: 'Delete Review?',
                          message: 'This cannot be undone.',
                          confirmLabel: 'Delete',
                          onConfirm: async () => {
                            if (!auth.user?.csrfToken) return;
                            const res = await api.content.deleteComment('comment_node_ios_app_directory', r.id, auth.user.csrfToken);
                            if (res.ok) {
                              setApp(a => a ? { ...a, reviews: a.reviews.filter(x => x.id !== r.id) } : a);
                              showToast('Review deleted.', 'success');
                            } else {
                              showToast('Could not delete review.', 'error');
                            }
                          },
                        });
                      }}
                      onReplyTo={() => {
                        if (!auth.isSignedIn) { showAlert({ ...ALERTS.auth.signInRequired('reply to reviews'), onConfirm: () => router.push('/settings-account' as any) }); return; }
                        setReplyingTo(review);
                        setTimeout(() => setShowReview(true), 350);
                      }}
                    />
                  </View>
                );
              })}

              {/* Load more */}
              {hasComments && app.reviews.length < app.reviewCount && (
                <Pressable
                  onPress={handleLoadMoreComments}
                  disabled={loadingMoreReviews}
                  accessible accessibilityRole="button"
                  accessibilityLabel={
                    loadingMoreReviews
                      ? 'Loading more comments'
                      : `Load ${app.reviewCount - app.reviews.length} more comment${app.reviewCount - app.reviews.length === 1 ? '' : 's'}`
                  }
                  accessibilityState={{ disabled: loadingMoreReviews }}
                  style={[styles.card, {
                    alignItems: 'center', paddingVertical: 14, marginBottom: 8,
                    flexDirection: 'row', justifyContent: 'center', gap: 8,
                  }]}>
                  {loadingMoreReviews
                    ? <ActivityIndicator size="small" color={colors.accent} />
                    : <>
                        <Ionicons name="ellipsis-horizontal-outline" size={18} color={colors.accent}
                          accessibilityElementsHidden />
                        <Text style={{ fontSize: 14, fontWeight: '700', color: colors.accent }}>
                          Load {app.reviewCount - app.reviews.length} More Comment{app.reviewCount - app.reviews.length === 1 ? '' : 's'}
                        </Text>
                      </>
                  }
                </Pressable>
              )}

              {/* Apple Intelligence - Summarise Community Discussion (only if available) */}
              {aiAvailable && hasComments && (
                <Pressable
                  onPress={handleSummariseCommunity}
                  disabled={aiWorking === 'community'}
                  accessible accessibilityRole="button"
                  accessibilityLabel={
                    aiWorking === 'community'
                      ? 'Summarising community comments, please wait'
                      : 'Summarise Community Discussion with Apple Intelligence'
                  }
                  accessibilityHint="Generates a brief AI summary of what the community says about accessibility"
                  style={({ pressed }) => ({
                    flexDirection: 'row', alignItems: 'center', gap: 8,
                    backgroundColor: colors.pill, borderRadius: 10,
                    paddingHorizontal: 14, paddingVertical: 12,
                    alignSelf: 'flex-start', marginTop: 4, marginBottom: 4,
                    opacity: pressed || aiWorking === 'community' ? 0.6 : 1,
                  })}>
                  {aiWorking === 'community'
                    ? <ActivityIndicator size="small" color={colors.pillText} accessibilityElementsHidden />
                    : <Ionicons name="sparkles-outline" size={16} color={colors.pillText} accessibilityElementsHidden />
                  }
                  <Text style={{ fontSize: 14, fontWeight: '600', color: colors.pillText }}>
                    {aiWorking === 'community' ? 'Summarising...' : 'Summarise Community Discussion'}
                  </Text>
                </Pressable>
              )}
            </View>

            </Animated.View>{/* end contentAnim */}

            {/* ── 11. Back to top ──────────────────────────────────────── */}
            <Pressable onPress={handleBackToTop}
              accessible accessibilityRole="button"
              accessibilityLabel="Back to top"
              accessibilityHint="Scrolls back to the app header"
              style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center',
                gap: 6, paddingVertical: 16 }}>
              <Ionicons name="arrow-up-outline" size={16} color={colors.textSecondary} accessibilityElementsHidden />
              <Text style={{ fontSize: 14, color: colors.textSecondary, fontWeight: '500' }}>Back to Top</Text>
            </Pressable>

          </>
        )}
      </ScrollView>

      {/* ── Fixed bottom toolbar ─────────────────────────────────────────── */}
      {app && (
        <View
          style={{
            position: 'absolute',
            left: 0,
            right: 0,
            bottom: 0,
            zIndex: 10,
            flexDirection: 'row',
            minHeight: TOOLBAR_H,
            paddingBottom: insets.bottom,
            paddingHorizontal: 4,
            backgroundColor: colors.card,
            borderTopWidth: StyleSheet.hairlineWidth,
            borderTopColor: colors.border,
            alignItems: 'center',
          }}
          accessibilityRole="toolbar"
          accessibilityLabel="App actions"
        >
          <ToolbarButton
            icon="logo-apple"
            label={displayPrice
              ? `Get — ${displayPrice}`
              : itunesNotFound ? 'Unavailable' : 'Get in\nApp Store'}
            a11yLabel={
              itunesNotFound
                ? 'Unavailable on App Store'
                : displayPrice && displayPrice !== 'Free'
                  ? `Get app for ${displayPrice} from App Store`
                  : 'Get app from App Store'
            }
            onPress={handleOpenAppStore}
            disabled={itunesNotFound || !app.appStoreUrl}
          />
          <ToolbarButton
            icon="bookmark-outline"
            activeIcon="bookmark"
            label={isSaved ? 'Saved' : 'Save this\nApp Entry'}
            a11yLabel={isSaved ? 'Saved' : 'Save this App Entry'}
            active={isSaved}
            onPress={handleSave}
          />
          <ToolbarButton
            icon="share-outline"
            label="Share this\nApp Entry"
            a11yLabel="Share this App Entry"
            onPress={handleShare}
          />
          <ToolbarButton
            icon="safari-outline"
            label="Open in\nSafari"
            a11yLabel="Open in Safari"
            onPress={handleOpenInBrowser}
          />
          <ToolbarButton
            icon="pencil-outline"
            label="Add New\nComment"
            a11yLabel="Add new comment"
            onPress={handleWriteReview}
            accent
          />
        </View>
      )}

      {/* Write Review Modal */}
      {app && (
        <WriteReviewModal
          visible={showReview}
          appId={id ?? ''}
          appName={app.name}
          replyToAuthor={replyingTo?.authorName}
          replyToText={replyingTo ? stripHtml(replyingTo.body) : undefined}
          onClose={() => { setShowReview(false); setReplyingTo(null); }}
          onSubmitted={() => {
            setShowReview(false);
            setReplyingTo(null);
            showToast('Comment submitted! It will appear after moderation.', 'success');
            if (id) contentCache.clear(`apps:detail:${id}`);
            loadApp();
          }}
        />
      )}

      {/* Admin Edit Node Modal */}
      {editingNode && app && auth.user?.csrfToken && (
        <EditContentModal
          visible={editingNode}
          onClose={() => setEditingNode(false)}
          onSaved={(newBody, newTitle) => {
            setApp(a => a ? { ...a, body: newBody, name: newTitle ?? a.name } : a);
            showToast('App entry updated.', 'success');
          }}
          nodeId={app.id}
          nodeType="ios_app_directory"
          initialTitle={app.name}
          csrfToken={auth.user.csrfToken}
          initialBody={app.body}
          label="App Entry"
        />
      )}

      {/* Edit Review Modal */}
      {editingReview && auth.user?.csrfToken && (
        <EditContentModal
          visible={!!editingReview}
          onClose={() => setEditingReview(null)}
          onSaved={(newBody) => {
            setApp(a => a ? { ...a, reviews: a.reviews.map(r => r.id === editingReview.id ? { ...r, body: newBody } : r) } : a);
            showToast('Review updated.', 'success');
          }}
          commentId={editingReview.id}
          commentType="comment_node_ios_app_directory"
          csrfToken={auth.user.csrfToken}
          initialBody={editingReview.body}
          label="Review"
        />
      )}

      {/* Author Profile Modal */}
      {app && (
        <AuthorProfileModal
          visible={authorProfile}
          onClose={() => setAuthorProfile(false)}
          authorId={app.submitterUid ?? ''}
          authorName={app.submittedBy ?? ''}
          isSignedIn={auth.isSignedIn}
          showToast={showToast}
        />
      )}
      </View>
    </Screen>
  );
}
