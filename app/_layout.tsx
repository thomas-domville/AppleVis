import '../src/i18n';
import { useCallback, useEffect, useState } from 'react';
import { I18nManager, Platform, View } from 'react-native';
import { Stack, router } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { StatusBar } from 'expo-status-bar';
import * as Linking from 'expo-linking';
import * as Notifications from 'expo-notifications';
import { isRTL } from '../src/i18n';
import { apiHealth } from '../src/services/apiHealth';
import { cachedApi } from '../src/services/cachedApi';
import { sounds } from '../src/services/sounds';
import { authEvents } from '../src/services/authEvents';
import { setupNotifications, handleNotificationResponse } from '../src/services/notifications';
import { handleIncomingUrl } from '../src/services/universalLinks';
import { registerBackgroundFetch } from '../src/tasks/backgroundFetch';
import { onboarding } from '../src/services/onboarding';
import { useKeyboardShortcuts } from '../src/hooks/useKeyboardShortcuts';
import { ThemeProvider, useTheme } from '../src/contexts/ThemeContext';
import { PreferencesProvider, usePreferences } from '../src/contexts/PreferencesContext';
import { ToastProvider, useToast } from '../src/contexts/ToastContext';
import { AuthProvider, useAuth } from '../src/contexts/AuthContext';
import { PlayerProvider, usePlayer } from '../src/contexts/PlayerContext';

// Keep splash visible until onboarding check + initial data load finishes.
SplashScreen.preventAutoHideAsync().catch(() => {});

const CATEGORY_PREF_MAP: Record<string, keyof import('../src/contexts/PreferencesContext').NotificationPrefs> = {
  forumReply:    'forumReplies',
  mention:       'mentions',
  newTopic:      'newTopics',
  followedTopic: 'followedTopics',
  newEpisode:    'newEpisodes',
  appUpdate:     'appUpdates',
  newResource:   'newResources',
  announcement:  'announcements',
};

function AuthExpiryHandler() {
  const auth = useAuth();
  const { showToast } = useToast();
  useEffect(() => {
    authEvents.onSessionExpiry(() => {
      auth.signOut();
      showToast('Your session expired. Please sign in again.', 'warning');
    });
  }, [auth, showToast]);
  return null;
}

function AppServices() {
  useKeyboardShortcuts();
  const { notificationPrefs, notificationSound } = usePreferences();

  // Reactive foreground notification handler — re-registers when prefs change.
  useEffect(() => {
    Notifications.setNotificationHandler({
      handleNotification: async (notification) => {
        const category = notification.request.content.categoryIdentifier ?? '';
        const prefKey  = CATEGORY_PREF_MAP[category];
        const enabled  = prefKey ? notificationPrefs[prefKey] : true;
        return {
          shouldShowBanner: enabled,
          shouldShowList:   enabled,
          shouldPlaySound:  enabled && notificationSound !== 'none',
          shouldSetBadge:   enabled,
          priority:         Notifications.AndroidNotificationPriority.HIGH,
        };
      },
    });
  }, [notificationPrefs, notificationSound]);

  useEffect(() => {
    setupNotifications().catch(() => {});
    if (Platform.OS === 'ios' || Platform.OS === 'android') {
      registerBackgroundFetch().catch(() => {});
    }

    const notifSub = Notifications.addNotificationResponseReceivedListener(handleNotificationResponse);

    Linking.getInitialURL().then((url) => { if (url) handleIncomingUrl(url); });
    const linkSub = Linking.addEventListener('url', ({ url }) => handleIncomingUrl(url));

    return () => { notifSub.remove(); linkSub.remove(); };
  }, []);

  return null;
}

const FORCE_NEW = process.env.EXPO_PUBLIC_RESET_ONBOARDING === 'true';

function OnboardingGate({ children }: { children: React.ReactNode }) {
  const [redirectTo, setRedirectTo] = useState<string | null>(null);

  useEffect(() => {
    const check = FORCE_NEW
      ? onboarding.reset().then(() => onboarding.isComplete())
      : onboarding.isComplete();

    check
      .then((done) => { if (!done) setRedirectTo('/onboarding'); })
      .catch(() => {})
      .finally(() => { SplashScreen.hideAsync().catch(() => {}); });
  }, []);

  useEffect(() => {
    if (redirectTo) router.replace(redirectTo as any);
  }, [redirectTo]);

  return <>{children}</>;
}

function ThemedStatusBar() {
  const { isDark } = useTheme();
  return <StatusBar style={isDark ? 'light' : 'dark'} />;
}

// Catches VoiceOver two-finger double-tap (magic tap) from any screen.
// Only acts when an episode is loaded; otherwise lets iOS handle it.
function MagicTapWrapper({ children }: { children: React.ReactNode }) {
  const player = usePlayer();
  const onMagicTap = useCallback(() => {
    if (!player.episode) return;
    if (player.isPlaying) player.pause();
    else player.play();
  }, [player]);
  return <View style={{ flex: 1 }} onMagicTap={onMagicTap}>{children}</View>;
}

export default function RootLayout() {
  useEffect(() => {
    if (Platform.OS === 'ios' || Platform.OS === 'android') {
      I18nManager.allowRTL(true);
      if (isRTL !== I18nManager.isRTL) I18nManager.forceRTL(isRTL);
    }
    apiHealth.probe();
    cachedApi.prefetchAll();
    sounds.preload();
    const t = setTimeout(() => SplashScreen.hideAsync().catch(() => {}), 3000);
    return () => clearTimeout(t);
  }, []);

  return (
    <PreferencesProvider>
      <ThemeProvider>
        <ToastProvider>
          <AuthProvider>
            <PlayerProvider>
              <AuthExpiryHandler />
              <AppServices />
              <ThemedStatusBar />
              <MagicTapWrapper>
                <OnboardingGate>
                  <Stack screenOptions={{ headerShown: false }} />
                </OnboardingGate>
              </MagicTapWrapper>
            </PlayerProvider>
          </AuthProvider>
        </ToastProvider>
      </ThemeProvider>
    </PreferencesProvider>
  );
}
