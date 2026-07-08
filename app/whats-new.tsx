import { Pressable, ScrollView, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';

type ChangeLink =
  | { label: string; kind: 'helpArticle'; articleId: string }
  | { label: string; kind: 'route'; route: string };

type ChangeItem = {
  icon: string;
  title: string;
  description: string;
  tag: 'New' | 'Improved' | 'Fixed';
  link?: ChangeLink;
};

const CURRENT_VERSION = '2026.0.7';

const CHANGES: ChangeItem[] = [
  {
    icon: 'watch-outline',
    tag: 'New',
    title: 'AppleVis on Apple Watch',
    description: 'A brand-new Apple Watch app lets you see what episode is playing, play or pause, and skip forward or back right from your wrist — no need to take out your phone. It also shows how many forum replies are waiting for you.',
  },
  {
    icon: 'share-outline',
    tag: 'New',
    title: 'Share Into AppleVis From Other Apps',
    description: 'Found an app, podcast, or article somewhere else? Use the Share button in Safari or any other app and choose AppleVis. It opens the right submission form automatically with the link already filled in.',
  },
  {
    icon: 'laptop-outline',
    tag: 'New',
    title: 'Pick Up Where You Left Off on Another Device',
    description: 'Reading a topic or listening to a podcast on your iPhone? With Handoff, an AppleVis icon appears on your nearby iPad or Mac so you can jump straight back in on that device.',
  },
  {
    icon: 'keypad-outline',
    tag: 'New',
    title: 'Keyboard Shortcuts on iPad',
    description: 'If you use an external keyboard with your iPad, hold down the Command key to see new shortcuts — jump to Search, Settings, or straight to Forums, Apps, Podcasts, or Resources.',
  },
  {
    icon: 'checkmark-done-circle-outline',
    tag: 'Fixed',
    title: 'Several Features Now Actually Work',
    description: 'A thorough check turned up a number of features that looked fine but were not fully working behind the scenes. Apple Intelligence, Siri Shortcuts, AirPlay, Spotlight search results, Lock Screen and Control Center playback controls, Voice Boost, Trim Silence, on-device podcast artwork descriptions, and iCloud sync of your podcast library are now all working properly.',
  },
  {
    icon: 'notifications-outline',
    tag: 'Improved',
    title: 'AppleVis Categories in Focus Settings',
    description: 'AppleVis notification categories now appear in Settings → Focus, so you can start choosing which ones — like mentions or new episodes — you want to allow through during a Focus mode.',
  },
];

const TAG_STYLES: Record<ChangeItem['tag'], { bg: string; text: string }> = {
  New:      { bg: '#ECFDF5', text: '#065F46' },
  Improved: { bg: '#EFF6FF', text: '#1D4ED8' },
  Fixed:    { bg: '#FFF7ED', text: '#9A3412' },
};

export default function WhatsNew() {
  const { colors, styles } = useTheme();
  const router = useRouter();

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
            A new Apple Watch app, sharing into AppleVis from other apps, picking up where you left off on another device, iPad keyboard shortcuts, and a big pass making sure everything actually works as expected.
          </Text>
        </View>

        {/* Change list */}
        {CHANGES.map(({ icon, tag, title, description, link }) => {
          const tagStyle = TAG_STYLES[tag];
          return (
            <View
              key={title}
              style={styles.card}
            >
              <View
                style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 12 }}
                accessible
                accessibilityLabel={`${tag}: ${title}. ${description}`}
              >
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
              {link && (
                <Pressable
                  onPress={() => {
                    if (link.kind === 'helpArticle') {
                      router.push({ pathname: '/help-article', params: { articleId: link.articleId } });
                    } else {
                      router.push(link.route as any);
                    }
                  }}
                  accessible
                  accessibilityRole="button"
                  accessibilityLabel={link.label}
                  style={({ pressed }) => ({
                    alignSelf: 'flex-start', marginTop: 10, marginLeft: 48,
                    opacity: pressed ? 0.7 : 1,
                  })}
                >
                  <Text style={{ color: colors.accent, fontSize: 14, fontWeight: '700' }}>{link.label} →</Text>
                </Pressable>
              )}
            </View>
          );
        })}

        {/* Previous version notes */}
        <View style={[styles.card, { backgroundColor: colors.pill, borderColor: colors.border, borderWidth: 1, marginBottom: 10 }]}
          accessible accessibilityLabel="Also in version 2026.0.6: in-app contact wizard, Apple Intelligence features, three new Siri shortcuts, AirPods next-episode skip, podcast artwork on the Lock Screen, refreshed Help Centre, adaptive app icon, Dynamic Island fix.">
          <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 8 }}>
            Also in 2026.0.6
          </Text>
          {[
            'Contact App Support wizard — reach the AppleVis team without leaving the app or using Mail',
            'Apple Intelligence features — summarize, simplify, and translate text on-device (iPhone 15 Pro+, iOS 26)',
            'Three new Siri Shortcuts — resume your podcast, search AppleVis, or open saved items by voice',
            'Skip to the next queued episode using AirPods or the Lock Screen',
            'Podcast artwork appears on the Lock Screen, Dynamic Island, and Control Center',
            'Help Centre fully refreshed to match the current app',
            'App icon adapts automatically to your Home Screen style (iOS 18+)',
            'Dynamic Island shows the correct play or pause icon',
          ].map((item) => (
            <View key={item} style={{ flexDirection: 'row', gap: 8, marginBottom: 6 }}
              accessible accessibilityLabel={item}>
              <Text style={{ color: colors.accent, fontSize: 15 }} accessibilityElementsHidden>•</Text>
              <Text style={{ flex: 1, fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>{item}</Text>
            </View>
          ))}
        </View>

        <View style={[styles.card, { backgroundColor: colors.pill, borderColor: colors.border, borderWidth: 1, marginBottom: 10 }]}
          accessible accessibilityLabel="Also in version 2026.0.5: submit bug reports, blog posts, podcasts, and app entries inside the app. Extended Share Extension. Step-by-step wizard guides in Help Centre. Refreshed UI sounds.">
          <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 8 }}>
            Also in 2026.0.5
          </Text>
          {[
            'Submit a bug report inside the app — four-step wizard with platform, OS version, title, Feedback ID, description, and recognition preference',
            'Submit a blog post inside the app — write, import a text or Markdown file, or paste from the clipboard',
            'Submit a podcast episode inside the app — upload your audio file directly from Files or iCloud Drive',
            'Submit an app entry to the App Directory inside the app — iTunes search, accessibility ratings, and immediate publication',
            'Share Extension now recognises App Store links, podcast URLs, and text files — each opens the right wizard automatically',
            'Help Centre step-by-step guides for all four submission wizards',
            'Refreshed UI sounds — cleaner versions throughout',
          ].map((item) => (
            <View key={item} style={{ flexDirection: 'row', gap: 8, marginBottom: 6 }}
              accessible accessibilityLabel={item}>
              <Text style={{ color: colors.accent, fontSize: 15 }} accessibilityElementsHidden>•</Text>
              <Text style={{ flex: 1, fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>{item}</Text>
            </View>
          ))}
        </View>

        <View style={[styles.card, { backgroundColor: colors.pill, borderColor: colors.border, borderWidth: 1, marginBottom: 10 }]}
          accessible accessibilityLabel="Also in version 2026.0.4 and 2026.0.3: admin edit and delete from detail pages, app detail redesign, topic category hero cards, blog and guide detail redesign, Home tab improvements.">
          <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 8 }}>
            Also in 2026.0.4 – 2026.0.3
          </Text>
          {[
            'Edit and delete your own posts and reviews directly from detail pages inside the app',
            'App Directory detail page redesigned — VoiceOver, labelling, and usability ratings, developer contact, iTunes link, and supported devices',
            'Forum topic category hero card, animated replies, braille-friendly paragraph splits, per-author avatar colours, and thread summary action',
            'Blog and guide detail pages match the forum topic visual design and VoiceOver behaviour',
            'Home tab welcome flow redesigned — focus-based, no announcements, jumps to last-read position',
          ].map((item) => (
            <View key={item} style={{ flexDirection: 'row', gap: 8, marginBottom: 6 }}
              accessible accessibilityLabel={item}>
              <Text style={{ color: colors.accent, fontSize: 15 }} accessibilityElementsHidden>•</Text>
              <Text style={{ flex: 1, fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>{item}</Text>
            </View>
          ))}
        </View>

        <View style={[styles.card, { backgroundColor: colors.pill, borderColor: colors.border, borderWidth: 1, marginBottom: 10 }]}
          accessible accessibilityLabel="Also in version 2026.0.2: Golden Retriever Bark alert sound, balanced alert volumes, smarter welcome summary, three VoiceOver detail levels, follow forum topics, in-app blog posts and guides, write app reviews in-app, load more and jump to first unread, episode duration on feed cards, app directory revamp, richer forum threads, redesigned detail pages, VoiceOver focus after feed loads, pitch correction fix.">
          <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 8 }}>
            Also in 2026.0.2
          </Text>
          {[
            'Golden Retriever Bark added as a third alert sound option',
            'All alert sounds balanced to the same loudness level',
            'Welcome card shows new comment counts and jumps to last-read position',
            'Three genuinely different VoiceOver Detail Levels: Simple, Normal, and All',
            'Follow forum topics and receive reply notifications',
            'Blog posts and guides open fully inside the app with comments',
            'Write app reviews in-app with rating and accessibility assessment',
            'Load More button and Jump to First Unread in long forum threads',
            'Episode duration shown on feed cards after first play',
            'App detail pages show VoiceOver, labelling, and usability ratings',
            'Forum threads: category headers, colour-coded avatars, NEW badges, code blocks',
            'Blog, guide, episode, and resource detail pages redesigned',
            'VoiceOver focus lands correctly after feed load and pull-to-refresh',
            'Pitch correction applied correctly when switching playback speed',
          ].map((item) => (
            <View key={item} style={{ flexDirection: 'row', gap: 8, marginBottom: 6 }}
              accessible accessibilityLabel={item}>
              <Text style={{ color: colors.accent, fontSize: 15 }} accessibilityElementsHidden>•</Text>
              <Text style={{ flex: 1, fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>{item}</Text>
            </View>
          ))}
        </View>

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

        <View style={[styles.card, { backgroundColor: colors.pill, borderColor: colors.border, borderWidth: 1 }]}
          accessible accessibilityLabel="Also in version 2026.0.1.1 and 2026.0.1.2: full forum threads, post replies, app listings with reviews, read guides in-app, working podcast and notification settings, theme and card size settings, VoiceOver Detail Level setting.">
          <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 8 }}>
            Also in 2026.0.1.1 – 2026.0.1.2
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
            'Back button added to every settings, detail, and sub-screen',
            'Magic tap (two-finger double tap) plays and pauses podcasts',
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
