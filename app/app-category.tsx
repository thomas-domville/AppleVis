import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActivityIndicator, Linking, Pressable,
  RefreshControl, ScrollView, Share, Text, TextInput, View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Screen } from '../src/components/Screen';
import { AccessibleCard } from '../src/components/AccessibleCard';
import { AutoLoadMoreFooter } from '../src/components/AutoLoadMoreFooter';
import { EmptyState } from '../src/components/EmptyState';
import { useAppCategoryExperiment } from '../src/hooks/useAppCategoryExperiment';
import { useAutoLoadMore } from '../src/hooks/useAutoLoadMore';
import { useSavedItems } from '../src/hooks/useSavedItems';
import { useFocusRestore } from '../src/hooks/useFocusRestore';
import { useRefreshFeedback } from '../src/hooks/useRefreshFeedback';
import { useToast } from '../src/contexts/ToastContext';
import { useTheme } from '../src/contexts/ThemeContext';
import { usePreferences } from '../src/contexts/PreferencesContext';
import { useAccessibilityPreferences } from '../src/hooks/useAccessibilityPreferences';
import { persistence } from '../src/services/persistence';
import { api } from '../src/services/api';
import { relativeTime } from '../src/utils/relativeTime';
import {
  isAppleIntelligenceAvailable, accessibilityConsensus,
  summariseText, simplifyText, readAloud, donateSiriActivity,
} from '../src/services/intelligenceService';
import type { AppListing } from '../src/types/content';

const APP_ACCENT = '#3b82f6';

// Days within which an app is considered "new" to this category (relative to last visit)
const NEW_DAYS = 30;

