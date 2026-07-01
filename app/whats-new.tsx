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

const CURRENT_VERSION = '2026.0.6';

const CHANGES: ChangeItem[] = [
  {
    icon: 'chatbubble-ellipses-outline',
    tag: 'New',
    title: 'Contact App Support — No Mail App Needed',
    description: 'Reach the AppleVis team without ever leaving the app. The new contact wizard lets you choose what you need help with, write your message, and send it in a few taps. If you are signed in, your name and email are filled in automatically. Open Profile → Contact App Support.',
    link: { label: 'Learn More', kind: 'helpArticle', articleId: 'trouble-contact' },
  },
  {
    icon: 'sparkles-outline',
    tag: 'New',
    title: 'Apple Intelligence Features',
    description: 'On iPhone 15 Pro or later running iOS 26 with Apple Intelligence turned on, AppleVis can now summarise long forum threads, simplify complex text into plain language, give you an accessibility snapshot for any app, rewrite your draft in a friendly tone, and translate non-English text — all on your device, privately, without sending anything to a server.',
    link: { label: 'Open Setting', kind: 'route', route: '/settings-intelligence' },
  },
  {
    icon: 'mic-circle-outline',
    tag: 'New',
    title: 'Three New Siri Shortcuts',
    description: 'AppleVis now understands three more Siri phrases. Say "Resume my AppleVis podcast" to pick up where you left off. Say "Search AppleVis for accessibility tips" — or any topic — to open search with your words already filled in. Say "Open my AppleVis saved items" to jump straight to your saved content.',
    link: { label: 'Learn More', kind: 'helpArticle', articleId: 'smart-siri-widgets' },
  },
  {
    icon: 'headset-outline',
    tag: 'New',
    title: 'Skip to the Next Episode with AirPods',
    description: 'When you have episodes in your podcast queue, use the next-track gesture on your AirPods or the next-track button on the Lock Screen to skip to the next episode. The previous-track button restarts the current episode from the beginning.',
  },
  {
    icon: 'image-outline',
    tag: 'Improved',
    title: 'Podcast Artwork on the Lock Screen',
    description: 'The episode artwork now appears on your Lock Screen, in Dynamic Island, and in the Control Center Now Playing card while a podcast is playing. Previously the artwork area was blank during playback.',
  },
  {
    icon: 'book-outline',
    tag: 'Improved',
    title: 'Help Centre Refreshed',
    description: 'Every guide has been reviewed and updated to match what the app does today. A brand-new Apple Intelligence guide explains which features it powers, which devices support it, and how to turn it on. The Siri article now lists every phrase you can say by name. The Contact App Support guide reflects the new in-app wizard.',
    link: { label: 'Open Help Centre', kind: 'route', route: '/help' },
  },
  {
    icon: 'color-palette-outline',
    tag: 'Improved',
    title: 'App Icon Adapts to Your Style',
    description: 'The AppleVis app icon now comes in three versions — light, dark, and tinted — and switches automatically to match your iPhone Home Screen appearance on iOS 18 and later.',
  },
  {
    icon: 'construct-outline',
    tag: 'Fixed',
    title: 'Dynamic Island and CarPlay Polished',
    description: 'The Dynamic Island compact view now shows the play icon when paused — not the pause icon — making the playback state easier to read at a glance. The CarPlay episode list now refreshes in place without pushing you back to the top of the navigation stack when new episodes arrive.',
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
            In-app contact wizard, Apple Intelligence on iOS 26, three new Siri shortcuts, AirPods next-episode, Lock Screen artwork, and a fully refreshed Help Centre.
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
