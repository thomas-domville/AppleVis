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

const CURRENT_VERSION = '2026.0.5';

const CHANGES: ChangeItem[] = [
  {
    icon: 'bug-outline',
    tag: 'New',
    title: 'Submit a Bug Report In-App',
    description: 'Report accessibility bugs without leaving AppleVis. The four-step wizard guides you through platform and OS version, bug title and Apple Feedback number, a detailed description, and recognition preference. Open Discover → Contribute → Submit a Bug Report.',
  },
  {
    icon: 'create-outline',
    tag: 'New',
    title: 'Submit a Blog Post In-App',
    description: 'Write, import a text or Markdown file, or paste from the clipboard to submit a blog post to the AppleVis Editorial Team. A three-step wizard handles title, category, content, and review — no need to open a browser.',
  },
  {
    icon: 'mic-outline',
    tag: 'New',
    title: 'Submit a Podcast In-App',
    description: 'Upload a podcast episode directly from the app. Pick an MP3, AAC, M4A, WAV, or AIFF file from Files or iCloud Drive, add a description, and submit. The three-step wizard keeps the process simple.',
  },
  {
    icon: 'phone-portrait-outline',
    tag: 'New',
    title: 'Submit an App Entry In-App',
    description: 'Add a new app to the AppleVis App Directory without visiting the website. The five-step wizard searches iTunes, confirms app details, and walks you through VoiceOver performance, labelling, and usability ratings. Entries are published immediately when submitted by a signed-in member.',
  },
  {
    icon: 'share-outline',
    tag: 'Improved',
    title: 'Share Extension Handles More Content Types',
    description: 'The AppleVis Share Extension now recognises three types of shared content: App Store URLs open the app submission wizard, podcast URLs (from Podcasts, Overcast, Spotify, Pocket Casts, and others) open the podcast wizard, and plain text or text files open the blog post wizard with your content pre-loaded.',
  },
  {
    icon: 'help-circle-outline',
    tag: 'Improved',
    title: 'Help Centre: Step-by-Step Wizard Guides',
    description: 'Settings → Help now includes dedicated step-by-step guides for all four submission wizards — Submit a Bug Report, Submit a Blog Post, Submit a Podcast, and Submit an App Entry. Tap any guide to jump straight to the article. The Bug Tracker and Be My Eyes articles have also been updated.',
  },
  {
    icon: 'musical-notes-outline',
    tag: 'Improved',
    title: 'Refreshed UI Sounds',
    description: 'The refresh and screen-close sounds have been updated to cleaner versions. Eight older duplicate sound files have been removed, leaving a single consistent set of audio assets.',
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
            Four in-app submission wizards (bug reports, blog posts, podcasts, app entries), extended Share Extension, wizard guides in Help Centre, and refreshed UI sounds.
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