export default function AppCategory() {
  const router             = useRouter();
  const { colors, styles } = useTheme();
  const { aiSummariesEnabled } = usePreferences();
  const { screenReaderEnabled } = useAccessibilityPreferences();
  const { showToast }      = useToast();
  const { save }           = useFocusRestore();
  const savedApps          = useSavedItems('appListing');
  const aiAvailable        = aiSummariesEnabled && isAppleIntelligenceAvailable();

  const {
    platform    = 'ios',
    platformName = 'iOS and iPadOS',
    categorySlug = '',
    categoryName  = '',
  } = useLocalSearchParams<{
    platform:     string;
    platformName: string;
    categorySlug: string;
    categoryName:  string;
  }>();

  const category = useMemo(() =>
    categorySlug && categoryName
      ? { name: String(categoryName), slug: String(categorySlug) }
      : null,
  [categorySlug, categoryName]);

  const probe  = useAppCategoryExperiment(String(platform), category);
  const appRefs = useRef<Map<string, View>>(new Map());

  const [searchQuery,  setSearchQuery]  = useState('');
  const [lastVisit,    setLastVisit]    = useState<Date | null>(null);
  const [feedLoadedAt, setFeedLoadedAt] = useState<Date | null>(null);
  const [followedIds,  setFollowedIds]  = useState<Set<string>>(new Set());
  const prevLoadingRef = useRef(false);
  const firstAppRef    = useRef<View | null>(null);

  // Persist per-category lastVisit: read on focus, write on blur
  const visitKey = `lastVisitedCategory_${platform}_${categorySlug}`;
  useEffect(() => {
    persistence.getSetting<string>(visitKey, '').then(iso => {
      if (iso) setLastVisit(new Date(iso));
    }).catch(() => {});
    return () => {
      persistence.setSetting(visitKey, new Date().toISOString()).catch(() => {});
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visitKey]);

  // Track when apps finish loading for the header timestamp
  useEffect(() => {
    if (prevLoadingRef.current && !probe.loading && probe.apps.length > 0) {
      setFeedLoadedAt(new Date());
    }
    prevLoadingRef.current = probe.loading;
  }, [probe.loading, probe.apps.length]);

  useRefreshFeedback(false, categoryName, probe.loading, () => firstAppRef.current);

  useEffect(() => {
    persistence.getFollowedItems()
      .then((items) => setFollowedIds(new Set(items.filter((item) => item.kind === 'appListing').map((item) => item.id))))
      .catch(() => {});
  }, []);

  const isNewApp = useCallback((app: AppListing): boolean => {
    if (!app.createdAt) return false;
    if (!lastVisit) {
      // First visit: mark apps added in the last NEW_DAYS days as new
      const cutoff = Date.now() - NEW_DAYS * 86_400_000;
      return new Date(app.createdAt).getTime() > cutoff;
    }
    return new Date(app.createdAt) > lastVisit;
  }, [lastVisit]);

  const visibleApps = useMemo(() => {
    if (!searchQuery.trim()) return probe.apps;
    const q = searchQuery.toLowerCase();
    return probe.apps.filter(app =>
      app.name.toLowerCase().includes(q) ||
      app.developer.toLowerCase().includes(q),
    );
  }, [probe.apps, searchQuery]);

  const groupedVisibleApps = useMemo(() => {
    const groups: Array<{ letter: string; apps: AppListing[] }> = [];
    let currentLetter = '';
    for (const app of visibleApps) {
      const first = app.name.trim().charAt(0).toUpperCase();
      const letter = first && first >= 'A' && first <= 'Z' ? first : '#';
      if (letter !== currentLetter) {
        currentLetter = letter;
        groups.push({ letter, apps: [] });
      }
      groups[groups.length - 1].apps.push(app);
    }
    return groups;
  }, [visibleApps]);

  const newCount = useMemo(() =>
    probe.apps.filter(isNewApp).length,
  [probe.apps, isNewApp]);

  const feedSummaryLabel = useMemo(() => {
    const n = visibleApps.length;
    if (n === 0) return 'No apps loaded.';
    const label = `${n} app${n !== 1 ? 's' : ''}${newCount > 0 ? `, ${newCount} new` : ''}`;
    return feedLoadedAt
      ? `${label}. Updated ${relativeTime(feedLoadedAt.toISOString())}.`
      : `${label}.`;
  }, [visibleApps.length, newCount, feedLoadedAt]);
  const shouldAutoLoadMore = probe.hasMore && !searchQuery.trim();
  const handleAutoLoadMore = useAutoLoadMore({
    hasMore: shouldAutoLoadMore,
    isLoadingMore: probe.isLoadingMore,
    onLoadMore: probe.loadMore,
  });

  // ── App actions (mirroring Discover tab pattern) ───────────────────────────
  function buildAppActions(app: AppListing): string[] {
    const isSaved = savedApps.isSaved(app.id);
    const isFollowing = followedIds.has(app.id);
    return [
      'Open App Page',
      ...(app.appStoreUrl ? ['Open in App Store'] : []),
      isSaved ? 'Unsave App' : 'Save App',
      isFollowing ? 'Unfollow App' : 'Follow App',
      ...(!screenReaderEnabled ? ['Read Aloud'] : []),
      'Share',
      ...(aiAvailable ? ['Summarise Reviews', 'Accessibility Consensus', 'Simplify'] : []),
    ];
  }

  function handleAppAction(action: string, app: AppListing) {
    if (action === 'Open App Page') {
      if (app.id.startsWith('public:') && app.url) {
        Linking.openURL(app.url).catch(() => showToast('Could not open the AppleVis app page.', 'error'));
        return;
      }
      save(appRefs.current.get(app.id) ?? null);
      donateSiriActivity({ type: 'searchApps', query: app.name });
      router.push({ pathname: '/app-detail/[id]' as any, params: { id: app.id, name: app.name } });
    } else if (action === 'Open in App Store') {
      Linking.openURL(app.appStoreUrl).catch(() => showToast('Could not open the App Store.', 'error'));
    } else if (action === 'Save App') {
      savedApps.save({ id: app.id, kind: 'appListing', title: app.name, savedAt: new Date().toISOString() });
      showToast('App saved.', 'success');
    } else if (action === 'Unsave App') {
      savedApps.unsave(app.id);
      showToast('App unsaved.', 'success');
    } else if (action === 'Follow App') {
      persistence.followItem({
        id: app.id,
        kind: 'appListing',
        nodeType: 'node--ios_app_directory',
        title: app.name,
        followedAt: new Date().toISOString(),
        lastActivityAt: app.lastUpdatedAt,
        url: app.url,
      }).then(async () => {
        setFollowedIds((prev) => new Set([...prev, app.id]));
        const token = await api.account.getSessionToken();
        if (token) {
          const res = await api.follows.follow(app.id, 'node--ios_app_directory', token);
          showToast(res.ok ? 'Following app.' : 'Following saved. Server sync is waiting for AppleVis support.', res.ok ? 'success' : 'warning');
        } else {
          showToast('Following saved locally. Sign in again to sync with AppleVis.', 'warning');
        }
      });
    } else if (action === 'Unfollow App') {
      persistence.unfollowItem(app.id).then(async () => {
        setFollowedIds((prev) => { const next = new Set(prev); next.delete(app.id); return next; });
        const token = await api.account.getSessionToken();
        if (token) await api.follows.unfollow(app.id, token).catch(() => {});
        showToast('Unfollowed app.', 'success');
      });
    } else if (action === 'Read Aloud') {
      readAloud([app.name, app.summary].filter(Boolean).join('. '));
    } else if (action === 'Share') {
      Share.share({
        title: app.name,
        message: `${app.name} on AppleVis — ${app.url ?? 'https://www.applevis.com/accessibility-apps'}`,
      }).catch(() => {});
    } else if (action === 'Summarise Reviews') {
      summariseText(`Summarise accessibility reviews for ${app.name}: ${app.summary}`)
        .then(s => { if (s) showToast(s, 'success'); });
    } else if (action === 'Accessibility Consensus') {
      accessibilityConsensus([app.summary])
        .then(s => { if (s) showToast(s, 'success'); });
    } else if (action === 'Simplify') {
      simplifyText(app.summary)
        .then(s => { if (s) showToast(s, 'success'); });
    }
  }

  // ── Render ─────────────────────────────────────────────────────────────────
  const screenTitle = `${String(categoryName)} · ${String(platformName)}`;

  return (
    <Screen title={screenTitle}>
      <ScrollView
        contentContainerStyle={{ padding: 16, paddingBottom: 120 }}
        showsVerticalScrollIndicator
        onScroll={handleAutoLoadMore}
        scrollEventThrottle={120}
      >

        {/* ── Search ────────────────────────────────────────────────────── */}
        <View style={{ flexDirection: 'row', alignItems: 'center',
          backgroundColor: colors.inputBackground, borderRadius: 10, borderWidth: 1,
          borderColor: colors.border, paddingHorizontal: 10, paddingVertical: 8, marginBottom: 10 }}>
          <Ionicons name="search" size={16} color={colors.textSecondary}
            style={{ marginRight: 6 }} accessibilityElementsHidden />
          <TextInput
            value={searchQuery}
            onChangeText={setSearchQuery}
            placeholder={`Search ${String(categoryName)}…`}
            placeholderTextColor={colors.textSecondary}
            style={{ flex: 1, fontSize: 15, color: colors.text }}
            accessible
            accessibilityLabel={`Search ${String(categoryName)}`}
            accessibilityHint="Type to filter apps by name or developer"
            returnKeyType="search"
            clearButtonMode="while-editing"
          />
        </View>

        {/* ── Section header ────────────────────────────────────────────── */}
        {!probe.loading && visibleApps.length > 0 && (
          <View style={{ flexDirection: 'row', alignItems: 'center', marginBottom: 10, marginTop: 4 }}>
            <Text
              style={{ flex: 1, fontSize: 13, fontWeight: '700', color: colors.textSecondary,
                textTransform: 'uppercase', letterSpacing: 0.8 }}
              accessibilityRole="header"
              accessibilityActions={[{ name: 'feedSummary', label: 'Feed summary' }]}
              onAccessibilityAction={() => AccessibilityInfo.announceForAccessibility(feedSummaryLabel)}
            >
              {String(categoryName)}
              {newCount > 0 ? `  ·  ${newCount} new` : ''}
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

        {/* ── Loading ───────────────────────────────────────────────────── */}
        {probe.loading && (
          <View
            accessible
            accessibilityLiveRegion="polite"
            accessibilityLabel={`Loading ${String(categoryName)} apps, please wait`}
            style={{ alignItems: 'center', paddingVertical: 32 }}
          >
            <ActivityIndicator size="large" color={colors.appleVisBlue} />
            <Text style={[styles.lede, { marginTop: 12, textAlign: 'center' }]}>
              Loading apps…
            </Text>
          </View>
        )}

        {/* ── Error ─────────────────────────────────────────────────────── */}
        {!probe.loading && probe.error && (
          <View style={[styles.card, { backgroundColor: '#FFF0F0' }]}>
            <Text style={[styles.cardTitle, { color: '#D00' }]}>Could not load apps</Text>
            <Text style={styles.cardMeta}>{probe.error}</Text>
            <Pressable
              onPress={probe.retry}
              accessible accessibilityRole="button"
              accessibilityLabel="Retry loading apps"
              style={{ marginTop: 12 }}
            >
              <Text style={{ color: colors.appleVisBlue, fontWeight: '700' }}>Retry</Text>
            </Pressable>
          </View>
        )}

        {/* ── Empty ─────────────────────────────────────────────────────── */}
        {!probe.loading && !probe.error && probe.apps.length === 0 && (
          <EmptyState
            icon="apps-outline"
            title="No apps listed yet"
            subtitle={`No ${String(categoryName)} apps found for ${String(platformName)}.`}
          />
        )}

        {/* ── Search empty ──────────────────────────────────────────────── */}
        {!probe.loading && probe.apps.length > 0 && visibleApps.length === 0 && (
          <EmptyState
            icon="search-outline"
            title="No results"
            subtitle={`No apps match "${searchQuery}".`}
          />
        )}

        {/* ── New badge row (sighted summary) ────────────────────────────── */}
        {!probe.loading && newCount > 0 && visibleApps.length > 0 && (
          <View
            style={{ flexDirection: 'row', alignItems: 'center', gap: 8,
              backgroundColor: APP_ACCENT + '12', borderRadius: 10,
              paddingHorizontal: 12, paddingVertical: 8, marginBottom: 10 }}
            accessible
            accessibilityLabel={`${newCount} new app${newCount !== 1 ? 's' : ''} added since your last visit.`}
          >
            <Ionicons name="sparkles" size={15} color={APP_ACCENT} accessibilityElementsHidden />
            <Text style={{ fontSize: 13, color: APP_ACCENT, fontWeight: '600' }}>
              {newCount} new since your last visit
            </Text>
          </View>
        )}

        {/* ── App cards ─────────────────────────────────────────────────── */}
        {!probe.loading && groupedVisibleApps.map((group, groupIndex) => (
          <View key={group.letter}>
            <Text
              accessibilityRole="header"
              style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
                textTransform: 'uppercase', letterSpacing: 0.8,
                marginTop: groupIndex === 0 ? 0 : 12, marginBottom: 8 }}
            >
              {group.letter}
            </Text>
            {group.apps.map((app, appIndex) => {
              const isNew   = isNewApp(app);
              const isSaved = savedApps.isSaved(app.id);
              const isFirst = groupIndex === 0 && appIndex === 0;
              return (
                <AccessibleCard
                  key={app.id}
                  ref={(el) => {
                    if (el) { appRefs.current.set(app.id, el); }
                    else    { appRefs.current.delete(app.id); }
                    if (isFirst) firstAppRef.current = el;
                  }}
                  title={app.name}
                  meta={[
                    isNew ? 'New' : null,
                    app.developer || null,
                    app.category  || null,
                    app.reviewCount > 0 ? `${app.reviewCount} review${app.reviewCount !== 1 ? 's' : ''}` : null,
                    app.createdAt
                      ? `Added ${relativeTime(app.createdAt)}`
                      : `Updated ${new Date(app.lastUpdatedAt).toLocaleDateString()}`,
                    isSaved ? 'Saved' : null,
                  ].filter(Boolean).join(' · ')}
                  iconUrl={app.iconUrl}
                  badge={isNew ? 'NEW' : undefined}
                  badgeColor={APP_ACCENT}
                  actions={buildAppActions(app)}
                  onAction={(a) => handleAppAction(a, app)}
                />
              );
            })}
          </View>
        ))}
        <AutoLoadMoreFooter isLoadingMore={probe.isLoadingMore} label="Loading more apps" />

        {/* ── End-of-feed ────────────────────────────────────────────────── */}
        {!probe.loading && !probe.hasMore && visibleApps.length > 0 && !searchQuery.trim() && (
          <Text
            style={{ textAlign: 'center', color: colors.textSecondary,
              fontSize: 13, paddingVertical: 20 }}
            accessible
            accessibilityLabel={`${visibleApps.length} app${visibleApps.length !== 1 ? 's' : ''} loaded.`}
            accessibilityLiveRegion="polite"
          >
            {visibleApps.length} app{visibleApps.length !== 1 ? 's' : ''} loaded
          </Text>
        )}

        <View style={{ height: 40 }} />
      </ScrollView>
    </Screen>
  );
}
