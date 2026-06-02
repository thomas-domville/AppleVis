import { useState } from 'react';
import { ActivityIndicator, Pressable, Text, View } from 'react-native';
import { router } from 'expo-router';
import { useTheme } from '../../src/contexts/ThemeContext';
import { usePreferences } from '../../src/contexts/PreferencesContext';
import { useToast } from '../../src/contexts/ToastContext';
import { WizardLayout } from '../../src/components/WizardLayout';
import { requestNotificationPermissions } from '../../src/services/notifications';
import { sounds } from '../../src/services/sounds';
import type { NotificationPrefs, NotificationSound } from '../../src/contexts/PreferencesContext';

type CategoryRow = {
  key: keyof NotificationPrefs;
  label: string;
  description: string;
};

const CATEGORIES: CategoryRow[] = [
  { key: 'forumReplies',   label: 'Forum Replies',             description: 'When someone replies to one of your posts.' },
  { key: 'mentions',       label: 'Mentions',                  description: 'When someone @-mentions you in a post.' },
  { key: 'newTopics',      label: 'New Topics',                description: 'When new forum discussions are started.' },
  { key: 'followedTopics', label: 'Followed Topic Activity',   description: 'New replies on topics you are following.' },
  { key: 'newEpisodes',    label: 'New Podcast Episodes',      description: 'When a new AppleVis podcast episode is published.' },
  { key: 'appUpdates',     label: 'App Updates & New Listings',description: 'When apps in the directory are updated or added.' },
  { key: 'newResources',   label: 'New Resources & Guides',    description: 'When new articles, guides, or tutorials are published.' },
  { key: 'announcements',  label: 'AppleVis Announcements',    description: 'Important news and updates from the AppleVis team.' },
];

type SoundOption = { id: NotificationSound; label: string; description: string };

const SOUNDS: SoundOption[] = [
  { id: 'mouseSqueak', label: 'Mouse Squeak',  description: 'A soft, distinctive mouse squeak — the AppleVis signature sound.' },
  { id: 'appleCrunch', label: 'Apple Crunch',  description: 'A satisfying apple crunch — crisp and unmistakable.' },
  { id: 'none',        label: 'System Default', description: 'Use your iPhone\'s standard notification sound.' },
];

export default function NotificationsStep() {
  const { colors }   = useTheme();
  const { showToast } = useToast();
  const {
    notificationPrefs,  setNotificationPrefs,
    notificationSound,  setNotificationSound,
  } = usePreferences();

  const [requesting, setRequesting] = useState(false);

  function toggleCategory(key: keyof NotificationPrefs) {
    setNotificationPrefs({ ...notificationPrefs, [key]: !notificationPrefs[key] });
  }

  async function previewSound(id: NotificationSound) {
    if (id === 'none') return;
    // Play the closest available sound as a preview
    try { await sounds.refreshComplete(); } catch (_e) { /* preview is non-critical */ }
  }

  async function handleAllow() {
    setRequesting(true);
    const granted = await requestNotificationPermissions();
    setRequesting(false);
    if (granted) {
      showToast('Notifications enabled.', 'success');
    } else {
      showToast('Notifications blocked. You can enable them in iOS Settings → AppleVis → Notifications.', 'warning');
    }
    router.push('/onboarding/ready');
  }

  return (
    <WizardLayout
      step={5}
      totalSteps={5}
      title="Notifications"
      description="Choose which notifications to receive and how they sound. You can adjust these any time in Settings → Notifications."
      onNext={handleAllow}
      nextLabel={requesting ? 'Requesting…' : 'Allow Notifications'}
      nextDisabled={requesting}
    >
      {/* Category toggles */}
      <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text, marginBottom: 12 }}>
        Which notifications do you want?
      </Text>
      {CATEGORIES.map(({ key, label, description }) => {
        const enabled = notificationPrefs[key];
        return (
          <Pressable
            key={key}
            onPress={() => toggleCategory(key)}
            accessible
            accessibilityRole="switch"
            accessibilityState={{ checked: enabled }}
            accessibilityLabel={label}
            accessibilityHint={description}
            style={{
              flexDirection: 'row', alignItems: 'center', gap: 12,
              paddingVertical: 13, borderBottomWidth: 1, borderBottomColor: colors.border,
            }}
          >
            {/* Toggle pill */}
            <View style={{
              width: 44, height: 26, borderRadius: 13,
              backgroundColor: enabled ? colors.accent : colors.border,
              justifyContent: 'center', padding: 2,
            }}>
              <View style={{
                width: 22, height: 22, borderRadius: 11, backgroundColor: '#FFFFFF',
                alignSelf: enabled ? 'flex-end' : 'flex-start',
              }} />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>{label}</Text>
              <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 18, marginTop: 1 }}>
                {description}
              </Text>
            </View>
          </Pressable>
        );
      })}

      {/* Sound picker */}
      <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text, marginTop: 24, marginBottom: 12 }}>
        Alert sound
      </Text>
      {SOUNDS.map(({ id, label, description }) => {
        const isSelected = notificationSound === id;
        return (
          <Pressable
            key={id}
            onPress={() => { setNotificationSound(id); previewSound(id); }}
            accessible
            accessibilityRole="radio"
            accessibilityState={{ selected: isSelected }}
            accessibilityLabel={`${label}${isSelected ? ', selected' : ''}`}
            accessibilityHint={description + (id !== 'none' ? ' Double tap to preview.' : '')}
            style={{
              flexDirection: 'row', alignItems: 'center', gap: 12,
              backgroundColor: isSelected ? colors.pill : colors.card,
              borderRadius: 12, padding: 13, marginBottom: 8,
              borderWidth: isSelected ? 2 : 1,
              borderColor: isSelected ? colors.accent : colors.border,
            }}
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

      {requesting && (
        <View style={{ alignItems: 'center', marginTop: 12 }}>
          <ActivityIndicator color={colors.accent} />
        </View>
      )}

      {/* Skip notifications */}
      <Pressable
        onPress={() => router.push('/onboarding/ready')}
        accessible
        accessibilityRole="button"
        accessibilityLabel="Skip notifications for now"
        accessibilityHint="You can enable notifications later in Settings."
        style={{ alignItems: 'center', paddingVertical: 12, marginTop: 4 }}
      >
        <Text style={{ color: colors.textSecondary, fontSize: 15 }}>Skip for now</Text>
      </Pressable>
    </WizardLayout>
  );
}
