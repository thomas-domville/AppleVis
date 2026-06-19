import { useCallback, useEffect, useMemo, useRef, useState, type RefObject } from 'react';
import {
  AccessibilityInfo, ActivityIndicator, AppState, findNodeHandle, FlatList,
  Modal, Pressable, RefreshControl, StyleSheet, Text, useColorScheme, View,
} from 'react-native';
import { useScrollToTop } from '@react-navigation/native';
import { Tabs, useFocusEffect, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { EmptyState } from '../../src/components/EmptyState';
import { Screen } from '../../src/components/Screen';
import { FeedCard } from '../../src/components/FeedCard';
import { useHomeFeed, DEFAULT_FEED_PREFS } from '../../src/hooks/useHomeFeed';
import { useAuth } from '../../src/contexts/AuthContext';
import { useTheme } from '../../src/contexts/ThemeContext';
import { usePreferences } from '../../src/contexts/PreferencesContext';
import { useHandoff } from '../../src/hooks/useHandoff';
import { persistence } from '../../src/services/persistence';
import { useTip, TIP_KEYS, TIPS } from '../../src/contexts/ContextualTipContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { relativeTime } from '../../src/utils/relativeTime';
import type { FeedItem, FeedPrefs } from '../../src/types/content';

// ─── Greeting ─────────────────────────────────────────────────────────────────

function getGreeting(): string {
  const h = new Date().getHours();
  if (h >= 5  && h < 12) return 'Good morning';
  if (h >= 12 && h < 17) return 'Good afternoon';
  if (h >= 17 && h < 22) return 'Good evening';
  return 'Good night';
}

const KIND_ACCENT: Record<FeedItem['kind'], string> = {
  topic:   '#6366f1',
  podcast: '#f97316',
  app:     '#3b82f6',
  guide:   '#10b981',
  blog:    '#8b5cf6',
};

function greetingAccent(): string {
  const h = new Date().getHours();
  if (h >= 5  && h < 12) return '#f59e0b';
  if (h >= 12 && h < 17) return '#0ea5e9';
  if (h >= 17 && h < 22) return '#6366f1';
  return '#7c3aed';
}

function formatToday(): string {
  return new Date().toLocaleDateString('en-US', {
    weekday: 'long', month: 'long', day: 'numeric',
  });
}

type WelcomeSummary = {
  message: string;
  accessibilityLabel: string;
  count: number;
};

function plural(count: number, singular: string, pluralLabel = `${singular}s`): string {
  return `${count} ${count === 1 ? singular : pluralLabel}`;
}

function joinParts(parts: string[]): string {
  if (parts.length <= 1) return parts[0] ?? '';
  if (parts.length === 2) return `${parts[0]} and ${parts[1]}`;
  return `${parts.slice(0, -1).join(', ')}, and ${parts[parts.length - 1]}`;
}

type ItemVisits = Record<string, { seenAt: string; commentCount: number }>;

function buildWelcomeSummary(
  items: FeedItem[],
  lastVisitAt: string | null,
  itemVisits: ItemVisits,
): WelcomeSummary | null {
  if (!lastVisitAt) return null;
  const lastVisitTime = new Date(lastVisitAt).getTime();
  if (!Number.isFinite(lastVisitTime)) return null;

  const counts: Partial<Record<FeedItem['kind'], number>> = {};
  for (const item of items) {
    const activityTime = new Date(item.activityAt).getTime();
    if (Number.isFinite(activityTime) && activityTime > lastVisitTime) {
      counts[item.kind] = (counts[item.kind] ?? 0) + 1;
    }
  }

  // Replies added to items the user has previously visited
  let newComments = 0;
  for (const item of items) {
    const visit = itemVisits[String(item.data.id)];
    if (!visit) continue;
    const current =
      item.kind === 'topic'   ? (item.data.replyCount  ?? 0) :
      item.kind === 'app'     ? (item.data.reviewCount  ?? 0) :
      item.kind === 'blog'    ? (item.data.commentCount ?? 0) :
      item.kind === 'guide'   ? (item.data.commentCount ?? 0) : 0;
    newComments += Math.max(0, current - visit.commentCount);
  }

  const parts = [
    counts.topic   ? plural(counts.topic,   'new forum topic')                  : null,
    counts.podcast ? plural(counts.podcast, 'new podcast episode')              : null,
    counts.app     ? plural(counts.app,     'new app entry', 'new app entries') : null,
    counts.guide   ? plural(counts.guide,   'new guide or resource')            : null,
    counts.blog    ? plural(counts.blog,    'new blog post')                    : null,
    newComments > 0 ? plural(newComments,   'new reply', 'new replies')         : null,
  ].filter((part): part is string => !!part);

  const count = Object.values(counts).reduce((total, n) => total + (n ?? 0), 0) + newComments;

  if (count === 0 || parts.length === 0) {
    return {
      message: 'You are all caught up — no new content since your last visit.',
      accessibilityLabel: 'Welcome back to AppleVis. You are all caught up — no new content since your last visit.',
      count: 0,
    };
  }

  const body = `Since your last visit: ${joinParts(parts)}.`;
  return {
    message: body,
    accessibilityLabel: `Welcome back to AppleVis. ${body}`,
    count,
  };
}

// ─── Filter picker ────────────────────────────────────────────────────────────

type FilterRow = {
  key: keyof FeedPrefs;
  label: string;
  subLabel: string;
  gated?: boolean;  // true = show but disabled (Coming soon)
};

const FILTER_ROWS: FilterRow[] = [
  { key: 'topics',    label: 'Latest Topics and Comments',        subLabel: 'Forum discussions and comment activity' },
  { key: 'podcasts',  label: 'Latest Podcasts and Comments',      subLabel: 'New episodes and episode discussion' },
  { key: 'apps',      label: 'Latest App Entries and Comments',   subLabel: 'New app listings and accessibility comments' },
  { key: 'guides',    label: 'Latest Blogs, Guides and Comments', subLabel: 'Blog posts, guides, tutorials, and how-tos' },
  { key: 'appleOnly', label: 'Apple-Related Topics Only',         subLabel: 'Filter topics to Apple products and services only' },
];

function FeedFilterModal({
  visible,
  prefs,
  onUpdate,
  onClose,
  headingRef,
}: {
  visible: boolean;
  prefs: FeedPrefs;
  onUpdate: (key: keyof FeedPrefs, val: boolean) => void;
  onClose: () => void;
  headingRef: RefObject<Text | null>;
}) {
  const { colors } = useTheme();
  const insets     = useSafeAreaInsets();

  useEffect(() => {
    if (!visible) return;
    const timer = setTimeout(() => {
      const handle = findNodeHandle(headingRef.current);
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, 400);
    return () => clearTimeout(timer);
  }, [visible, headingRef]);

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={onClose}
      accessibilityViewIsModal
    >
      <View style={{ flex: 1, backgroundColor: colors.background }} onAccessibilityEscape={onClose}>
        {/* Header */}
        <View style={{
          flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
          paddingHorizontal: 20, paddingTop: insets.top + 16, paddingBottom: 16,
          borderBottomWidth: 1, borderBottomColor: colors.border,
        }}>
          <Text
            ref={headingRef}
            accessible
            accessibilityRole="header"
            style={{ fontSize: 18, fontWeight: '700', color: colors.text }}
          >
            Customize Home
          </Text>
          <Pressable
            onPress={onClose}
            accessible
            accessibilityRole="button"
            accessibilityLabel="Close Customize Home"
            style={{ padding: 8 }}
          >
            <Ionicons name="close" size={22} color={colors.text} />
          </Pressable>
        </View>

        <Text style={{
          fontSize: 13, color: colors.textSecondary,
          paddingHorizontal: 20, paddingTop: 14, paddingBottom: 10,
          lineHeight: 18,
        }}>
          Choose what appears on your Home screen. Your preferences are saved automatically.
        </Text>

        {FILTER_ROWS.map((row) => {
          const isOn    = prefs[row.key];
          const isGated = row.gated;

          return (
            <Pressable
              key={row.key}
              onPress={() => {
                if (isGated) return;
                Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                const newVal = !isOn;
                const label  = row.label;
                onUpdate(row.key, newVal);
                setTimeout(() => {
                  AccessibilityInfo.announceForAccessibility(`${label}, ${newVal ? 'on' : 'off'}`);
                }, 100);
              }}
              accessible
              accessibilityRole="switch"
              accessibilityLabel={isGated ? `${row.label}, coming soon` : row.label}
              accessibilityHint={isGated ? undefined : row.subLabel}
              accessibilityState={{ checked: isOn, disabled: !!isGated }}
              style={({ pressed }) => ({
                flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
                paddingHorizontal: 20, paddingVertical: 14,
                borderBottomWidth: 1, borderBottomColor: colors.border,
                opacity: pressed && !isGated ? 0.7 : 1,
              })}
            >
              <View style={{ flex: 1, marginRight: 16 }}>
                <Text style={{
                  fontSize: 16, fontWeight: '500',
                  color: isGated ? colors.textSecondary : colors.text,
                }}>
                  {row.label}
                </Text>
                <Text style={{ fontSize: 13, color: colors.textSecondary, marginTop: 2 }}>
                  {isGated ? 'Coming soon' : row.subLabel}
                </Text>
              </View>
              {isGated ? (
                <View style={{
                  paddingHorizontal: 8, paddingVertical: 3,
                  backgroundColor: colors.pill, borderRadius: 6,
                }}>
                  <Text style={{ fontSize: 12, color: colors.textSecondary, fontWeight: '600' }}>
                    Soon
                  </Text>
                </View>
              ) : (
                <View
                  style={{
                    width: 50, height: 28, borderRadius: 14,
                    backgroundColor: isOn ? colors.accent : colors.border,
                    justifyContent: 'center', paddingHorizontal: 3,
                  }}
                  accessibilityElementsHidden
                >
                  <View style={{
                    width: 22, height: 22, borderRadius: 11,
                    backgroundColor: '#fff',
                    alignSelf: isOn ? 'flex-end' : 'flex-start',
                  }} />
                </View>
              )}
            </Pressable>
          );
        })}
      </View>
    </Modal>
  );
}

// ─── Main screen ──────────────────────────────────────────────────────────────

export default function HomeScreen() {
  const router       = useRouter();
  const { colors, styles } = useTheme();
  const auth         = useAuth();
  const feed         = useHomeFeed();
  const { showTip }  = useTip();
  const colorScheme  = useColorScheme();
  const a11y         = useAccessibilityPreferences();
  const { welcomeSummaryEnabled } = usePreferences();
  const [filterVisible, setFilterVisible] = useState(false);
  const flatListRef       = useRef<FlatList>(null);
  const firstItemRef      = useRef<View | null>(null);
  const itemRefs          = useRef<Record<string, View | null>>({});
  const lastTappedIdRef   = useRef<string | null>(null);
  const pendingFocusRestoreRef = useRef(false);
  const feedItemsRef      = useRef<FeedItem[]>([]);
  const firstItemFocusTimersRef = useRef<ReturnType<typeof setTimeout>[]>([]);
  const prevRefreshingRef = useRef(false);
  const hasAnnouncedRef = useRef(false);
  const appStateRef = useRef(AppState.currentState);
  const welcomeAnnouncementTimersRef = useRef<ReturnType<typeof setTimeout>[]>([]);
  const [itemVisits, setItemVisits] = useState<Record<string, { seenAt: string; commentCount: number }>>({});
  const [lastVisitAt, setLastVisitAt] = useState<string | null>(null);
  const [lastVisitLoaded, setLastVisitLoaded] = useState(false);
  const [welcomeDismissed, setWelcomeDismissed] = useState(false);
  const [welcomeFocusToken, setWelcomeFocusToken] = useState(0);
  useScrollToTop(flatListRef);
  const modalHeadingRef        = useRef<Text | null>(null);
  const lastFocusedBeforeModal = useRef<View | null>(null);
  const welcomeSummaryRef      = useRef<View | null>(null);
  const [feedLoadedAt, setFeedLoadedAt] = useState<Date | null>(null);

  function getNewCount(item: FeedItem): number {
    const visit = itemVisits[item.data.id];
    if (!visit) return 0;
    const current =
      item.kind === 'topic'   ? item.data.replyCount :
      item.kind === 'app'     ? item.data.reviewCount :
      item.kind === 'blog'    ? item.data.commentCount :
      item.kind === 'guide'   ? item.data.commentCount : 0;
    return Math.max(0, current - visit.commentCount);
  }

  const unreadCount   = useMemo(
    () => feed.items.filter(i => i.kind === 'topic' && i.data.isUnread).length,
    [feed.items],
  );
  const latestWelcomeSummaryRef = useRef<WelcomeSummary | null>(null);
  const welcomeSummary = useMemo(
    () => welcomeSummaryEnabled && !welcomeDismissed
      ? buildWelcomeSummary(feed.items, lastVisitAt, itemVisits)
      : null,
    [feed.items, itemVisits, lastVisitAt, welcomeDismissed, welcomeSummaryEnabled],
  );
  latestWelcomeSummaryRef.current = welcomeSummary;

  useEffect(() => {
    feedItemsRef.current = feed.items;
  }, [feed.items]);

  useFocusEffect(useCallback(() => {
    showTip(TIP_KEYS.tabHome, TIPS.tabHome);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []));

  const clearFirstItemFocusTimers = useCallback(() => {
    firstItemFocusTimersRef.current.forEach(clearTimeout);
    firstItemFocusTimersRef.current = [];
  }, []);

  const clearWelcomeAnnouncementTimers = useCallback(() => {
    welcomeAnnouncementTimersRef.current.forEach(clearTimeout);
    welcomeAnnouncementTimersRef.current = [];
  }, []);

  const focusFirstFeedItem = useCallback((scrollToTop = false) => {
    clearFirstItemFocusTimers();
    if (scrollToTop) {
      flatListRef.current?.scrollToOffset({ offset: 0, animated: false });
    }

    const tryFocus = () => {
      const handle = findNodeHandle(firstItemRef.current);
      if (!handle) return;

      AccessibilityInfo.setAccessibilityFocus(handle);
      clearFirstItemFocusTimers();
    };

    firstItemFocusTimersRef.current = [450, 800, 1200].map((delay) =>
      setTimeout(tryFocus, delay),
    );
  }, [clearFirstItemFocusTimers]);

  useEffect(() => clearFirstItemFocusTimers, [clearFirstItemFocusTimers]);
  useEffect(() => clearWelcomeAnnouncementTimers, [clearWelcomeAnnouncementTimers]);

  const focusLastVisitedFeedItem = useCallback(() => {
    const sorted = Object.entries(itemVisits)
      .sort(([, a], [, b]) => new Date(b.seenAt).getTime() - new Date(a.seenAt).getTime());

    for (const [visitedId] of sorted) {
      const feedItem = feedItemsRef.current.find(
        (item) => String(item.data.id) === String(visitedId),
      );
      if (!feedItem) continue;

      const key = `${feedItem.kind}-${feedItem.data.id}`;
      const index = feedItemsRef.current.indexOf(feedItem);
      if (index >= 0) {
        try { flatListRef.current?.scrollToIndex({ index, animated: false, viewPosition: 0.3 }); }
        catch {}
      }

      const tryFocus = (retries: number) => {
        const node = itemRefs.current[key];
        const handle = node ? findNodeHandle(node) : null;
        if (handle) { AccessibilityInfo.setAccessibilityFocus(handle); return; }
        if (retries > 0) {
          const t = setTimeout(() => tryFocus(retries - 1), 250);
          firstItemFocusTimersRef.current.push(t);
        } else {
          focusFirstFeedItem(false);
        }
      };
      const t = setTimeout(() => tryFocus(2), 300);
      firstItemFocusTimersRef.current.push(t);
      return;
    }

    focusFirstFeedItem(false);
  }, [itemVisits, focusFirstFeedItem]);

  const focusWelcomeSummary = useCallback((): boolean => {
    clearFirstItemFocusTimers();
    flatListRef.current?.scrollToOffset({ offset: 0, animated: false });
    const handle = findNodeHandle(welcomeSummaryRef.current);
    if (!handle) return false;
    AccessibilityInfo.setAccessibilityFocus(handle);
    return true;
  }, [clearFirstItemFocusTimers]);

  useFocusEffect(useCallback(() => {
    persistence.getAllItemVisits().then(setItemVisits);
    const timers: ReturnType<typeof setTimeout>[] = [];
    timers.push(setTimeout(() => flatListRef.current?.flashScrollIndicators(), 350));

    // Restore VoiceOver focus to the item that triggered navigation away.
    const id = lastTappedIdRef.current;
    if (id && pendingFocusRestoreRef.current && hasAnnouncedRef.current) {
      const restoreFocus = (isFinalAttempt = false) => {
        const node = itemRefs.current[id];
        if (node) {
          const handle = findNodeHandle(node);
          if (handle) {
            AccessibilityInfo.setAccessibilityFocus(handle);
            pendingFocusRestoreRef.current = false;
          }
          return;
        }

        const index = feedItemsRef.current.findIndex((item) => `${item.kind}-${item.data.id}` === id);
        if (index >= 0) {
          flatListRef.current?.scrollToIndex({ index, animated: false, viewPosition: 0.5 });
        }
        if (isFinalAttempt) pendingFocusRestoreRef.current = false;
      };

      timers.push(setTimeout(restoreFocus, 400));
      timers.push(setTimeout(restoreFocus, 700));
      timers.push(setTimeout(() => restoreFocus(true), 1000));
    }

    return () => timers.forEach(clearTimeout);
  }, []));

  useHandoff({
    activityType: 'com.applevis.app.viewHome',
    title: 'AppleVis',
    webpageURL: 'https://www.applevis.com',
  });

  useEffect(() => {
    let mounted = true;
    persistence.getLastVisit()
      .then((iso) => {
        if (mounted) setLastVisitAt(iso);
      })
      .finally(() => {
        if (mounted) setLastVisitLoaded(true);
        persistence.stampVisit().catch(() => {});
      });
    return () => { mounted = false; };
  }, []);

  useEffect(() => {
    const sub = AppState.addEventListener('change', (state) => {
      const wasInactive = appStateRef.current === 'background' || appStateRef.current === 'inactive';
      appStateRef.current = state;

      if (state === 'background' || state === 'inactive') {
        persistence.stampVisit().catch(() => {});
        return;
      }

      if (state === 'active' && wasInactive) {
        persistence.getLastVisit()
          .then((iso) => {
            setLastVisitAt(iso);
            setWelcomeDismissed(false);
            hasAnnouncedRef.current = false;
            pendingFocusRestoreRef.current = false;
            lastTappedIdRef.current = null;
            setWelcomeFocusToken((token) => token + 1);
            feed.refresh();
          })
          .finally(() => {
            persistence.stampVisit().catch(() => {});
          });
      }
    });
    return () => sub.remove();
  }, [feed.refresh]);

  // On initial load: move VoiceOver focus to the welcome card (or first feed item if no card).
  // latestWelcomeSummaryRef avoids keeping welcomeSummary in deps, which would cause React's
  // cleanup to cancel the focus timer every time feed items finish loading.
  useEffect(() => {
    if (!hasAnnouncedRef.current && lastVisitLoaded && !feed.loading && feed.items.length > 0) {
      hasAnnouncedRef.current = true;
      pendingFocusRestoreRef.current = false;
      lastTappedIdRef.current = null;
      setFeedLoadedAt(new Date());
      if (latestWelcomeSummaryRef.current) {
        flatListRef.current?.scrollToOffset({ offset: 0, animated: false });
        const t = setTimeout(() => {
          if (!focusWelcomeSummary()) focusFirstFeedItem(false);
        }, 350);
        return () => clearTimeout(t);
      } else {
        focusFirstFeedItem(true);
      }
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [feed.loading, feed.items.length, focusFirstFeedItem, focusWelcomeSummary, lastVisitLoaded, welcomeFocusToken]);

  // After pull-to-refresh completes: move VoiceOver focus back to the first feed item.
  useEffect(() => {
    if (prevRefreshingRef.current && !feed.refreshing && feed.items.length > 0) {
      setFeedLoadedAt(new Date());
      focusFirstFeedItem(true);
    }
    prevRefreshingRef.current = feed.refreshing;
  }, [feed.refreshing, feed.items.length, focusFirstFeedItem]);

  function handleItemPress(item: FeedItem) {
    lastTappedIdRef.current = `${item.kind}-${item.data.id}`;
    pendingFocusRestoreRef.current = true;
    switch (item.kind) {
      case 'topic':
        router.push({ pathname: '/topic/[id]' as any, params: { id: item.data.id, title: item.data.title } });
        break;
      case 'podcast':
        router.push({
          pathname: '/episode/[id]' as any,
          params: {
            id: item.data.id,
            title: item.data.title,
            showTitle: item.data.showTitle,
            description: item.data.description ?? '',
            artworkUrl: item.data.artworkUrl ?? '',
            publishedAt: item.data.publishedAt ?? '',
            duration: String(item.data.duration),
            audioUrl: item.data.audioUrl ?? '',
            url: item.data.url ?? '',
          },
        });
        break;
      case 'app':
        router.push({ pathname: '/app-detail/[id]' as any, params: { id: item.data.id, name: item.data.name } });
        break;
      case 'guide':
        router.push({
          pathname: '/resource-detail/[id]' as any,
          params: { id: item.data.id, title: item.data.title, url: item.data.url },
        });
        break;
      case 'blog':
        router.push({
          pathname: '/blog-detail/[id]' as any,
          params: { id: item.data.id, title: item.data.title, url: item.data.url },
        });
        break;
    }
  }

  // Greeting card at the top
  const greeting = getGreeting();
  const name     = auth.isSignedIn ? (auth.user?.name ?? '') : '';

  function renderHeader() {
    const anyErrors  = Object.keys(feed.errors).length > 0;
    const accent     = greetingAccent();
    const today      = formatToday();
    const warnBg     = colorScheme === 'dark' ? 'rgba(255, 152, 0, 0.15)' : '#FFF8F0';
    const warnText   = colorScheme === 'dark' ? '#FFAB40' : '#C05000';

    const kindCounts = feed.items.reduce<Partial<Record<FeedItem['kind'], number>>>((acc, item) => {
      acc[item.kind] = (acc[item.kind] ?? 0) + 1;
      return acc;
    }, {});
    const countParts = (['topic', 'podcast', 'app', 'guide', 'blog'] as FeedItem['kind'][])
      .filter(k => (kindCounts[k] ?? 0) > 0)
      .map(k => {
        const n = kindCounts[k] ?? 0;
        const kl = k === 'topic' ? 'forum' : k;
        return `${n} ${kl}${n !== 1 ? 's' : ''}`;
      });
    const updatedLabel = feedLoadedAt
      ? ` Last updated ${relativeTime(feedLoadedAt.toISOString())}.`
      : '';
    const feedSummary = feed.items.length > 0
      ? `${feed.items.length} item${feed.items.length !== 1 ? 's' : ''}: ${countParts.join(', ')}.${updatedLabel}`
      : 'Feed is empty.';

    return (
      <>
        {/* Greeting */}
        {name ? (
          <View
            style={[styles.card, {
              marginBottom: 4,
              borderLeftWidth: 4,
              borderLeftColor: accent,
              overflow: 'hidden',
            }]}
            accessible
            accessibilityLabel={`${greeting}, ${name}. Today is ${today}.`}
          >
            {!a11y.reduceTransparency && (
              <View
                style={{ ...StyleSheet.absoluteFillObject, backgroundColor: accent, opacity: 0.06 }}
                pointerEvents="none"
              />
            )}
            <Text style={{ fontSize: 20, fontWeight: '300', color: colors.text, letterSpacing: 0.2 }}
              importantForAccessibility="no-hide-descendants">
              {greeting},
            </Text>
            <Text style={{ fontSize: 26, fontWeight: '700', color: colors.appleVisBlue }}
              importantForAccessibility="no-hide-descendants">
              {name}
            </Text>
            <Text style={{ fontSize: 13, color: colors.textSecondary, marginTop: 4 }}
              importantForAccessibility="no-hide-descendants">
              {today}
            </Text>
          </View>
        ) : null}

        {welcomeSummary && (
          <View
            style={[styles.cardSmall, {
              marginBottom: 10,
              borderLeftWidth: 4,
              borderLeftColor: colors.accent,
              gap: 10,
            }]}
          >
            <Pressable
              ref={welcomeSummaryRef}
              onPress={focusLastVisitedFeedItem}
              accessible
              accessibilityRole="button"
              accessibilityLabel={welcomeSummary.accessibilityLabel}
              accessibilityHint={welcomeSummary.count > 0
                ? 'Double-tap to jump to where you left off in the feed.'
                : 'Double-tap to go to your feed.'}
              style={({ pressed }) => ({
                flexDirection: 'row', alignItems: 'flex-start', gap: 10,
                opacity: pressed ? 0.7 : 1,
              })}
            >
              <Ionicons name="sparkles-outline" size={19} color={colors.accent} accessibilityElementsHidden />
              <View style={{ flex: 1 }} accessibilityElementsHidden>
                <Text style={{ fontSize: 13, fontWeight: '700', color: colors.accent, marginBottom: 3 }}>
                  Welcome Back
                </Text>
                <Text style={{ fontSize: 15, lineHeight: 21, color: colors.text }}>
                  {welcomeSummary.message}
                </Text>
              </View>
            </Pressable>

            <Pressable
              onPress={() => setWelcomeDismissed(true)}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Dismiss welcome summary"
              style={({ pressed }) => ({
                alignItems: 'center',
                borderRadius: 8,
                borderWidth: 1,
                borderColor: colors.border,
                backgroundColor: colors.background,
                paddingVertical: 9,
                opacity: pressed ? 0.75 : 1,
              })}
            >
              <Text style={{ color: colors.textSecondary, fontWeight: '700', fontSize: 14 }}>
                Dismiss
              </Text>
            </Pressable>
          </View>
        )}

        {/* Unread strip */}
        {unreadCount > 0 && (
          <Pressable
            onPress={() => focusFirstFeedItem()}
            accessible
            accessibilityRole="button"
            accessibilityLabel={`${unreadCount} unread topic${unreadCount !== 1 ? 's' : ''}. Activate to jump to first unread.`}
            style={({ pressed }) => ({
              flexDirection: 'row', alignItems: 'center', gap: 8,
              backgroundColor: colors.accent + '1A',
              borderRadius: 10, padding: 12, marginBottom: 10,
              opacity: pressed ? 0.7 : 1,
            })}
          >
            <Ionicons name="ellipse" size={8} color={colors.accent} accessibilityElementsHidden />
            <Text style={{ flex: 1, fontSize: 13, fontWeight: '600', color: colors.accent }}>
              {unreadCount} unread topic{unreadCount !== 1 ? 's' : ''}
            </Text>
            <Text style={{ fontSize: 13, color: colors.accent, fontWeight: '500' }}>
              Jump to first →
            </Text>
          </Pressable>
        )}

        {/* Per-source error banners — only shown if something failed */}
        {anyErrors && (
          <View style={{
            flexDirection: 'row', gap: 8, alignItems: 'flex-start',
            backgroundColor: warnBg, borderRadius: 10, padding: 12, marginBottom: 10,
          }}
            accessible
            accessibilityLabel={`Some content could not be loaded: ${Object.keys(feed.errors).join(', ')}.`}
          >
            <Ionicons name="warning-outline" size={16} color={warnText} accessibilityElementsHidden style={{ marginTop: 1 }} />
            <Text style={{ flex: 1, fontSize: 13, color: warnText, lineHeight: 18 }}>
              Some sources could not be loaded. Pull down to retry.
            </Text>
          </View>
        )}

        {/* Section header */}
        <View style={{ flexDirection: 'row', alignItems: 'center', marginBottom: 10, marginTop: 4 }}>
          <Text
            style={{ flex: 1, fontSize: 13, fontWeight: '700', color: colors.textSecondary,
              textTransform: 'uppercase', letterSpacing: 0.8 }}
            accessibilityRole="header"
            accessibilityActions={[{ name: 'feedSummary', label: 'Feed summary' }]}
            onAccessibilityAction={() => AccessibilityInfo.announceForAccessibility(feedSummary)}
          >
            Latest Activity
          </Text>
          {feedLoadedAt && (
            <Text style={{ fontSize: 11, color: colors.textSecondary }} accessibilityElementsHidden>
              Updated {relativeTime(feedLoadedAt.toISOString())}
            </Text>
          )}
        </View>
      </>
    );
  }

  function renderFooter() {
    if (feed.isLoadingMore) {
      return (
        <View style={{ paddingVertical: 20, alignItems: 'center' }}>
          <ActivityIndicator color={colors.appleVisBlue} accessibilityLabel="Loading more" />
        </View>
      );
    }
    if (!feed.hasMore && feed.items.length > 0) {
      return (
        <Text style={{ textAlign: 'center', color: colors.textSecondary, fontSize: 13, paddingVertical: 20 }}
          accessible accessibilityLabel="You've reached the end."
          accessibilityLiveRegion="polite">
          You're all caught up.
        </Text>
      );
    }
    return <View style={{ height: 20 }} />;
  }

  return (
    <>
    <Tabs.Screen options={{ tabBarBadge: unreadCount > 0 ? unreadCount : undefined }} />
    <Screen
      title="Home"
      showBack={false}
      headerLeft={
        <Pressable
          onPress={() => setFilterVisible(true)}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Customize Home"
          accessibilityHint="Choose what content types appear on your Home screen"
          style={{ padding: 8 }}
        >
          <Ionicons name="options-outline" size={22} color={colors.accent} />
        </Pressable>
      }
    >
      {/* Loading state */}
      {feed.loading && (
        <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', paddingBottom: 80 }}>
          <ActivityIndicator size="large" color={colors.appleVisBlue} accessibilityLabel="Loading Home" />
          <Text style={[styles.lede, { marginTop: 14, textAlign: 'center' }]}>Loading…</Text>
        </View>
      )}

      {/* Empty state — all sources off or all failed */}
      {!feed.loading && feed.items.length === 0 && (
        <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 16 }}>
          <EmptyState
            icon="newspaper-outline"
            title="Nothing to show"
            subtitle="Turn on at least one content type using the Customize Home button above."
            action={{ label: 'Customize Home', onPress: () => setFilterVisible(true) }}
          />
        </View>
      )}

      {/* Feed */}
      {!feed.loading && feed.items.length > 0 && (
        <FlatList
          data={feed.items}
          keyExtractor={(item) => `${item.kind}-${item.data.id}`}
          accessibilityLabel="Activity feed"
          renderItem={({ item, index }) => {
            const key = `${item.kind}-${item.data.id}`;
            return (
              <FeedCard
                item={item}
                onPress={() => handleItemPress(item)}
                newCount={getNewCount(item)}
                accentColor={KIND_ACCENT[item.kind as FeedItem['kind']]}
                cardRef={(el) => {
                  itemRefs.current[key] = el;
                  if (index === 0) firstItemRef.current = el;
                }}
                onFocus={() => { lastFocusedBeforeModal.current = itemRefs.current[key]; }}
              />
            );
          }}
          ListHeaderComponent={renderHeader}
          ListFooterComponent={renderFooter}
          contentContainerStyle={{ padding: 16, paddingBottom: 100 }}
          onEndReached={() => feed.loadMore()}
          onEndReachedThreshold={0.3}
          refreshControl={
            <RefreshControl
              refreshing={feed.refreshing}
              onRefresh={feed.refresh}
              tintColor={colors.appleVisBlue}
              accessibilityLabel="Pull to refresh"
            />
          }
          ref={flatListRef}
          showsVerticalScrollIndicator
        />
      )}

      {/* Filter modal */}
      <FeedFilterModal
        visible={filterVisible}
        prefs={feed.prefs}
        onUpdate={feed.updatePref}
        headingRef={modalHeadingRef}
        onClose={() => {
          setFilterVisible(false);
          const target = lastFocusedBeforeModal.current ?? firstItemRef.current;
          if (target) {
            setTimeout(() => {
              const handle = findNodeHandle(target);
              if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
            }, 200);
          }
        }}
      />
    </Screen>
    </>
  );
}
