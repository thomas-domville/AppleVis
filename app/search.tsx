import { useEffect, useRef, useState } from 'react';
import { AccessibilityInfo, ScrollView, Text, TextInput, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Screen } from '../src/components/Screen';
import { AppleVisSearchInput } from '../src/components/search/AppleVisSearchInput';
import { SearchResultsGrouped } from '../src/components/search/SearchResultsGrouped';
import { SearchEmptyState } from '../src/components/search/SearchEmptyState';
import { SearchLoadingState } from '../src/components/search/SearchLoadingState';
import { SearchErrorState } from '../src/components/search/SearchErrorState';
import { SearchTranslationPrompt } from '../src/components/search/SearchTranslationPrompt';
import { useSearch } from '../src/hooks/useSearch';
import { useSearchTranslation } from '../src/hooks/useSearchTranslation';
import { useTheme } from '../src/contexts/ThemeContext';
import { usePreferences } from '../src/contexts/PreferencesContext';
import { useToast } from '../src/contexts/ToastContext';
import { useAccessibilityPreferences } from '../src/hooks/useAccessibilityPreferences';
import { sounds } from '../src/services/sounds';

export default function SearchScreen() {
  const router = useRouter();
  const { styles } = useTheme();
  const { nonEnglishDetectionEnabled, searchTranslationEnabled, searchAutoFocusEnabled } = usePreferences();
  const { screenReaderEnabled } = useAccessibilityPreferences();
  const { showToast } = useToast();
  const search = useSearch();
  const { results, loading, error, hasQuery, totalCount } = search;
  const inputRef = useRef<TextInput>(null);
  const lastAnnouncedCountRef = useRef<number | null>(null);

  const { visible: showTranslateSearch, translating: translatingSearch, translate: handleTranslateSearch } =
    useSearchTranslation(
      search,
      nonEnglishDetectionEnabled,
      searchTranslationEnabled,
      () => showToast('In-app search translation requires Apple Intelligence on this device.', 'warning'),
      inputRef,
    );

  // Auto-focus the input on mount — configurable, since immediately raising the
  // keyboard can be disorienting for some VoiceOver users who want to get
  // oriented on the screen first.
  useEffect(() => {
    if (!searchAutoFocusEnabled) return;
    const timer = setTimeout(() => inputRef.current?.focus(), 300);
    return () => clearTimeout(timer);
  }, [searchAutoFocusEnabled]);

  // Announce result count to VoiceOver when a search settles, and only play the
  // completion sound when the count actually changed — not on every debounced update.
  // Kept concise ("12 results found in 4 categories.") — each section heading
  // (Site Results, Forum Topics, Apps, Guides and Resources) gives the detail.
  useEffect(() => {
    if (!hasQuery || loading) return;
    const categoryCount = [results.site, results.forums, results.apps, results.resources]
      .filter((group) => group.length > 0).length;
    const msg = totalCount === 0
      ? 'No results found.'
      : `${totalCount} result${totalCount === 1 ? '' : 's'} found in ${categoryCount} categor${categoryCount === 1 ? 'y' : 'ies'}.`;
    AccessibilityInfo.announceForAccessibility(msg);

    if (lastAnnouncedCountRef.current !== totalCount) {
      sounds.searchComplete().catch(() => {});
      lastAnnouncedCountRef.current = totalCount;
    }
  }, [totalCount, hasQuery, loading, results]);

  return (
    <Screen title="Search" showSettings={false}>
      <AppleVisSearchInput
        ref={inputRef}
        value={search.query}
        onChangeText={search.search}
        onClear={search.clear}
        placeholder="Search forums, apps, resources…"
      />

      {showTranslateSearch && (
        <SearchTranslationPrompt translating={translatingSearch} onTranslate={handleTranslateSearch} />
      )}

      <ScrollView showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">

        {loading && <SearchLoadingState />}

        {!loading && error && <SearchErrorState message={error} />}

        {!loading && hasQuery && totalCount === 0 && !error && (
          <SearchEmptyState
            query={search.query}
            onClearSearch={search.clear}
            onBrowseDiscover={() => router.push('/(tabs)/discover' as any)}
          />
        )}

        {!hasQuery && !loading && (
          <Text style={styles.lede}>
            Search AppleVis. Public site results are used until the search API is available.
          </Text>
        )}

        {!loading && (
          <SearchResultsGrouped
            results={results}
            screenReaderEnabled={screenReaderEnabled}
            onOpenExternalError={() => showToast('Could not open the AppleVis result.', 'error')}
          />
        )}

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
