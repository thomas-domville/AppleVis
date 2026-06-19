import { icloudStorage } from '../services/icloudStorage';
import {
  createContext,
  useCallback,
  useContext,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import {
  AccessibilityInfo,
  Animated,
  findNodeHandle,
  Modal,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { useTheme } from './ThemeContext';

// ─── Types ────────────────────────────────────────────────────────────────────

export type TipOptions = {
  title: string;
  message: string;
  icon?: React.ComponentProps<typeof Ionicons>['name'];
  confirmLabel?: string;
  screenReaderOnly?: boolean;
};

type TipContextValue = {
  showTip: (key: string, options: TipOptions) => void;
};

// ─── Storage key prefix ───────────────────────────────────────────────────────

const KEY_PREFIX = 'applevis:tip:';

// ─── Context ──────────────────────────────────────────────────────────────────

const TipContext = createContext<TipContextValue>({ showTip: () => {} });

export function useTip(): TipContextValue {
  return useContext(TipContext);
}

// ─── Tip modal ────────────────────────────────────────────────────────────────

function TipModal({
  options,
  onDismiss,
}: {
  options: TipOptions;
  onDismiss: () => void;
}) {
  const { colors, isDark } = useTheme();
  const scaleAnim   = useRef(new Animated.Value(0.90)).current;
  const opacityAnim = useRef(new Animated.Value(0)).current;
  const titleRef    = useRef<Text>(null);

  const {
    title,
    message,
    icon = 'bulb-outline',
    confirmLabel = 'Got it',
  } = options;
  const introLabel = `AppleVis Tip. ${title}. ${message}`;

  function handleShow() {
    Animated.parallel([
      Animated.spring(scaleAnim, {
        toValue: 1, useNativeDriver: true,
        damping: 20, stiffness: 300,
      }),
      Animated.timing(opacityAnim, {
        toValue: 1, useNativeDriver: true, duration: 180,
      }),
    ]).start(() => {
      // Move VoiceOver focus to an element that identifies this as a tip before reading the content.
      setTimeout(() => {
        const handle = findNodeHandle(titleRef.current);
        if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
        else AccessibilityInfo.announceForAccessibility(introLabel);
      }, 100);
    });
  }

  return (
    <Modal
      visible
      transparent
      animationType="none"
      onShow={handleShow}
      onRequestClose={onDismiss}
    >
      {/* Backdrop */}
      <Pressable
        style={styles.backdrop}
        onPress={onDismiss}
        accessibilityElementsHidden
        importantForAccessibility="no-hide-descendants"
      />

      <View style={styles.container} pointerEvents="box-none">
        <Animated.View
          style={[
            styles.card,
            {
              backgroundColor: isDark ? colors.card : '#FFFFFF',
              transform: [{ scale: scaleAnim }],
              opacity: opacityAnim,
            },
          ]}
          accessibilityViewIsModal
        >
          {/* Header strip */}
          <View style={styles.header}>
            <View style={styles.iconBadge}>
              <Ionicons
                name={icon}
                size={20}
                color="#0A84FF"
                accessibilityElementsHidden
              />
            </View>
            <Text
              style={[styles.headerLabel, { color: '#0A84FF' }]}
              accessibilityLabel="AppleVis Tip"
            >
              AppleVis Tip
            </Text>
          </View>

          {/* Title */}
          <Text
            ref={titleRef}
            style={[styles.title, { color: colors.text }]}
            accessibilityRole="header"
            accessibilityLabel={introLabel}
          >
            {title}
          </Text>

          {/* Message */}
          <Text
            style={[styles.message, { color: colors.textSecondary }]}
            accessibilityElementsHidden
            importantForAccessibility="no-hide-descendants"
          >
            {message}
          </Text>

          {/* Got it button */}
          <Pressable
            onPress={onDismiss}
            accessible
            accessibilityRole="button"
            accessibilityLabel={confirmLabel}
            accessibilityHint="Dismisses this tip. It will not appear again."
            style={[styles.button, { backgroundColor: '#0A84FF' }]}
          >
            <Text style={styles.buttonText}>{confirmLabel}</Text>
          </Pressable>
        </Animated.View>
      </View>
    </Modal>
  );
}

// ─── Provider ─────────────────────────────────────────────────────────────────

type ActiveTip = { key: string; options: TipOptions };

export function ContextualTipProvider({ children }: { children: ReactNode }) {
  const [activeTip, setActiveTip] = useState<ActiveTip | null>(null);
  // Track keys already checked this session to avoid repeated AsyncStorage reads.
  const seenRef = useRef<Set<string>>(new Set());

  const showTip = useCallback((key: string, options: TipOptions) => {
    if (seenRef.current.has(key)) return;

    icloudStorage.getString(KEY_PREFIX + key, '').then((val) => {
      if (val === 'dismissed') {
        seenRef.current.add(key);
        return;
      }
      const presentTip = () => {
        seenRef.current.add(key);
        Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
        setActiveTip({ key, options });
      };
      if (!options.screenReaderOnly) {
        presentTip();
        return;
      }
      AccessibilityInfo.isScreenReaderEnabled()
        .then((enabled) => {
          if (enabled) presentTip();
        })
        .catch(() => {});
    }).catch(() => {});
  }, []);

  function handleDismiss() {
    if (activeTip) {
      icloudStorage.setString(KEY_PREFIX + activeTip.key, 'dismissed').catch(() => {});
    }
    setActiveTip(null);
  }

  return (
    <TipContext.Provider value={{ showTip }}>
      {children}
      {activeTip && (
        <TipModal options={activeTip.options} onDismiss={handleDismiss} />
      )}
    </TipContext.Provider>
  );
}

// ─── Tip keys ─────────────────────────────────────────────────────────────────

/** Stable keys used across the app — import where needed. */
export const TIP_KEYS = {
  forumRotorActions:        'forum_rotor_actions',
  playerMagicTap:           'player_magic_tap',
  episodeChapters:          'episode_chapters',
  savedSwipeActions:        'saved_swipe_actions',
  downloadsOffline:         'downloads_offline',
  reviewStarRating:         'review_star_rating',
  settingsIntelligence:     'settings_intelligence',
  followTopicNotifications: 'follow_topic_notifications',
  tabHome:                  'tab_home',
  tabDiscover:              'tab_discover',
  tabForYou:                'tab_for_you',
} as const;

// ─── Tip content library ──────────────────────────────────────────────────────

/** Ready-made tip content for every TIP_KEY entry. */
export const TIPS: Record<keyof typeof TIP_KEYS, TipOptions> = {
  forumRotorActions: {
    title: 'Community Comment Actions',
    icon: 'list-outline',
    screenReaderOnly: true,
    message:
      'In the Community Discussion section, each comment header has VoiceOver actions. ' +
      'Rotate two fingers to the Actions rotor, then flick up or down to choose options ' +
      'such as Reply to this Comment, Copy Comment Text, Share Comment, or Report Comment. ' +
      'This tip applies to the comment list, not the main topic text.',
  },
  playerMagicTap: {
    title: 'Quick Play and Pause',
    icon: 'play-circle-outline',
    message:
      'Two-finger double-tap anywhere on the screen plays or pauses the current episode. ' +
      'This works from any screen in the app while an episode is loaded — you do not ' +
      'need to open the player first. This is called a Magic Tap and is available ' +
      'throughout AppleVis.',
  },
  episodeChapters: {
    title: 'This Episode Has Chapters',
    icon: 'bookmark-outline',
    message:
      'This podcast includes chapter markers. In the Chapters section, activate any chapter ' +
      'to jump directly to that part of the episode. With VoiceOver, swipe through the chapter ' +
      'list and double-tap your chosen chapter.',
  },
  savedSwipeActions: {
    title: 'Quick Actions on Episodes',
    icon: 'hand-left-outline',
    message:
      'In saved or downloaded episode lists, swipe left on an episode to reveal quick action ' +
      'buttons for deleting, sharing, or marking as played. You can also long-press an episode ' +
      'to open the full action menu.',
  },
  downloadsOffline: {
    title: 'Listening Without Internet',
    icon: 'cloud-download-outline',
    message:
      'Downloaded episodes are stored on your device and play without an internet ' +
      'connection — perfect for flights, commutes, or areas with poor signal. ' +
      'Downloads stay on your device until you remove them.',
  },
  reviewStarRating: {
    title: 'Rating With VoiceOver',
    icon: 'star-outline',
    screenReaderOnly: true,
    message:
      'In the Write Comment form, the star rating control works like an adjustable slider. ' +
      'Flick up to increase the rating and flick down to decrease it. You can also use the ' +
      'VoiceOver rotor to choose Value, then flick up or down.',
  },
  settingsIntelligence: {
    title: 'Apple Intelligence in AppleVis',
    icon: 'hardware-chip-outline',
    message:
      'On supported iPhone and iPad models, AppleVis works with Apple Intelligence. ' +
      'You can ask Siri to open topics, check the podcast feed, or look up app ' +
      'information using natural language. Enable features in Settings → Siri & Intelligence.',
  },
  followTopicNotifications: {
    title: 'Managing Followed Topics',
    icon: 'notifications-outline',
    message:
      'You are now following this topic and will be notified of new replies. ' +
      'To see all your followed topics or turn off notifications for specific ones, ' +
      'go to your Profile → Followed Topics, or adjust notification settings in ' +
      'Settings → Notifications.',
  },
  tabHome: {
    title: 'Welcome to Your Home Feed',
    icon: 'home-outline',
    message:
      'This is the heart of AppleVis. Your Home feed brings together the latest forum ' +
      'discussions, podcast episodes, accessible app news, guides, and blog posts from ' +
      'the community.\n\nPull down at any time to refresh. Use the filter button at the ' +
      'top right to choose which types of content appear here.',
  },
  tabDiscover: {
    title: 'Explore All of AppleVis',
    icon: 'compass-outline',
    message:
      'The Discover tab is your browsing hub. Here you can explore the AppleVis forums, ' +
      'listen to the podcast, browse the App Directory for accessible apps, and read guides ' +
      'and blog posts.\n\nUse the search bar at the top to find specific topics, apps, or ' +
      'episodes by name.',
  },
  tabForYou: {
    title: 'Your Personalised Space',
    icon: 'heart-outline',
    message:
      'The For You tab is yours. Your episode queue lives here — episodes you have added to ' +
      'play next — along with your saved items.\n\nContent here updates as you read, save, ' +
      'and follow topics across the app.',
  },
};

// ─── Styles ───────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  backdrop: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.40)',
  },
  container: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 28,
  },
  card: {
    width: '100%',
    borderRadius: 22,
    paddingHorizontal: 22,
    paddingTop: 22,
    paddingBottom: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.16,
    shadowRadius: 24,
    elevation: 12,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 14,
  },
  iconBadge: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: '#EFF6FF',
    alignItems: 'center',
    justifyContent: 'center',
  },
  headerLabel: {
    fontSize: 13,
    fontWeight: '700',
    textTransform: 'uppercase',
    letterSpacing: 0.6,
  },
  title: {
    fontSize: 18,
    fontWeight: '700',
    marginBottom: 10,
    lineHeight: 24,
  },
  message: {
    fontSize: 15,
    lineHeight: 23,
    marginBottom: 22,
  },
  button: {
    borderRadius: 13,
    paddingVertical: 14,
    alignItems: 'center',
  },
  buttonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '700',
  },
});
