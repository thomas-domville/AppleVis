import { AccessibilityInfo, findNodeHandle } from 'react-native';

type FocusableRef = { current: { measure?: unknown } | number | null } | { current: null };

type RestoreFocusOptions = {
  delay?: number;
  fallbackAnnouncement?: string;
};

/**
 * Moves VoiceOver focus to the node held by `ref` after a delay (giving layout/animation
 * time to settle), announcing `fallbackAnnouncement` instead if the node isn't mounted.
 * Returns the timer so callers that track pending timers for cleanup still can.
 */
export function restoreAccessibilityFocus(
  ref: FocusableRef,
  { delay = 250, fallbackAnnouncement }: RestoreFocusOptions = {},
): ReturnType<typeof setTimeout> {
  return setTimeout(() => {
    const handle = findNodeHandle(ref.current as never);
    if (handle) {
      AccessibilityInfo.setAccessibilityFocus(handle);
    } else if (fallbackAnnouncement) {
      AccessibilityInfo.announceForAccessibility(fallbackAnnouncement);
    }
  }, delay);
}
