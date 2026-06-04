import { useEffect, useState } from 'react';
import { AccessibilityInfo, Platform } from 'react-native';

/**
 * Returns true when the user has enabled Settings → Accessibility →
 * Display & Text Size → Reduce Transparency. Glass/blur surfaces must
 * fall back to solid colours in this mode to maintain legibility.
 *
 * Updates in real-time as the setting changes (no app restart required).
 * Always returns false on Android (no equivalent setting exists).
 */
export function useReduceTransparency(): boolean {
  const [reduce, setReduce] = useState(false);

  useEffect(() => {
    if (Platform.OS !== 'ios') return;
    AccessibilityInfo.isReduceTransparencyEnabled().then(setReduce).catch(() => {});
    const sub = AccessibilityInfo.addEventListener('reduceTransparencyChanged', setReduce);
    return () => sub.remove();
  }, []);

  return reduce;
}
