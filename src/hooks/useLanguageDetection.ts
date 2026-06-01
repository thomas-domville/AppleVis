import { useEffect, useState } from 'react';
import { detectNonEnglish } from '../services/intelligenceService';

export type LanguageDetectionResult = {
  isNonEnglish: boolean;
  /** True once the text is long enough to trust the result. */
  isConfident: boolean;
};

/**
 * Watches a text value and reports whether it appears to be non-English.
 * Debounced by 600 ms so it does not fire on every keystroke.
 *
 * Usage in a future compose screen:
 *   const { isNonEnglish, isConfident } = useLanguageDetection(draftText);
 *   if (isNonEnglish && isConfident) show <TranslationBanner />
 */
export function useLanguageDetection(text: string): LanguageDetectionResult {
  const [result, setResult] = useState<LanguageDetectionResult>({
    isNonEnglish: false,
    isConfident: false,
  });

  useEffect(() => {
    const timer = setTimeout(() => {
      setResult({
        isNonEnglish: detectNonEnglish(text),
        isConfident: text.trim().length >= 20,
      });
    }, 600);
    return () => clearTimeout(timer);
  }, [text]);

  return result;
}
