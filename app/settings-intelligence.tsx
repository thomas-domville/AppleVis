import { Alert, Pressable, ScrollView, Switch, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { usePreferences } from '../src/contexts/PreferencesContext';
import { useToast } from '../src/contexts/ToastContext';
import { readAloud, translateContent } from '../src/services/intelligenceService';

// ─── Local helpers ────────────────────────────────────────────────────────────

type BadgeVariant = 'live' | 'ios' | 'system';

const BADGE_COLORS: Record<BadgeVariant, { bg: string; text: string }> = {
  live:   { bg: '#D1FAE5', text: '#065F46' },
  ios:    { bg: '#E0E7FF', text: '#3730A3' },
  system: { bg: '#FEF3C7', text: '#92400E' },
};

function Badge({ label, variant }: { label: string; variant: BadgeVariant }) {
  const c = BADGE_COLORS[variant];
  return (
    <View style={{ backgroundColor: c.bg, borderRadius: 6, paddingHorizontal: 8, paddingVertical: 2 }}>
      <Text style={{ fontSize: 11, fontWeight: '700', color: c.text }}>{label}</Text>
    </View>
  );
}

function SectionLabel({ children }: { children: string }) {
  const { colors } = useTheme();
  return (
    <Text
      accessibilityRole="header"
      style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
        textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 12, marginTop: 8 }}
    >
      {children}
    </Text>
  );
}

function FeatureCard({
  icon, title, badge, badgeVariant = 'ios', description, onPress, children,
}: {
  icon: string;
  title: string;
  badge: string;
  badgeVariant?: BadgeVariant;
  description: string;
  onPress?: () => void;
  children?: React.ReactNode;
}) {
  const { colors, styles } = useTheme();
  return (
    <Pressable
      onPress={onPress}
      accessible
      accessibilityRole={onPress ? 'button' : 'none'}
      accessibilityLabel={`${title}. ${badge}. ${description}`}
      accessibilityHint={onPress ? 'Double tap for more information' : undefined}
      style={({ pressed }) => [styles.card, { marginBottom: 14, opacity: pressed && onPress ? 0.85 : 1 }]}
    >
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 8 }}>
        <Ionicons name={icon as any} size={20} color={colors.accent} accessibilityElementsHidden />
        <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text, flex: 1 }}>{title}</Text>
        <Badge label={badge} variant={badgeVariant} />
      </View>
      <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 21, marginBottom: children ? 12 : 0 }}>
        {description}
      </Text>
      {children}
    </Pressable>
  );
}

function TryButton({ label, onPress }: { label: string; onPress: () => void }) {
  const { colors } = useTheme();
  return (
    <Pressable
      onPress={onPress}
      accessible
      accessibilityRole="button"
      accessibilityLabel={label}
      style={({ pressed }) => ({
        backgroundColor: colors.appleVisBlue, borderRadius: 8,
        paddingHorizontal: 16, paddingVertical: 9, alignSelf: 'flex-start',
        opacity: pressed ? 0.75 : 1,
      })}
    >
      <Text style={{ color: '#FFFFFF', fontSize: 14, fontWeight: '700' }}>{label}</Text>
    </Pressable>
  );
}

