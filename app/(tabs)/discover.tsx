import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActivityIndicator, Clipboard, Linking, Pressable,
  RefreshControl, ScrollView, Share, Text, TextInput, View,
} from 'react-native';
import { useScrollToTop } from '@react-navigation/native';
import { useFocusEffect, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { EmptyState } from '../../src/components/EmptyState';
import { Screen } from '../../src/components/Screen';
import { AccessibleCard } from '../../src/components/AccessibleCard';
import { LoadMoreButton } from '../../src/components/LoadMoreButton';
import { useSearch } from '../../src/hooks/useSearch';
import { useAppList } from '../../src/hooks/useAppList';
import { useResourceList } from '../../src/hooks/useResourceList';
import { useSavedItems } from '../../src/hooks/useSavedItems';
import { useFocusRestore } from '../../src/hooks/useFocusRestore';
import { useHandoff } from '../../src/hooks/useHandoff';
import { useToast } from '../../src/contexts/ToastContext';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import {
  readAloud, summariseText, simplifyText,
  accessibilityConsensus, isAppleIntelligenceAvailable, donateSiriActivity,
} from '../../src/services/intelligenceService';
import type { ForumTopic, AppListing, Resource } from '../../src/types/content';

// ─── App directory constants ──────────────────────────────────────────────────
// Mirrors the AppleVis website app directory taxonomy.
// Replace with live taxonomy API results once Drupal confirms vocabulary name.

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
  'watchOS': ['Health & Fitness', 'Lifestyle', 'Productivity', 'Utilities'],
  'Apple TV': ['Entertainment', 'Games', 'Music', 'Sports', 'Utilities'],
  'Vision Pro': ['Entertainment', 'Games', 'Productivity', 'Utilities'],
};

// ─── SearchResultsSection ─────────────────────────────────────────────────────

function SearchResultsSection({
  title,
  count,
  children,
}: {
  title: string;
  count: number;
  children: React.ReactNode;
}) {
  const { colors } = useTheme();
  if (count === 0) return null;
  return (
    <View style={{ marginBottom: 8 }}>
      <Text
        style={{
          fontSize: 13, fontWeight: '700', color: colors.textSecondary,
          textTransform: 'uppercase', letterSpacing: 0.8,
          marginBottom: 8, marginTop: 4,
        }}
        accessibilityRole="header"
      >
        {title} ({count})
      </Text>
      {children}
    </View>
  );
}

// ─── SectionHeader ────────────────────────────────────────────────────────────

function SectionHeader({ label }: { label: string }) {
  const { colors } = useTheme();
  return (
    <Text
      style={{
        fontSize: 13, fontWeight: '700', color: colors.textSecondary,
        textTransform: 'uppercase', letterSpacing: 0.8,
        marginTop: 20, marginBottom: 10,
      }}
      accessibilityRole="header"
    >
      {label}
    </Text>
  );
}

// ─── Main screen ──────────────────────────────────────────────────────────────

