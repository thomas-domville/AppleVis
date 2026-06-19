import { Pressable, ScrollView, Switch, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { usePreferences } from '../src/contexts/PreferencesContext';
import { useToast } from '../src/contexts/ToastContext';
import { useAuth } from '../src/contexts/AuthContext';
import { requestNotificationPermissions } from '../src/services/notifications';
import { sounds } from '../src/services/sounds';
import type { NotificationPrefs, NotificationSound } from '../src/contexts/PreferencesContext';

type CategoryDef = { key: keyof NotificationPrefs; label: string; description: string; requiresAuth?: boolean };

const CATEGORIES: CategoryDef[] = [
  { key: 'forumReplies',   label: 'Forum Replies',            description: 'When someone replies to one of your posts.',        requiresAuth: true },
  { key: 'mentions',       label: 'Mentions',                 description: 'When someone @-mentions you in a post.',            requiresAuth: true },
  { key: 'newTopics',      label: 'New Topics',               description: 'When new forum discussions are started.' },
  { key: 'followedTopics', label: 'Followed Topic Activity',  description: 'New replies in topics you are following.',          requiresAuth: true },
  { key: 'newEpisodes',    label: 'New Podcast Episodes',     description: 'When a new AppleVis podcast episode is published.' },
  { key: 'appUpdates',     label: 'New App Directory Entries', description: 'When new app directory entries are published or existing ones are updated.' },
  { key: 'newResources',   label: 'New Guides & Blog Posts',  description: 'When new guides or blog posts are published.' },
  { key: 'announcements',  label: 'AppleVis Announcements',   description: 'Important news from the AppleVis team.' },
];

const SOUNDS: { id: NotificationSound; label: string; description: string }[] = [
  { id: 'mouseSqueak',         label: 'Mouse Squeak',          description: 'The AppleVis signature sound -- soft and distinctive.' },
  { id: 'appleCrunch',         label: 'Apple Crunch',          description: 'A crisp apple crunch.' },
  { id: 'goldenRetrieverBark', label: 'Golden Retriever Bark', description: 'A friendly golden retriever bark -- warm and cheerful.' },
  { id: 'none',                label: 'System Default',         description: 'Your iPhone\'s standard notification tone.' },
];

export default function NotificationSettings() {
  const { colors, styles } = useTheme();
  const { showToast }      = useToast();
  const router             = useRouter();
  const { isSignedIn }     = useAuth();
  const { notificationPrefs, setNotificationPrefs,
          notificationSound, setNotificationSound } = usePreferences();
  const anyEnabled = Object.values(notificationPrefs).some(Boolean);

  function toggleCategory(key: keyof NotificationPrefs) {
    setNotificationPrefs({ ...notificationPrefs, [key]: !notificationPrefs[key] });
  }

  async function previewSound(id: NotificationSound) {
    if (id === 'mouseSqueak') await sounds.mouseSqueak().catch(() => {});
    else if (id === 'appleCrunch') await sounds.appleCrunch().catch(() => {});
    else if (id === 'goldenRetrieverBark') await sounds.goldenRetrieverBark().catch(() => {});
  }

  async function handleRequestPermissions() {
    const granted = await requestNotificationPermissions();
    showToast(
      granted
        ? 'Notifications enabled.'
        : 'Notifications blocked. Enable them in iOS Settings -> AppleVis -> Notifications.',
      granted ? 'success' : 'warning',
    );
  }

  return (
    <Screen title="Notifications" showSettings={false}>
      <ScrollView showsVerticalScrollIndicator={false}>
        <Text style={styles.lede}>
          Choose which notifications AppleVis can show you. These toggles control
          what appears while the app is open. For background notifications, adjust
          them in iOS Settings → Notifications → AppleVis.
        </Text>

        {/* Sign-in banner — only shown when signed out */}
        {!isSignedIn && (
          <Pressable
            onPress={() => router.push('/settings-account' as any)}
            accessible
            accessibilityRole="button"
            accessibilityLabel="Sign in to unlock 3 notifications: Forum Replies, Mentions, and Followed Topic Activity. Double tap to go to sign in."
            style={[styles.card, {
              flexDirection: 'row', gap: 12, alignItems: 'center',
              borderLeftWidth: 4, borderLeftColor: '#D97706', marginBottom: 16,
            }]}
          >
            <Ionicons name="person-outline" size={22} color="#D97706" accessibilityElementsHidden />
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: 14, fontWeight: '700', color: colors.text, marginBottom: 2 }}>
                Sign in to unlock 3 notifications
              </Text>
              <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 18 }}>
                Forum Replies, Mentions, and Followed Topic Activity require an AppleVis account.
              </Text>
            </View>
            <Ionicons name="chevron-forward" size={16} color={colors.textSecondary} accessibilityElementsHidden />
          </Pressable>
        )}

        {/* Request permissions button */}
        <Pressable
          onPress={handleRequestPermissions}
          accessible accessibilityRole="button"
          accessibilityLabel="Allow notifications -- opens iOS permission dialog"
          style={{ backgroundColor: colors.accent, borderRadius: 12,
            paddingVertical: 14, alignItems: 'center', marginBottom: 20 }}
        >
          <Text style={{ color: colors.accentText, fontWeight: '700', fontSize: 15 }}>
            Allow Notifications
          </Text>
        </Pressable>

        {/* Category toggles */}
        <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
          textTransform: 'uppercase', letterSpacing: 0, marginBottom: 8 }}
          accessibilityRole="header">Notification Types</Text>

        {CATEGORIES.map(({ key, label, description, requiresAuth }) => {
          const locked  = !!requiresAuth && !isSignedIn;
          const enabled = notificationPrefs[key];
          return (
            <Pressable
              key={key}
              onPress={locked ? undefined : () => toggleCategory(key)}
              style={[styles.cardSmall, {
                flexDirection: 'row', alignItems: 'center', gap: 12,
                opacity: locked ? 0.5 : 1,
              }]}
              accessible
              accessibilityRole={locked ? 'none' : 'switch'}
              accessibilityLabel={locked
                ? `${label}. Sign in required to enable this notification.`
                : `${label}. ${description}`}
              accessibilityState={locked ? undefined : { checked: enabled }}
            >
              <View style={{ flex: 1 }}>
                <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>{label}</Text>
                <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 18, marginTop: 2 }}>
                  {description}
                </Text>
                {locked && (
                  <Text style={{ fontSize: 12, fontWeight: '700', color: '#92400E', marginTop: 3 }}>
                    Sign in required
                  </Text>
                )}
              </View>
              {locked ? (
                <Ionicons name="lock-closed-outline" size={20} color={colors.textSecondary} accessibilityElementsHidden />
              ) : (
                <Switch
                  value={enabled}
                  onValueChange={() => toggleCategory(key)}
                  trackColor={{ false: colors.border, true: colors.accent }}
                  thumbColor="#FFFFFF"
                  accessibilityElementsHidden
                />
              )}
            </Pressable>
          );
        })}

        {/* Sound picker */}
        <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
          textTransform: 'uppercase', letterSpacing: 0, marginTop: 20, marginBottom: 8 }}
          accessibilityRole="header">Alert Sound</Text>

        {SOUNDS.map(({ id, label, description }) => {
          const isSelected = notificationSound === id;
          return (
            <Pressable
              key={id}
              onPress={() => { setNotificationSound(id); previewSound(id); }}
              accessible accessibilityRole="button"
              accessibilityState={{ selected: isSelected }}
              accessibilityLabel={label}
              accessibilityHint={`${description}${id !== 'none' ? ' Double tap to preview.' : ''}`}
              style={[styles.cardSmall, {
                flexDirection: 'row', alignItems: 'center', gap: 12,
                borderWidth: isSelected ? 2 : 1,
                borderColor: isSelected ? colors.accent : colors.border,
                backgroundColor: isSelected ? colors.pill : colors.card,
              }]}
            >
              <View style={{
                width: 20, height: 20, borderRadius: 10,
                borderWidth: 2, borderColor: isSelected ? colors.accent : colors.border,
                backgroundColor: isSelected ? colors.accent : 'transparent',
                alignItems: 'center', justifyContent: 'center',
              }}>
                {isSelected && <View style={{ width: 8, height: 8, borderRadius: 4, backgroundColor: colors.accentText }} />}
              </View>
              <View style={{ flex: 1 }}>
                <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>{label}</Text>
                <Text style={{ fontSize: 13, color: colors.textSecondary }}>{description}</Text>
              </View>
              {id !== 'none' && (
                <Text style={{ fontSize: 13, color: colors.accent, fontWeight: '600' }}>Preview</Text>
              )}
            </Pressable>
          );
        })}

        {!anyEnabled && (
          <View
            accessible
            accessibilityLabel="No notification types are enabled. Enable one or more types above to receive notifications with your chosen sound."
            style={{
              flexDirection: 'row', gap: 8, alignItems: 'flex-start',
              backgroundColor: colors.card, borderRadius: 10, padding: 12,
              marginTop: 8, borderWidth: 1, borderColor: colors.border,
            }}
          >
            <Ionicons name="information-circle-outline" size={16} color={colors.textSecondary}
              style={{ marginTop: 1 }} accessibilityElementsHidden />
            <Text style={{ fontSize: 13, color: colors.textSecondary, flex: 1, lineHeight: 18 }}>
              No notification types are currently enabled. Enable one or more above to receive notifications with your chosen sound.
            </Text>
          </View>
        )}

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
