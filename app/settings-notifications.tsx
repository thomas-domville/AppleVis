import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { AccessibilityInfo, findNodeHandle, Linking, Pressable, ScrollView, Switch, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as Notifications from 'expo-notifications';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { usePreferences } from '../src/contexts/PreferencesContext';
import { useToast } from '../src/contexts/ToastContext';
import { useAuth } from '../src/contexts/AuthContext';
import { requestNotificationPermissions } from '../src/services/notifications';
import { sounds } from '../src/services/sounds';
import type { NotificationPrefs, NotificationSound } from '../src/contexts/PreferencesContext';

type CategoryDef = {
  key: keyof NotificationPrefs;
  label: string;
  description: string;
  icon: string;
  requiresAuth?: boolean;
};

const CATEGORIES: CategoryDef[] = [
  { key: 'forumReplies',   label: 'Forum Replies',             description: 'When someone replies to one of your posts.', icon: 'chatbubbles-outline', requiresAuth: true },
  { key: 'mentions',       label: 'Mentions',                  description: 'When someone @-mentions you in a post.', icon: 'at-outline', requiresAuth: true },
  { key: 'newTopics',      label: 'New Topics',                description: 'When new forum discussions are started.', icon: 'reader-outline' },
  { key: 'followedTopics', label: 'Followed Topic Activity',   description: 'New replies in topics you are following.', icon: 'heart-outline', requiresAuth: true },
  { key: 'newEpisodes',    label: 'New Podcast Episodes',      description: 'When a new AppleVis podcast episode is published.', icon: 'mic-outline' },
  { key: 'appUpdates',     label: 'New App Directory Entries', description: 'When new app directory entries are published or existing ones are updated.', icon: 'apps-outline' },
  { key: 'newResources',   label: 'New Guides & Blog Posts',   description: 'When new guides or blog posts are published.', icon: 'library-outline' },
  { key: 'announcements',  label: 'AppleVis Announcements',    description: 'Important news from the AppleVis team.', icon: 'megaphone-outline' },
];

const SOUNDS: { id: NotificationSound; label: string; description: string; icon: string }[] = [
  { id: 'mouseSqueak',         label: 'Mouse Squeak',          description: 'The AppleVis signature sound, soft and distinctive.', icon: 'musical-note-outline' },
  { id: 'appleCrunch',         label: 'Apple Crunch',          description: 'A crisp apple crunch.', icon: 'nutrition-outline' },
  { id: 'goldenRetrieverBark', label: 'Golden Retriever Bark', description: 'A friendly golden retriever bark, warm and cheerful.', icon: 'happy-outline' },
  { id: 'none',                label: 'System Default',        description: "Your iPhone's standard notification tone.", icon: 'phone-portrait-outline' },
];

const EMPTY_PREFS: NotificationPrefs = {
  forumReplies: false,
  mentions: false,
  newTopics: false,
  followedTopics: false,
  newEpisodes: false,
  appUpdates: false,
  newResources: false,
  announcements: false,
};

function SectionHeader({ label, colors }: {
  label: string;
  colors: ReturnType<typeof useTheme>['colors'];
}) {
  return (
    <Text
      style={{
        fontSize: 13,
        fontWeight: '700',
        color: colors.textSecondary,
        textTransform: 'uppercase',
        letterSpacing: 0.8,
        marginTop: 18,
        marginBottom: 8,
      }}
      accessibilityRole="header"
    >
      {label}
    </Text>
  );
}

function permissionLabel(status: Notifications.PermissionStatus | 'unknown') {
  if (status === 'granted') return 'Allowed';
  if (status === 'denied') return 'Blocked';
  if (status === 'undetermined') return 'Not Asked';
  return 'Unknown';
}

export default function NotificationSettings() {
  const { colors, styles } = useTheme();
  const { showToast } = useToast();
  const router = useRouter();
  const { isSignedIn } = useAuth();
  const {
    notificationPrefs,
    setNotificationPrefs,
    notificationSound,
    setNotificationSound,
  } = usePreferences();
  const [permissionStatus, setPermissionStatus] = useState<Notifications.PermissionStatus | 'unknown'>('unknown');
  const [canAskAgain, setCanAskAgain] = useState(true);
  const firstHeadingRef = useRef<Text | null>(null);
  const didFocusFirstHeadingRef = useRef(false);

  const enabledCount = useMemo(
    () => CATEGORIES.filter(({ key }) => notificationPrefs[key]).length,
    [notificationPrefs],
  );
  const lockedCount = CATEGORIES.filter((category) => category.requiresAuth && !isSignedIn).length;
  const anyEnabled = enabledCount > 0;
  const selectedSound = SOUNDS.find((sound) => sound.id === notificationSound) ?? SOUNDS[0];
  const summary = `${enabledCount} of ${CATEGORIES.length} notification types enabled. Notification permission is ${permissionLabel(permissionStatus)}. Alert sound is ${selectedSound.label}. ${lockedCount > 0 ? `${lockedCount} account notifications require sign in.` : 'All notification types are available.'}`;

  const refreshPermissionStatus = useCallback(() => {
    Notifications.getPermissionsAsync()
      .then((permission) => {
        setPermissionStatus(permission.status);
        setCanAskAgain(permission.canAskAgain);
      })
      .catch(() => setPermissionStatus('unknown'));
  }, []);

  useEffect(() => {
    refreshPermissionStatus();
  }, [refreshPermissionStatus]);

  useEffect(() => {
    const timers = [350, 700, 1100].map((delay) =>
      setTimeout(() => {
        if (didFocusFirstHeadingRef.current) return;
        const handle = findNodeHandle(firstHeadingRef.current);
        if (handle) {
          didFocusFirstHeadingRef.current = true;
          AccessibilityInfo.setAccessibilityFocus(handle);
        }
      }, delay),
    );
    return () => timers.forEach(clearTimeout);
  }, []);

  function toggleCategory(key: keyof NotificationPrefs, label: string) {
    const next = !notificationPrefs[key];
    setNotificationPrefs({ ...notificationPrefs, [key]: next });
    AccessibilityInfo.announceForAccessibility(`${label}, ${next ? 'on' : 'off'}.`);
  }

  async function previewSound(id: NotificationSound) {
    if (id === 'mouseSqueak') await sounds.mouseSqueak().catch(() => {});
    else if (id === 'appleCrunch') await sounds.appleCrunch().catch(() => {});
    else if (id === 'goldenRetrieverBark') await sounds.goldenRetrieverBark().catch(() => {});
  }

  async function handleRequestPermissions() {
    const granted = await requestNotificationPermissions();
    refreshPermissionStatus();
    showToast(
      granted
        ? 'Notifications enabled.'
        : 'Notifications blocked. Enable them in iOS Settings, AppleVis, Notifications.',
      granted ? 'success' : 'warning',
    );
  }

  function handleDisableAll() {
    setNotificationPrefs(EMPTY_PREFS);
    AccessibilityInfo.announceForAccessibility('All notification types disabled.');
  }

  return (
    <Screen title="Notifications" showSettings={false}>
      <ScrollView showsVerticalScrollIndicator={false}>
        <View
          style={[styles.card, {
            borderLeftWidth: 4,
            borderLeftColor: colors.accent,
            marginBottom: 14,
          }]}
        >
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
            <View
              style={{
                width: 48,
                height: 48,
                borderRadius: 13,
                backgroundColor: colors.pill,
                alignItems: 'center',
                justifyContent: 'center',
              }}
              accessibilityElementsHidden
            >
              <Ionicons name="notifications-outline" size={25} color={colors.accent} />
            </View>
            <View style={{ flex: 1 }}>
              <Text
                ref={firstHeadingRef}
                style={styles.cardTitle}
                accessibilityRole="header"
                accessibilityActions={[{ name: 'readNotificationSummary', label: 'Read Notification Summary' }]}
                onAccessibilityAction={(event) => {
                  if (event.nativeEvent.actionName === 'readNotificationSummary') {
                    AccessibilityInfo.announceForAccessibility(`Notification settings. ${summary}`);
                  }
                }}
              >
                Notification Settings
              </Text>
              <Text style={styles.cardMeta}>
                {enabledCount} of {CATEGORIES.length} types enabled. Permission: {permissionLabel(permissionStatus)}.
              </Text>
              <Text style={[styles.cardMeta, { marginTop: 4 }]}>
                Choose what AppleVis alerts you about and which sound it uses.
              </Text>
            </View>
          </View>
        </View>

        {!isSignedIn && (
          <Pressable
            onPress={() => router.push('/profile' as any)}
            accessible
            accessibilityRole="button"
            accessibilityLabel="Sign in to unlock account notifications"
            accessibilityHint="Opens Profile so you can sign in. Forum Replies, Mentions, and Followed Topic Activity require an AppleVis account."
            style={({ pressed }) => [styles.cardSmall, {
              flexDirection: 'row',
              gap: 12,
              alignItems: 'center',
              borderLeftWidth: 4,
              borderLeftColor: '#D97706',
              backgroundColor: colors.card,
            }, pressed && { opacity: 0.85 }]}
          >
            <View
              style={{
                width: 38,
                height: 38,
                borderRadius: 10,
                backgroundColor: '#FEF3C7',
                alignItems: 'center',
                justifyContent: 'center',
              }}
              accessibilityElementsHidden
            >
              <Ionicons name="person-outline" size={20} color="#D97706" />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text, marginBottom: 2 }}>
                Sign in to unlock account notifications
              </Text>
              <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>
                Forum Replies, Mentions, and Followed Topic Activity require an AppleVis account.
              </Text>
            </View>
            <Ionicons name="chevron-forward" size={16} color={colors.textSecondary} accessibilityElementsHidden />
          </Pressable>
        )}

        <SectionHeader label="iOS Permission" colors={colors} />
        <Pressable
          onPress={permissionStatus === 'denied' || !canAskAgain ? () => Linking.openSettings().catch(() => {}) : handleRequestPermissions}
          accessible
          accessibilityRole="button"
          accessibilityLabel={`Notification permission: ${permissionLabel(permissionStatus)}`}
          accessibilityHint={permissionStatus === 'denied' || !canAskAgain
            ? 'Opens iOS Settings so you can allow notifications for AppleVis.'
            : 'Opens the iOS permission prompt for AppleVis notifications.'}
          style={({ pressed }) => [styles.cardSmall, {
            flexDirection: 'row',
            alignItems: 'center',
            gap: 12,
            borderLeftWidth: 4,
            borderLeftColor: permissionStatus === 'granted' ? colors.accent : colors.border,
          }, pressed && { opacity: 0.85 }]}
        >
          <View
            style={{
              width: 38,
              height: 38,
              borderRadius: 10,
              backgroundColor: colors.pill,
              alignItems: 'center',
              justifyContent: 'center',
            }}
            accessibilityElementsHidden
          >
            <Ionicons name={permissionStatus === 'granted' ? 'checkmark-circle-outline' : 'alert-circle-outline'} size={20} color={colors.accent} />
          </View>
          <View style={{ flex: 1 }}>
            <View style={{ flexDirection: 'row', gap: 8, alignItems: 'center', flexWrap: 'wrap', marginBottom: 2 }}>
              <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text }}>iOS Notification Permission</Text>
              <View style={{ backgroundColor: permissionStatus === 'granted' ? colors.accent : colors.pill, borderRadius: 6, paddingHorizontal: 7, paddingVertical: 2 }}>
                <Text style={{ color: permissionStatus === 'granted' ? colors.accentText : colors.pillText, fontSize: 11, fontWeight: '800' }}>
                  {permissionLabel(permissionStatus)}
                </Text>
              </View>
            </View>
            <Text style={styles.cardMeta}>
              {permissionStatus === 'granted'
                ? 'AppleVis can show notifications on this device.'
                : 'AppleVis needs iOS permission before background notifications can appear.'}
            </Text>
          </View>
          <Ionicons name={permissionStatus === 'denied' || !canAskAgain ? 'open-outline' : 'chevron-forward'} size={16} color={colors.textSecondary} accessibilityElementsHidden />
        </Pressable>

        <SectionHeader label="Notification Types" colors={colors} />
        {CATEGORIES.map(({ key, label, description, requiresAuth, icon }) => {
          const locked = !!requiresAuth && !isSignedIn;
          const enabled = notificationPrefs[key];
          return (
            <Pressable
              key={key}
              onPress={locked ? undefined : () => toggleCategory(key, label)}
              disabled={locked}
              style={({ pressed }) => [styles.cardSmall, {
                flexDirection: 'row',
                alignItems: 'center',
                gap: 12,
                opacity: locked ? 0.72 : 1,
                borderLeftWidth: 4,
                borderLeftColor: enabled && !locked ? colors.accent : colors.border,
              }, pressed && !locked && { opacity: 0.85 }]}
              accessible
              accessibilityRole={locked ? 'button' : 'switch'}
              accessibilityLabel={locked
                ? `${label}. Sign in required. ${description}`
                : `${label}. ${description}`}
              accessibilityState={locked ? { disabled: true } : { checked: enabled }}
            >
              <View
                style={{
                  width: 38,
                  height: 38,
                  borderRadius: 10,
                  backgroundColor: colors.pill,
                  alignItems: 'center',
                  justifyContent: 'center',
                  flexShrink: 0,
                }}
                accessibilityElementsHidden
              >
                <Ionicons name={locked ? 'lock-closed-outline' : icon as any} size={20} color={locked ? colors.textSecondary : colors.accent} />
              </View>
              <View style={{ flex: 1 }}>
                <View style={{ flexDirection: 'row', gap: 8, alignItems: 'center', flexWrap: 'wrap', marginBottom: 2 }}>
                  <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text }}>{label}</Text>
                  <View style={{ backgroundColor: enabled && !locked ? colors.accent : colors.pill, borderRadius: 6, paddingHorizontal: 7, paddingVertical: 2 }}>
                    <Text style={{ color: enabled && !locked ? colors.accentText : colors.pillText, fontSize: 11, fontWeight: '800' }}>
                      {locked ? 'Sign In Required' : enabled ? 'On' : 'Off'}
                    </Text>
                  </View>
                </View>
                <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>
                  {description}
                </Text>
              </View>
              {locked ? (
                <Ionicons name="lock-closed-outline" size={20} color={colors.textSecondary} accessibilityElementsHidden />
              ) : (
                <Switch
                  value={enabled}
                  onValueChange={() => toggleCategory(key, label)}
                  trackColor={{ false: colors.border, true: colors.accent }}
                  thumbColor="#FFFFFF"
                  accessibilityElementsHidden
                  importantForAccessibility="no-hide-descendants"
                />
              )}
            </Pressable>
          );
        })}

        {anyEnabled ? (
          <>
            <Pressable
              onPress={handleDisableAll}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Disable all notification types"
              accessibilityHint="Turns off every AppleVis notification type on this screen."
              style={({ pressed }) => [styles.cardSmall, {
                alignItems: 'center',
                borderWidth: 1,
                borderColor: colors.border,
                backgroundColor: colors.background,
              }, pressed && { opacity: 0.85 }]}
            >
              <Text style={{ color: colors.accent, fontWeight: '800', fontSize: 15 }}>
                Disable All Notification Types
              </Text>
            </Pressable>

            <SectionHeader label="Alert Sound" colors={colors} />
            {SOUNDS.map(({ id, label, description, icon }) => {
              const isSelected = notificationSound === id;
              return (
                <Pressable
                  key={id}
                  onPress={() => {
                    setNotificationSound(id);
                    previewSound(id);
                    AccessibilityInfo.announceForAccessibility(`${label} selected${id !== 'none' ? ' and previewing' : ''}.`);
                  }}
                  accessible
                  accessibilityRole="button"
                  accessibilityState={{ selected: isSelected }}
                  accessibilityLabel={`${label}${isSelected ? ', selected' : ''}. ${description}`}
                  accessibilityHint={id !== 'none' ? 'Double tap to select and preview this sound.' : 'Double tap to use your iPhone system default notification sound.'}
                  style={({ pressed }) => [styles.cardSmall, {
                    flexDirection: 'row',
                    alignItems: 'center',
                    gap: 12,
                    borderWidth: isSelected ? 2 : 1,
                    borderColor: isSelected ? colors.accent : colors.border,
                    borderLeftWidth: isSelected ? 5 : 3,
                    borderLeftColor: isSelected ? colors.accent : colors.border,
                    backgroundColor: isSelected ? colors.pill : colors.card,
                  }, pressed && { opacity: 0.85 }]}
                >
                  <View
                    style={{
                      width: 38,
                      height: 38,
                      borderRadius: 10,
                      backgroundColor: isSelected ? colors.accent : colors.pill,
                      alignItems: 'center',
                      justifyContent: 'center',
                      flexShrink: 0,
                    }}
                    accessibilityElementsHidden
                  >
                    <Ionicons name={icon as any} size={20} color={isSelected ? colors.accentText : colors.accent} />
                  </View>
                  <View style={{ flex: 1 }}>
                    <View style={{ flexDirection: 'row', gap: 8, alignItems: 'center', flexWrap: 'wrap', marginBottom: 2 }}>
                      <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text }}>{label}</Text>
                      {isSelected && (
                        <View style={{ backgroundColor: colors.accent, borderRadius: 6, paddingHorizontal: 7, paddingVertical: 2 }}>
                          <Text style={{ color: colors.accentText, fontSize: 11, fontWeight: '800' }}>
                            Selected
                          </Text>
                        </View>
                      )}
                    </View>
                    <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>
                      {description}
                    </Text>
                  </View>
                  {isSelected && <Ionicons name="checkmark-circle" size={20} color={colors.accent} accessibilityElementsHidden />}
                </Pressable>
              );
            })}
          </>
        ) : (
          <View
            accessible
            accessibilityLabel="No notification types are enabled. Enable one or more notification types above before choosing an alert sound."
            style={[styles.cardSmall, {
              flexDirection: 'row',
              gap: 10,
              alignItems: 'flex-start',
              backgroundColor: colors.pill,
              borderWidth: 1,
              borderColor: colors.border,
              marginTop: 8,
            }]}
          >
            <Ionicons name="information-circle-outline" size={18} color={colors.pillText} style={{ marginTop: 1 }} accessibilityElementsHidden />
            <Text style={{ fontSize: 14, color: colors.pillText, flex: 1, lineHeight: 20, fontWeight: '700' }}>
              Enable one or more notification types above before choosing an alert sound.
            </Text>
          </View>
        )}

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
