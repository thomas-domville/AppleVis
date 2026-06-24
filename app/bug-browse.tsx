import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActionSheetIOS, ActivityIndicator, Clipboard,
  findNodeHandle, Linking, Platform,
  Pressable, RefreshControl, ScrollView, Share, StyleSheet, Text, TextInput, View,
} from 'react-native';
import { useFocusEffect, useLocalSearchParams, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { Screen } from '../src/components/Screen';
import { EmptyState } from '../src/components/EmptyState';
import { AutoLoadMoreFooter } from '../src/components/AutoLoadMoreFooter';
import { FilterPicker } from '../src/components/FilterPicker';
import { useAutoLoadMore } from '../src/hooks/useAutoLoadMore';
import { useRefreshFeedback } from '../src/hooks/useRefreshFeedback';
import { useFocusRestore } from '../src/hooks/useFocusRestore';
import { useTheme } from '../src/contexts/ThemeContext';
import { useToast } from '../src/contexts/ToastContext';
import { usePreferences } from '../src/contexts/PreferencesContext';
import { useAccessibilityPreferences } from '../src/hooks/useAccessibilityPreferences';
import { cachedApi } from '../src/services/cachedApi';
import { relativeTime } from '../src/utils/relativeTime';
import type { BugReport } from '../src/types/content';

// ─── Accent + label maps ──────────────────────────────────────────────────────

const BUG_ACCENT = '#f97316';

const SEVERITY_CONFIG: Record<BugReport['severity'], { label: string; color: string; bg: string }> = {
  low:    { label: 'Low',    color: '#16a34a', bg: '#dcfce7' },
  medium: { label: 'Medium', color: '#d97706', bg: '#fef3c7' },
  high:   { label: 'High',   color: '#dc2626', bg: '#fee2e2' },
};

const STATUS_CONFIG: Record<BugReport['status'], { label: string; color: string; icon: string }> = {
  active: { label: 'Active', color: '#f97316', icon: 'ellipse'        },
  fixed:  { label: 'Fixed',  color: '#16a34a', icon: 'checkmark-circle' },
};

type BugPlatform = 'ios' | 'macos';
type Filter      = 'active' | 'all';

const FILTER_OPTIONS = ['Active', 'All Bugs'] as const;
type FilterLabel = typeof FILTER_OPTIONS[number];
const FILTER_TO_API: Record<FilterLabel, Filter> = { 'Active': 'active', 'All Bugs': 'all' };

// ─── Bug card ─────────────────────────────────────────────────────────────────

function BugCard({
  bug, onPress, onOpenWeb, onReportToApple, cardRef, announcementLevel,
}: {
  bug: BugReport;
  onPress: () => void;
  onOpenWeb: () => void;
  onReportToApple: () => void;
  cardRef?: (el: View | null) => void;
  announcementLevel: 'simple' | 'normal' | 'all';
}) {
  const { colors, styles } = useTheme();
  const { reduceTransparency } = useAccessibilityPreferences();
  const sev    = SEVERITY_CONFIG[bug.severity];
  const status = STATUS_CONFIG[bug.status];

  const a11yLabel = announcementLevel === 'simple'
    ? `${bug.title}. ${status.label}.`
    : [
        bug.title,
        `Severity: ${sev.label}`,
        `Status: ${status.label}`,
        bug.firstSeen ? `First seen in ${bug.firstSeen}` : null,
        bug.fixedIn   ? `Fixed in ${bug.fixedIn}` : null,
        bug.commentCount > 0 ? `${bug.commentCount} comment${bug.commentCount !== 1 ? 's' : ''}` : null,
        `Reported ${relativeTime(bug.createdAt)}`,
        `Last updated ${relativeTime(bug.changedAt)}`,
      ].filter(Boolean).join('. ');

  const actions = [
    {
      label: 'Share this Bug Report',
      onPress: () => Share.share({ title: bug.title, url: bug.url }).catch(() => {}),
    },
    {
      label: 'Report to Apple',
      onPress: onReportToApple,
    },
    {
      label: 'Open on AppleVis',
      onPress: onOpenWeb,
    },
    {
      label: 'Copy Link',
      onPress: () => Clipboard.setString(bug.url),
    },
  ];

  function handleLongPress() {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    if (Platform.OS === 'ios') {
      ActionSheetIOS.showActionSheetWithOptions(
        {
          title: bug.title,
          options: ['Cancel', ...actions.map(a => a.label)],
          cancelButtonIndex: 0,
        },
        (index) => {
          if (index > 0) actions[index - 1].onPress();
        },
      );
    } else {
      actions[0].onPress();
    }
  }

  return (
    <Pressable
      ref={cardRef as any}
      onPress={() => { Haptics.selectionAsync(); onPress(); }}
      onLongPress={handleLongPress}
      delayLongPress={400}
      accessible
      accessibilityRole="button"
      accessibilityLabel={a11yLabel}
      accessibilityHint="Double tap to open. Hold for options."
      accessibilityActions={actions.map(a => ({ name: a.label }))}
      onAccessibilityAction={({ nativeEvent }) => {
        const action = actions.find(a => a.label === nativeEvent.actionName);
        action?.onPress();
      }}
      style={({ pressed }) => [
        styles.card,
        {
          marginBottom: 10, opacity: pressed ? 0.75 : 1,
          overflow: 'hidden', padding: 0,
          borderLeftWidth: 4,
          borderLeftColor: bug.status === 'active' ? BUG_ACCENT : '#16a34a',
        },
      ]}
    >
      {/* Accent tint — subtle background wash behind the card content */}
      {!reduceTransparency && (
        <View
          style={{
            ...StyleSheet.absoluteFillObject,
            backgroundColor: bug.status === 'active' ? BUG_ACCENT : '#16a34a',
            opacity: 0.04,
          }}
          accessibilityElementsHidden
          importantForAccessibility="no-hide-descendants"
        />
      )}

      <View style={{ padding: 14 }}>
      {/* Top row: severity pill + status badge */}
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 8 }}>
        <View style={{
          backgroundColor: reduceTransparency ? colors.inputBackground : sev.bg,
          borderRadius: 6, paddingHorizontal: 8, paddingVertical: 3,
        }}>
          <Text style={{ fontSize: 11, fontWeight: '700', color: sev.color, letterSpacing: 0.3 }}
            accessibilityElementsHidden>
            {sev.label}
          </Text>
        </View>

        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
          <Ionicons name={status.icon as any} size={10} color={status.color} accessibilityElementsHidden />
          <Text style={{ fontSize: 11, fontWeight: '600', color: status.color }}
            accessibilityElementsHidden>
            {status.label}
          </Text>
        </View>
      </View>

      {/* Title */}
      <Text
        style={{ fontSize: 16, fontWeight: '600', color: colors.text, lineHeight: 22, marginBottom: 8 }}
        numberOfLines={3}
        accessibilityElementsHidden
      >
        {bug.title}
      </Text>

      {/* Version row */}
      {(bug.firstSeen || bug.fixedIn) && (
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 12, marginBottom: 8 }}>
          {bug.firstSeen ? (
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
              <Ionicons name="alert-circle-outline" size={12} color={colors.textSecondary} accessibilityElementsHidden />
              <Text style={{ fontSize: 12, color: colors.textSecondary }} accessibilityElementsHidden>
                First seen: {bug.firstSeen}
              </Text>
            </View>
          ) : null}
          {bug.fixedIn ? (
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
              <Ionicons name="checkmark-circle-outline" size={12} color="#16a34a" accessibilityElementsHidden />
              <Text style={{ fontSize: 12, color: '#16a34a' }} accessibilityElementsHidden>
                Fixed: {bug.fixedIn}
              </Text>
            </View>
          ) : null}
        </View>
      )}

      {/* Reported · Updated dates */}
      <View
        style={{ flexDirection: 'row', alignItems: 'center', gap: 6, marginBottom: 6 }}
        accessible
        accessibilityLabel={`Reported ${relativeTime(bug.createdAt)}. Last updated ${relativeTime(bug.changedAt)}.`}
      >
        <Ionicons name="calendar-outline" size={11} color={colors.textSecondary} accessibilityElementsHidden />
        <Text style={{ fontSize: 11, color: colors.textSecondary }} accessibilityElementsHidden>
          Reported {relativeTime(bug.createdAt)}
        </Text>
        <Text style={{ fontSize: 11, color: colors.textSecondary }} accessibilityElementsHidden>·</Text>
        <Ionicons name="refresh-outline" size={11} color={colors.textSecondary} accessibilityElementsHidden />
        <Text style={{ fontSize: 11, color: colors.textSecondary }} accessibilityElementsHidden>
          Updated {relativeTime(bug.changedAt)}
        </Text>
      </View>

      {/* Footer: comments + chevron */}
      <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 2 }}>
        {bug.commentCount > 0 && (
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
            <Ionicons name="chatbubble-outline" size={13} color={colors.textSecondary} accessibilityElementsHidden />
            <Text style={{ fontSize: 12, color: colors.textSecondary }} accessibilityElementsHidden>
              {bug.commentCount}
            </Text>
          </View>
        )}
        <View style={{ flex: 1 }} />
        <Ionicons name="chevron-forward" size={14} color={colors.textSecondary} accessibilityElementsHidden />
      </View>
      </View>{/* end padding wrapper */}
    </Pressable>
  );
}

