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

const CURRENT_VERSION = '2026.0.2';

const CHANGES: ChangeItem[] = [
  {
    icon: 'paw-outline',
    tag: 'New',
    title: 'Golden Retriever Bark Alert Sound',
    description: 'A third notification sound option joins Mouse Squeak and Apple Crunch — a warm, friendly golden retriever bark. Choose it in Settings → Notifications or during setup.',
  },
  {
    icon: 'volume-medium-outline',
    tag: 'Improved',
    title: 'All Sounds Now at the Same Volume',
    description: 'Mouse Squeak, Apple Crunch, Golden Retriever Bark, and the welcome tone are now all balanced to the same loudness level. No more sounds that are much louder or quieter than others.',
  },
  {
    icon: 'home-outline',
    tag: 'Improved',
    title: 'Smarter Welcome Summary',
    description: 'The welcome card on the Home tab now tells you how many new comments have appeared in threads you have visited since your last session. Tap it to jump straight to the last item you were reading — VoiceOver focus lands on it automatically.',
  },
  {
    icon: 'headset-outline',
    tag: 'Improved',
    title: 'Three Distinct VoiceOver Detail Levels',
    description: 'Simple, Normal, and All now produce genuinely different labels. Simple gives title and content type only. Normal adds author and comment count. All adds posted date and last-comment time. The setup wizard and Accessibility Settings both show updated examples.',
  },
  {
    icon: 'heart-outline',
    tag: 'New',
    title: 'Follow Forum Topics',
    description: 'Tap the Follow button on any forum topic to subscribe to it. You will receive notifications when new replies are posted. Manage your followed topics from your profile.',
  },
  {
    icon: 'newspaper-outline',
    tag: 'New',
    title: 'Read Blog Posts and Guides in the App',
    description: 'Blog posts and guides now open fully inside the app — no need to switch to Safari. Comments are included, and you can post a comment directly from the page.',
  },
  {
    icon: 'star-outline',
    tag: 'New',
    title: 'Write App Reviews In-App',
    description: 'You can now write a review of any app in the directory directly from the app detail page. Your rating, accessibility rating, and review text are submitted straight to AppleVis.',
  },
  {
    icon: 'arrow-down-outline',
    tag: 'New',
    title: 'Load More and Jump to First Unread',
    description: 'Long forum threads now have a Load More button to page through replies. A Jump to First Unread button takes you straight to the reply you have not seen yet — one tap instead of scrolling through dozens of replies.',
  },
  {
    icon: 'time-outline',
    tag: 'New',
    title: 'Episode Duration on Feed Cards',
    description: 'Podcast episode cards in the feed now show the episode duration after the first time you play or tap that episode. Durations are cached locally so they appear instantly on future visits.',
  },
  {
    icon: 'apps-outline',
    tag: 'Improved',
    title: 'App Directory Fully Revamped',
    description: 'App detail pages now show VoiceOver support, labelling, usability, and other ratings directly from AppleVis. Reviews and comments load live. The detail layout is cleaner and more structured for VoiceOver navigation.',
  },
  {
    icon: 'chatbubbles-outline',
    tag: 'Improved',
    title: 'Richer Forum Thread Presentation',
    description: 'Topic detail pages now have category headers, animated entry, colour-coded author avatars, NEW badges on unread replies, and correct formatting for code blocks and quoted text. Braille display users get cleaner paragraph breaks.',
  },
  {
    icon: 'document-text-outline',
    tag: 'Improved',
    title: 'Redesigned Detail Pages',
    description: 'Blog, guide, episode, and resource detail pages have all been redesigned with consistent layout, better typography, and improved VoiceOver navigation — matching the look and feel of the forum topic view.',
  },
  {
    icon: 'notifications-outline',
    tag: 'Improved',
    title: 'Cleaner Notifications Setup',
    description: 'Notification categories now default to off during setup. The sound picker and Disable All button only appear once you turn at least one category on — so the first screen you see is not confusing with a "nothing selected" note while a sound appears selected.',
  },
  {
    icon: 'accessibility-outline',
    tag: 'Fixed',
    title: 'VoiceOver Focus After Feed Loads',
    description: 'VoiceOver cursor now lands on the welcome card when the Home feed finishes loading, and returns to your last position after pull-to-refresh or navigating back from a detail page.',
  },
  {
    icon: 'speedometer-outline',
    tag: 'Fixed',
    title: 'Pitch Correction When Changing Speed',
    description: 'Switching playback speed between episodes no longer causes audio to sound like a chipmunk. Pitch correction is now applied correctly whenever the speed is changed.',
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
            New sounds, smarter home welcome, follow topics, in-app blogs and reviews, richer detail pages, and VoiceOver focus fixes.
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
          accessible accessibilityLabel="Also in versions 2026.0.1.3 through 2026.0.1.5: welcome tone on launch, refreshed sounds, saved and downloaded episodes with full actions, sort filters for saved and downloads, VoiceOver saved status on episode cards, revamped episode About section, transcript screen, podcast artwork described, topic and episode detail screens, bottom toolbars on all detail pages.">
          <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 8 }}>
            Also in 2026.0.1.3 – 2026.0.1.5
          </Text>
          {[
            'Welcome tone plays on every app launch',
            'Refreshed notification and system sounds',
            'Saved and downloaded episodes with full Queue, Share, Mark as Played actions',
            'Sort your saved and downloaded episodes by date, title, or duration',
            'VoiceOver announces "Saved" on bookmarked episode cards (Detail Level: All)',
            'Episode About section revamped — clean text, live links with icons',
            'Episode transcripts open in a dedicated full-screen modal',
            'Podcast artwork described by on-device iOS intelligence',
            'Full forum topic and episode detail screens',
            'Bottom toolbars on all detail pages for quick actions',
          ].map((item) => (
            <View key={item} style={{ flexDirection: 'row', gap: 8, marginBottom: 6 }}
              accessible accessibilityLabel={item}>
              <Text style={{ color: colors.accent, fontSize: 15 }} accessibilityElementsHidden>•</Text>
              <Text style={{ flex: 1, fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>{item}</Text>
            </View>
          ))}
        </View>

        <View style={[styles.card, { backgroundColor: colors.pill, borderColor: colors.border, borderWidth: 1, marginBottom: 10 }]}
          accessible accessibilityLabel="Also in version 2026.0.1.2: search, sort and filter bars, Liquid Glass, forum filter pill, podcast speed pill, VoiceOver tab positions, sign-in fixes, settings routing fixes.">
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
