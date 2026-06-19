import { useState } from 'react';
import { ActivityIndicator, Pressable, Text, View } from 'react-native';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
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
  requiresAuth?: boolean;
};

const CATEGORIES: CategoryRow[] = [
  { key: 'forumReplies',   label: 'Forum Replies',            description: 'When someone replies to one of your posts.',        requiresAuth: true },
  { key: 'mentions',       label: 'Mentions',                 description: 'When someone @-mentions you in a post.',            requiresAuth: true },
  { key: 'newTopics',      label: 'New Topics',               description: 'When new forum discussions are started.' },
  { key: 'followedTopics', label: 'Followed Topic Activity',  description: 'New replies on topics you are following.',          requiresAuth: true },
  { key: 'newEpisodes',    label: 'New Podcast Episodes',     description: 'When a new AppleVis podcast episode is published.' },
  { key: 'appUpdates',     label: 'New App Directory Entries', description: 'When new app directory entries are published or existing ones are updated.' },
  { key: 'newResources',   label: 'New Guides & Blog Posts',  description: 'When new guides or blog posts are published.' },
  { key: 'announcements',  label: 'AppleVis Announcements',   description: 'Important news and updates from the AppleVis team.' },
];

type SoundOption = { id: NotificationSound; label: string; description: string };

const SOUNDS: SoundOption[] = [
  { id: 'mouseSqueak',         label: 'Mouse Squeak',         description: 'A soft, distinctive mouse squeak — the AppleVis signature sound.' },
  { id: 'appleCrunch',         label: 'Apple Crunch',         description: 'A satisfying apple crunch — crisp and unmistakable.' },
  { id: 'goldenRetrieverBark', label: 'Golden Retriever Bark', description: 'A friendly golden retriever bark — warm and cheerful.' },
  { id: 'none',                label: 'System Default',        description: 'Use your iPhone\'s standard notification sound.' },
];

