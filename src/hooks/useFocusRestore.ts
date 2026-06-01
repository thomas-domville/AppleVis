import { useCallback, useRef } from 'react';
import { AccessibilityInfo, findNodeHandle, View } from 'react-native';
import { useFocusEffect } from '@react-navigation/native';

/**
 * Restores VoiceOver focus to the last saved element whenever the screen
 * regains focus — i.e. when the user returns from a child screen.
 *
 * Pattern:
 *   const { save } = useFocusRestore();
 *
 *   // Before navigating away, pass the element that triggered navigation:
 *   save(myRef.current);
 *   router.push('/somewhere');
 *
 * On return, VoiceOver focus is placed back on that element automatically.
 * The hook is a no-op on initial screen mount (save() was never called).
 */
export function useFocusRestore() {
  const savedEl = useRef<View | null>(null);

  useFocusEffect(
    useCallback(() => {
      const el = savedEl.current;
      if (!el) return;

      // Delay lets the screen transition animation finish before moving focus,
      // otherwise the platform animation can fight VoiceOver's cursor movement.
      const timer = setTimeout(() => {
        const handle = findNodeHandle(el);
        if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
      }, 350);

      return () => clearTimeout(timer);
    }, []),
  );

  /** Call this with the element the user just activated before navigating. */
  const save = useCallback((element: View | null) => {
    savedEl.current = element;
  }, []);

  return { save };
}
