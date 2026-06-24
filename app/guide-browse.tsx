import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActivityIndicator, findNodeHandle, Pressable,
  RefreshControl, ScrollView, Text, TextInput, View,
} from 'react-native';
import { useFocusEffect, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { EmptyState } from '../src/components/EmptyState';
import { Screen } from '../src/components/Screen';
import { FeedCard } from '../src/components/FeedCard';
import { FilterPicker } from '../src/components/FilterPicker';
import { AutoLoadMoreFooter } from '../src/components/AutoLoadMoreFooter';
import { useResourceList } from '../src/hooks/useResourceList';
import { useAutoLoadMore } from '../src/hooks/useAutoLoadMore';
import { useRefreshFeedback } from '../src/hooks/useRefreshFeedback';
import { useFocusRestore } from '../src/hooks/useFocusRestore';
import { useTheme } from '../src/contexts/ThemeContext';
import { persistence } from '../src/services/persistence';
import { relativeTime } from '../src/utils/relativeTime';
import type { Resource } from '../src/types/content';

// ─── Filter definitions ───────────────────────────────────────────────────────

const GUIDE_FILTERS = [
  'All', 'Apps', 'iOS', 'iPadOS', 'iPhone', 'iPad', 'macOS', 'VoiceOver',
  'Braille', 'Accessories', 'Gaming', 'Programming', 'Miscellaneous',
] as const;
type GuideFilter = typeof GUIDE_FILTERS[number];

const GUIDE_FILTER_TIDS: Record<GuideFilter, number[]> = {
  All:           [],
  Apps:          [27, 28, 115],
  iOS:           [26],
  iPadOS:        [244],
  iPhone:        [93],
  iPad:          [92],
  macOS:         [114],
  VoiceOver:     [101],
  Braille:       [88],
  Accessories:   [97],
  Gaming:        [90],
  Programming:   [194, 195],
  Miscellaneous: [31],
};

const GUIDE_DESCRIPTIONS: Record<GuideFilter, string> = {
  All:           'All guides and resources.',
  Apps:          'Guides tagged for iOS, iPadOS, Mac, or iTunes apps.',
  iOS:           'Guides tagged for iOS.',
  iPadOS:        'Guides tagged for iPadOS.',
  iPhone:        'Guides tagged for iPhone.',
  iPad:          'Guides tagged for iPad.',
  macOS:         'Guides tagged for macOS.',
  VoiceOver:     'Guides tagged for VoiceOver.',
  Braille:       'Guides tagged for Braille.',
  Accessories:   'Guides tagged for accessories.',
  Gaming:        'Guides tagged for gaming.',
  Programming:   'Guides tagged for iOS or macOS programming.',
  Miscellaneous: 'Guides tagged as miscellaneous.',
};

// Emerald green — matches home tab guide colour
const GUIDE_ACCENT = '#10b981';

// ─── Screen ───────────────────────────────────────────────────────────────────

export default function GuideBrowse() {
  const router             = useRouter();
  const { colors, styles } = useTheme();
  const cardRefs           = useRef<Map<string, View>>(new Map());
  const firstGuideRef      = useRef<View | null>(null);
  const didFocusFirstGuide = useRef(false);
  const { save }           = useFocusRestore();

  const [guideFilter,  setGuideFilter]  = useState<GuideFilter>('All');
  const [searchQuery,  setSearchQuery]  = useState('');
  const [itemVisits,   setItemVisits]   = useState<Record<string, { seenAt: string; commentCount: number }>>({});
  const [feedLoadedAt, setFeedLoadedAt] = useState<Date | null>(null);
  const prevLoadingRef = useRef(false);
  const selectedCategoryTids = useMemo(() => GUIDE_FILTER_TIDS[guideFilter], [guideFilter]);
  const resources = useResourceList(selectedCategoryTids);

  // Reload visit history when screen comes into focus
  useFocusEffect(useCallback(() => {
    persistence.getAllItemVisits().then(setItemVisits);
  }, []));

  // Track when data finishes loading
  useEffect(() => {
    if (prevLoadingRef.current && !resources.loading && resources.resources.length > 0) {
      setFeedLoadedAt(new Date());
    }
    prevLoadingRef.current = resources.loading;
  }, [resources.loading, resources.resources.length]);

  useRefreshFeedback(
    resources.refreshing, 'Guides', resources.loading,
    () => firstGuideRef.current ?? cardRefs.current.get(resources.resources[0]?.id ?? '') ?? null,
  );

  const handleGuideFilterChange = useCallback((f: GuideFilter) => {
    setGuideFilter(f);
    setSearchQuery('');
    AccessibilityInfo.announceForAccessibility(GUIDE_DESCRIPTIONS[f]);
  }, []);

  const visibleResources = useMemo(() => {
    if (!searchQuery.trim()) return resources.resources;
    const q = searchQuery.toLowerCase();
    return resources.resources.filter((r) => r.title.toLowerCase().includes(q));
  }, [resources.resources, searchQuery]);

  useEffect(() => {
    if (didFocusFirstGuide.current) return;
    if (resources.loading || visibleResources.length === 0) return;

    const timer = setTimeout(() => {
      const handle = findNodeHandle(firstGuideRef.current);
      if (handle) {
        didFocusFirstGuide.current = true;
        AccessibilityInfo.setAccessibilityFocus(handle);
      }
    }, 450);

    return () => clearTimeout(timer);
  }, [resources.loading, visibleResources.length]);

  // New-comment count
  function getNewCount(resource: Resource): number {
    const visit = itemVisits[resource.id];
    if (!visit) return 0;
    return Math.max(0, resource.commentCount - visit.commentCount);
  }

  const feedSummaryLabel = useMemo(() => {
    if (visibleResources.length === 0) return 'No resources loaded.';
    const label = `${visibleResources.length} resource${visibleResources.length !== 1 ? 's' : ''}`;
    return feedLoadedAt
      ? `${label}. Updated ${relativeTime(feedLoadedAt.toISOString())}.`
      : `${label}.`;
  }, [visibleResources.length, feedLoadedAt]);

  const showLoadMore = resources.hasMore && !searchQuery.trim();
  const handleAutoLoadMore = useAutoLoadMore({
    hasMore: showLoadMore,
    isLoadingMore: resources.isLoadingMore,
    onLoadMore: resources.loadMore,
  });
  const isFiltered = guideFilter !== 'All' || !!searchQuery.trim();

  return (
    <Screen
      title="Guides and Resources"
      refreshing={resources.refreshing}
    >
      <ScrollView
        showsVerticalScrollIndicator
        onScroll={handleAutoLoadMore}
        scrollEventThrottle={120}
        refreshControl={
          <RefreshControl
            refreshing={resources.refreshing}
            onRefresh={resources.refresh}
            tintColor={colors.appleVisBlue}
            accessibilityLabel="Pull to refresh guides and resources"
          />
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
            placeholder="Search guides…"
            placeholderTextColor={colors.textSecondary}
            style={{ flex: 1, fontSize: 15, color: colors.text }}
            accessible
            accessibilityLabel="Search guides and resources"
            accessibilityHint="Type to filter by title"
            returnKeyType="search"
            clearButtonMode="while-editing"
          />
        </View>

        {/* Kind filter */}
        <FilterPicker
          label="Filter by Category"
          value={guideFilter}
          options={GUIDE_FILTERS}
          onChange={handleGuideFilterChange}
        />

        {/* Filter description */}
        <Text style={[styles.lede, { marginBottom: 12 }]}>
          {GUIDE_DESCRIPTIONS[guideFilter]}
        </Text>

        {/* Section header */}
        {!resources.loading && visibleResources.length > 0 && (
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
              {guideFilter === 'All' ? 'Guides and Resources' : guideFilter}
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
        {resources.loading && (
          <View
            accessible
            accessibilityLiveRegion="polite"
            accessibilityLabel="Loading guides and resources, please wait"
            style={{ alignItems: 'center', paddingVertical: 32 }}
          >
            <ActivityIndicator size="large" color={colors.appleVisBlue} />
            <Text style={[styles.lede, { marginTop: 12, textAlign: 'center' }]}>
              Loading resources…
            </Text>
          </View>
        )}

        {/* Error */}
        {!resources.loading && resources.error && (
          <View style={[styles.card, { backgroundColor: '#FFF0F0' }]}>
            <Text style={[styles.cardTitle, { color: '#D00' }]}>Could not load resources</Text>
            <Text style={styles.cardMeta}>{resources.error}</Text>
            <Pressable
              onPress={resources.refresh}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Retry loading resources"
              style={{ marginTop: 12 }}
            >
              <Text style={{ color: colors.appleVisBlue, fontWeight: '700' }}>Retry</Text>
            </Pressable>
          </View>
        )}

        {/* Empty — nothing loaded */}
        {!resources.loading && !resources.error && resources.resources.length === 0 && !isFiltered && (
          <EmptyState
            icon="book-outline"
            title="No resources"
            subtitle="No guides or resources could be loaded. Pull down to try again."
          />
        )}

        {/* Empty — filter or search narrowed to zero */}
        {!resources.loading && isFiltered && visibleResources.length === 0 && (
          <EmptyState
            icon="search-outline"
            title="No results"
            subtitle={
              searchQuery.trim()
                ? `No resources match "${searchQuery}".`
                : `No ${guideFilter.toLowerCase()} guides found.`
            }
          />
        )}

        {/* Resource cards */}
        {!resources.loading && visibleResources.map((resource, index) => (
          <FeedCard
            key={resource.id}
            item={{ kind: 'guide', data: resource, activityAt: resource.updatedAt }}
            cardRef={(el: View | null) => {
              if (el) cardRefs.current.set(resource.id, el);
              else cardRefs.current.delete(resource.id);
              if (index === 0) firstGuideRef.current = el;
            }}
            accentColor={GUIDE_ACCENT}
            newCount={getNewCount(resource)}
            onPress={() => {
              save(cardRefs.current.get(resource.id) ?? null);
              router.push({
                pathname: '/resource-detail/[id]' as any,
                params: { id: resource.id, title: resource.title, url: resource.url },
              });
            }}
          />
        ))}

        <AutoLoadMoreFooter isLoadingMore={resources.isLoadingMore} label="Loading more guides and resources" />

        {/* End-of-feed */}
        {!resources.loading && !showLoadMore && visibleResources.length > 0 && (
          <Text
            style={{ textAlign: 'center', color: colors.textSecondary, fontSize: 13, paddingVertical: 20 }}
            accessible
            accessibilityLabel={`${visibleResources.length} resource${visibleResources.length !== 1 ? 's' : ''} loaded.`}
            accessibilityLiveRegion="polite"
          >
            {visibleResources.length} resource{visibleResources.length !== 1 ? 's' : ''} loaded
          </Text>
        )}

        <View style={{ height: 120 }} />
      </ScrollView>
    </Screen>
  );
}
