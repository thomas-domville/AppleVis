import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActivityIndicator, Pressable,
  RefreshControl, ScrollView, Text, TextInput, View,
} from 'react-native';
import { useFocusEffect, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { EmptyState } from '../src/components/EmptyState';
import { Screen } from '../src/components/Screen';
import { FeedCard } from '../src/components/FeedCard';
import { FilterPicker } from '../src/components/FilterPicker';
import { AutoLoadMoreFooter } from '../src/components/AutoLoadMoreFooter';
import { useForumState } from '../src/hooks/useForumState';
import type { ForumFilter } from '../src/hooks/useForumState';
import { useAutoLoadMore } from '../src/hooks/useAutoLoadMore';
import { useRefreshFeedback } from '../src/hooks/useRefreshFeedback';
import { useFocusRestore } from '../src/hooks/useFocusRestore';
import { useAccessibilityPreferences } from '../src/hooks/useAccessibilityPreferences';
import { useAuth } from '../src/contexts/AuthContext';
import { useAlert } from '../src/contexts/AccessibleAlertContext';
import { ALERTS } from '../src/data/alertMessages';
import { useTheme } from '../src/contexts/ThemeContext';
import { api } from '../src/services/api';
import { persistence } from '../src/services/persistence';
import { relativeTime } from '../src/utils/relativeTime';
import type { ForumTopic } from '../src/types/content';

// ─── Filter definitions ───────────────────────────────────────────────────────

const BASE_FILTERS = ['All Topics', 'Apple Related', 'Non-Apple Related'] as const;
type BaseFilter = typeof BASE_FILTERS[number];

const NON_APPLE_FORUM_TIDS = [265, 266, 267, 269];
const NON_APPLE_FORUM_NAMES = [
  'Windows',
  'Android',
  'Smart Home Tech and Gadgets',
  'Assistive Technology',
];

function isBaseFilter(f: string): f is BaseFilter {
  return (BASE_FILTERS as readonly string[]).includes(f);
}

function toForumFilter(f: string): ForumFilter {
  return 'Recent';
}

function isNonApple(category?: string): boolean {
  const c = (category ?? '').toLowerCase();
  return NON_APPLE_FORUM_NAMES.some((name) => c === name.toLowerCase()) ||
    c.includes('non-apple') ||
    c.includes('non apple');
}

const BASE_DESCRIPTIONS: Record<BaseFilter, string> = {
  'All Topics':        'All recent forum topics.',
  'Apple Related':     'Recent discussions about Apple products and software.',
  'Non-Apple Related': 'Recent discussions about non-Apple products.',
};

function filterDescription(f: string): string {
  return BASE_DESCRIPTIONS[f as BaseFilter] ?? `Recent discussions in ${f}.`;
}

// Indigo — matches home tab forum topic colour
const TOPIC_ACCENT = '#6366f1';

// ─── Screen ───────────────────────────────────────────────────────────────────

export default function ForumsBrowse() {
  const router             = useRouter();
  const { colors, styles } = useTheme();
  const auth               = useAuth();
  const forum              = useForumState();
  const { showAlert }      = useAlert();
  const a11y               = useAccessibilityPreferences();
  const topicRefs          = useRef<Map<string, View>>(new Map());
  const { save }           = useFocusRestore();

  const [browseFilter, setBrowseFilter] = useState<string>('All Topics');
  const [searchQuery,  setSearchQuery]  = useState('');

  // Drupal forum categories fetched once on mount
  const [categories, setCategories] = useState<Array<{ name: string; tid: number }>>([]);

  // Item-visit tracking — same approach as Home tab for new-reply badges
  const [itemVisits, setItemVisits] = useState<Record<string, { seenAt: string; commentCount: number }>>({});

  // When data last finished loading (for "Updated X ago" label)
  const [feedLoadedAt, setFeedLoadedAt] = useState<Date | null>(null);
  const prevLoadingRef = useRef(false);

  // State for category-specific (server-side) topic fetches
  const [catTopics,      setCatTopics]      = useState<ForumTopic[]>([]);
  const [catLoading,     setCatLoading]     = useState(false);
  const [catError,       setCatError]       = useState<string | null>(null);
  const [catHasMore,     setCatHasMore]     = useState(false);
  const [catPage,        setCatPage]        = useState(0);
  const [catLoadingMore, setCatLoadingMore] = useState(false);

  // Load category taxonomy once on mount
  useEffect(() => {
    api.forums.categories().then((res) => {
      if (res.ok) setCategories(res.data);
    });
  }, []);

  // Reload itemVisits whenever the screen comes into focus (same as Home tab)
  useFocusEffect(useCallback(() => {
    persistence.getAllItemVisits().then(setItemVisits);
  }, []));

  // Base 4 filters + all Drupal categories in one picker list
  const filterOptions = useMemo(
    () => [...BASE_FILTERS, ...categories.map((c) => c.name)],
    [categories],
  );

  const isSpecificCategory = !isBaseFilter(browseFilter);
  const isNonAppleGroup = browseFilter === 'Non-Apple Related';
  const usesCategoryTopics = isSpecificCategory || isNonAppleGroup;

  const selectedCategory = useMemo(
    () => (isSpecificCategory ? categories.find((c) => c.name === browseFilter) : undefined),
    [isSpecificCategory, categories, browseFilter],
  );
  const selectedTid = selectedCategory?.tid;
  const selectedTids = useMemo(() => {
    if (isNonAppleGroup) {
      const liveTids = categories
        .filter((category) => NON_APPLE_FORUM_NAMES.includes(category.name) || NON_APPLE_FORUM_TIDS.includes(category.tid))
        .map((category) => category.tid);
      return liveTids.length > 0 ? liveTids : NON_APPLE_FORUM_TIDS;
    }
    return selectedTid === undefined ? [] : [selectedTid];
  }, [categories, isNonAppleGroup, selectedTid]);

  // Sync broad-filter mode to useForumState
  useEffect(() => {
    if (usesCategoryTopics) return;
    forum.setFilter(toForumFilter(browseFilter));
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [browseFilter, usesCategoryTopics]);

  // Fetch topics when a specific category or grouped category filter is selected.
  useEffect(() => {
    if (!usesCategoryTopics || selectedTids.length === 0) return;
    setCatTopics([]);
    setCatPage(0);
    setCatHasMore(false);
    setCatError(null);
    setCatLoading(true);
    api.forums.listByCategories(selectedTids, 0).then((res) => {
      setCatLoading(false);
      if (res.ok) {
        setCatTopics(res.data.items);
        setCatHasMore(res.data.hasMore);
      } else {
        setCatError(res.error);
      }
    });
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [usesCategoryTopics, selectedTids]);

  const retryCategory = useCallback(() => {
    if (selectedTids.length === 0) return;
    setCatLoading(true);
    setCatError(null);
    api.forums.listByCategories(selectedTids, 0).then((res) => {
      setCatLoading(false);
      if (res.ok) { setCatTopics(res.data.items); setCatHasMore(res.data.hasMore); }
      else setCatError(res.error);
    });
  }, [selectedTids]);

  const loadMoreCategory = useCallback(async () => {
    if (selectedTids.length === 0 || catLoadingMore || !catHasMore) return;
    setCatLoadingMore(true);
    const nextPage = catPage + 1;
    const res = await api.forums.listByCategories(selectedTids, nextPage);
    setCatLoadingMore(false);
    if (res.ok) {
      setCatTopics((prev) => [...prev, ...res.data.items]);
      setCatHasMore(res.data.hasMore);
      setCatPage(nextPage);
    }
  }, [selectedTids, catLoadingMore, catHasMore, catPage]);

  useRefreshFeedback(
    forum.refreshing, 'Forums', forum.loading,
    () => topicRefs.current.get(forum.topics[0]?.id ?? '') ?? null,
  );

  const handleBrowseFilterChange = useCallback((f: string) => {
    setBrowseFilter(f);
    setSearchQuery('');
    setFeedLoadedAt(null);
    AccessibilityInfo.announceForAccessibility(filterDescription(f));
  }, []);

  // Source of truth depends on whether a specific category is selected
  const sourceTopics = usesCategoryTopics ? catTopics : forum.topics;

  // Full-text search across the source
  const searchedTopics = useMemo(() => {
    if (!searchQuery.trim()) return sourceTopics;
    const q = searchQuery.toLowerCase();
    return sourceTopics.filter((t) =>
      t.title.toLowerCase().includes(q) ||
      t.authorName.toLowerCase().includes(q),
    );
  }, [sourceTopics, searchQuery]);

  // Client-side Apple / Non-Apple slice on top of the broad 'Recent' feed
  const visibleTopics = useMemo(() => {
    if (browseFilter === 'Apple Related') return searchedTopics.filter((t) => t.category && !isNonApple(t.category));
    return searchedTopics;
  }, [searchedTopics, browseFilter]);

  // Unified status for the current mode
  const isLoading     = usesCategoryTopics ? catLoading     : forum.loading;
  const topicError    = usesCategoryTopics ? catError       : forum.error;
  const isLoadingMore = usesCategoryTopics ? catLoadingMore : forum.isLoadingMore;
  const showLoadMore  = usesCategoryTopics
    ? catHasMore
    : (forum.hasMore && browseFilter !== 'Apple Related');
  const handleLoadMore = usesCategoryTopics ? loadMoreCategory : forum.loadMore;
  const handleAutoLoadMore = useAutoLoadMore({
    hasMore: showLoadMore,
    isLoadingMore,
    onLoadMore: handleLoadMore,
    disabled: !!searchQuery.trim(),
  });

  // Track when data finishes loading for the "Updated X ago" label
  useEffect(() => {
    if (prevLoadingRef.current && !isLoading && sourceTopics.length > 0) {
      setFeedLoadedAt(new Date());
    }
    prevLoadingRef.current = isLoading;
  }, [isLoading, sourceTopics.length]);

  // New-reply count for a topic (same logic as Home tab)
  function getNewCount(topic: ForumTopic): number {
    const visit = itemVisits[topic.id];
    if (!visit) return 0;
    return Math.max(0, topic.replyCount - visit.commentCount);
  }

  // Feed summary text for the VoiceOver section-header action
  const feedSummaryLabel = useMemo(() => {
    if (visibleTopics.length === 0) return 'No topics loaded.';
    const label = `${visibleTopics.length} topic${visibleTopics.length !== 1 ? 's' : ''}`;
    return feedLoadedAt
      ? `${label}. Updated ${relativeTime(feedLoadedAt.toISOString())}.`
      : `${label}.`;
  }, [visibleTopics.length, feedLoadedAt]);

  // Category badge background — solid when reduceTransparency is on
  const categoryBg = a11y.reduceTransparency ? colors.inputBackground : TOPIC_ACCENT + '18';
  const categoryBadgeTitle = isNonAppleGroup ? 'Non-Apple Related' : selectedCategory?.name;

  return (
    <Screen
      title="Forums"
      refreshing={!usesCategoryTopics && forum.refreshing}
      headerLeft={
        <Pressable
          onPress={() => {
            if (!auth.isSignedIn) {
              showAlert({
                ...ALERTS.auth.signInRequired('start a new topic'),
                onConfirm: () => router.push('/settings-account' as any),
              });
              return;
            }
            router.push({ pathname: '/compose' as any, params: { mode: 'newTopic' } });
          }}
          accessible
          accessibilityRole="button"
          accessibilityLabel="New Topic"
          accessibilityHint={auth.isSignedIn ? 'Start a new forum topic' : 'Sign in to start a new forum topic'}
          style={{
            padding: 8, borderRadius: 10,
            backgroundColor: colors.inputBackground,
            borderWidth: 1, borderColor: colors.border,
          }}
        >
          <Ionicons name="create-outline" size={20} color={colors.accent} accessibilityElementsHidden />
        </Pressable>
      }
    >
      <ScrollView
        showsVerticalScrollIndicator
        onScroll={handleAutoLoadMore}
        scrollEventThrottle={120}
        refreshControl={
          !usesCategoryTopics ? (
            <RefreshControl
              refreshing={forum.refreshing}
              onRefresh={forum.refresh}
              tintColor={colors.appleVisBlue}
              accessibilityLabel="Pull to refresh forums"
            />
          ) : undefined
        }
      >
        {/* Search */}
        <View style={{
          flexDirection: 'row', alignItems: 'center',
          backgroundColor: colors.inputBackground, borderRadius: 10, borderWidth: 1,
          borderColor: colors.border, paddingHorizontal: 10, paddingVertical: 8, marginBottom: 10,
        }}>
          <Ionicons name="search" size={16} color={colors.textSecondary}
            style={{ marginRight: 6 }} accessibilityElementsHidden />
          <TextInput
            value={searchQuery}
            onChangeText={setSearchQuery}
            placeholder="Search topics…"
            placeholderTextColor={colors.textSecondary}
            style={{ flex: 1, fontSize: 15, color: colors.text }}
            accessible
            accessibilityLabel="Search topics"
            accessibilityHint="Type to filter topics by title or author name"
            returnKeyType="search"
            clearButtonMode="while-editing"
          />
        </View>

        {/* Filter — 4 broad options + all 17 Drupal categories */}
        <FilterPicker
          label="Filter Forums"
          value={browseFilter}
          options={filterOptions}
          onChange={handleBrowseFilterChange}
        />

        {/* Description — announced immediately on change */}
        <Text style={[styles.lede, { marginBottom: 12 }]}>
          {filterDescription(browseFilter)}
        </Text>

        {/* Category badge — shown when a specific Drupal category/group is selected */}
        {usesCategoryTopics && categoryBadgeTitle && !isLoading && (
          <View
            style={{
              flexDirection: 'row', alignItems: 'center', gap: 8,
              backgroundColor: categoryBg,
              borderRadius: 10, padding: 12, marginBottom: 10,
              borderWidth: a11y.reduceTransparency ? 1 : 0,
              borderColor: TOPIC_ACCENT + '40',
            }}
            accessible
            accessibilityLabel={`Browsing ${categoryBadgeTitle}${visibleTopics.length > 0 ? `, ${visibleTopics.length} topic${visibleTopics.length !== 1 ? 's' : ''} loaded` : ''}.`}
          >
            <Ionicons name="folder-outline" size={16} color={TOPIC_ACCENT} accessibilityElementsHidden />
            <Text style={{ flex: 1, fontSize: 14, fontWeight: '600', color: TOPIC_ACCENT }}>
              {categoryBadgeTitle}
            </Text>
            {visibleTopics.length > 0 && (
              <Text
                style={{ fontSize: 12, color: TOPIC_ACCENT, fontWeight: '500', opacity: 0.75 }}
                accessibilityElementsHidden
              >
                {visibleTopics.length} topic{visibleTopics.length !== 1 ? 's' : ''}
              </Text>
            )}
          </View>
        )}

        {/* Section header — shown once topics are loaded */}
        {!isLoading && visibleTopics.length > 0 && (
          <View style={{ flexDirection: 'row', alignItems: 'center', marginBottom: 10, marginTop: 4 }}>
            <Text
              style={{
                flex: 1, fontSize: 13, fontWeight: '700', color: colors.textSecondary,
                textTransform: 'uppercase', letterSpacing: 0.8,
              }}
              accessibilityRole="header"
              accessibilityActions={[{ name: 'feedSummary', label: 'Feed summary' }]}
              onAccessibilityAction={() => AccessibilityInfo.announceForAccessibility(feedSummaryLabel)}
            >
              {usesCategoryTopics ? (categoryBadgeTitle ?? browseFilter) : 'Latest Topics'}
            </Text>
            {feedLoadedAt && (
              <Text
                style={{ fontSize: 11, color: colors.textSecondary }}
                accessibilityElementsHidden
              >
                Updated {relativeTime(feedLoadedAt.toISOString())}
              </Text>
            )}
          </View>
        )}

        {/* Loading */}
        {isLoading && (
          <View
            accessible
            accessibilityLiveRegion="polite"
            accessibilityLabel="Loading topics, please wait"
            style={{ alignItems: 'center', paddingVertical: 32 }}
          >
            <ActivityIndicator size="large" color={colors.appleVisBlue} />
            <Text style={[styles.lede, { marginTop: 12, textAlign: 'center' }]}>
              Loading topics…
            </Text>
          </View>
        )}

        {/* Error */}
        {!isLoading && topicError && (
          <View style={[styles.card, { backgroundColor: '#FFF0F0' }]}>
            <Text style={[styles.cardTitle, { color: '#D00' }]}>Could not load topics</Text>
            <Text style={styles.cardMeta}>{topicError}</Text>
            <Pressable
              onPress={usesCategoryTopics ? retryCategory : forum.refresh}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Retry loading topics"
              style={{ marginTop: 12 }}
            >
              <Text style={{ color: colors.appleVisBlue, fontWeight: '700' }}>Retry</Text>
            </Pressable>
          </View>
        )}

        {/* Empty — nothing loaded from source */}
        {!isLoading && !topicError && sourceTopics.length === 0 && (
          <EmptyState
            icon="chatbubbles-outline"
            title="No topics"
            subtitle={
              usesCategoryTopics && selectedTids.length === 0
                ? 'Loading category list…'
                : 'No topics found. Pull down to try again.'
            }
          />
        )}

        {/* Empty — search or broad filter narrowed results to zero */}
        {!isLoading && sourceTopics.length > 0 && visibleTopics.length === 0 && (
          <EmptyState
            icon="search-outline"
            title="No results"
            subtitle={
              searchQuery.trim()
                ? `No topics match "${searchQuery}".`
                : `No ${browseFilter} topics found.`
            }
          />
        )}

        {/* Topic list — same FeedCard used on the Home tab, with new-reply badges */}
        {!isLoading && visibleTopics.map((topic) => (
          <FeedCard
            key={topic.id}
            item={{ kind: 'topic', data: topic, activityAt: topic.lastActivityAt }}
            cardRef={(el: View | null) => {
              if (el) topicRefs.current.set(topic.id, el);
              else topicRefs.current.delete(topic.id);
            }}
            accentColor={TOPIC_ACCENT}
            newCount={getNewCount(topic)}
            onPress={() => {
              save(topicRefs.current.get(topic.id) ?? null);
              router.push({ pathname: '/topic/[id]' as any, params: { id: topic.id, title: topic.title } });
            }}
          />
        ))}

        <AutoLoadMoreFooter isLoadingMore={isLoadingMore} label="Loading more topics" />

        {/* End-of-feed indicator */}
        {!isLoading && !showLoadMore && visibleTopics.length > 0 && (
          <Text
            style={{ textAlign: 'center', color: colors.textSecondary, fontSize: 13, paddingVertical: 20 }}
            accessible
            accessibilityLabel={`${visibleTopics.length} topic${visibleTopics.length !== 1 ? 's' : ''} loaded.`}
            accessibilityLiveRegion="polite"
          >
            {visibleTopics.length} topic{visibleTopics.length !== 1 ? 's' : ''} loaded
          </Text>
        )}

        <View style={{ height: 120 }} />
      </ScrollView>
    </Screen>
  );
}
