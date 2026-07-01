import { useEffect, useMemo, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActivityIndicator, findNodeHandle, Pressable,
  RefreshControl, ScrollView, Text, View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { Screen } from '../src/components/Screen';
import { EmptyState } from '../src/components/EmptyState';
import { FilterPicker } from '../src/components/FilterPicker';
import { useAppDirectoryCategories } from '../src/hooks/useAppDirectoryCategories';
import { useFocusRestore } from '../src/hooks/useFocusRestore';
import { useTheme } from '../src/contexts/ThemeContext';
import { useAccessibilityPreferences } from '../src/hooks/useAccessibilityPreferences';
import { APP_PLATFORMS } from '../src/data/appDirectory';
import { relativeTime } from '../src/utils/relativeTime';
import { sounds } from '../src/services/sounds';
import type { AppCategory } from '../src/types/content';

const APP_ACCENT = '#3b82f6';
const PLATFORM_OPTIONS = APP_PLATFORMS.map((platform) => platform.name);

const CATEGORY_ICONS: Record<string, React.ComponentProps<typeof Ionicons>['name']> = {
  'books':               'book-outline',
  'business':            'briefcase-outline',
  'developer-tools':     'code-slash-outline',
  'education':           'school-outline',
  'entertainment':       'film-outline',
  'finance':             'wallet-outline',
  'food-and-drink':      'restaurant-outline',
  'games':               'game-controller-outline',
  'graphics-and-design': 'color-palette-outline',
  'health-and-fitness':  'heart-outline',
  'lifestyle':           'leaf-outline',
  'medical':             'medkit-outline',
  'music':               'musical-notes-outline',
  'navigation':          'navigate-outline',
  'news':                'newspaper-outline',
  'photo-and-video':     'camera-outline',
  'productivity':        'checkmark-circle-outline',
  'reference':           'library-outline',
  'safari-extensions':   'globe-outline',
  'shopping':            'bag-handle-outline',
  'social-networking':   'people-outline',
  'sports-and-activities': 'bicycle-outline',
  'travel':              'airplane-outline',
  'utilities':           'construct-outline',
  'weather':             'partly-sunny-outline',
};

// ─── Main screen ──────────────────────────────────────────────────────────────
export default function AppBrowse() {
  const router             = useRouter();
  const { colors, styles } = useTheme();
  const a11y               = useAccessibilityPreferences();
  const { save }           = useFocusRestore();

  const [platformId,   setPlatformId]   = useState('ios');
  const [feedLoadedAt, setFeedLoadedAt] = useState<Date | null>(null);
  const prevLoadingRef = useRef(false);
  const summaryRef = useRef<Text | null>(null);
  const focusedInitialSummaryRef = useRef(false);

  const categoryList = useAppDirectoryCategories(platformId);
  const categoryRefs = useRef<Map<string, View>>(new Map());

  const platformName = APP_PLATFORMS.find(p => p.id === platformId)?.name ?? 'Apps';

  useEffect(() => {
    if (prevLoadingRef.current && !categoryList.loading && categoryList.categories.length > 0) {
      setFeedLoadedAt(new Date());
    }
    prevLoadingRef.current = categoryList.loading;
  }, [categoryList.loading, categoryList.categories.length]);

  useEffect(() => {
    if (focusedInitialSummaryRef.current || categoryList.loading || categoryList.categories.length === 0) return;
    focusedInitialSummaryRef.current = true;
    const timer = setTimeout(() => {
      const handle = findNodeHandle(summaryRef.current);
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, 450);
    return () => clearTimeout(timer);
  }, [categoryList.loading, categoryList.categories.length]);

  useEffect(() => {
    setFeedLoadedAt(null);
    prevLoadingRef.current = false;
  }, [platformId]);

  const hasCounts = categoryList.categories.some(c => c.count !== undefined);

  const groupedCategories = useMemo(() => {
    const groups: Array<{ letter: string; categories: AppCategory[] }> = [];
    let currentLetter = '';
    for (const category of categoryList.categories) {
      const first = category.name.trim().charAt(0).toUpperCase();
      const letter = first && first >= 'A' && first <= 'Z' ? first : '#';
      if (letter !== currentLetter) {
        currentLetter = letter;
        groups.push({ letter, categories: [] });
      }
      groups[groups.length - 1].categories.push(category);
    }
    return groups;
  }, [categoryList.categories]);

  const feedSummaryLabel = useMemo(() => {
    const n = categoryList.categories.length;
    if (n === 0) return 'No categories loaded.';
    const label = `${n} categor${n !== 1 ? 'ies' : 'y'} for ${platformName}`;
    return feedLoadedAt
      ? `${label}. Updated ${relativeTime(feedLoadedAt.toISOString())}.`
      : `${label}.`;
  }, [categoryList.categories.length, platformName, feedLoadedAt]);

  function handlePlatformChange(name: string) {
    const platform = APP_PLATFORMS.find(p => p.name === name);
    if (!platform) return;
    setPlatformId(platform.id);
    setFeedLoadedAt(null);
    AccessibilityInfo.announceForAccessibility(`${name} selected.`);
  }

  function navigateToCategory(category: AppCategory) {
    sounds.articleOpen().catch(() => {});
    save(categoryRefs.current.get(category.slug) ?? null);
    router.push({
      pathname: '/app-category' as any,
      params: {
        platform: platformId,
        platformName,
        categorySlug: category.slug,
        categoryTid: category.tid ?? '',
        categoryName: category.name,
      },
    });
  }

  return (
    <Screen title="App Directory">
      <ScrollView
        refreshControl={
          <RefreshControl
            refreshing={categoryList.loading}
            onRefresh={categoryList.refresh}
            tintColor={colors.appleVisBlue}
            accessibilityLabel="Pull to refresh categories"
          />
        }
        contentContainerStyle={{ padding: 16, paddingBottom: 120 }}
        showsVerticalScrollIndicator
      >
        <FilterPicker
          label="Platform"
          options={PLATFORM_OPTIONS}
          value={platformName}
          onChange={handlePlatformChange}
        />

        {/* Section header */}
        {!categoryList.loading && categoryList.categories.length > 0 && (
          <View style={{ flexDirection: 'row', alignItems: 'center', marginBottom: 10 }}>
            <Text
              ref={summaryRef}
              style={{ flex: 1, fontSize: 13, fontWeight: '700',
                color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.8 }}
              accessibilityRole="header"
              accessibilityLabel={feedSummaryLabel}
            >
              {platformName} · {categoryList.categories.length} categories
            </Text>
            {feedLoadedAt && (
              <Text style={{ fontSize: 11, color: colors.textSecondary }} accessibilityElementsHidden>
                Updated {relativeTime(feedLoadedAt.toISOString())}
              </Text>
            )}
          </View>
        )}

        {/* Loading */}
        {categoryList.loading && (
          <View
            accessible
            accessibilityLiveRegion="polite"
            accessibilityLabel="Loading categories, please wait"
            style={{ alignItems: 'center', paddingVertical: 32 }}
          >
            <ActivityIndicator size="large" color={colors.appleVisBlue} />
            <Text style={[styles.lede, { marginTop: 12, textAlign: 'center' }]}>
              Loading categories…
            </Text>
          </View>
        )}

        {/* Category list */}
        {!categoryList.loading && groupedCategories.map((group, groupIndex) => (
          <View key={group.letter}>
            <Text
              accessibilityRole="header"
              style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
                textTransform: 'uppercase', letterSpacing: 0.8,
                marginTop: groupIndex === 0 ? 0 : 12, marginBottom: 8 }}
            >
              {group.letter}
            </Text>
            {group.categories.map((category) => {
              const icon     = CATEGORY_ICONS[category.slug] ?? 'apps-outline';
              const hasCount = category.count !== undefined;
              const iconBg   = a11y.reduceTransparency ? colors.inputBackground : APP_ACCENT + '18';

              return (
                <Pressable
                  key={category.slug}
                  ref={(el) => {
                    if (el) categoryRefs.current.set(category.slug, el);
                    else    categoryRefs.current.delete(category.slug);
                  }}
                  onPress={() => navigateToCategory(category)}
                  accessible
                  accessibilityRole="button"
                  accessibilityLabel={[
                    category.name,
                    hasCount ? `${category.count} apps` : null,
                    'Double tap to browse',
                  ].filter(Boolean).join('. ')}
                  style={({ pressed }) => [
                    styles.card,
                    { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 8, opacity: pressed ? 0.75 : 1 },
                  ]}
                >
                  <View
                    style={{ width: 40, height: 40, borderRadius: 10,
                      backgroundColor: iconBg, alignItems: 'center', justifyContent: 'center' }}
                    accessibilityElementsHidden
                  >
                    <Ionicons name={icon} size={20} color={APP_ACCENT} />
                  </View>

                  <Text style={{ flex: 1, fontSize: 16, fontWeight: '500', color: colors.text }}>
                    {category.name}
                  </Text>

                  {hasCount && (
                    <View
                      style={{ backgroundColor: a11y.reduceTransparency ? colors.inputBackground : APP_ACCENT + '18',
                        borderRadius: 12, paddingHorizontal: 8, paddingVertical: 3 }}
                      accessibilityElementsHidden
                    >
                      <Text style={{ fontSize: 12, color: APP_ACCENT, fontWeight: '700' }}>
                        {category.count}
                      </Text>
                    </View>
                  )}

                  <Ionicons name="chevron-forward" size={16} color={colors.textSecondary} accessibilityElementsHidden />
                </Pressable>
              );
            })}
          </View>
        ))}

        {!categoryList.loading && categoryList.categories.length === 0 && (
          <EmptyState
            icon="apps-outline"
            title="No categories"
            subtitle="No app categories could be loaded. Pull down to try again."
          />
        )}

        {!categoryList.loading && categoryList.fromFallback && (
          <Text
            style={{ fontSize: 12, color: colors.textSecondary, textAlign: 'center', paddingVertical: 12 }}
            accessible
            accessibilityLabel="Using offline category list. Live counts will appear when connected."
          >
            {hasCounts ? '' : 'Using offline category list. Connect for live app counts.'}
          </Text>
        )}

        <View style={{ height: 40 }} />
      </ScrollView>
    </Screen>
  );
}