function nativeAlert(feature: string, requirement: string) {
  Alert.alert(
    feature,
    `This feature requires ${requirement}.\n\nThe interface is fully wired and will activate automatically once the native module is integrated into the build.`,
    [{ text: 'Got it' }],
  );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

export default function IntelligenceSettings() {
  const { colors, styles }    = useTheme();
  const { showToast }         = useToast();
  const {
    nonEnglishDetectionEnabled,
    setNonEnglishDetectionEnabled,
  } = usePreferences();

  return (
    <Screen title="Intelligence & Siri" showSettings={false}>
      <ScrollView showsVerticalScrollIndicator={false}>

        <Text style={styles.lede}>
          AppleVis uses on-device AI and system integrations to help you browse faster,
          listen hands-free, and get accessibility insights — without sending your
          content to a server.
        </Text>

        {/* ── Available Now ─────────────────────────────────────────────── */}
        <SectionLabel>Available Now</SectionLabel>

        <FeatureCard
          icon="volume-high-outline"
          title="Read Aloud"
          badge="Live"
          badgeVariant="live"
          description="Reads the title and description of any content card aloud using your device's text-to-speech voice. Works without VoiceOver and without internet. Available on every forum topic, app, resource, and podcast episode via the VoiceOver actions rotor."
        >
          <TryButton
            label="Try Read Aloud"
            onPress={() => {
              readAloud('Welcome to AppleVis — the premier community for blind, DeafBlind, and low vision Apple users.');
              showToast('Speaking…', 'success');
            }}
          />
        </FeatureCard>

        <FeatureCard
          icon="language-outline"
          title="Translate"
          badge="Live"
          badgeVariant="live"
          description="Opens the iOS Share sheet with content pre-filled. Supports any language iOS supports — no extra setup needed. Available via the VoiceOver actions rotor on forum topics, app listings, and resources."
        >
          <TryButton
            label="Try Translate"
            onPress={() => translateContent(
              'Welcome to AppleVis — the premier community for blind, DeafBlind, and low vision Apple users.',
              'AppleVis',
            )}
          />
        </FeatureCard>

        {/* Non-English Detection toggle */}
        <Pressable
          onPress={() => setNonEnglishDetectionEnabled(!nonEnglishDetectionEnabled)}
          accessible
          accessibilityRole="switch"
          accessibilityState={{ checked: nonEnglishDetectionEnabled }}
          accessibilityLabel={`Non-English Text Detection, ${nonEnglishDetectionEnabled ? 'on' : 'off'}. When you type or paste non-English text in the search bar or compose screen, a banner appears offering to translate it before you search or post.`}
          style={({ pressed }) => [
            styles.card,
            { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 14,
              opacity: pressed ? 0.85 : 1 },
          ]}
        >
          <Ionicons name="text-outline" size={20} color={colors.accent} accessibilityElementsHidden />
          <View style={{ flex: 1 }}>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 4 }}>
              <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text }}>
                Non-English Detection
              </Text>
              <Badge label="Live" variant="live" />
            </View>
            <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>
              Shows a translate banner when non-English text is detected in search or compose.
            </Text>
          </View>
          <Switch
            value={nonEnglishDetectionEnabled}
            onValueChange={setNonEnglishDetectionEnabled}
            accessibilityElementsHidden
            importantForAccessibility="no-hide-descendants"
            trackColor={{ false: colors.border, true: colors.appleVisBlue }}
            thumbColor="#FFFFFF"
          />
        </Pressable>

        {/* ── Apple Intelligence · iOS 18.2+ ────────────────────────────── */}
        <SectionLabel>Apple Intelligence  ·  iOS 18.2+</SectionLabel>

        <FeatureCard
          icon="document-text-outline"
          title="Summarise"
          badge="iOS 18.2+"
          description="Condenses long forum threads and resource articles to 2–3 sentences using Apple's on-device Foundation Models. Never leaves your device. Requires Apple Intelligence to be enabled in iOS Settings."
          onPress={() => nativeAlert('Summarise', 'iOS 18.2+ with Apple Intelligence enabled in Settings → Apple Intelligence & Siri')}
        />

        <FeatureCard
          icon="sparkles-outline"
          title="Simplify"
          badge="iOS 18.2+"
          description="Rewrites technical accessibility content in plain, simple language using Foundation Models. Useful for complex developer discussions and spec-heavy articles."
          onPress={() => nativeAlert('Simplify', 'iOS 18.2+ with Apple Intelligence enabled in Settings → Apple Intelligence & Siri')}
        />

        <FeatureCard
          icon="people-outline"
          title="Accessibility Consensus"
          badge="iOS 18.2+"
          description='Aggregates multiple app reviews into a single clear statement — "Most reviewers say this app works well with VoiceOver, though some note issues with the settings screen."'
          onPress={() => nativeAlert('Accessibility Consensus', 'iOS 18.2+ with Apple Intelligence enabled in Settings → Apple Intelligence & Siri')}
        />

        {/* ── Siri Voice Commands ───────────────────────────────────────── */}
        <SectionLabel>Siri Voice Commands</SectionLabel>

        <FeatureCard
          icon="mic-outline"
          title='Say "Open AppleVis Forums"'
          badge="App Intents"
          badgeVariant="system"
          description='Ask Siri to open the Forums, show unread topics, open saved items, or search for apps — all by voice. Works on Lock Screen, with AirPods, and via Hey Siri.'
          onPress={() => nativeAlert('Siri Voice Commands', 'the Siri App Intents native module')}
        />

        <FeatureCard
          icon="mic-outline"
          title='Say "Play the Latest AppleVis Podcast"'
          badge="App Intents"
          badgeVariant="system"
          description="Ask Siri to play the most recent episode hands-free, even with the phone in your pocket. Also supports continue, pause, and skip commands."
          onPress={() => nativeAlert('Siri Podcast Command', 'the Siri App Intents native module')}
        />

        {/* ── System Integrations ───────────────────────────────────────── */}
        <SectionLabel>System Integrations</SectionLabel>

        <FeatureCard
          icon="phone-portrait-outline"
          title="Live Activities & Dynamic Island"
          badge="ActivityKit"
          badgeVariant="system"
          description="While a podcast is playing, a Live Activity shows the episode title, progress bar, and playback controls on your Lock Screen and in the Dynamic Island on iPhone 14 Pro and later."
          onPress={() => nativeAlert('Live Activities', 'the ActivityKit native module')}
        />

        <FeatureCard
          icon="grid-outline"
          title="Home Screen Widgets"
          badge="WidgetKit"
          badgeVariant="system"
          description="Add AppleVis widgets to your Home Screen or Lock Screen showing unread topic count, the latest podcast episode, or your personalised activity digest. Tap a widget to open directly to that content."
          onPress={() => nativeAlert('Home Screen Widgets', 'the WidgetKit native module')}
        />

        <FeatureCard
          icon="search-outline"
          title="Spotlight Search"
          badge="CoreSpotlight"
          badgeVariant="system"
          description="Forum topics, podcast episodes, and app listings appear in iOS system Search (swipe down from the Home Screen) so you can find AppleVis content without opening the app."
          onPress={() => nativeAlert('Spotlight Search', 'the CoreSpotlight native module')}
        />

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
