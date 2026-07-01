import { useCallback, useEffect, useRef } from 'react';
import {
  AccessibilityInfo, Linking, Pressable,
  ScrollView, Text, TextInput, View,
} from 'react-native';
import { useScrollToTop } from '@react-navigation/native';
import { useFocusEffect, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { Screen } from '../../src/components/Screen';
import { AppleVisSearchInput } from '../../src/components/search/AppleVisSearchInput';
import { SearchResultsGrouped } from '../../src/components/search/SearchResultsGrouped';
import { SearchEmptyState } from '../../src/components/search/SearchEmptyState';
import { SearchLoadingState } from '../../src/components/search/SearchLoadingState';
import { SearchErrorState } from '../../src/components/search/SearchErrorState';
import { SearchTranslationPrompt } from '../../src/components/search/SearchTranslationPrompt';
import { useSearch } from '../../src/hooks/useSearch';
import { useSearchTranslation } from '../../src/hooks/useSearchTranslation';
import { useFocusRestore } from '../../src/hooks/useFocusRestore';
import { useHandoff } from '../../src/hooks/useHandoff';
import { useToast } from '../../src/contexts/ToastContext';
import { useTip, TIP_KEYS, TIPS } from '../../src/contexts/ContextualTipContext';
import { useTheme } from '../../src/contexts/ThemeContext';
import { usePreferences } from '../../src/contexts/PreferencesContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { APPLEVIS_SOCIAL_LINKS } from '../../src/data/socialLinks';
import { sounds } from '../../src/services/sounds';

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

// Be My Eyes deep link helpers — partner_id confirmed: 'applevis' (2026-06-25)
const BME_APP_STORE = 'https://apps.apple.com/us/app/be-my-eyes/id905177575';
const BME_DEEP_LINKS = {
  volunteer:  'bemyeyes://volunteer',            // open volunteer call screen
  beMyAI:     'bemyeyes://ai',                   // open Be My AI screen
  directory:  'bemyeyes://partner/applevis',     // open AppleVis specialized support channel
} as const;

const SOCIAL_ACCENT: Record<string, string> = {
  x:        '#000000',
  facebook: '#1877F2',
  mastodon: '#6364FF',
};

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
  icon, title, subtitle, onPress, external = false, externalApp = false, nodeRef, accentColor, hint,
}: {
  icon: React.ComponentProps<typeof Ionicons>['name'];
  title: string;
  subtitle: string;
  onPress: () => void;
  external?: boolean;    // opens in browser — appends "Opens in your browser" to VoiceOver label
  externalApp?: boolean; // opens another app — link role + open icon, no browser text
  nodeRef?: { current: View | null };
  accentColor?: string;
  hint?: string;
}) {
  const { colors, styles } = useTheme();
  const { reduceTransparency } = useAccessibilityPreferences();
  const accent = accentColor ?? colors.accent;
  const isExternal = external || externalApp;

  return (
    <Pressable
      ref={nodeRef as any}
      onPress={() => {
        Haptics.selectionAsync();
        sounds.articleOpen().catch(() => {});
        onPress();
      }}
      accessible
      accessibilityRole={isExternal ? 'link' : 'button'}
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
        name={isExternal ? 'open-outline' : 'chevron-forward'}
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
  const { reduceTransparency, screenReaderEnabled } = useAccessibilityPreferences();
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
  const lastAnnouncedCountRef = useRef<number | null>(null);
  useScrollToTop(scrollRef);

  const { visible: showTranslateSearch, translating: translatingSearch, translate: handleTranslateSearch } =
    useSearchTranslation(
      search,
      nonEnglishDetectionEnabled,
      searchTranslationEnabled,
      () => showToast('In-app search translation requires Apple Intelligence on this device.', 'warning'),
      searchInputRef,
    );

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

  // Announce result count to VoiceOver when a search settles, and only play the
  // completion sound when the count actually changed — not on every debounced update.
  // Kept concise ("12 results found in 4 categories.") — each section heading
  // (Site Results, Forum Topics, Apps, Guides and Resources) gives the detail.
  useEffect(() => {
    if (!search.hasQuery || search.loading) return;
    const total = search.totalCount;
    const categoryCount = [search.results.site, search.results.forums, search.results.apps, search.results.resources]
      .filter((group) => group.length > 0).length;
    const msg = total === 0
      ? 'No results found.'
      : `${total} result${total === 1 ? '' : 's'} found in ${categoryCount} categor${categoryCount === 1 ? 'y' : 'ies'}.`;
    AccessibilityInfo.announceForAccessibility(msg);

    if (lastAnnouncedCountRef.current !== total) {
      sounds.searchComplete().catch(() => {});
      lastAnnouncedCountRef.current = total;
    }
  }, [search.hasQuery, search.loading, search.totalCount]);

  // ── Be My Eyes deep link launcher ──────────────────────────────────────────

  async function openBME(deepLink: string, label: string) {
    Haptics.selectionAsync();
    try {
      const canOpen = await Linking.canOpenURL(deepLink);
      if (canOpen) {
        AccessibilityInfo.announceForAccessibility(`Opening ${label} app.`);
        await Linking.openURL(deepLink);
      } else {
        AccessibilityInfo.announceForAccessibility(`${label} is not installed. Opening its App Store page instead.`);
        await Linking.openURL(BME_APP_STORE);
      }
    } catch {
      showToast(`Could not open ${label}.`, 'error');
    }
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
        <AppleVisSearchInput
          ref={searchInputRef}
          value={search.query}
          onChangeText={search.search}
          onClear={search.clear}
        />

        {/* Search-query translation prompt — only shown while a search is active */}
        {showTranslateSearch && (
          <SearchTranslationPrompt translating={translatingSearch} onTranslate={handleTranslateSearch} />
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
            {search.loading && <SearchLoadingState />}

            {!search.loading && search.totalCount === 0 && (
              <SearchEmptyState query={search.query} onClearSearch={search.clear} />
            )}

            {search.error && <SearchErrorState message={search.error} />}

            {!search.loading && (
              <SearchResultsGrouped
                results={search.results}
                screenReaderEnabled={screenReaderEnabled}
                onOpenExternalError={() => showToast('Could not open the AppleVis result.', 'error')}
              />
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
            <HubRow
              icon="add-circle-outline"
              title="Report a New Bug"
              subtitle="Found an accessibility bug not yet in the tracker? Submit it here"
              accentColor={SECTION_ACCENTS.bugs}
              hint="Opens the bug report submission wizard"
              onPress={() => router.push('/submit-bug' as any)}
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
              externalApp
              onPress={() => openBME(BME_DEEP_LINKS.volunteer, 'Be My Eyes')}
            />
            <HubRow
              icon="sparkles-outline"
              title="Be My AI"
              subtitle="Ask AI to describe images, read text, or answer visual questions in 36 languages"
              accentColor={SECTION_ACCENTS.bemyeyes}
              hint="Opens the Be My Eyes app to the AI assistant"
              externalApp
              onPress={() => openBME(BME_DEEP_LINKS.beMyAI, 'Be My Eyes')}
            />
            <HubRow
              icon="business-outline"
              title="Service Directory"
              subtitle="Reach accessible customer service at hundreds of companies and government departments"
              accentColor={SECTION_ACCENTS.bemyeyes}
              hint="Opens the Be My Eyes app to the service directory"
              externalApp
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
              hint="Opens the blog submission wizard"
              onPress={() => router.push('/submit-blog' as any)}
            />
            <HubRow
              icon="mic-outline"
              title="Submit a Podcast"
              subtitle="Nominate an accessible podcast for the AppleVis directory"
              accentColor={SECTION_ACCENTS.contribute}
              hint="Opens the podcast submission wizard"
              onPress={() => router.push('/submit-podcast' as any)}
            />
            <HubRow
              icon="bug-outline"
              title="Submit a Bug Report"
              subtitle="Found an accessibility bug? Report it to the AppleVis community"
              accentColor={SECTION_ACCENTS.contribute}
              hint="Opens the community bug report wizard"
              onPress={() => router.push('/submit-bug' as any)}
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
