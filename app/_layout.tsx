import '../src/i18n';
import { useCallback, useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator, Animated, I18nManager, Image, Platform, StyleSheet, View,
} from 'react-native';
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
import { setupNotifications, handleNotificationResponse, NOTIFICATION_SOUND_FILE } from '../src/services/notifications';
import { api } from '../src/services/api';
import { handleIncomingUrl } from '../src/services/universalLinks';
import { registerBackgroundFetch } from '../src/tasks/backgroundFetch';
import { registerBackgroundTasks } from '../src/services/backgroundFetch';
import { onboarding } from '../src/services/onboarding';
import { resetAppStateForDevelopment } from '../src/services/devReset';
import { useKeyboardShortcuts } from '../src/hooks/useKeyboardShortcuts';
import { ThemeProvider, useTheme } from '../src/contexts/ThemeContext';
import { PreferencesProvider, usePreferences } from '../src/contexts/PreferencesContext';
import { ToastProvider, useToast } from '../src/contexts/ToastContext';
import { AccessibleAlertProvider, useAlert } from '../src/contexts/AccessibleAlertContext';
import { ContextualTipProvider } from '../src/contexts/ContextualTipContext';
import { AuthProvider, useAuth } from '../src/contexts/AuthContext';
import { PlayerProvider, usePlayer } from '../src/contexts/PlayerContext';

// Prevent iOS from auto-hiding the launch screen — AppLoader calls hideAsync()
// as soon as the in-app overlay is ready to take over seamlessly.
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
  const { showAlert } = useAlert();
  useEffect(() => {
    authEvents.onSessionExpiry(() => {
      auth.signOut();
      showAlert({
        title: 'Session Expired',
        message:
          'Your sign-in session has ended. This happens automatically after a period ' +
          'of inactivity to keep your account secure — nothing is wrong.\n\n' +
          'Please sign in again to continue posting, following topics, and using ' +
          'other account features.',
        confirmLabel: 'OK',
        type: 'warning',
      });
    });
  }, [auth, showAlert]);
  return null;
}

function AppServices() {
  useKeyboardShortcuts();
  const { notificationPrefs, notificationSound } = usePreferences();
  const { user } = useAuth();

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

  // Sync the user's chosen notification sound to the server whenever they
  // sign in or change the sound picker. Drupal reads field_push_sound to
  // include the right sound file name in push notification payloads.
  useEffect(() => {
    if (!user) return;
    const soundFile = NOTIFICATION_SOUND_FILE[notificationSound] ?? 'default';
    api.account.updatePushSound(soundFile, user.csrfToken).catch(() => {});
  }, [user, notificationSound]);

  useEffect(() => {
    setupNotifications().catch(() => {});
    if (Platform.OS === 'ios' || Platform.OS === 'android') {
      registerBackgroundFetch().catch(() => {});
      registerBackgroundTasks().catch(() => {});
    }

    const notifSub = Notifications.addNotificationResponseReceivedListener(handleNotificationResponse);

    Linking.getInitialURL().then((url) => { if (url) handleIncomingUrl(url); });
    const linkSub = Linking.addEventListener('url', ({ url }) => handleIncomingUrl(url));

    return () => { notifSub.remove(); linkSub.remove(); };
  }, []);

  return null;
}

const FORCE_NEW  = process.env.EXPO_PUBLIC_RESET_ONBOARDING === 'true';
const SPLASH_BG  = '#0A84FF';
const LOGO       = require('../assets/images/applevis-logo-2026-black.png');

function DevelopmentResetGate({ children }: { children: React.ReactNode }) {
  const [ready, setReady] = useState(process.env.EXPO_PUBLIC_RESET_APP_STATE !== 'true');

  useEffect(() => {
    if (process.env.EXPO_PUBLIC_RESET_APP_STATE !== 'true') return;
    resetAppStateForDevelopment()
      .finally(() => setReady(true));
  }, []);

  return ready ? <>{children}</> : null;
}

