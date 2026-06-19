import { useCallback, useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActivityIndicator, Linking, Pressable,
  ScrollView, Share, Text, TextInput, View,
} from 'react-native';
import { useScrollToTop } from '@react-navigation/native';
import { useFocusEffect, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { EmptyState } from '../../src/components/EmptyState';
import { Screen } from '../../src/components/Screen';
import { AccessibleCard } from '../../src/components/AccessibleCard';
import { LoadMoreButton } from '../../src/components/LoadMoreButton';
import { useSearch } from '../../src/hooks/useSearch';
import { useAppCategoryExperiment } from '../../src/hooks/useAppCategoryExperiment';
import { useAppDirectoryCategories } from '../../src/hooks/useAppDirectoryCategories';
import { useSavedItems } from '../../src/hooks/useSavedItems';
import { useFocusRestore } from '../../src/hooks/useFocusRestore';
import { useHandoff } from '../../src/hooks/useHandoff';
import { useToast } from '../../src/contexts/ToastContext';
import { useTip, TIP_KEYS, TIPS } from '../../src/contexts/ContextualTipContext';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { APPLEVIS_SOCIAL_LINKS } from '../../src/data/socialLinks';
import { APP_PLATFORMS } from '../../src/data/appDirectory';
import {
  readAloud, summariseText, simplifyText,
  accessibilityConsensus, isAppleIntelligenceAvailable, donateSiriActivity,
} from '../../src/services/intelligenceService';
import type { ForumTopic, AppListing, AppCategory } from '../../src/types/content';

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

// ─── Hub sections ─────────────────────────────────────────────────────────────

function SectionIntro({ title, subtitle }: { title: string; subtitle: string }) {
  const { colors } = useTheme();
  return (
    <View style={{ marginTop: 22, marginBottom: 10 }}>
      <Text
        style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 4 }}
        accessibilityRole="header"
      >
        {title}
      </Text>
      <Text style={{ fontSize: 14, lineHeight: 20, color: colors.textSecondary }}>
        {subtitle}
      </Text>
    </View>
  );
}

function HubRow({
  icon,
  title,
  subtitle,
  onPress,
  external = false,
}: {
  icon: React.ComponentProps<typeof Ionicons>['name'];
  title: string;
  subtitle: string;
  onPress: () => void;
  external?: boolean;
}) {
  const { colors, styles } = useTheme();
  return (
    <Pressable
      onPress={onPress}
      accessible
      accessibilityRole={external ? 'link' : 'button'}
      accessibilityLabel={`${title}. ${subtitle}.${external ? ' Opens in your browser.' : ''}`}
      style={({ pressed }) => [
        styles.card,
        {
          flexDirection: 'row',
          alignItems: 'center',
          gap: 14,
          marginBottom: 8,
          opacity: pressed ? 0.75 : 1,
        },
      ]}
    >
      <Ionicons name={icon} size={28} color={colors.accent} accessibilityElementsHidden />
      <View style={{ flex: 1 }}>
        <Text style={{ fontSize: 16, fontWeight: '600', color: colors.text, marginBottom: 3 }}>
          {title}
        </Text>
        <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 18 }}>
          {subtitle}
        </Text>
      </View>
      <Ionicons
        name={external ? 'open-outline' : 'chevron-forward'}
        size={16}
        color={colors.textSecondary}
        accessibilityElementsHidden
      />
    </Pressable>
  );
}

// ─── Main screen ──────────────────────────────────────────────────────────────

