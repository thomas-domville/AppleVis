import { useCallback, useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActivityIndicator, findNodeHandle, Linking, Pressable,
  ScrollView, Text, TextInput, View,
} from 'react-native';
import { useScrollToTop } from '@react-navigation/native';
import { useFocusEffect, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { EmptyState } from '../../src/components/EmptyState';
import { Screen } from '../../src/components/Screen';
import { AccessibleCard } from '../../src/components/AccessibleCard';
import { useSearch } from '../../src/hooks/useSearch';
import { useFocusRestore } from '../../src/hooks/useFocusRestore';
import { useHandoff } from '../../src/hooks/useHandoff';
import { useToast } from '../../src/contexts/ToastContext';
import { useTip, TIP_KEYS, TIPS } from '../../src/contexts/ContextualTipContext';
import { useTheme } from '../../src/contexts/ThemeContext';
import { usePreferences } from '../../src/contexts/PreferencesContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { useLanguageDetection } from '../../src/hooks/useLanguageDetection';
import { APPLEVIS_SOCIAL_LINKS } from '../../src/data/socialLinks';
import {
  donateSiriActivity,
  translateSearchQueryToEnglish,
} from '../../src/services/intelligenceService';
import type { ForumTopic } from '../../src/types/content';

// ─── Section accent palette ────────────────────────────────────────────────────
const SECTION_ACCENTS = {
  apps:       '#3b82f6',  // blue
  community:  '#6366f1',  // indigo
  learn:      '#10b981',  // emerald
  bugs:       '#f97316',  // orange
  bemyeyes:   '#00A99D',  // Be My Eyes teal
  contribute: '#f59e0b',  // amber
  connect:    '#0ea5e9',  // sky
} as const;

// Be My Eyes deep link helpers
// TODO: Replace placeholder schemes with confirmed URLs from Be My Eyes team
const BME_APP_STORE = 'https://apps.apple.com/us/app/be-my-eyes/id905177575';
const BME_DEEP_LINKS = {
  volunteer:  'bemyeyes://volunteer',   // placeholder — awaiting confirmation
  beMyAI:     'bemyeyes://ai',          // placeholder — awaiting confirmation
  directory:  'bemyeyes://directory',   // placeholder — awaiting confirmation
} as const;

const SOCIAL_ACCENT: Record<string, string> = {
  x:        '#000000',
  facebook: '#1877F2',
  mastodon: '#6364FF',
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

// ─── Hub sections ─────────────────────────────────────────────────────────────

function SectionIntro({ title, subtitle, accentColor }: {
  title: string;
  subtitle: string;
  accentColor?: string;
}) {
  const { colors } = useTheme();
  const accent = accentColor ?? colors.accent;
  return (
    <View style={{ marginTop: 22, marginBottom: 10, flexDirection: 'row', alignItems: 'flex-start', gap: 10 }}>
      <View style={{ width: 3, borderRadius: 2, backgroundColor: accent, marginTop: 2, alignSelf: 'stretch', minHeight: 36 }} />
      <View style={{ flex: 1 }}>
        <Text
          style={{ fontSize: 13, fontWeight: '700', color: accent, textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 4 }}
          accessibilityRole="header"
          accessibilityLabel={title}
        >
          {title}
        </Text>
        <Text style={{ fontSize: 14, lineHeight: 20, color: colors.textSecondary }}>
          {subtitle}
        </Text>
      </View>
    </View>
  );
}

function HubRow({
  icon, title, subtitle, onPress, external = false, nodeRef, accentColor, hint,
}: {
  icon: React.ComponentProps<typeof Ionicons>['name'];
  title: string;
  subtitle: string;
  onPress: () => void;
  external?: boolean;
  nodeRef?: { current: View | null };
  accentColor?: string;
  hint?: string;
}) {
  const { colors, styles } = useTheme();
  const { reduceTransparency } = useAccessibilityPreferences();
  const accent = accentColor ?? colors.accent;

  return (
    <Pressable
      ref={nodeRef as any}
      onPress={() => { Haptics.selectionAsync(); onPress(); }}
      accessible
      accessibilityRole={external ? 'link' : 'button'}
      accessibilityLabel={`${title}. ${subtitle}.${external ? ' Opens in your browser.' : ''}`}
      accessibilityHint={hint}
      style={({ pressed }) => [
        styles.card,
        { flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 8, opacity: pressed ? 0.75 : 1 },
      ]}
    >
      {/* Tinted icon square — gated by reduceTransparency */}
      <View
        style={{
          width: 44, height: 44, borderRadius: 12, flexShrink: 0,
          alignItems: 'center', justifyContent: 'center',
          backgroundColor: reduceTransparency ? colors.inputBackground : accent + '18',
        }}
        accessibilityElementsHidden
      >
        <Ionicons name={icon} size={24} color={accent} accessibilityElementsHidden />
      </View>
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
  const { reduceTransparency } = useAccessibilityPreferences();
  const {
    nonEnglishDetectionEnabled,
    searchTranslationEnabled,
  } = usePreferences();
  const { showToast } = useToast();
  const { showTip }   = useTip();
  const search  = useSearch();
  const appsHubRef    = useRef<View>(null);
  const forumsHubRef  = useRef<View>(null);
  const blogHubRef    = useRef<View>(null);
  const guidesHubRef  = useRef<View>(null);
  const podcastHubRef = useRef<View>(null);
  const bugHubRef     = useRef<View>(null);
  const searchInputRef = useRef<TextInput>(null);
  const { save: saveFocus } = useFocusRestore();
  const scrollRef = useRef<ScrollView>(null);
  const [translatingSearch, setTranslatingSearch] = useState(false);
  const [translatedFrom, setTranslatedFrom] = useState('');
  useScrollToTop(scrollRef);
  const searchLanguage = useLanguageDetection(search.query);

  useFocusEffect(useCallback(() => {
    showTip(TIP_KEYS.tabDiscover, TIPS.tabDiscover);
    const t = setTimeout(() => scrollRef.current?.flashScrollIndicators(), 350);
    return () => clearTimeout(t);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []));


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

  const showTranslateSearch =
    nonEnglishDetectionEnabled &&
    searchTranslationEnabled &&
    search.hasQuery &&
    searchLanguage.isConfident &&
    searchLanguage.isNonEnglish &&
    translatedFrom.trim() !== search.query.trim();

  async function handleTranslateSearch() {
    const original = search.query.trim();
    if (!original || translatingSearch) return;
    setTranslatingSearch(true);
    try {
      const translated = await translateSearchQueryToEnglish(original);
      if (!translated) {
        showToast('In-app search translation requires Apple Intelligence on this device.', 'warning');
        return;
      }
      setTranslatedFrom(original);
      search.search(translated);
      AccessibilityInfo.announceForAccessibility(`Searching translated English query: ${translated}`);
      setTimeout(() => searchInputRef.current?.focus(), 100);
    } finally {
      setTranslatingSearch(false);
    }
  }

  // ── Be My Eyes deep link launcher ──────────────────────────────────────────

  async function openBME(deepLink: string, label: string) {
    Haptics.selectionAsync();
    try {
      const canOpen = await Linking.canOpenURL(deepLink);
      if (canOpen) {
        await Linking.openURL(deepLink);
      } else {
        await Linking.openURL(BME_APP_STORE);
      }
    } catch {
      showToast(`Could not open ${label}.`, 'error');
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
            ref={searchInputRef}
            value={search.query}
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
              onPress={() => {
                search.clear();
                // Restore VoiceOver focus to the search field after clearing
                setTimeout(() => {
                  const handle = findNodeHandle(searchInputRef.current);
                  if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
                }, 100);
              }}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Clear search"
              accessibilityHint="Returns to the browse screen"
              style={{ padding: 4 }}
            >
              <Ionicons name="close-circle" size={18} color={colors.textSecondary} />
            </Pressable>
          )}
        </View>

        {/* Title-match disclaimer — only shown while a search is active */}
        {showTranslateSearch && (
          <View
            style={{
              backgroundColor: colors.pill,
              borderRadius: 10,
              borderWidth: 1,
              borderColor: colors.border,
              paddingHorizontal: 12,
              paddingVertical: 10,
              marginBottom: 12,
              gap: 8,
            }}
            accessible
            accessibilityRole="alert"
            accessibilityLabel="AppleVis search works best in English. Translate this search to English?"
          >
            <Text style={{ color: colors.text, fontSize: 14, lineHeight: 20 }} importantForAccessibility="no">
              AppleVis search works best in English. Translate this search to English?
            </Text>
            <Pressable
              onPress={handleTranslateSearch}
              disabled={translatingSearch}
              accessible
              accessibilityRole="button"
              accessibilityLabel={translatingSearch ? 'Translating search, please wait' : 'Translate search to English'}
              accessibilityState={{ disabled: translatingSearch }}
              style={{
                alignItems: 'center',
                backgroundColor: colors.accent,
                borderRadius: 8,
                paddingVertical: 9,
                opacity: translatingSearch ? 0.7 : 1,
              }}
            >
              {translatingSearch
                ? <ActivityIndicator color={colors.accentText} />
                : <Text style={{ color: colors.accentText, fontWeight: '700', fontSize: 14 }}>
                    Translate Search
                  </Text>
              }
            </Pressable>
          </View>
        )}

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
              <View
                style={{ alignItems: 'center', paddingVertical: 32 }}
                accessible
                accessibilityLiveRegion="polite"
                accessibilityLabel="Searching AppleVis, please wait"
              >
                <ActivityIndicator size="large" color={colors.appleVisBlue} accessibilityElementsHidden />
                <Text style={[styles.lede, { marginTop: 12, textAlign: 'center' }]}
                  accessibilityElementsHidden>
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
              subtitle="Browse accessible apps by platform and category, or view your saved apps."
              accentColor={SECTION_ACCENTS.apps}
            />
            <HubRow
              nodeRef={appsHubRef}
              icon="apps-outline"
              title="Browse Apps"
              subtitle="Search and explore accessible apps across iOS, Mac, Apple Watch, and more"
              accentColor={SECTION_ACCENTS.apps}
              hint="Opens the app directory browser"
              onPress={() => {
                saveFocus(appsHubRef.current);
                router.push('/app-browse' as any);
              }}
            />

            <SectionIntro
              title="Community"
              subtitle="Find discussions and recent posts from AppleVis members."
              accentColor={SECTION_ACCENTS.community}
            />
            <HubRow
              nodeRef={forumsHubRef}
              icon="chatbubbles-outline"
              title="Forums"
              subtitle="Browse community discussions about accessibility and Apple products"
              accentColor={SECTION_ACCENTS.community}
              hint="Opens the forum browser"
              onPress={() => {
                saveFocus(forumsHubRef.current);
                router.push('/forums-browse' as any);
              }}
            />
            <HubRow
              nodeRef={blogHubRef}
              icon="newspaper-outline"
              title="AppleVis Blog"
              subtitle="Read AppleVis posts, news, reviews, and opinion pieces in-app"
              accentColor={SECTION_ACCENTS.community}
              hint="Opens the blog reader"
              onPress={() => {
                saveFocus(blogHubRef.current);
                router.push('/blog-browse' as any);
              }}
            />

            <SectionIntro
              title="Learn"
              subtitle="Explore guides, podcast episodes, and practical accessibility resources."
              accentColor={SECTION_ACCENTS.learn}
            />
            <HubRow
              nodeRef={guidesHubRef}
              icon="book-outline"
              title="Guides and Resources"
              subtitle="How-to articles, getting-started content, and accessibility resources"
              accentColor={SECTION_ACCENTS.learn}
              hint="Opens the guides and resources browser"
              onPress={() => {
                saveFocus(guidesHubRef.current);
                router.push('/guide-browse' as any);
              }}
            />
            <HubRow
              nodeRef={podcastHubRef}
              icon="radio-outline"
              title="Podcast"
              subtitle="Browse episodes, your queue, downloads, and play history"
              accentColor={SECTION_ACCENTS.learn}
              hint="Opens the podcast browser"
              onPress={() => {
                saveFocus(podcastHubRef.current);
                router.push('/podcast-browse' as any);
              }}
            />

            <SectionIntro
              title="Bug Tracker"
              subtitle="Browse active accessibility bugs reported by the AppleVis community."
              accentColor={SECTION_ACCENTS.bugs}
            />
            <HubRow
              nodeRef={bugHubRef}
              icon="bug-outline"
              title="iOS / iPadOS Bugs"
              subtitle="Active and resolved accessibility bugs on iPhone and iPad"
              accentColor={SECTION_ACCENTS.bugs}
              hint="Opens the iOS bug tracker"
              onPress={() => {
                saveFocus(bugHubRef.current);
                router.push({ pathname: '/bug-browse' as any, params: { platform: 'ios' } });
              }}
            />
            <HubRow
              icon="desktop-outline"
              title="macOS Bugs"
              subtitle="Active and resolved accessibility bugs on Mac"
              accentColor={SECTION_ACCENTS.bugs}
              hint="Opens the macOS bug tracker"
              onPress={() => {
                saveFocus(bugHubRef.current);
                router.push({ pathname: '/bug-browse' as any, params: { platform: 'macos' } });
              }}
            />

            <SectionIntro
              title="Be My Eyes"
              subtitle="Free visual assistance — connect with volunteers, AI, and accessible services."
              accentColor={SECTION_ACCENTS.bemyeyes}
            />
            <HubRow
              icon="people-outline"
              title="Call a Volunteer"
              subtitle="Connect instantly with a sighted volunteer via live video, 24/7 in 185 languages"
              accentColor={SECTION_ACCENTS.bemyeyes}
              hint="Opens the Be My Eyes app to start a volunteer call"
              external
              onPress={() => openBME(BME_DEEP_LINKS.volunteer, 'Be My Eyes')}
            />
            <HubRow
              icon="sparkles-outline"
              title="Be My AI"
              subtitle="Ask AI to describe images, read text, or answer visual questions in 36 languages"
              accentColor={SECTION_ACCENTS.bemyeyes}
              hint="Opens the Be My Eyes app to the AI assistant"
              external
              onPress={() => openBME(BME_DEEP_LINKS.beMyAI, 'Be My Eyes')}
            />
            <HubRow
              icon="business-outline"
              title="Service Directory"
              subtitle="Reach accessible customer service at hundreds of companies and government departments"
              accentColor={SECTION_ACCENTS.bemyeyes}
              hint="Opens the Be My Eyes app to the service directory"
              external
              onPress={() => openBME(BME_DEEP_LINKS.directory, 'Be My Eyes')}
            />

            <SectionIntro
              title="Contribute"
              subtitle="Share useful apps, posts, and podcast recommendations with AppleVis."
              accentColor={SECTION_ACCENTS.contribute}
            />
            <HubRow
              icon="phone-portrait-outline"
              title="Submit an App"
              subtitle="Add an accessible app to the AppleVis directory"
              accentColor={SECTION_ACCENTS.contribute}
              hint="Opens the app submission screen"
              onPress={() => router.push('/submit-wizard' as any)}
            />
            <HubRow
              icon="create-outline"
              title="Submit a Blog Post"
              subtitle="Share your expertise or experience with the community"
              accentColor={SECTION_ACCENTS.contribute}
              hint="Opens the submission form in your browser"
              external
              onPress={() => Linking.openURL('https://www.applevis.com/form/blog-submission').catch(() => showToast('Could not open the blog submission form.', 'error'))}
            />
            <HubRow
              icon="mic-outline"
              title="Submit a Podcast"
              subtitle="Nominate an accessible podcast for the AppleVis directory"
              accentColor={SECTION_ACCENTS.contribute}
              hint="Opens the submission form in your browser"
              external
              onPress={() => Linking.openURL('https://www.applevis.com/podcasts/upload').catch(() => showToast('Could not open the podcast submission form.', 'error'))}
            />
            <HubRow
              icon="bug-outline"
              title="Submit a Bug Report"
              subtitle="Found an accessibility bug? Report it to the AppleVis community"
              accentColor={SECTION_ACCENTS.contribute}
              hint="Opens the bug report submission form in your browser"
              external
              onPress={() => Linking.openURL('https://applevis.com/form/community-bug-report-form').catch(() => showToast('Could not open the bug report form.', 'error'))}
            />

            <SectionIntro
              title="Connect"
              subtitle="Follow AppleVis on social platforms."
              accentColor={SECTION_ACCENTS.connect}
            />
            <View style={{ flexDirection: 'row', gap: 8, marginBottom: 10 }}>
              {APPLEVIS_SOCIAL_LINKS.map((link) => {
                const socialAccent = SOCIAL_ACCENT[link.id] ?? SECTION_ACCENTS.connect;
                return (
                  <Pressable
                    key={link.id}
                    onPress={() => {
                      Haptics.selectionAsync();
                      Linking.openURL(link.url).catch(() => showToast('Could not open link.', 'error'));
                    }}
                    accessible
                    accessibilityRole="link"
                    accessibilityLabel={`${link.description}. Opens in your browser.`}
                    accessibilityHint="Double tap to open in your browser"
                    style={({ pressed }) => [
                      styles.cardSmall,
                      {
                        flex: 1, alignItems: 'center', justifyContent: 'center',
                        gap: 6, minHeight: 86, marginBottom: 0,
                        opacity: pressed ? 0.75 : 1,
                      },
                    ]}
                  >
                    <View
                      style={{
                        width: 40, height: 40, borderRadius: 10,
                        alignItems: 'center', justifyContent: 'center',
                        backgroundColor: reduceTransparency ? colors.inputBackground : socialAccent + '18',
                      }}
                      accessibilityElementsHidden
                    >
                      <Ionicons name={link.icon as any} size={22} color={socialAccent} accessibilityElementsHidden />
                    </View>
                    <Text style={{ fontSize: 13, fontWeight: '700', color: colors.text, textAlign: 'center' }}>
                      {link.label}
                    </Text>
                    <Ionicons name="open-outline" size={13} color={colors.textSecondary} accessibilityElementsHidden />
                  </Pressable>
                );
              })}
            </View>
          </>
        )}
      </ScrollView>
    </Screen>
  );
}