export default function DiscoverScreen() {
  const router  = useRouter();
  const { colors, styles, isDark } = useTheme();
  const { screenReaderEnabled } = useAccessibilityPreferences();
  const { showToast } = useToast();
  const search  = useSearch();
  const apps    = useAppList();
  const guides  = useResourceList();
  const savedApps = useSavedItems('appListing');
  const appRefs   = useRef<Map<string, View>>(new Map());
  const { save: saveFocus } = useFocusRestore();
  const aiAvailable = isAppleIntelligenceAvailable();
  const scrollRef = useRef<ScrollView>(null);
  useScrollToTop(scrollRef);

  useFocusEffect(useCallback(() => {
    const t = setTimeout(() => scrollRef.current?.flashScrollIndicators(), 350);
    return () => clearTimeout(t);
  }, []));

  const [selectedPlatform, setSelectedPlatform] = useState<Platform>('iOS');
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);

  useHandoff({
    activityType: 'com.applevis.app.discover',
    title: 'Discover — AppleVis',
    webpageURL: 'https://www.applevis.com',
  });

  // Announce result count to VoiceOver when a search completes
  useEffect(() => {
    if (!search.hasQuery || search.loading) return;
    const total = search.totalCount;
    const msg = total === 0
      ? 'No results found'
      : `${total} result${total === 1 ? '' : 's'} found`;
    AccessibilityInfo.announceForAccessibility(msg);
  }, [search.hasQuery, search.loading, search.totalCount]);

  // ── Derived app lists ───────────────────────────────────────────────────────

  const categoryApps = useMemo(() => {
    if (!selectedCategory) return [];
    return apps.apps.filter((a) =>
      (a.category === selectedCategory || a.category === '') &&
      (a.platform === selectedPlatform || a.platform === ''),
    );
  }, [apps.apps, selectedCategory, selectedPlatform]);

  // ── App card helpers (same pattern as apps.tsx) ─────────────────────────────

  function buildAppActions(app: AppListing) {
    const isSaved = savedApps.isSaved(app.id);
    return [
      'Open App Page',
      ...(app.appStoreUrl ? ['Open in App Store'] : []),
      isSaved ? 'Unsave App' : 'Save App',
      ...(!screenReaderEnabled ? ['Read Aloud'] : []),
      'Share',
      ...(aiAvailable ? ['Summarise Reviews', 'Accessibility Consensus', 'Simplify'] : []),
    ];
  }

  function handleAppAction(action: string, app: AppListing) {
    if (action === 'Open App Page') {
      saveFocus(appRefs.current.get(app.id) ?? null);
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
    } else if (action === 'Read Aloud') {
      readAloud([app.name, app.summary].filter(Boolean).join('. '));
    } else if (action === 'Share') {
      Share.share({ title: app.name, message: `${app.name} on AppleVis — https://www.applevis.com/accessibility-apps` }).catch(() => {});
    } else if (action === 'Summarise Reviews') {
      summariseText(`Summarise accessibility reviews for ${app.name}: ${app.summary}`).then((s) => { if (s) showToast(s, 'success'); });
    } else if (action === 'Accessibility Consensus') {
      accessibilityConsensus([app.summary]).then((s) => { if (s) showToast(s, 'success'); });
    } else if (action === 'Simplify') {
      simplifyText(app.summary).then((s) => { if (s) showToast(s, 'success'); });
    }
  }

  function renderAppCard(app: AppListing) {
    const isSaved = savedApps.isSaved(app.id);
    return (
      <AccessibleCard
        key={app.id}
        ref={(el) => { if (el) appRefs.current.set(app.id, el); else appRefs.current.delete(app.id); }}
        title={app.name}
        meta={[
          app.developer || null,
          app.category  || null,
          app.reviewCount > 0 ? `${app.reviewCount} reviews` : null,
          `Updated ${new Date(app.lastUpdatedAt).toLocaleDateString()}`,
          isSaved ? 'Saved' : null,
        ].filter(Boolean).join(' · ')}
        iconUrl={app.iconUrl}
        actions={buildAppActions(app)}
        onAction={(a) => handleAppAction(a, app)}
      />
    );
  }

  // ── Guide card helpers ──────────────────────────────────────────────────────

  function handleGuideAction(action: string, item: Resource) {
    if (action === 'Open') {
      router.push({ pathname: '/resource-detail/[id]' as any, params: { id: item.id, title: item.title, url: item.url } });
    } else if (action === 'Read Aloud') {
      readAloud([item.title, item.summary].filter(Boolean).join('. '));
    } else if (action === 'Summarise') {
      summariseText([item.title, item.summary].filter(Boolean).join('\n')).then((s) => {
        if (s) showToast(s, 'success');
      });
    } else if (action === 'Simplify') {
      simplifyText([item.title, item.summary].filter(Boolean).join('\n')).then((s) => {
        if (s) showToast(s, 'success');
      });
    } else if (action === 'Share') {
      Share.share({ title: item.title, message: `${item.title} — ${item.url}` }).catch(() => {});
    } else if (action === 'Copy Link') {
      Clipboard.setString(item.url);
      showToast('Link copied.', 'success');
    }
  }

  // ── Search result topic handler ─────────────────────────────────────────────

  function handleTopicPress(topic: ForumTopic) {
    router.push({ pathname: '/topic/[id]' as any, params: { id: topic.id, title: topic.title } });
  }

  // ── Render ──────────────────────────────────────────────────────────────────

  const isSearching = search.hasQuery;

  return (
    <Screen title="Discover" showBack={false}>
      <ScrollView
        ref={scrollRef}
        contentContainerStyle={{ padding: 16, paddingBottom: 120 }}
        showsVerticalScrollIndicator
        refreshControl={isSearching ? undefined : (
          <RefreshControl
            refreshing={guides.refreshing}
            onRefresh={guides.refresh}
            tintColor={colors.appleVisBlue}
            accessibilityLabel="Pull to refresh"
          />
        )}
      >

        {/* ── Search bar ────────────────────────────────────────────────── */}
        <View style={{
          flexDirection: 'row', alignItems: 'center',
          backgroundColor: colors.inputBackground,
          borderRadius: 12, borderWidth: 1, borderColor: colors.border,
          paddingHorizontal: 12, paddingVertical: 10, marginBottom: 4,
        }}>
          <Ionicons name="search" size={17} color={colors.textSecondary}
            style={{ marginRight: 8 }} accessibilityElementsHidden />
          <TextInput
            value={isSearching ? undefined : ''}
            onChangeText={search.search}
            placeholder="Search topics, apps, guides…"
            placeholderTextColor={colors.textSecondary}
            style={{ flex: 1, fontSize: 16, color: colors.text }}
            accessible
            accessibilityRole="search"
            accessibilityLabel="Search AppleVis"
            accessibilityHint="Type to search topics, apps, and guides"
            returnKeyType="search"
            clearButtonMode="while-editing"
            onSubmitEditing={(e) => search.search(e.nativeEvent.text)}
          />
          {isSearching && (
            <Pressable
              onPress={search.clear}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Clear search"
              style={{ padding: 4 }}
            >
              <Ionicons name="close-circle" size={18} color={colors.textSecondary} />
            </Pressable>
          )}
        </View>

        {/* Title-match disclaimer — only shown while a search is active */}
        {isSearching && (
          <Text
            style={{ fontSize: 12, color: colors.textSecondary, marginBottom: 12 }}
            accessibilityElementsHidden
          >
            Searching by title — full site search coming soon
          </Text>
        )}

        {/* ════════════════════════════════════════════════════════════════
            SEARCH RESULTS
        ════════════════════════════════════════════════════════════════ */}
        {isSearching && (
          <>
            {search.loading && (
              <View style={{ alignItems: 'center', paddingVertical: 32 }}>
                <ActivityIndicator size="large" color={colors.appleVisBlue}
                  accessibilityLabel="Searching…" />
                <Text style={[styles.lede, { marginTop: 12, textAlign: 'center' }]}>
                  Searching…
                </Text>
              </View>
            )}

            {!search.loading && search.totalCount === 0 && (
              <EmptyState
                icon="search-outline"
                title="No results"
                subtitle="Nothing matched your search. Try different keywords."
              />
            )}

            {search.error && (
              <View style={{
                flexDirection: 'row', gap: 8, alignItems: 'flex-start',
                backgroundColor: '#FFF8F0', borderRadius: 10, padding: 12, marginBottom: 10,
              }}
                accessible accessibilityLabel="Some search results may be incomplete. Check your connection."
              >
                <Ionicons name="warning-outline" size={16} color="#C05000"
                  accessibilityElementsHidden style={{ marginTop: 1 }} />
                <Text style={{ flex: 1, fontSize: 13, color: '#C05000', lineHeight: 18 }}>
                  {search.error}
                </Text>
              </View>
            )}

            {!search.loading && (
              <>
                {/* Topics */}
                <SearchResultsSection title="Topics" count={search.results.forums.length}>
                  {search.results.forums.map((topic) => (
                    <AccessibleCard
                      key={topic.id}
                      title={topic.title}
                      meta={[
                        topic.replyCount > 0 ? `${topic.replyCount} repl${topic.replyCount === 1 ? 'y' : 'ies'}` : 'No replies',
                        topic.authorName || null,
                        new Date(topic.lastActivityAt).toLocaleDateString(),
                      ].filter(Boolean).join(' · ')}
                      actions={['Open Topic']}
                      onAction={() => handleTopicPress(topic)}
                    />
                  ))}
                </SearchResultsSection>

                {/* Apps */}
                <SearchResultsSection title="Apps" count={search.results.apps.length}>
                  {search.results.apps.map((app) => (
                    <AccessibleCard
                      key={app.id}
                      title={app.name}
                      meta={[
                        app.developer || null,
                        app.reviewCount > 0 ? `${app.reviewCount} reviews` : null,
                      ].filter(Boolean).join(' · ')}
                      iconUrl={app.iconUrl}
                      actions={['Open App Page']}
                      onAction={() => {
                        donateSiriActivity({ type: 'searchApps', query: app.name });
                        router.push({ pathname: '/app-detail/[id]' as any, params: { id: app.id, name: app.name } });
                      }}
                    />
                  ))}
                </SearchResultsSection>

                {/* Guides */}
                <SearchResultsSection title="Guides" count={search.results.resources.length}>
                  {search.results.resources.map((item) => (
                    <AccessibleCard
                      key={item.id}
                      title={item.title}
                      meta={[item.kind, `Updated ${new Date(item.updatedAt).toLocaleDateString()}`].join(' · ')}
                      actions={['Open Guide']}
                      onAction={() => router.push({ pathname: '/resource-detail/[id]' as any, params: { id: item.id, title: item.title, url: item.url } })}
                    />
                  ))}
                </SearchResultsSection>
              </>
            )}
          </>
        )}

        {/* ════════════════════════════════════════════════════════════════
            BROWSE — shown when not searching
        ════════════════════════════════════════════════════════════════ */}
        {!isSearching && (
          <>
            {/* ── Apps ──────────────────────────────────────────────────── */}
            <SectionHeader label="Apps" />

            {/* Platform tabs */}
            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={{ gap: 8, paddingBottom: 12 }}
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
                    <Text style={{ fontSize: 14, fontWeight: '600', color: isSelected ? '#FFF' : colors.text }}>
                      {platform}
                    </Text>
                  </Pressable>
                );
              })}
            </ScrollView>

            {/* Category list or filtered app list */}
            {!selectedCategory ? (
              <>
                <Text style={{ fontSize: 13, color: colors.textSecondary, marginBottom: 10, lineHeight: 18 }}
                  accessibilityElementsHidden>
                  {CATEGORIES[selectedPlatform].length} categories
                </Text>
                {CATEGORIES[selectedPlatform].map((category) => (
                  <Pressable
                    key={category}
                    onPress={() => setSelectedCategory(category)}
                    accessible
                    accessibilityRole="button"
                    accessibilityLabel={category}
                    accessibilityHint="Double tap to browse apps in this category"
                    style={({ pressed }) => [
                      styles.card,
                      { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
                        marginBottom: 6, opacity: pressed ? 0.75 : 1 },
                    ]}
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
              <>
                {/* Back button */}
                <Pressable
                  onPress={() => setSelectedCategory(null)}
                  accessible accessibilityRole="button"
                  accessibilityLabel={`Back to ${selectedPlatform} categories`}
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6, marginBottom: 14 }}
                >
                  <Ionicons name="chevron-back" size={16} color={colors.accent} accessibilityElementsHidden />
                  <Text style={{ fontSize: 15, color: colors.accent, fontWeight: '600' }}>
                    {selectedPlatform} Categories
                  </Text>
                </Pressable>

                <Text style={{ fontSize: 19, fontWeight: '700', color: colors.text, marginBottom: 14 }}
                  accessibilityRole="header">
                  {selectedCategory}
                </Text>

                {apps.loading && (
                  <ActivityIndicator size="large" color={colors.appleVisBlue}
                    accessibilityLabel="Loading apps" style={{ marginVertical: 24 }} />
                )}

                {!apps.loading && categoryApps.length === 0 && (
                  <EmptyState
                    icon="apps-outline"
                    title="No apps listed yet"
                    subtitle={`${selectedCategory} apps for ${selectedPlatform} will appear here once the Drupal category fields are confirmed and mapped.`}
                  />
                )}

                {!apps.loading && categoryApps.map(renderAppCard)}
              </>
            )}

            {/* ── Forums ────────────────────────────────────────────────── */}
            <SectionHeader label="Forums" />
            <Pressable
              onPress={() => router.push('/(tabs)/forums' as any)}
              accessible
              accessibilityRole="button"
              accessibilityLabel="AppleVis Forums. Browse and join discussions. Double tap to open."
              style={({ pressed }) => [
                styles.card,
                { flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 8, opacity: pressed ? 0.75 : 1 },
              ]}
            >
              <Ionicons name="chatbubbles-outline" size={32} color={colors.accent} accessibilityElementsHidden />
              <View style={{ flex: 1 }}>
                <Text style={{ fontSize: 16, fontWeight: '600', color: colors.text, marginBottom: 3 }}>
                  AppleVis Forums
                </Text>
                <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 18 }}>
                  Community discussions about accessibility and Apple products
                </Text>
              </View>
              <Ionicons name="chevron-forward" size={16} color={colors.textSecondary}
                accessibilityElementsHidden />
            </Pressable>

            {/* ── Podcasts ───────────────────────────────────────────────── */}
            <SectionHeader label="Podcasts" />
            <Pressable
              onPress={() => router.push('/(tabs)/podcasts' as any)}
              accessible
              accessibilityRole="button"
              accessibilityLabel="AppleVis Podcast. Browse all episodes. Double tap to open."
              style={({ pressed }) => [
                styles.card,
                { flexDirection: 'row', alignItems: 'center', gap: 14, opacity: pressed ? 0.75 : 1 },
              ]}
            >
              <Ionicons name="radio-outline" size={32} color={colors.accent} accessibilityElementsHidden />
              <View style={{ flex: 1 }}>
                <Text style={{ fontSize: 16, fontWeight: '600', color: colors.text, marginBottom: 3 }}>
                  AppleVis Podcast
                </Text>
                <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 18 }}>
                  Episodes, discussions, and community interviews — browse and listen
                </Text>
              </View>
              <Ionicons name="chevron-forward" size={16} color={colors.textSecondary}
                accessibilityElementsHidden />
            </Pressable>

            {/* ── Guides ─────────────────────────────────────────────────── */}
            <SectionHeader label="Guides" />

            {guides.loading && (
              <View style={{ alignItems: 'center', paddingVertical: 24 }}>
                <ActivityIndicator size="large" color={colors.appleVisBlue}
                  accessibilityLabel="Loading guides" />
              </View>
            )}

            {!guides.loading && guides.error && (
              <View style={[styles.card, { backgroundColor: '#FFF0F0' }]}>
                <Text style={[styles.cardTitle, { color: '#D00' }]}>Could not load guides</Text>
                <Text style={styles.cardMeta}>{guides.error}</Text>
                <Pressable onPress={guides.refresh} accessible accessibilityRole="button"
                  accessibilityLabel="Retry loading guides" style={{ marginTop: 12 }}>
                  <Text style={{ color: colors.appleVisBlue, fontWeight: '700' }}>Retry</Text>
                </Pressable>
              </View>
            )}

            {!guides.loading && !guides.error && guides.resources.length === 0 && (
              <EmptyState
                icon="book-outline"
                title="No guides yet"
                subtitle="Pull down to refresh."
              />
            )}

            {!guides.loading && guides.resources.map((item) => (
              <AccessibleCard
                key={item.id}
                title={item.title}
                meta={[item.kind, `Updated ${new Date(item.updatedAt).toLocaleDateString()}`].join(' · ')}
                actions={[
                  'Open',
                  ...(!screenReaderEnabled ? ['Read Aloud'] : []),
                  'Summarise',
                  'Simplify',
                  'Share',
                  'Copy Link',
                ]}
                onAction={(action) => handleGuideAction(action, item)}
              />
            ))}

            <LoadMoreButton
              hasMore={guides.hasMore}
              isLoadingMore={guides.isLoadingMore}
              onPress={guides.loadMore}
            />

            {/* ── Blogs (Coming Soon) ─────────────────────────────────────── */}
            <SectionHeader label="Blogs" />
            <View
              style={[styles.card, {
                flexDirection: 'row', alignItems: 'flex-start', gap: 12, opacity: 0.6,
              }]}
              accessible
              accessibilityLabel="Blogs coming soon. Blog posts and editorials will appear here once the content type is confirmed with the Drupal developer."
            >
              <Ionicons name="newspaper-outline" size={28} color={colors.textSecondary}
                accessibilityElementsHidden style={{ marginTop: 2 }} />
              <View style={{ flex: 1 }}>
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                  <Text style={{ fontSize: 16, fontWeight: '600', color: colors.text }}>
                    Blogs
                  </Text>
                  <View style={{
                    paddingHorizontal: 7, paddingVertical: 2,
                    backgroundColor: colors.pill, borderRadius: 6,
                  }}>
                    <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary }}>
                      COMING SOON
                    </Text>
                  </View>
                </View>
                <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 18 }}>
                  AppleVis blog posts and editorials — pending confirmation of the blog content type with the Drupal developer.
                </Text>
              </View>
            </View>

            {/* ── Contribute to AppleVis ───────────────────────────────────── */}
            <SectionHeader label="Contribute to AppleVis" />
            <Pressable
              onPress={() => Linking.openURL('https://www.applevis.com/podcasts/upload').catch(() => {})}
              accessible
              accessibilityRole="link"
              accessibilityLabel="Submit a Podcast. Know an accessible podcast? Nominate it for the AppleVis directory. Opens submission form in your browser."
              style={({ pressed }) => [
                styles.card,
                { flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 8, opacity: pressed ? 0.75 : 1 },
              ]}
            >
              <Ionicons name="mic-outline" size={28} color={colors.accent} accessibilityElementsHidden />
              <View style={{ flex: 1 }}>
                <Text style={{ fontSize: 16, fontWeight: '600', color: colors.text, marginBottom: 3 }}>
                  Submit a Podcast
                </Text>
                <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 18 }}>
                  Know an accessible podcast? Nominate it for the AppleVis directory
                </Text>
              </View>
              <Ionicons name="open-outline" size={16} color={colors.textSecondary} accessibilityElementsHidden />
            </Pressable>

            <Pressable
              onPress={() => Linking.openURL('https://www.applevis.com/form/blog-submission').catch(() => {})}
              accessible
              accessibilityRole="link"
              accessibilityLabel="Submit a Blog Post. Share your expertise or experience with the AppleVis community. Opens submission form in your browser."
              style={({ pressed }) => [
                styles.card,
                { flexDirection: 'row', alignItems: 'center', gap: 14, opacity: pressed ? 0.75 : 1 },
              ]}
            >
              <Ionicons name="create-outline" size={28} color={colors.accent} accessibilityElementsHidden />
              <View style={{ flex: 1 }}>
                <Text style={{ fontSize: 16, fontWeight: '600', color: colors.text, marginBottom: 3 }}>
                  Submit a Blog Post
                </Text>
                <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 18 }}>
                  Share your expertise or experience with the AppleVis community
                </Text>
              </View>
              <Ionicons name="open-outline" size={16} color={colors.textSecondary} accessibilityElementsHidden />
            </Pressable>

            <Pressable
              onPress={() => router.push('/submit-app')}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Submit an App. Found an accessible iOS app? Add it to the AppleVis directory with your accessibility notes."
              style={({ pressed }) => [
                styles.card,
                { flexDirection: 'row', alignItems: 'center', gap: 14, marginTop: 0, opacity: pressed ? 0.75 : 1 },
              ]}
            >
              <Ionicons name="phone-portrait-outline" size={28} color={colors.accent} accessibilityElementsHidden />
              <View style={{ flex: 1 }}>
                <Text style={{ fontSize: 16, fontWeight: '600', color: colors.text, marginBottom: 3 }}>
                  Submit an App
                </Text>
                <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 18 }}>
                  Found an accessible iOS app? Add it to the AppleVis directory
                </Text>
              </View>
              <Ionicons name="chevron-forward" size={16} color={colors.textSecondary} accessibilityElementsHidden />
            </Pressable>
          </>
        )}
      </ScrollView>
    </Screen>
  );
}
