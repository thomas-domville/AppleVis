import { useEffect, useRef } from 'react';
import { AccessibilityInfo, findNodeHandle, View } from 'react-native';
import * as Haptics from 'expo-haptics';
import { i18n } from '../i18n';
import { sounds } from '../services/sounds';

/**
 * Fires multi-modal feedback on refresh and initial load transitions.
 *
 * Refresh:
 *   false → true  : start sound + VoiceOver "Refreshing <label>"
 *   true  → false : complete sound + VoiceOver "<label> updated" + success haptic
 *
 * Initial load (optional loading param):
 *   true  → false : complete sound + VoiceOver "<label> loaded" + success haptic
 *
 * @param refreshing    The refreshing boolean from any list hook.
 * @param label         Human-readable name of the content, e.g. "Podcasts".
 * @param loading       The initial loading boolean from the same hook (optional).
 * @param getFirstItem  Returns the first content card View so VoiceOver focus
 *                      can be restored there after load/refresh completes.
 */
export function useRefreshFeedback(
  refreshing: boolean,
  label: string,
  loading?: boolean,
  getFirstItem?: () => View | null,
): void {
  const wasRefreshing   = useRef(false);
  const wasLoading      = useRef(loading ?? false);
  // Keep a stable ref so effects don't need it as a dependency.
  const getFirstItemRef = useRef(getFirstItem);
  getFirstItemRef.current = getFirstItem;

  function focusFirstItem() {
    setTimeout(() => {
      const el = getFirstItemRef.current?.();
      if (!el) return;
      const handle = findNodeHandle(el);
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, 400);
  }

  useEffect(() => {
    const started   =  refreshing && !wasRefreshing.current;
    const completed = !refreshing &&  wasRefreshing.current;

    if (started) {
      sounds.refreshStart();
      AccessibilityInfo.announceForAccessibility(i18n.t('refresh.refreshing', { label }));
    }

    if (completed) {
      sounds.refreshComplete();
      AccessibilityInfo.announceForAccessibility(i18n.t('refresh.updated', { label }));
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      focusFirstItem();
    }

    wasRefreshing.current = refreshing;
  }, [refreshing, label]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    if (loading === undefined) return;
    const loadStarted   =  loading && !wasLoading.current;
    const loadCompleted = !loading && wasLoading.current;

    if (loadStarted) {
      sounds.loadingStart();
    }

    if (loadCompleted) {
      sounds.refreshComplete();
      AccessibilityInfo.announceForAccessibility(i18n.t('refresh.loaded', { label }));
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      focusFirstItem();
    }

    wasLoading.current = loading;
  }, [loading, label]); // eslint-disable-line react-hooks/exhaustive-deps
}
