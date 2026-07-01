// DEPRECATED (hidden tab, href: null) — kept only as a compatibility net.
// No in-app code routes here anymore; see src/navigation/routeResolver.ts and
// app/app-browse.tsx, which is the current replacement.
import { useEffect, useMemo, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActivityIndicator, Linking, Pressable,
  RefreshControl, ScrollView, Share, Text, TextInput, View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { EmptyState } from '../../src/components/EmptyState';
import { Screen } from '../../src/components/Screen';
import { AccessibleCard } from '../../src/components/AccessibleCard';
import { FilterPicker } from '../../src/components/FilterPicker';
import { LoadMoreButton } from '../../src/components/LoadMoreButton';
import { useAppList } from '../../src/hooks/useAppList';
import { useSavedItems } from '../../src/hooks/useSavedItems';
import { useRefreshFeedback } from '../../src/hooks/useRefreshFeedback';
import { useFocusRestore } from '../../src/hooks/useFocusRestore';
import { useHandoff } from '../../src/hooks/useHandoff';
import { useToast } from '../../src/contexts/ToastContext';
import { useAlert } from '../../src/contexts/AccessibleAlertContext';
import { confirmDestructiveAction } from '../../src/utils/confirmDestructiveAction';
import { usePreferences } from '../../src/contexts/PreferencesContext';
import {
  donateSiriActivity, readAloud,
  summariseText, simplifyText, accessibilityConsensus,
  isAppleIntelligenceAvailable,
} from '../../src/services/intelligenceService';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { persistence } from '../../src/services/persistence';
import { api } from '../../src/services/api';

// ─── Filter ───────────────────────────────────────────────────────────────────

const APP_FILTERS = ['Latest', 'Active', 'Explore', 'Saved'] as const;
type AppFilter = typeof APP_FILTERS[number];

// ─── Explore — platforms & categories ────────────────────────────────────────
// Placeholder values mirroring the AppleVis website's app directory structure.
// These will be replaced with live taxonomy API results once the Drupal
// developer confirms the vocabulary machine name (see Brief v2, Question A3).

const PLATFORMS = ['iOS', 'macOS', 'watchOS', 'Apple TV', 'Vision Pro'] as const;
type Platform = typeof PLATFORMS[number];

const CATEGORIES: Record<Platform, string[]> = {
  'iOS': [
    'Books', 'Business', 'Education', 'Entertainment', 'Finance',
    'Food & Drink', 'Games', 'Graphics & Design', 'Health & Fitness',
    'Lifestyle', 'Medical', 'Music', 'Navigation', 'News',
    'Photo & Video', 'Productivity', 'Reference', 'Shopping',
    'Social Networking', 'Sports', 'Travel', 'Utilities', 'Weather',
  ],
  'macOS': [
    'Business', 'Developer Tools', 'Education', 'Entertainment', 'Finance',
    'Games', 'Graphics & Design', 'Health & Fitness', 'Lifestyle', 'Music',
    'News', 'Photo & Video', 'Productivity', 'Reference',
    'Social Networking', 'Sports', 'Travel', 'Utilities', 'Weather',
  ],
  'watchOS': [
    'Health & Fitness', 'Lifestyle', 'Productivity', 'Utilities',
  ],
  'Apple TV': [
    'Entertainment', 'Games', 'Music', 'Sports', 'Utilities',
  ],
  'Vision Pro': [
    'Entertainment', 'Games', 'Productivity', 'Utilities',
  ],
};


// ─── Main component ───────────────────────────────────────────────────────────

export default function Apps() {
  const router                  = useRouter();
  const { colors, styles, isDark } = useTheme();
  const { screenReaderEnabled } = useAccessibilityPreferences();
  const list                    = useAppList();
  const saved                   = useSavedItems('appListing');
  const { showToast }           = useToast();
  const { showAlert }           = useAlert();
  const { aiSummariesEnabled }  = usePreferences();
  const appRefs                 = useRef<Map<string, View>>(new Map());
  const { save: saveFocus }     = useFocusRestore();
  const aiAvailable             = aiSummariesEnabled && isAppleIntelligenceAvailable();

  const [filter, setFilter]               = useState<AppFilter>('Latest');
  const [searchQuery, setSearchQuery]     = useState('');
  const [selectedPlatform, setSelectedPlatform] = useState<Platform>('iOS');
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [followedIds, setFollowedIds]     = useState<Set<string>>(new Set());

  useEffect(() => {
    persistence.getFollowedItems()
      .then((items) => setFollowedIds(new Set(items.filter((item) => item.kind === 'appListing').map((item) => item.id))))
      .catch(() => {});
  }, []);

  // ── Derived lists ─────────────────────────────────────────────────────────

  const visibleApps = useMemo(() => {
    if (!searchQuery.trim()) return list.apps;
    const q = searchQuery.toLowerCase();
    return list.apps.filter(app =>
      app.name.toLowerCase().includes(q) ||
      app.developer.toLowerCase().includes(q) ||
      app.category.toLowerCase().includes(q));
  }, [list.apps, searchQuery]);

  // Explore — apps filtered by selected platform + category.
  // Currently empty until Drupal returns real category/platform fields.
  // Will populate automatically once api.ts maps those fields correctly.
  const exploreApps = useMemo(() => {
    if (!selectedCategory) return [];
    return list.apps.filter(app =>
      app.category === selectedCategory &&
      (app.platform === selectedPlatform || app.platform === ''));
  }, [list.apps, selectedCategory, selectedPlatform]);

  useRefreshFeedback(list.refreshing, 'Apps', list.loading,
    () => appRefs.current.get(list.apps[0]?.id ?? '') ?? null);

  useHandoff({
    activityType: 'com.applevis.app.viewApps',
    title: 'AppleVis App Directory',
    webpageURL: 'https://www.applevis.com/accessibility-apps',
  });

  // ── Shared card action handler ────────────────────────────────────────────

  function buildActions(app: { id: string; appStoreUrl: string }) {
    const isSaved     = saved.isSaved(app.id);
    const isFollowing = followedIds.has(app.id);
    const hasStoreUrl = !!app.appStoreUrl;
    return [
      'Open App Page',
      ...(hasStoreUrl ? ['Open in App Store'] : []),
      isSaved ? 'Unsave App' : 'Save App',
      isFollowing ? 'Unfollow App' : 'Follow App',
      ...(!screenReaderEnabled ? ['Read Aloud'] : []),
      'Share',
      ...(aiAvailable ? ['Summarise Reviews', 'Accessibility Consensus', 'Simplify'] : []),
    ];
  }

  function handleAction(action: string, app: {
    id: string; name: string; summary: string; appStoreUrl: string; lastUpdatedAt: string; url?: string;
  }) {
    if (action === 'Open App Page') {
      saveFocus(appRefs.current.get(app.id) ?? null);
      donateSiriActivity({ type: 'searchApps', query: app.name });
      router.push({ pathname: '/app-detail/[id]' as any, params: { id: app.id, name: app.name } });
    } else if (action === 'Open in App Store') {
      Linking.openURL(app.appStoreUrl).catch(() => showToast('Could not open the App Store.', 'error'));
    } else if (action === 'Save App') {
      saved.save({ id: app.id, kind: 'appListing', title: app.name, savedAt: new Date().toISOString() });
      showToast('App saved.', 'success');
    } else if (action === 'Unsave App') {
      saved.unsave(app.id);
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
        message: `${app.name} on AppleVis — https://www.applevis.com/accessibility-apps`,
      }).catch(() => {});
    } else if (action === 'Summarise Reviews') {
      summariseText(`Summarise accessibility reviews for ${app.name}: ${app.summary}`).then(s => {
        if (s) showToast(s, 'success');
      });
    } else if (action === 'Accessibility Consensus') {
      accessibilityConsensus([app.summary]).then(s => {
        if (s) showToast(s, 'success');
      });
    } else if (action === 'Simplify') {
      simplifyText(app.summary).then(s => {
        if (s) showToast(s, 'success');
      });
    }
  }

  function renderAppCard(app: typeof list.apps[number]) {
    const isSaved = saved.isSaved(app.id);
    return (
      <AccessibleCard
        key={app.id}
        ref={(el) => {
          if (el) appRefs.current.set(app.id, el);
          else appRefs.current.delete(app.id);
        }}
        title={app.name}
        meta={[
          app.developer || null,
          app.category  || null,
          app.reviewCount > 0 ? `${app.reviewCount} reviews` : null,
          `Updated ${new Date(app.lastUpdatedAt).toLocaleDateString()}`,
          isSaved ? 'Saved' : null,
        ].filter(Boolean).join(' · ')}
        iconUrl={app.iconUrl}
        actions={buildActions(app)}
        onAction={(action) => handleAction(action, app)}
      />
    );
  }

  // ── Render ────────────────────────────────────────────────────────────────

  return (
    <Screen title="Apps" refreshing={list.refreshing} showBack={false}>
      <ScrollView
        refreshControl={
          <RefreshControl
            refreshing={list.refreshing}
            onRefresh={list.refresh}
            tintColor={colors.appleVisBlue}
            accessibilityLabel="Pull to refresh apps"
          />
        }
        contentContainerStyle={{ padding: 16, paddingBottom: 40 }}
      >

        {/* ── Search bar (Latest + Active only) ───────────────────────── */}
        {(filter === 'Latest' || filter === 'Active') && (
          <View style={{ flexDirection: 'row', alignItems: 'center',
            backgroundColor: colors.inputBackground, borderRadius: 10, borderWidth: 1,
            borderColor: colors.border, paddingHorizontal: 10, paddingVertical: 8, marginBottom: 10 }}>
            <Ionicons name="search" size={16} color={colors.textSecondary}
              style={{ marginRight: 6 }} accessibilityElementsHidden />
            <TextInput
              value={searchQuery}
              onChangeText={setSearchQuery}
              placeholder="Search apps, developers, categories…"
              placeholderTextColor={colors.textSecondary}
              style={{ flex: 1, fontSize: 15, color: colors.text }}
              accessible
              accessibilityLabel="Search apps"
              accessibilityHint="Type to filter apps by name, developer, or category"
              returnKeyType="search"
              clearButtonMode="while-editing"
            />
          </View>
        )}

        {/* ── View filter ──────────────────────────────────────────────── */}
        <FilterPicker
          label="View"
          options={APP_FILTERS}
          value={filter}
          onChange={(v) => {
            setFilter(v);
            setSearchQuery('');
            setSelectedCategory(null);
          }}
        />

        {/* ════════════════════════════════════════════════════════════════
            LATEST — most recently updated app entries
        ════════════════════════════════════════════════════════════════ */}
        {filter === 'Latest' && (
          <>
            {list.loading && (
              <View style={{ alignItems: 'center', paddingVertical: 32 }}>
                <ActivityIndicator size="large" color={colors.appleVisBlue} />
                <Text style={[styles.lede, { marginTop: 12, textAlign: 'center' }]}>Loading apps…</Text>
              </View>
            )}

            {!list.loading && list.error && (
              <View style={[styles.card, { backgroundColor: '#FFF0F0' }]}>
                <Text style={[styles.cardTitle, { color: '#D00' }]}>Could not load apps</Text>
                <Text style={styles.cardMeta}>{list.error}</Text>
                <Pressable onPress={list.refresh} accessible accessibilityRole="button"
                  accessibilityLabel="Retry loading apps" style={{ marginTop: 12 }}>
                  <Text style={{ color: colors.appleVisBlue, fontWeight: '700' }}>Retry</Text>
                </Pressable>
              </View>
            )}

            {!list.loading && !list.error && list.apps.length === 0 && (
              <EmptyState icon="apps-outline" title="No apps yet"
                subtitle="Pull down to refresh." />
            )}

            {!list.loading && list.apps.length > 0 && visibleApps.length === 0 && searchQuery.trim() && (
              <EmptyState icon="search-outline" title="No results"
                subtitle={`No apps match "${searchQuery}". Try a different search.`} />
            )}

            {!list.loading && visibleApps.map(renderAppCard)}

            <LoadMoreButton
              hasMore={list.hasMore}
              isLoadingMore={list.isLoadingMore}
              onPress={list.loadMore}
            />
          </>
        )}

        {/* ════════════════════════════════════════════════════════════════
            ACTIVE — apps with most recent community activity
            Shell: shows same feed as Latest until the Drupal developer
            confirms the last_comment_timestamp sort field (Brief v2, Q A8).
        ════════════════════════════════════════════════════════════════ */}
        {filter === 'Active' && (
          <>
            {/* Placeholder banner — remove once API sort is confirmed */}
            <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 10,
              backgroundColor: colors.pill, borderRadius: 10,
              padding: 12, marginBottom: 14 }}
              accessible
              accessibilityLabel="Coming soon. This view will show apps with the most recent comments and reviews once the activity sort field is confirmed with the Drupal developer."
            >
              <Ionicons name="information-circle-outline" size={18} color={colors.accent}
                accessibilityElementsHidden style={{ marginTop: 1 }} />
              <Text style={{ flex: 1, fontSize: 13, color: colors.accent, lineHeight: 19 }}>
                <Text style={{ fontWeight: '700' }}>Activity sorting coming soon. </Text>
                Showing recently updated apps for now. Once the Drupal activity field is confirmed this will show apps with the latest comments and reviews first.
              </Text>
            </View>

            {list.loading && (
              <ActivityIndicator size="large" color={colors.appleVisBlue}
                accessibilityLabel="Loading apps" style={{ marginVertical: 24 }} />
            )}

            {!list.loading && visibleApps.length === 0 && searchQuery.trim() && (
              <EmptyState icon="search-outline" title="No results"
                subtitle={`No apps match "${searchQuery}".`} />
            )}

            {!list.loading && visibleApps.map(renderAppCard)}

            <LoadMoreButton
              hasMore={list.hasMore}
              isLoadingMore={list.isLoadingMore}
              onPress={list.loadMore}
            />
          </>
        )}

        {/* ════════════════════════════════════════════════════════════════
            EXPLORE — browse by platform and category
        ════════════════════════════════════════════════════════════════ */}
        {filter === 'Explore' && (
          <>
            {/* Platform selector */}
            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={{ gap: 8, paddingBottom: 14 }}
              accessibilityRole="tablist"
              accessibilityLabel="Platform"
            >
              {PLATFORMS.map((platform) => {
                const isSelected = selectedPlatform === platform;
                return (
                  <Pressable
                    key={platform}
                    onPress={() => {
                      setSelectedPlatform(platform);
                      setSelectedCategory(null);
                      AccessibilityInfo.announceForAccessibility(`${platform} selected`);
                    }}
                    accessible
                    accessibilityRole="tab"
                    accessibilityLabel={platform}
                    accessibilityState={{ selected: isSelected }}
                    style={{
                      paddingHorizontal: 14, paddingVertical: 8,
                      borderRadius: 20, borderWidth: isSelected ? 0 : 1,
                      borderColor: colors.border,
                      backgroundColor: isSelected ? colors.accent : colors.inputBackground,
                    }}
                  >
                    <Text style={{
                      fontSize: 14, fontWeight: '600',
                      color: isSelected ? '#FFF' : colors.text,
                    }}>{platform}</Text>
                  </Pressable>
                );
              })}
            </ScrollView>

            {/* Category list or filtered app list */}
            {!selectedCategory ? (
              // Category list for selected platform
              <>
                <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
                  textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 10 }}
                  accessibilityRole="header">
                  {selectedPlatform} Categories
                </Text>
                {CATEGORIES[selectedPlatform].map((category) => (
                  <Pressable
                    key={category}
                    onPress={() => setSelectedCategory(category)}
                    accessible
                    accessibilityRole="button"
                    accessibilityLabel={category}
                    accessibilityHint="Double tap to browse apps in this category"
                    style={({ pressed }) => [styles.card, {
                      flexDirection: 'row', alignItems: 'center',
                      justifyContent: 'space-between',
                      opacity: pressed ? 0.75 : 1, marginBottom: 6,
                    }]}
                  >
                    <Text style={{ fontSize: 16, color: colors.text, fontWeight: '500' }}>
                      {category}
                    </Text>
                    <Ionicons name="chevron-forward" size={16} color={colors.textSecondary}
                      accessibilityElementsHidden />
                  </Pressable>
                ))}
              </>
            ) : (
              // App list for selected platform + category
              <>
                {/* Back button */}
                <Pressable
                  onPress={() => setSelectedCategory(null)}
                  accessible
                  accessibilityRole="button"
                  accessibilityLabel={`Back to ${selectedPlatform} categories`}
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6, marginBottom: 14 }}
                >
                  <Ionicons name="chevron-back" size={16} color={colors.accent}
                    accessibilityElementsHidden />
                  <Text style={{ fontSize: 15, color: colors.accent, fontWeight: '600' }}>
                    {selectedPlatform} Categories
                  </Text>
                </Pressable>

                <Text style={{ fontSize: 19, fontWeight: '700', color: colors.text,
                  marginBottom: 14 }} accessibilityRole="header">
                  {selectedCategory}
                </Text>

                {list.loading && (
                  <ActivityIndicator size="large" color={colors.appleVisBlue}
                    accessibilityLabel="Loading apps" style={{ marginVertical: 24 }} />
                )}

                {!list.loading && exploreApps.length === 0 && (
                  <EmptyState
                    icon="apps-outline"
                    title="No apps listed yet"
                    subtitle={`${selectedCategory} apps for ${selectedPlatform} will appear here once the Drupal category fields are confirmed and mapped.`}
                  />
                )}

                {!list.loading && exploreApps.map(renderAppCard)}
              </>
            )}
          </>
        )}

        {/* ════════════════════════════════════════════════════════════════
            SAVED — apps the user has bookmarked
        ════════════════════════════════════════════════════════════════ */}
        {filter === 'Saved' && (
          <>
            {saved.items.length === 0 ? (
              <EmptyState
                icon="bookmark-outline"
                title="No saved apps"
                subtitle="Save any app from the Latest or Explore lists. Your saved apps sync across your devices via iCloud."
              />
            ) : (
              <>
                {/* Bulk action */}
                <View style={{ flexDirection: 'row', justifyContent: 'flex-end', marginBottom: 12 }}>
                  <Pressable
                    onPress={() => confirmDestructiveAction(showAlert, {
                      title: 'Unsave All?',
                      message: `This will remove all ${saved.items.length} saved app${saved.items.length === 1 ? '' : 's'} from Saved.`,
                      confirmLabel: 'Unsave All',
                      onConfirm: async () => {
                        for (const item of saved.items) await saved.unsave(item.id).catch(() => {});
                        showToast('All saved apps removed.', 'success');
                      },
                    })}
                    accessible accessibilityRole="button" accessibilityLabel="Unsave all apps"
                    style={{ paddingHorizontal: 12, paddingVertical: 6,
                      backgroundColor: colors.pill, borderRadius: 8 }}>
                    <Text style={{ fontSize: 13, color: '#FF3B30', fontWeight: '600' }}>Unsave All</Text>
                  </Pressable>
                </View>

                {saved.items.map((item) => {
                  // Try to find full app data from the loaded list
                  const fullApp = list.apps.find(a => a.id === item.id);
                  if (fullApp) {
                    return renderAppCard(fullApp);
                  }
                  // App not in current page — show simplified card
                  return (
                    <AccessibleCard
                      key={item.id}
                      title={item.title}
                      meta={`Saved ${new Date(item.savedAt).toLocaleDateString()} · Saved`}
                      actions={['Open App Page', 'Unsave App']}
                      onAction={(action) => {
                        if (action === 'Open App Page') {
                          router.push({ pathname: '/app-detail/[id]' as any,
                            params: { id: item.id, name: item.title } });
                        } else if (action === 'Unsave App') {
                          saved.unsave(item.id);
                          showToast('App unsaved.', 'success');
                        }
                      }}
                    />
                  );
                })}
              </>
            )}
          </>
        )}

      </ScrollView>
    </Screen>
  );
}
