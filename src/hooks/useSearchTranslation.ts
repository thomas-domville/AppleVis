import { useRef, useState } from 'react';
import { AccessibilityInfo, TextInput } from 'react-native';
import { useLanguageDetection } from './useLanguageDetection';
import { translateSearchQueryToEnglish } from '../services/intelligenceService';
import type { SearchState } from './useSearch';

/**
 * Shared "translate this search to English" flow used by both the dedicated
 * Search screen and Discover's embedded search. Consolidates state that was
 * previously duplicated (and had diverged) between the two screens.
 */
export function useSearchTranslation(
  search: Pick<SearchState, 'query' | 'hasQuery' | 'search'>,
  nonEnglishDetectionEnabled: boolean,
  searchTranslationEnabled: boolean,
  onUnavailable: () => void,
  searchInputRef?: React.RefObject<TextInput | null>,
) {
  const [translating, setTranslating] = useState(false);
  const [translatedFrom, setTranslatedFrom] = useState('');
  const searchLanguage = useLanguageDetection(search.query);
  const busyRef = useRef(false);

  const visible =
    nonEnglishDetectionEnabled &&
    searchTranslationEnabled &&
    search.hasQuery &&
    searchLanguage.isConfident &&
    searchLanguage.isNonEnglish &&
    translatedFrom.trim() !== search.query.trim();

  async function translate() {
    const original = search.query.trim();
    if (!original || busyRef.current) return;
    busyRef.current = true;
    setTranslating(true);
    try {
      const translated = await translateSearchQueryToEnglish(original);
      if (!translated) {
        onUnavailable();
        return;
      }
      setTranslatedFrom(original);
      search.search(translated);
      AccessibilityInfo.announceForAccessibility(`Searching translated English query: ${translated}`);
      setTimeout(() => searchInputRef?.current?.focus(), 100);
    } finally {
      busyRef.current = false;
      setTranslating(false);
    }
  }

  return { visible, translating, translate };
}