export default function NotificationsStep() {
  const { colors }   = useTheme();
  const { showToast } = useToast();
  const {
    notificationPrefs,  setNotificationPrefs,
    notificationSound,  setNotificationSound,
  } = usePreferences();

  const [requesting, setRequesting] = useState(false);
  const anyEnabled = Object.values(notificationPrefs).some(Boolean);

  function toggleCategory(key: keyof NotificationPrefs) {
    setNotificationPrefs({ ...notificationPrefs, [key]: !notificationPrefs[key] });
  }

  async function previewSound(id: NotificationSound) {
    if (id === 'none') return;
    try {
      if (id === 'mouseSqueak') await sounds.mouseSqueak();
      else if (id === 'appleCrunch') await sounds.appleCrunch();
      else if (id === 'goldenRetrieverBark') await sounds.goldenRetrieverBark();
    } catch (_e) { /* preview is non-critical */ }
  }

  async function handleAllow() {
    if (!anyEnabled) {
      router.push('/onboarding/ready');
      return;
    }
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
      nextLabel={requesting ? 'Requesting…' : anyEnabled ? 'Allow Notifications' : 'Continue'}
      nextDisabled={requesting}
    >
      {/* Category toggles */}
      <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
        <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text }}>
          Which notifications do you want?
        </Text>
        <View style={{ flexDirection: 'row', gap: 8 }}>
          <Pressable
            onPress={() => {
              const all = {} as typeof notificationPrefs;
              CATEGORIES.forEach(({ key }) => { all[key] = true; });
              setNotificationPrefs(all);
            }}
            accessible
            accessibilityRole="button"
            accessibilityLabel="Enable all notifications"
            style={{ backgroundColor: colors.accent, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 6 }}
          >
            <Text style={{ color: colors.accentText, fontSize: 13, fontWeight: '700' }}>Enable All</Text>
          </Pressable>
          {anyEnabled && (
            <Pressable
              onPress={() => {
                const none = {} as typeof notificationPrefs;
                CATEGORIES.forEach(({ key }) => { none[key] = false; });
                setNotificationPrefs(none);
              }}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Disable all notifications"
              style={{ backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 6 }}
            >
              <Text style={{ color: colors.pillText, fontSize: 13, fontWeight: '700' }}>Disable All</Text>
            </Pressable>
          )}
        </View>
      </View>
      {CATEGORIES.map(({ key, label, description, requiresAuth }) => {
        const enabled = notificationPrefs[key];
        return (
          <Pressable
            key={key}
            onPress={() => toggleCategory(key)}
            accessible
            accessibilityRole="switch"
            accessibilityState={{ checked: enabled }}
            accessibilityLabel={label}
            accessibilityHint={requiresAuth
              ? `${description} Account required — your preference will activate when you sign in.`
              : description}
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
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
                <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>{label}</Text>
                {requiresAuth && (
                  <View style={{ backgroundColor: '#FFF3E0', borderRadius: 5, paddingHorizontal: 6, paddingVertical: 2 }}>
                    <Text style={{ fontSize: 12, fontWeight: '700', color: '#92400E' }}>Account required</Text>
                  </View>
                )}
              </View>
              <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 18, marginTop: 2 }}>
                {description}
              </Text>
            </View>
          </Pressable>
        );
      })}

      {/* Note about account-required categories */}
      <View
        accessible
        accessibilityLabel="Note: Forum Replies, Mentions, and Followed Topic Activity require an AppleVis account. Your preferences are saved and will activate when you sign in."
        style={{
          flexDirection: 'row', gap: 8, alignItems: 'flex-start',
          backgroundColor: '#FFF3E0', borderRadius: 10, padding: 12,
          marginTop: 10, marginBottom: 4,
        }}
      >
        <Ionicons name="information-circle-outline" size={16} color="#D97706" style={{ marginTop: 1 }} accessibilityElementsHidden />
        <Text style={{ fontSize: 13, color: '#92400E', flex: 1, lineHeight: 18 }}>
          Forum Replies, Mentions, and Followed Topic Activity require an AppleVis account. Your preferences are saved and will activate when you sign in.
        </Text>
      </View>

      {/* Sound picker — only relevant when at least one notification type is on */}
      {anyEnabled && <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text, marginTop: 24, marginBottom: 12 }}>
        Alert sound
      </Text>}
      {anyEnabled && <View accessibilityRole="radiogroup" accessibilityLabel="Alert sound">
      {SOUNDS.map(({ id, label, description }) => {
        const isSelected = notificationSound === id;
        return (
          <Pressable
            key={id}
            onPress={() => { setNotificationSound(id); previewSound(id); }}
            accessible
            accessibilityRole="radio"
            accessibilityState={{ checked: isSelected }}
            accessibilityLabel={label}
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
      </View>}

      {/* Info note when nothing is selected */}
      {!anyEnabled && (
        <View
          accessible
          accessibilityLabel="Nothing selected. No notification permission will be requested. You can enable notifications any time in Settings."
          style={{
            flexDirection: 'row', gap: 8, alignItems: 'flex-start',
            backgroundColor: colors.card, borderRadius: 10, padding: 12,
            marginTop: 10, borderWidth: 1, borderColor: colors.border,
          }}
        >
          <Ionicons name="information-circle-outline" size={16} color={colors.textSecondary}
            style={{ marginTop: 1 }} accessibilityElementsHidden />
          <Text style={{ fontSize: 13, color: colors.textSecondary, flex: 1, lineHeight: 18 }}>
            Nothing selected — no notification permission will be requested. You can enable notifications any time in Settings → Notifications.
          </Text>
        </View>
      )}

      {requesting && (
        <View style={{ alignItems: 'center', marginTop: 12 }}>
          <ActivityIndicator color={colors.accent} />
        </View>
      )}

      {/* Only show skip link when something IS selected, as an escape from the permission dialog */}
      {anyEnabled && (
        <Pressable
          onPress={() => router.push('/onboarding/ready')}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Skip notifications for now"
          accessibilityHint="Saves your selections but skips the iOS permission request. You can grant permission later in Settings."
          style={{ alignItems: 'center', paddingVertical: 12, marginTop: 4 }}
        >
          <Text style={{ color: colors.textSecondary, fontSize: 15 }}>Skip for now</Text>
        </Pressable>
      )}
    </WizardLayout>
  );
}