export default function DiscoverScreen() {
  const router  = useRouter();
  const { colors, styles } = useTheme();
  const { screenReaderEnabled } = useAccessibilityPreferences();
  const { showToast } = useToast();
  const { showTip }   = useTip();
  const search  = useSearch();
  const savedApps = useSavedItems('appListing');
  const appRefs   = useRef<Map<string, View>>(new Map());
  const { save: saveFocus } = useFocusRestore();
  const aiAvailable = isAppleIntelligenceAvailable();
  const scrollRef = useRef<ScrollView>(null);
  useScrollToTop(scrollRef);

  useFocusEffect(useCallback(() => {
    showTip(TIP_KEYS.tabDiscover, TIPS.tabDiscover);
    const t = setTimeout(() => scrollRef.current?.flashScrollIndicators(), 350);
    return () => clearTimeout(t);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []));

  const [selectedPlatform, setSelectedPlatform] = useState('ios');
  const [selectedCategory, setSelectedCategory] = useState<AppCategory | null>(null);
  const categoryList = useAppDirectoryCategories(selectedPlatform);
  const categoryProbe = useAppCategoryExperiment(selectedPlatform, selectedCategory);
  const selectedPlatformName = APP_PLATFORMS.find((platform) => platform.id === selectedPlatform)?.name ?? 'Apps';

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
      if (app.id.startsWith('public:') && app.url) {
        Linking.openURL(app.url).catch(() => showToast('Could not open the AppleVis app page.', 'error'));
        return;
      }
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
      Share.share({ title: app.name, message: `${app.name} on AppleVis — ${app.url ?? 'https://www.applevis.com/accessibility-apps'}` }).catch(() => {});
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
            Searching AppleVis. Public site results are used until the search API is available.
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
                <SearchResultsSection title="Site Results" count={search.results.site.length}>
                  {search.results.site.map((item) => (
                    <AccessibleCard
                      key={item.id}
                      title={item.title}
                      meta={[
                        item.contentType !== 'unknown' ? item.contentType : null,
                        item.source === 'public' ? 'AppleVis public search' : 'AppleVis search API',
                      ].filter(Boolean).join(' · ')}
                      actions={['Open Result']}
                      onAction={() => Linking.openURL(item.url).catch(() => showToast('Could not open the AppleVis result.', 'error'))}
                    />
                  ))}
                </SearchResultsSection>

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
            {/* ── App Directory ─────────────────────────────────────────── */}
            <SectionIntro
              title="App Directory"
              subtitle="Browse accessible apps by platform and category."
            />

            {/* Platform tabs */}
            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={{ gap: 8, paddingBottom: 12 }}
              accessibilityRole="tablist"
              accessibilityLabel="Platform"
            >
              {APP_PLATFORMS.map((platform) => {
                const isSelected = selectedPlatform === platform.id;
                return (
                  <Pressable
                    key={platform.id}
                    onPress={() => {
                      setSelectedPlatform(platform.id);
                      setSelectedCategory(null);
                      AccessibilityInfo.announceForAccessibility(`${platform.name} selected`);
                    }}
                    accessible
                    accessibilityRole="tab"
                    accessibilityLabel={platform.name}
                    accessibilityState={{ selected: isSelected }}
                    style={{
                      paddingHorizontal: 14, paddingVertical: 8,
                      borderRadius: 20, borderWidth: isSelected ? 0 : 1,
                      borderColor: colors.border,
                      backgroundColor: isSelected ? colors.accent : colors.inputBackground,
                    }}
                  >
                    <Text style={{ fontSize: 14, fontWeight: '600', color: isSelected ? '#FFF' : colors.text }}>
                      {platform.name}
                    </Text>
                  </Pressable>
                );
              })}
            </ScrollView>

            {/* Category list or filtered app list */}
            {!selectedCategory ? (
              <>
                <Text
                  style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 8 }}
                  accessibilityRole="header"
                >
                  {selectedPlatformName} Categories
                </Text>
                <Text style={{ fontSize: 13, color: colors.textSecondary, marginBottom: 10, lineHeight: 18 }}>
                  {categoryList.categories.length} categories{categoryList.fromFallback && selectedPlatform !== 'ios' ? ' prepared for the app directory API' : ''}
                </Text>
                {categoryList.categories.map((category) => (
                  <Pressable
                    key={category.slug}
                    onPress={() => setSelectedCategory(category)}
                    accessible
                    accessibilityRole="button"
                    accessibilityLabel={category.count ? `${category.name}, ${category.count} apps` : category.name}
                    accessibilityHint="Double tap to browse apps in this category"
                    style={({ pressed }) => [
                      styles.card,
                      { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
                        marginBottom: 6, opacity: pressed ? 0.75 : 1 },
                    ]}
                  >
                    <View style={{ flex: 1 }}>
                      <Text style={{ fontSize: 16, color: colors.text, fontWeight: '500' }}>
                        {category.name}
                      </Text>
                      {typeof category.count === 'number' && (
                        <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2 }}>
                          {category.count} apps
                        </Text>
                      )}
                    </View>
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
                  accessibilityLabel={`Back to ${selectedPlatformName} categories`}
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6, marginBottom: 14 }}
                >
                  <Ionicons name="chevron-back" size={16} color={colors.accent} accessibilityElementsHidden />
                  <Text style={{ fontSize: 15, color: colors.accent, fontWeight: '600' }}>
                    {selectedPlatformName} Categories
                  </Text>
                </Pressable>

                <Text style={{ fontSize: 19, fontWeight: '700', color: colors.text, marginBottom: 14 }}
                  accessibilityRole="header">
                  {selectedCategory.name}
                </Text>

                {categoryProbe.loading && (
                  <ActivityIndicator size="large" color={colors.appleVisBlue}
                    accessibilityLabel="Loading apps" style={{ marginVertical: 24 }} />
                )}

                {!categoryProbe.loading && categoryProbe.error && (
                  <View style={[styles.card, { backgroundColor: '#FFF8F0' }]}>
                    <Text style={[styles.cardTitle, { color: colors.text }]}>Could not load this category</Text>
                    <Text style={[styles.cardMeta, { lineHeight: 19 }]}>
                      The app tried the app directory API and fallback sources, but no app listings were available.
                    </Text>
                    <Pressable
                      onPress={categoryProbe.retry}
                      accessible
                      accessibilityRole="button"
                      accessibilityLabel="Retry category lookup"
                      style={{ marginTop: 12 }}
                    >
                      <Text style={{ color: colors.appleVisBlue, fontWeight: '700' }}>Retry</Text>
                    </Pressable>
                  </View>
                )}

                {!categoryProbe.loading && !categoryProbe.error && categoryProbe.probe && (
                  <Text style={{ fontSize: 12, color: colors.textSecondary, marginBottom: 10 }}>
                    {categoryProbe.probe.source === 'public'
                      ? 'Using AppleVis public directory page until the app directory API is available.'
                      : `Loaded from ${categoryProbe.probe.fieldName}.`}
                  </Text>
                )}

                {!categoryProbe.loading && !categoryProbe.error && categoryProbe.apps.length === 0 && (
                  <EmptyState
                    icon="apps-outline"
                    title="No apps listed yet"
                    subtitle={`No ${selectedCategory.name} apps came back for this platform.`}
                  />
                )}

                {!categoryProbe.loading && categoryProbe.apps.map(renderAppCard)}

                <LoadMoreButton
                  hasMore={categoryProbe.hasMore}
                  isLoadingMore={categoryProbe.isLoadingMore}
                  onPress={categoryProbe.loadMore}
                />
              </>
            )}

            <SectionIntro
              title="Community"
              subtitle="Find discussions and recent posts from AppleVis members."
            />
            <HubRow
              icon="chatbubbles-outline"
              title="Forums"
              subtitle="Browse community discussions about accessibility and Apple products"
              onPress={() => router.push('/(tabs)/forums' as any)}
            />
            <HubRow
              icon="newspaper-outline"
              title="Community Blog"
              subtitle="Read recent AppleVis posts, news, reviews, and opinion pieces"
              external
              onPress={() => Linking.openURL('https://www.applevis.com/blog').catch(() => showToast('Could not open the AppleVis blog.', 'error'))}
            />

            <SectionIntro
              title="Learn"
              subtitle="Explore guides, podcast episodes, and practical accessibility resources."
            />
            <HubRow
              icon="book-outline"
              title="Guides and Resources"
              subtitle="How-to articles, getting-started content, and accessibility resources"
              onPress={() => router.push('/(tabs)/resources' as any)}
            />
            <HubRow
              icon="radio-outline"
              title="Podcast"
              subtitle="Episodes, discussions, and community interviews"
              onPress={() => router.push('/(tabs)/podcasts' as any)}
            />

            <SectionIntro
              title="Contribute"
              subtitle="Share useful apps, posts, and podcast recommendations with AppleVis."
            />
            <HubRow
              icon="phone-portrait-outline"
              title="Submit an App"
              subtitle="Add an accessible app to the AppleVis directory"
              onPress={() => router.push('/submit-app')}
            />
            <HubRow
              icon="create-outline"
              title="Submit a Blog Post"
              subtitle="Share your expertise or experience with the community"
              external
              onPress={() => Linking.openURL('https://www.applevis.com/form/blog-submission').catch(() => showToast('Could not open the blog submission form.', 'error'))}
            />
            <HubRow
              icon="mic-outline"
              title="Submit a Podcast"
              subtitle="Nominate an accessible podcast for the AppleVis directory"
              external
              onPress={() => Linking.openURL('https://www.applevis.com/podcasts/upload').catch(() => showToast('Could not open the podcast submission form.', 'error'))}
            />

            <SectionIntro
              title="Connect"
              subtitle="Follow AppleVis on social platforms."
            />
            <View style={{ flexDirection: 'row', gap: 8, marginBottom: 10 }}>
              {APPLEVIS_SOCIAL_LINKS.map((link) => (
                <Pressable
                  key={link.id}
                  onPress={() => Linking.openURL(link.url).catch(() => showToast('Could not open link.', 'error'))}
                  accessible
                  accessibilityRole="link"
                  accessibilityLabel={`${link.description}. Opens in your browser.`}
                  style={({ pressed }) => [
                    styles.cardSmall,
                    {
                      flex: 1,
                      alignItems: 'center',
                      justifyContent: 'center',
                      gap: 6,
                      minHeight: 86,
                      marginBottom: 0,
                      opacity: pressed ? 0.75 : 1,
                    },
                  ]}
                >
                  <Ionicons name={link.icon as any} size={24} color={colors.accent} accessibilityElementsHidden />
                  <Text style={{ fontSize: 14, fontWeight: '700', color: colors.text, textAlign: 'center' }}>
                    {link.label}
                  </Text>
                  <Ionicons name="open-outline" size={14} color={colors.textSecondary} accessibilityElementsHidden />
                </Pressable>
              ))}
            </View>
          </>
        )}
      </ScrollView>
    </Screen>
  );
}