// Replaces OnboardingGate. Keeps the in-app branded overlay visible for at
// least 1.4 s while the onboarding check runs, then fades out. VoiceOver
// users hear the app announce itself as ready when the fade completes.
function AppLoader({ children }: { children: React.ReactNode }) {
  const [overlayVisible, setOverlayVisible] = useState(true);
  const fadeAnim       = useRef(new Animated.Value(1)).current;
  const readyDestRef   = useRef<string | null | undefined>(undefined); // undefined = still pending
  const minTimeDoneRef = useRef(false);
  const completingRef  = useRef(false);

  // Using a ref for complete() avoids stale-closure issues in the useEffect below.
  const completeRef = useRef<() => void>(() => {});
  completeRef.current = () => {
    if (completingRef.current) return;
    if (readyDestRef.current === undefined) return; // onboarding check not done yet
    if (!minTimeDoneRef.current) return;            // min display time not elapsed yet
    completingRef.current = true;

    const dest = readyDestRef.current;

    if (!dest) {
      // Returning user arriving at home — play welcome tone and announce readiness.
      sounds.welcome().catch(() => {});
    }

    Animated.timing(fadeAnim, { toValue: 0, duration: 350, useNativeDriver: true })
      .start(() => {
        setOverlayVisible(false);
        if (dest) router.replace(dest as any);
      });
  };

  useEffect(() => {
    // Hide iOS launch screen immediately — the in-app overlay takes over visually.
    SplashScreen.hideAsync().catch(() => {});

    // Minimum display time so the splash feels intentional, not a flash.
    const minTimer = setTimeout(() => {
      minTimeDoneRef.current = true;
      completeRef.current();
    }, 1400);

    // Onboarding state check.
    const check = FORCE_NEW
      ? onboarding.reset().then(() => onboarding.isComplete())
      : onboarding.isComplete();

    check
      .then((done) => { readyDestRef.current = done ? null : '/onboarding'; })
      .catch(()    => { readyDestRef.current = null; })
      .finally(()  => { completeRef.current(); });

    // Hard failsafe — never hang forever.
    const failsafe = setTimeout(() => {
      if (!completingRef.current) {
        readyDestRef.current   = readyDestRef.current ?? null;
        minTimeDoneRef.current = true;
        completeRef.current();
      }
    }, 5000);

    return () => { clearTimeout(minTimer); clearTimeout(failsafe); };
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <>
      {children}
      {overlayVisible && (
        <Animated.View
          style={[styles.overlay, { opacity: fadeAnim }]}
          accessible
          accessibilityLabel="AppleVis, loading"
          importantForAccessibility="yes"
        >
          <Image
            source={LOGO}
            style={styles.splashLogo}
            resizeMode="contain"
            // tintColor inverts the black logo pixels to white on the blue background.
            tintColor="#FFFFFF"
            accessibilityElementsHidden
          />
          <ActivityIndicator
            color="rgba(255,255,255,0.75)"
            size="small"
            style={{ marginTop: 36 }}
            accessibilityElementsHidden
          />
        </Animated.View>
      )}
    </>
  );
}

const styles = StyleSheet.create({
  overlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: SPLASH_BG,
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 9999,
  },
  // Logo is 2167×620 — render at 280 wide, height scales proportionally (~80 px).
  splashLogo: {
    width: 280,
    height: 80,
  },
});

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
  }, []);

  return (
    <DevelopmentResetGate>
      <PreferencesProvider>
        <ThemeProvider>
          <ToastProvider>
            <AccessibleAlertProvider>
              <ContextualTipProvider>
                <AuthProvider>
                  <PlayerProvider>
                    <AuthExpiryHandler />
                    <AppServices />
                    <ThemedStatusBar />
                    <MagicTapWrapper>
                      <AppLoader>
                        <Stack screenOptions={{ headerShown: false }}>
                          <Stack.Screen name="player" options={{ presentation: 'modal' }} />
                        </Stack>
                      </AppLoader>
                    </MagicTapWrapper>
                  </PlayerProvider>
                </AuthProvider>
              </ContextualTipProvider>
            </AccessibleAlertProvider>
          </ToastProvider>
        </ThemeProvider>
      </PreferencesProvider>
    </DevelopmentResetGate>
  );
}
