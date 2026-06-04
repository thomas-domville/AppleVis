import { ScrollView, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';

type ChangeItem = {
  icon: string;
  title: string;
  description: string;
  tag: 'New' | 'Improved' | 'Fixed';
};

const CURRENT_VERSION = '2026.0.1.2';

const CHANGES: ChangeItem[] = [
  {
    icon: 'person-circle-outline',
    tag: 'Improved',
    title: 'Profile Now Includes About',
    description: 'Everything that was in the separate About screen — version number, device info, What\'s New, copy support info, privacy policy, credits — now lives inside your Profile. Settings is now purely a settings screen. Sign Out has moved to Profile too.',
  },
  {
    icon: 'options-outline',
    tag: 'Improved',
    title: 'Podcast Settings Are Much Less Swipeable',
    description: 'Playback Speed and Sleep Timer now open a list — tap once to pick your value. Skip Back, Skip Forward, EQ, Auto-Download, and Auto-Delete use compact segmented buttons. A new Resume Rewind setting has also been added to the Queue section.',
  },
  {
    icon: 'chatbubbles-outline',
    tag: 'New',
    title: 'Forums Has Its Own Settings Page',
    description: 'A new Forums section in Settings lets you choose which view the Forums tab opens on by default — Recent, Since Last Visit, or Unread. No more switching the filter every time you open the app.',
  },
  {
    icon: 'search-outline',
    tag: 'New',
    title: 'Search on Forums, Apps, and Resources',
    description: 'All three tabs now have a search bar at the top. Type to filter by title, author, developer, category, or resource type. Results update as you type.',
  },
  {
    icon: 'funnel-outline',
    tag: 'New',
    title: 'Sort and Filter Bar on Every Tab',
    description: 'Forums, Apps, Resources, and Podcasts all now have the same action bar: a sort button showing the current order, a filter button (by category, type, or show), and a count of visible results. Opening one closes the other automatically.',
  },
  {
    icon: 'water-outline',
    tag: 'New',
    title: 'Liquid Glass on iOS',
    description: 'Sort sheets, filter sheets, the mini player, and the tab bar now use the iOS frosted-glass blur effect. It turns off automatically if you have Reduce Transparency enabled in iOS Accessibility Settings, or if you use a High Contrast theme.',
  },
  {
    icon: 'chevron-back-outline',
    tag: 'New',
    title: 'Back Button on Every Screen',
    description: 'Every settings page, topic view, and detail screen now shows a Back button at the top left so you can always find your way back without hunting for it.',
  },
  {
    icon: 'funnel-outline',
    tag: 'Improved',
    title: 'Forum Filter is One Tap, Not Six Swipes',
    description: 'The row of six filter buttons (Recent, New, Unread, etc.) has been replaced with a single button showing your current choice. Tap it to open a list and pick a different one. Much less swiping with VoiceOver.',
  },
  {
    icon: 'speedometer-outline',
    tag: 'Improved',
    title: 'Podcast Speed is One Tap Too',
    description: 'The nine playback speed buttons have been replaced the same way — one button shows the current speed, tap to change it.',
  },
  {
    icon: 'headset-outline',
    tag: 'Improved',
    title: 'VoiceOver Tabs Now Say Their Position',
    description: 'VoiceOver now reads each tab as "Home, 1 of 5" or "Forums, 2 of 5" — the same way any Apple app announces tabs. Previously it just said the tab name with no position.',
  },
  {
    icon: 'search-outline',
    tag: 'Fixed',
    title: 'Search and Settings Buttons No Longer Repeat',
    description: 'VoiceOver was announcing the Search and Settings buttons twice — once as a group and once as a link. They now each announce once, cleanly, as a button.',
  },
  {
    icon: 'person-outline',
    tag: 'Improved',
    title: 'Forum Topics Now Say Who Posted Them',
    description: 'When VoiceOver Detail Level is set to "All" in Accessibility Settings, VoiceOver now reads the name of the person who posted a topic — for example "VoiceOver Tips. By JohnDoe. 5 replies."',
  },
  {
    icon: 'settings-outline',
    tag: 'Fixed',
    title: 'Settings Pages Now Open the Real Controls',
    description: 'Tapping Appearance, Accessibility, Notifications, or Podcasts in Settings now goes straight to the page where you can actually make changes. Before, it opened a description page instead.',
  },
  {
    icon: 'toggle-outline',
    tag: 'Fixed',
    title: 'Your Settings Now Actually Take Effect',
    description: 'Six settings that were being saved but had no effect are now wired up: your default forum filter, card size (Comfortable or Compact), notification toggles, silence notifications option, podcast auto-play, and default sleep timer.',
  },
  {
    icon: 'log-in-outline',
    tag: 'Improved',
    title: 'Sign In Accepts Username or Email',
    description: 'The sign-in screen now accepts either your AppleVis username or your email address, not just email. There is also a direct link to create a free account, and a "Skip for now" button so you can explore the app first.',
  },
  {
    icon: 'person-add-outline',
    tag: 'Fixed',
    title: 'Sign In Now Works',
    description: 'A server issue that was preventing sign-in has been fixed. You can now log in with your AppleVis account.',
  },
  {
    icon: 'phone-portrait-outline',
    tag: 'Fixed',
    title: 'App Opens Correctly in Expo Go',
    description: 'The app now opens without a blank white screen. A startup sound that was playing by accident has also been silenced.',
  },
];

const TAG_STYLES: Record<ChangeItem['tag'], { bg: string; text: string }> = {
  New:      { bg: '#ECFDF5', text: '#065F46' },
  Improved: { bg: '#EFF6FF', text: '#1D4ED8' },
  Fixed:    { bg: '#FFF7ED', text: '#9A3412' },
};

export default function WhatsNew() {
  const { colors, styles } = useTheme();

  return (
    <Screen title="What's New" showSettings={false}>
      <ScrollView showsVerticalScrollIndicator={false}>

        {/* Version header */}
        <View style={[styles.card, { alignItems: 'center', paddingVertical: 20 }]}
          accessible
          accessibilityLabel={`What's new in AppleVis version ${CURRENT_VERSION}`}>
          <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 6 }}>
            Version {CURRENT_VERSION}
          </Text>
          <Text style={{ fontSize: 16, color: colors.textSecondary, textAlign: 'center', lineHeight: 23 }}>
            Search, sort, glass UI, smarter settings, and a unified Profile.
          </Text>
        </View>

        {/* Change list */}
        {CHANGES.map(({ icon, tag, title, description }) => {
          const tagStyle = TAG_STYLES[tag];
          return (
            <View
              key={title}
              style={styles.card}
              accessible
              accessibilityLabel={`${tag}: ${title}. ${description}`}
            >
              <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 12 }}>
                <View style={{ width: 36, height: 36, borderRadius: 10,
                  backgroundColor: colors.pill, alignItems: 'center', justifyContent: 'center',
                  flexShrink: 0, marginTop: 2 }} accessibilityElementsHidden>
                  <Ionicons name={icon as any} size={18} color={colors.accent} />
                </View>
                <View style={{ flex: 1 }}>
                  <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 5 }}>
                    <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text }}>{title}</Text>
                    <View style={{ backgroundColor: tagStyle.bg, borderRadius: 6,
                      paddingHorizontal: 7, paddingVertical: 2 }}>
                      <Text style={{ color: tagStyle.text, fontSize: 11, fontWeight: '700' }}>{tag}</Text>
                    </View>
                  </View>
                  <Text style={{ fontSize: 14, lineHeight: 21, color: colors.textSecondary }}>
                    {description}
                  </Text>
                </View>
              </View>
            </View>
          );
        })}

        {/* Previous version notes */}
        <View style={[styles.card, { backgroundColor: colors.pill, borderColor: colors.border, borderWidth: 1, marginBottom: 10 }]}
          accessible accessibilityLabel="Also in version 2026.0.1.2: back buttons, forum filter pill, podcast speed pill, VoiceOver tab positions, sign-in fixes, settings routing fixes.">
          <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 8 }}>
            Also in 2026.0.1.2
          </Text>
          {[
            'Back button added to every settings, detail, and sub-screen',
            'Forum filter replaced with a single pill — one tap to switch',
            'Podcast speed replaced with a single pill — one tap to change',
            'VoiceOver now reads tab position (e.g. "Forums, 2 of 5")',
            'Settings pages now open the real interactive controls',
            'Six settings that were saved but ignored are now wired up',
            'Sign in now accepts username or email, and actually works',
            'Magic tap (two-finger double tap) plays and pauses podcasts',
            'Episode detail screen with show notes, chapters, and actions',
          ].map((item) => (
            <View key={item} style={{ flexDirection: 'row', gap: 8, marginBottom: 6 }}
              accessible accessibilityLabel={item}>
              <Text style={{ color: colors.accent, fontSize: 15 }} accessibilityElementsHidden>•</Text>
              <Text style={{ flex: 1, fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>{item}</Text>
            </View>
          ))}
        </View>

        <View style={[styles.card, { backgroundColor: colors.pill, borderColor: colors.border, borderWidth: 1 }]}
          accessible accessibilityLabel="Also in version 2026.0.1.1: forum topic detail, reply to topics, app detail screen, resource detail screen, profile screen, interactive podcast and notification settings, appearance and accessibility settings.">
          <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 8 }}>
            Also in 2026.0.1.1
          </Text>
          {[
            'Read full forum threads with all replies inside the app',
            'Post replies to forum topics directly from the app',
            'Full app listings with all community reviews',
            'Read complete guides and articles inside the app',
            'Podcast settings with working controls for speed, skip times, and more',
            'Notification settings with real on/off toggles for each category',
            'Theme and card size settings with instant preview',
            'VoiceOver Detail Level setting — choose Simple, Normal, or All',
          ].map((item) => (
            <View key={item} style={{ flexDirection: 'row', gap: 8, marginBottom: 6 }}
              accessible accessibilityLabel={item}>
              <Text style={{ color: colors.accent, fontSize: 15 }} accessibilityElementsHidden>•</Text>
              <Text style={{ flex: 1, fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>{item}</Text>
            </View>
          ))}
        </View>

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
