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

const CURRENT_VERSION = '2026.0.1.1';

const CHANGES: ChangeItem[] = [
  {
    icon: 'chatbubbles-outline',
    tag: 'New',
    title: 'Forum Topic Detail',
    description: 'Tap any forum topic to read the full thread. See all replies with author names, dates, and content. VoiceOver reads each reply as a complete element.',
  },
  {
    icon: 'create-outline',
    tag: 'New',
    title: 'Reply to Forum Topics',
    description: 'Post replies directly from the app. The posting guidelines checker, Writing Tools tip, and non-English detection all work in the compose screen. Requires sign-in.',
  },
  {
    icon: 'apps-outline',
    tag: 'New',
    title: 'App Detail Screen',
    description: 'Tap any app listing to see the full description, developer details, and all community accessibility reviews. Accessibility Consensus available on each app detail page.',
  },
  {
    icon: 'library-outline',
    tag: 'New',
    title: 'Resource Detail Screen',
    description: 'Read complete articles and guides inside the app. Long articles are rendered with proper paragraph spacing. "Open in Safari" available for any resource.',
  },
  {
    icon: 'person-outline',
    tag: 'New',
    title: 'Profile Screen',
    description: 'View your saved items count, link to your applevis.com profile, and sign out from your profile. Accessible via the Profile button on the signed-in Settings card.',
  },
  {
    icon: 'radio-outline',
    tag: 'New',
    title: 'Podcast Settings (Interactive)',
    description: 'All podcast defaults now have working controls: playback speed, skip times, auto-play next, sleep timer, voice enhancement, EQ preset, auto-download, and auto-delete. Changes persist across sessions.',
  },
  {
    icon: 'notifications-outline',
    tag: 'New',
    title: 'Notification Settings (Interactive)',
    description: 'All 8 notification categories now have real toggle switches. Sound picker has a tap-to-preview button. "Allow Notifications" button triggers the system permission dialog.',
  },
  {
    icon: 'color-palette-outline',
    tag: 'New',
    title: 'Appearance Settings (Interactive)',
    description: 'Full 13-theme picker and card density selector now live in Settings → Appearance. Themes apply instantly as you tap each option, the same as in the onboarding wizard.',
  },
  {
    icon: 'accessibility-outline',
    tag: 'New',
    title: 'Accessibility Settings (Interactive)',
    description: 'VoiceOver Detail Level (Simple / Normal / All) is now a live picker in Settings → Accessibility. Each option shows a VoiceOver preview string so you know exactly what you will hear.',
  },
  {
    icon: 'information-circle-outline',
    tag: 'New',
    title: 'About Screen',
    description: 'A dedicated About screen showing app version, build number, iOS version, device model, and active accessibility settings. "Copy Support Information" button lets you paste all of this into a bug report with one tap.',
  },
  {
    icon: 'settings-outline',
    tag: 'Improved',
    title: 'Settings Navigation',
    description: 'Settings sections now route to dedicated interactive screens instead of informational cards. The INTERACTIVE_ROUTES map connects all relevant setting items to their functional screens.',
  },
  {
    icon: 'shield-checkmark-outline',
    tag: 'Improved',
    title: 'API Layer',
    description: 'Extended with topicDetail, submitReply, app detail, and resource detail endpoints. Each new API method includes notes for the Drupal developer on endpoint and filter path confirmation.',
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
            Full content screens, interactive settings, profile, and a complete About screen.
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

        {/* Previous version note */}
        <View style={[styles.card, { backgroundColor: colors.pill, borderColor: colors.border, borderWidth: 1 }]}
          accessible accessibilityLabel="Previous version. Version 2026.0.1 included: theme system, onboarding wizard, push notifications, Handoff, Universal Links, Dynamic Type support, VoiceOver detail levels, accessibility preferences, background fetch, App Store review prompt, settings overhaul, help centre, and podcast player defaults.">
          <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 8 }}>
            Also in 2026.0.1
          </Text>
          {[
            '13-theme system including Mouse, High Contrast, Nebula, and more',
            'Onboarding wizard with theme, VoiceOver level, and notification setup',
            'Push notifications with 8 categories and native action buttons',
            'Handoff -- continue reading or listening on nearby Apple devices',
            'Universal Links from applevis.com open directly in the app',
            'VoiceOver detail levels: Simple, Normal, and All',
            'Dynamic Type, Reduce Motion, Bold Text respected automatically',
            'Background content refresh every 15 minutes',
            'App Store review prompt after podcast episode completion',
            'Complete Help centre with 9 sections and 30+ FAQ answers',
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