// ─── Main screen ──────────────────────────────────────────────────────────────

export default function BugBrowse() {
  const router             = useRouter();
  const params             = useLocalSearchParams<{ platform?: string }>();
  const { colors, styles }      = useTheme();
  const { showToast }           = useToast();
  const { save }                = useFocusRestore();
  const { announcementLevel }   = usePreferences();

  const initialPlatform = (params.platform === 'macos' ? 'macos' : 'ios') as BugPlatform;
  const [platform]             = useState<BugPlatform>(initialPlatform);
  const [filterLabel,    setFilterLabel]    = useState<FilterLabel>('Active');
  const [searchQuery,    setSearchQuery]    = useState('');
  const [bugs,           setBugs]           = useState<BugReport[]>([]);
  const [loading,        setLoading]        = useState(true);
  const [refreshing,     setRefreshing]     = useState(false);
  const [isLoadingMore,  setIsLoadingMore]  = useState(false);
  const [hasMore,        setHasMore]        = useState(false);
  const [error,          setError]          = useState<string | null>(null);
  const [page,           setPage]           = useState(0);
  const [feedLoadedAt,   setFeedLoadedAt]   = useState<Date | null>(null);

  const cardRefs       = useRef<Map<string, View>>(new Map());
  const firstCardRef   = useRef<View | null>(null);
  const didFocusFirst  = useRef(false);

  const screenTitle = platform === 'ios' ? 'iOS Bug Tracker' : 'macOS Bug Tracker';

  async function loadBugs(flt: Filter, pg: number, isRefresh = false) {
    if (isRefresh) setRefreshing(true);
    else if (pg === 0) setLoading(true);
    else setIsLoadingMore(true);
    setError(null);

    const res = await cachedApi.bugs.list(platform, flt, pg);

    if (res.ok) {
      setBugs((prev) => pg === 0 ? res.data.items : [...prev, ...res.data.items]);
      setHasMore(res.data.hasMore);
      if (pg === 0) setFeedLoadedAt(new Date());
    } else {
      setError(res.error);
    }

    if (isRefresh) setRefreshing(false);
    else if (pg === 0) setLoading(false);
    else setIsLoadingMore(false);
  }

  useFocusEffect(useCallback(() => {
    didFocusFirst.current = false;
    setPage(0);
    setBugs([]);
    loadBugs(FILTER_TO_API[filterLabel], 0);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filterLabel]));

  function handleFilterChange(lbl: FilterLabel) {
    setFilterLabel(lbl);
    setSearchQuery('');
    didFocusFirst.current = false;
  }

  function handleRefresh() {
    setPage(0);
    loadBugs(FILTER_TO_API[filterLabel], 0, true);
  }

  function handleLoadMore() {
    if (!hasMore || isLoadingMore || searchQuery.trim()) return;
    const nextPage = page + 1;
    setPage(nextPage);
    loadBugs(FILTER_TO_API[filterLabel], nextPage);
  }

  useRefreshFeedback(
    refreshing, screenTitle, loading,
    () => firstCardRef.current ?? cardRefs.current.get(bugs[0]?.id ?? '') ?? null,
  );

  useEffect(() => {
    if (didFocusFirst.current || loading || bugs.length === 0) return;
    const timer = setTimeout(() => {
      const handle = findNodeHandle(firstCardRef.current);
      if (handle) {
        didFocusFirst.current = true;
        AccessibilityInfo.setAccessibilityFocus(handle);
      }
    }, 450);
    return () => clearTimeout(timer);
  }, [loading, bugs.length]);

  const visibleBugs = useMemo(() => {
    if (!searchQuery.trim()) return bugs;
    const q = searchQuery.toLowerCase();
    return bugs.filter((b) => b.title.toLowerCase().includes(q));
  }, [bugs, searchQuery]);

  const feedSummaryLabel = useMemo(() => {
    const count = visibleBugs.length;
    if (count === 0) return 'No bugs loaded.';
    const label = `${count} bug report${count !== 1 ? 's' : ''}`;
    return feedLoadedAt
      ? `${label}. Updated ${relativeTime(feedLoadedAt.toISOString())}.`
      : `${label}.`;
  }, [visibleBugs.length, feedLoadedAt]);

  const handleAutoLoadMore = useAutoLoadMore({
    hasMore: hasMore && !searchQuery.trim(),
    isLoadingMore,
    onLoadMore: handleLoadMore,
  });

  const platformLabel = platform === 'ios' ? 'iOS/iPadOS' : 'macOS';
  const sectionTitle = filterLabel === 'Active'
    ? `Active ${platformLabel} Bugs`
    : `All ${platformLabel} Bugs`;

  function bugOpenWebHandler(bug: BugReport) {
    return () => {
      Linking.openURL(bug.url).catch(() => showToast('Could not open the bug report.', 'error'));
    };
  }

  function bugReportToAppleHandler() {
    return () => {
      Linking.openURL('https://feedbackassistant.apple.com/')
        .catch(() => showToast('Could not open Feedback Assistant.', 'error'));
    };
  }

  return (
    <Screen title={screenTitle} showBack>
      <ScrollView
        showsVerticalScrollIndicator
        onScroll={handleAutoLoadMore}
        scrollEventThrottle={120}
        contentContainerStyle={{ paddingBottom: 40 }}
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            onRefresh={handleRefresh}
            tintColor={BUG_ACCENT}
            accessibilityLabel="Pull to refresh bug reports"
          />
        }
      >
        {/* Active / All Bugs filter picker */}
        <FilterPicker
          label="Filter"
          value={filterLabel}
          options={FILTER_OPTIONS}
          onChange={handleFilterChange}
        />

        {/* Search */}
        <View style={{
          flexDirection: 'row', alignItems: 'center',
          backgroundColor: colors.inputBackground, borderRadius: 10, borderWidth: 1,
          borderColor: colors.border, paddingHorizontal: 10, paddingVertical: 8, marginBottom: 12,
        }}>
          <Ionicons name="search" size={16} color={colors.textSecondary}
            style={{ marginRight: 6 }} accessibilityElementsHidden />
          <TextInput
            value={searchQuery}
            onChangeText={setSearchQuery}
            placeholder="Search bug reports…"
            placeholderTextColor={colors.textSecondary}
            style={{ flex: 1, fontSize: 15, color: colors.text }}
            accessible
            accessibilityLabel="Search bug reports"
            accessibilityHint="Type to filter reports by title"
            returnKeyType="search"
            clearButtonMode="while-editing"
          />
        </View>

        {/* Section header */}
        {!loading && visibleBugs.length > 0 && (
          <View style={{
            flexDirection: 'row', alignItems: 'center', marginBottom: 10,
            backgroundColor: colors.inputBackground,
            borderRadius: 10, borderWidth: 1, borderColor: colors.border,
            paddingHorizontal: 12, paddingVertical: 8,
          }}>
            <View
              style={{ width: 8, height: 8, borderRadius: 4, backgroundColor: BUG_ACCENT, marginRight: 8 }}
              accessibilityElementsHidden
            />
            <Text
              style={{
                flex: 1, fontSize: 13, fontWeight: '700', color: colors.text,
                textTransform: 'uppercase', letterSpacing: 0.7,
              }}
              accessibilityRole="header"
              accessibilityActions={[{ name: 'feedSummary', label: 'Feed summary' }]}
              onAccessibilityAction={() => AccessibilityInfo.announceForAccessibility(feedSummaryLabel)}
            >
              {sectionTitle}
            </Text>
            <View style={{
              backgroundColor: BUG_ACCENT,
              borderRadius: 10, paddingHorizontal: 8, paddingVertical: 2,
            }}
              accessibilityElementsHidden
            >
              <Text style={{ fontSize: 12, fontWeight: '700', color: '#fff' }}>
                {visibleBugs.length}
              </Text>
            </View>
          </View>
        )}

        {/* Loading */}
        {loading && (
          <View
            accessible
            accessibilityLiveRegion="polite"
            accessibilityLabel="Loading bug reports, please wait"
            style={{ alignItems: 'center', paddingVertical: 40 }}
          >
            <ActivityIndicator size="large" color={BUG_ACCENT} />
            <Text style={[styles.lede, { marginTop: 12, textAlign: 'center' }]}>
              Loading bug reports…
            </Text>
          </View>
        )}

        {/* Error */}
        {!loading && error && (
          <View style={[styles.card, { backgroundColor: colors.inputBackground }]}>
            <Text style={[styles.cardTitle, { color: '#dc2626' }]}>Could not load bug reports</Text>
            <Text style={[styles.cardMeta, { marginBottom: 12 }]}>{error}</Text>
            <Pressable
              onPress={handleRefresh}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Retry loading bug reports"
            >
              <Text style={{ color: BUG_ACCENT, fontWeight: '700' }}>Retry</Text>
            </Pressable>
          </View>
        )}

        {/* Empty states */}
        {!loading && !error && bugs.length === 0 && (
          <EmptyState
            icon="bug-outline"
            title="No bug reports"
            subtitle={filterLabel === 'Active'
              ? `No active ${platformLabel} bugs found. Pull down to refresh.`
              : `No ${platformLabel} bug reports found.`}
          />
        )}
        {!loading && bugs.length > 0 && visibleBugs.length === 0 && (
          <EmptyState
            icon="search-outline"
            title="No results"
            subtitle={`No bug reports match "${searchQuery}".`}
          />
        )}

        {/* Bug cards */}
        {!loading && visibleBugs.map((bug, index) => (
          <BugCard
            key={bug.id}
            bug={bug}
            cardRef={(el) => {
              if (el) cardRefs.current.set(bug.id, el);
              else cardRefs.current.delete(bug.id);
              if (index === 0) firstCardRef.current = el;
            }}
            onPress={() => {
              save(cardRefs.current.get(bug.id) ?? null);
              router.push({
                pathname: '/bug-detail/[id]' as any,
                params: { id: bug.id, platform: bug.platform, title: bug.title, url: bug.url },
              });
            }}
            onOpenWeb={bugOpenWebHandler(bug)}
            onReportToApple={bugReportToAppleHandler()}
            announcementLevel={announcementLevel}
          />
        ))}

        <AutoLoadMoreFooter isLoadingMore={isLoadingMore} label="Loading more bug reports" />

        {/* End of feed */}
        {!loading && !hasMore && visibleBugs.length > 0 && !searchQuery.trim() && (
          <Text
            style={{ textAlign: 'center', color: colors.textSecondary, fontSize: 13, paddingVertical: 20 }}
            accessible
            accessibilityLabel={`${visibleBugs.length} bug report${visibleBugs.length !== 1 ? 's' : ''} loaded.`}
            accessibilityLiveRegion="polite"
          >
            {visibleBugs.length} report{visibleBugs.length !== 1 ? 's' : ''} loaded
          </Text>
        )}

        {/* Submit bug CTA */}
        {!loading && (
          <Pressable
            onPress={() => {
              Haptics.selectionAsync();
              Linking.openURL('https://applevis.com/form/community-bug-report-form')
                .catch(() => showToast('Could not open the bug report form.', 'error'));
            }}
            accessible
            accessibilityRole="link"
            accessibilityLabel="Submit a bug report. Opens the AppleVis bug report form in your browser."
            style={({ pressed }) => [
              styles.card,
              {
                flexDirection: 'row', alignItems: 'center', gap: 12,
                borderStyle: 'dashed', borderWidth: 1.5, borderColor: BUG_ACCENT,
                backgroundColor: 'transparent', opacity: pressed ? 0.7 : 1,
                marginTop: 8,
              },
            ]}
          >
            <Ionicons name="bug-outline" size={22} color={BUG_ACCENT} accessibilityElementsHidden />
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: 15, fontWeight: '600', color: BUG_ACCENT }}>
                Submit a Bug Report
              </Text>
              <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2 }}>
                Found a bug? Share it with the AppleVis community.
              </Text>
            </View>
            <Ionicons name="open-outline" size={15} color={BUG_ACCENT} accessibilityElementsHidden />
          </Pressable>
        )}

        <View style={{ height: 40 }} />
      </ScrollView>
    </Screen>
  );
}
