import { useLocalSearchParams, useRouter } from 'expo-router';
import { Pressable, ScrollView, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { SETTINGS_SECTIONS } from '../src/data/settingsData';
import type { SettingItem, SettingType, SettingStatus } from '../src/data/settingsData';

function statusLabel(status?: SettingStatus): string | null {
  if (status === 'coming') return 'Coming soon';
  if (status === 'ios') return 'iOS Setting';
  return null;
}

function statusBadgeColor(status?: SettingStatus, accent?: string): string {
  if (status === 'coming') return '#D97706';
  if (status === 'ios') return accent ?? '#0A84FF';
  return 'transparent';
}

function typeIcon(type: SettingType): string {
  switch (type) {
    case 'toggle':  return 'toggle-outline';
    case 'picker':  return 'list-outline';
    case 'action':  return 'flash-outline';
    case 'link':    return 'open-outline';
    case 'nav':     return 'chevron-forward';
    default:        return 'information-circle-outline';
  }
}

function typeLabel(type: SettingType): string {
  switch (type) {
    case 'toggle':  return 'Toggle on/off';
    case 'picker':  return 'Choose one option';
    case 'action':  return 'Tap to perform action';
    case 'link':    return 'Opens in Safari';
    case 'nav':     return 'Opens a screen';
    default:        return 'Read-only information';
  }
}

function SettingCard({ item }: { item: SettingItem }) {
  const { colors, styles } = useTheme();
  const router = useRouter();
  const badge = statusLabel(item.status);

  // Map well-known setting IDs to dedicated interactive screens
  const INTERACTIVE_ROUTES: Record<string, string> = {
    theme:                  '/settings-appearance',
    cardDensity:            '/settings-appearance',
    announcementLevel:      '/settings-accessibility',
    focusRestoration:       '/settings-accessibility',
    notifForumReplies:      '/settings-notifications',
    notifMentions:          '/settings-notifications',
    notifNewTopics:         '/settings-notifications',
    notifFollowedTopics:    '/settings-notifications',
    notifNewEpisodes:       '/settings-notifications',
    notifAppUpdates:        '/settings-notifications',
    notifNewResources:      '/settings-notifications',
    notifAnnouncements:     '/settings-notifications',
    notifSound:             '/settings-notifications',
    defaultForumFilter:     '/settings-forums',
    podcastSpeed:           '/settings-podcast',
    podcastSkipBack:        '/settings-podcast',
    podcastSkipForward:     '/settings-podcast',
    podcastAutoPlay:        '/settings-podcast',
    podcastSleepTimer:      '/settings-podcast',
    podcastVoiceBoost:      '/settings-podcast',
    podcastEQ:              '/settings-podcast',
    podcastAutoDownload:    '/settings-podcast',
    podcastAutoDelete:      '/settings-podcast',
    // About items now live in Profile
    version:                '/profile',
    whatsNew:               '/whats-new',
    credits:                '/profile',
    privacyPolicyAbout:     '/profile',
    termsOfUse:             '/profile',
    openSource:             '/profile',
    helpGettingStarted:     '/help',
    helpVoiceOver:          '/help',
    helpForums:             '/help',
    helpApps:               '/help',
    helpPodcasts:           '/help',
    helpResources:          '/help',
    helpIntelligence:       '/help',
    helpFAQ:                '/help',
    helpGuidelines:         '/help',
    deleteAccount:          '/profile',
    // Intelligence & Siri — all items open the dedicated intelligence screen
    readAloud:              '/settings-intelligence',
    translate:              '/settings-intelligence',
    nonEnglishDetection:    '/settings-intelligence',
    summarise:              '/settings-intelligence',
    simplify:               '/settings-intelligence',
    consensus:              '/settings-intelligence',
    siriForums:             '/settings-intelligence',
    siriPodcast:            '/settings-intelligence',
    liveActivities:         '/settings-intelligence',
    widgets:                '/settings-intelligence',
    spotlight:              '/settings-intelligence',
  };

  const interactiveRoute = INTERACTIVE_ROUTES[item.id];
  const isNavigable = item.type === 'nav' || item.type === 'link' || !!interactiveRoute;

  function handlePress() {
    if (interactiveRoute) { router.push(interactiveRoute as any); return; }
    if (item.route) router.push(item.route as any);
  }

  return (
    <Pressable
      onPress={isNavigable ? handlePress : undefined}
      accessible
      accessibilityRole={isNavigable ? 'button' : 'none'}
      accessibilityLabel={[
        item.label,
        badge ? `(${badge})` : null,
        item.description,
        `Example: ${item.example}`,
      ].filter(Boolean).join('. ')}
      accessibilityHint={isNavigable ? typeLabel(item.type) : undefined}
      style={({ pressed }) => [
        styles.card,
        item.destructive && { borderColor: '#FCA5A5', borderWidth: 1 },
        isNavigable && pressed && { opacity: 0.85 },
      ]}
    >
      {/* Header row */}
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 8 }}>
        <Text style={{ fontSize: 17, fontWeight: '700',
          color: item.destructive ? '#B91C1C' : colors.text, flex: 1 }}>
          {item.label}
        </Text>
        {badge && (
          <View style={{ backgroundColor: statusBadgeColor(item.status, colors.accent),
            borderRadius: 6, paddingHorizontal: 7, paddingVertical: 2 }}>
            <Text style={{ color: '#FFFFFF', fontSize: 11, fontWeight: '700' }}>{badge}</Text>
          </View>
        )}
        <Ionicons
          name={(item.destructive ? 'warning-outline' : typeIcon(item.type)) as any}
          size={16}
          color={item.destructive ? '#B91C1C' : colors.textSecondary}
        />
      </View>

      {/* Description */}
      <Text style={[styles.cardMeta, { marginBottom: 10, lineHeight: 21 }]}>
        {item.description}
      </Text>

      {/* Example box */}
      <View style={{ backgroundColor: colors.background, borderRadius: 8,
        padding: 10, borderLeftWidth: 3, borderLeftColor: colors.accent }}>
        <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary,
          textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 4 }}>
          Example
        </Text>
        <Text style={{ fontSize: 14, lineHeight: 20, color: colors.text, fontStyle: 'italic' }}>
          {item.example}
        </Text>
      </View>

      {item.type !== 'info' && (
        <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 8, fontWeight: '600' }}>
          {typeLabel(item.type)}
        </Text>
      )}
    </Pressable>
  );
}

export default function SettingsDetail() {
  const { sectionId, title } = useLocalSearchParams<{ sectionId?: string; title?: string }>();
  const { colors } = useTheme();

  const section = sectionId
    ? SETTINGS_SECTIONS.find((s) => s.id === sectionId)
    : SETTINGS_SECTIONS.find((s) => s.title === title) ?? SETTINGS_SECTIONS[0];

  if (!section) return null;

  return (
    <Screen title={section.title} showSettings={false}>
      <ScrollView>
        <View style={{ backgroundColor: colors.card, borderRadius: 14, padding: 14,
          borderWidth: 1, borderColor: colors.border, marginBottom: 16 }}>
          <Text style={{ fontSize: 15, lineHeight: 22, color: colors.textSecondary }}>
            {section.description}
          </Text>
        </View>
        {section.items.map((item) => (
          <SettingCard key={item.id} item={item} />
        ))}
        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
