import { Pressable, ScrollView, Switch, Text, View } from 'react-native';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { usePreferences } from '../src/contexts/PreferencesContext';
import { useToast } from '../src/contexts/ToastContext';
import { requestNotificationPermissions } from '../src/services/notifications';
import { sounds } from '../src/services/sounds';
import type { NotificationPrefs, NotificationSound } from '../src/contexts/PreferencesContext';

type CategoryDef = { key: keyof NotificationPrefs; label: string; description: string };

const CATEGORIES: CategoryDef[] = [
  { key: 'forumReplies',   label: 'Forum Replies',             description: 'When someone replies to one of your posts.' },
  { key: 'mentions',       label: 'Mentions',                  description: 'When someone @-mentions you in a post.' },
  { key: 'newTopics',      label: 'New Topics',                description: 'When new forum discussions are started.' },
  { key: 'followedTopics', label: 'Followed Topic Activity',   description: 'New replies in topics you are following.' },
  { key: 'newEpisodes',    label: 'New Podcast Episodes',      description: 'When a new AppleVis podcast episode is published.' },
  { key: 'appUpdates',     label: 'New App Directory Entries',  description: 'When new app directory entries are published or existing ones are updated.' },
  { key: 'newResources',   label: 'New Guides & Blog Posts',    description: 'When new guides or blog posts are published.' },
  { key: 'announcements',  label: 'AppleVis Announcements',    description: 'Important news from the AppleVis team.' },
];

const SOUNDS: { id: NotificationSound; label: string; description: string }[] = [
  { id: 'mouseSqueak', label: 'Mouse Squeak',  description: 'The AppleVis signature sound -- soft and distinctive.' },
  { id: 'appleCrunch', label: 'Apple Crunch',  description: 'A crisp apple crunch.' },
  { id: 'none',        label: 'System Default', description: 'Your iPhone\'s standard notification tone.' },
];

export default function NotificationSettings() {
  const { colors, styles } = useTheme();
  const { showToast }      = useToast();
  const { notificationPrefs, setNotificationPrefs,
          notificationSound, setNotificationSound } = usePreferences();

  function toggleCategory(key: keyof NotificationPrefs) {
    setNotificationPrefs({ ...notificationPrefs, [key]: !notificationPrefs[key] });
  }

  async function previewSound(id: NotificationSound) {
    if (id === 'mouseSqueak') await sounds.mouseSqueak().catch(() => {});
    else if (id === 'appleCrunch') await sounds.appleCrunch().catch(() => {});
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
          Choose which notifications you receive. Changes take effect immediately
          and are sent to the AppleVis server with your next sync.
        </Text>

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
          textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 8 }}
          accessibilityRole="header">Notification Types</Text>

        {CATEGORIES.map(({ key, label, description }) => {
          const enabled = notificationPrefs[key];
          return (
            <View
              key={key}
              style={[styles.cardSmall, { flexDirection: 'row', alignItems: 'center', gap: 12 }]}
              accessible
              accessibilityLabel={`${label}. ${description}. ${enabled ? 'On' : 'Off'}.`}
              accessibilityRole="switch"
              accessibilityState={{ checked: enabled }}
            >
              <View style={{ flex: 1 }}>
                <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>{label}</Text>
                <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 18, marginTop: 2 }}>
                  {description}
                </Text>
              </View>
              <Switch
                value={enabled}
                onValueChange={() => toggleCategory(key)}
                trackColor={{ false: colors.border, true: colors.accent }}
                thumbColor="#FFFFFF"
                accessibilityElementsHidden
              />
            </View>
          );
        })}

        {/* Sound picker */}
        <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
          textTransform: 'uppercase', letterSpacing: 0.8, marginTop: 20, marginBottom: 8 }}
          accessibilityRole="header">Alert Sound</Text>

        {SOUNDS.map(({ id, label, description }) => {
          const isSelected = notificationSound === id;
          return (
            <Pressable
              key={id}
              onPress={() => { setNotificationSound(id); previewSound(id); }}
              accessible accessibilityRole="none"
              accessibilityState={{ selected: isSelected }}
              accessibilityLabel={`${label}${isSelected ? ', selected' : ''}`}
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

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
