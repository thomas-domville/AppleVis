import { useEffect } from 'react';
import { AppState } from 'react-native';
import { advertiseHandoff, resignHandoff } from '../native/nativeModules';
import type { HandoffActivity } from '../native/nativeModules';

/**
 * Advertises the current screen as a Handoff activity.
 * Pass null to disable Handoff for this screen.
 *
 * The activity is resigned automatically when:
 *   - The component unmounts (user leaves the screen)
 *   - The app moves to background
 *
 * It is re-advertised when the app returns to foreground.
 *
 * Usage:
 *   useHandoff({
 *     activityType: 'com.applevis.app.viewForums',
 *     title: 'AppleVis Forums',
 *     webpageURL: 'https://www.applevis.com/forum',
 *   });
 */
export function useHandoff(activity: HandoffActivity | null) {
  useEffect(() => {
    if (!activity) return;

    advertiseHandoff(activity);

    const subscription = AppState.addEventListener('change', (nextState) => {
      if (nextState === 'active') {
        advertiseHandoff(activity);
      } else if (nextState === 'background' || nextState === 'inactive') {
        resignHandoff();
      }
    });

    return () => {
      resignHandoff();
      subscription.remove();
    };
  // Only re-run when the activity type or URL changes, not on every re-render.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activity?.activityType, activity?.webpageURL]);
}
