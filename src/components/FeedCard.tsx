import { memo, useState } from 'react';
import { ActionSheetIOS, Clipboard, Linking, Platform, Pressable, Share, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { useRouter } from 'expo-router';
import { useTheme } from '../contexts/ThemeContext';
import { usePreferences } from '../contexts/PreferencesContext';
import { useAuth } from '../contexts/AuthContext';
import { usePlayer } from '../contexts/PlayerContext';
import { useToast } from '../contexts/ToastContext';
import { useAccessibilityPreferences } from '../hooks/useAccessibilityPreferences';
import { useSavedItems } from '../hooks/useSavedItems';
import { readAloud } from '../services/intelligenceService';
import { relativeTime } from '../utils/relativeTime';
import { WriteReviewModal } from './WriteReviewModal';
import type { FeedItem } from '../types/content';

// ─── Label / icon maps ────────────────────────────────────────────────────────

const KIND_LABELS: Record<FeedItem['kind'], string> = {
  topic:   'Topic',
  podcast: 'Podcast',
  app:     'App',
  guide:   'Guide',
  blog:    'Blog',
};

const KIND_ICONS: Record<FeedItem['kind'], string> = {
  topic:   'chatbubbles-outline',
  podcast: 'radio-outline',
  app:     'apps-outline',
  guide:   'library-outline',
  blog:    'newspaper-outline',
};

// ─── Content helpers ──────────────────────────────────────────────────────────

function getTitle(item: FeedItem): string {
  if (item.kind === 'app') return item.data.name;
  return item.data.title;
}

function getShareMessage(item: FeedItem): string {
  switch (item.kind) {
    case 'topic':   return `${item.data.title} — ${item.data.url ?? 'https://www.applevis.com/forums'}`;
    case 'podcast': return `${item.data.title} from ${item.data.showTitle} — ${item.data.url ?? 'https://www.applevis.com/podcast'}`;
    case 'app':     return item.data.appStoreUrl
      ? `${item.data.name} — ${item.data.appStoreUrl}`
      : `${item.data.name} on AppleVis`;
    case 'guide':   return `${item.data.title} — ${item.data.url}`;
    case 'blog':    return `${item.data.title} — ${item.data.url}`;
  }
}

function getMeta(item: FeedItem): string {
  const when = relativeTime(item.activityAt);
  switch (item.kind) {
    case 'topic':
      return [
        item.data.replyCount > 0 ? `${item.data.replyCount} repl${item.data.replyCount === 1 ? 'y' : 'ies'}` : 'No replies',
        item.data.authorName || null,
        when,
      ].filter(Boolean).join(' · ');
    case 'podcast':
      return [item.data.showTitle, when].filter(Boolean).join(' · ');
    case 'app':
      return [
        item.data.developer || null,
        item.data.reviewCount > 0 ? `${item.data.reviewCount} reviews` : null,
        when,
      ].filter(Boolean).join(' · ');
    case 'guide':
      return when;
    case 'blog':
      return [
        item.data.authorName || null,
        item.data.commentCount > 0 ? `${item.data.commentCount} comments` : null,
        when,
      ].filter(Boolean).join(' · ');
  }
}

// ─── Action builder ───────────────────────────────────────────────────────────

type Action = {
  label: string;
  name: string;
  onPress: () => void;
};

function buildActions(
  item: FeedItem,
  opts: {
    isSignedIn: boolean;
    voiceOverOn: boolean;
    isQueued: boolean;
    isSavedTopic: boolean;
    showToast: (msg: string, type?: 'success' | 'warning' | 'error') => void;
    onQueue: () => void;
    onPlayNext: () => void;
    onReply: () => void;
    onWriteReview: () => void;
    onSaveTopic: () => void;
    onFollowTopic: () => void;
    onOpenTopicInBrowser: () => void;
  },
): Action[] {
  const { isSignedIn, voiceOverOn, isQueued, isSavedTopic, showToast, onQueue, onPlayNext, onReply, onWriteReview, onSaveTopic, onFollowTopic, onOpenTopicInBrowser } = opts;
  const title = getTitle(item);
  const stub  = () => showToast('Coming soon.', 'warning');
  const commentStub = () => {
    if (!isSignedIn) { showToast('Sign in to add a new comment.', 'warning'); return; }
    showToast('Open the item to add a new comment.', 'warning');
  };

  function copyLink(url: string | undefined) {
    if (url) {
      Clipboard.setString(url);
      showToast('Link copied.', 'success');
    } else {
      showToast('Link not available yet.', 'warning');
    }
  }

  // Read Aloud — hidden when VoiceOver is active (VoiceOver already reads everything)
  const readAloudAction: Action | null = !voiceOverOn
    ? { label: 'Read Aloud', name: 'readAloud', onPress: () => readAloud(`${title}. ${getMeta(item)}`) }
    : null;

  const shareAction: Action = {
    label: item.kind === 'app'     ? 'Share this App Entry'
         : item.kind === 'podcast' ? 'Share this Episode'
         : item.kind === 'blog'    ? 'Share this Post'
         : `Share this ${KIND_LABELS[item.kind]}`,
    name: 'share',
    onPress: () => Share.share({ title, message: getShareMessage(item) }),
  };

  switch (item.kind) {
    case 'topic': {
      const actions: Action[] = [];
      actions.push({ label: 'Add New Comment',                                              name: 'reply',    onPress: onReply });
      actions.push({ label: isSavedTopic ? 'Remove from Saved' : 'Save this Topic',         name: 'save',     onPress: onSaveTopic });
      actions.push({ label: 'Follow this Topic',                                            name: 'follow',   onPress: onFollowTopic });
      if (readAloudAction) actions.push(readAloudAction);
      actions.push({ label: 'Open in Safari',           name: 'browser',  onPress: onOpenTopicInBrowser });
      actions.push({ label: 'Copy Link to this Topic', name: 'copyLink', onPress: () => copyLink(item.data.url) });
      actions.push(shareAction);
      return actions;
    }

    case 'podcast': {
      const actions: Action[] = [];
      actions.push({
        label: isQueued ? 'Remove from Queue' : 'Queue this Episode',
        name: 'queue',
        onPress: onQueue,
      });
      actions.push({ label: 'Play Next',                  name: 'playNext', onPress: onPlayNext });
      actions.push({ label: 'Add New Comment',              name: 'comment',  onPress: commentStub });
      actions.push({ label: 'Save this Episode',          name: 'save',     onPress: stub });
      if (readAloudAction) actions.push(readAloudAction);
      actions.push({ label: 'Copy Link to this Episode', name: 'copyLink', onPress: () => copyLink(item.data.url) });
      actions.push(shareAction);
      return actions;
    }

    case 'app': {
      const actions: Action[] = [];
      actions.push({ label: 'Add New Comment',      name: 'review', onPress: onWriteReview });
      actions.push({ label: 'Save this App Entry', name: 'save',   onPress: stub });
      if (readAloudAction) actions.push(readAloudAction);
      if (item.data.appStoreUrl) {
        actions.push({
          label: 'Get in App Store',
          name: 'appStore',
          onPress: () => Linking.openURL(item.data.appStoreUrl).catch(() => showToast('Could not open App Store.', 'error')),
        });
      }
      actions.push({ label: 'Copy Link to this App', name: 'copyLink', onPress: () => copyLink(item.data.appStoreUrl || undefined) });
      actions.push(shareAction);
      return actions;
    }

    case 'guide': {
      const actions: Action[] = [];
      actions.push({ label: 'Add New Comment',        name: 'comment',  onPress: commentStub });
      actions.push({ label: 'Save this Guide',        name: 'save',     onPress: stub });
      if (readAloudAction) actions.push(readAloudAction);
      actions.push({ label: 'Copy Link to this Guide', name: 'copyLink', onPress: () => copyLink(item.data.url) });
      actions.push(shareAction);
      return actions;
    }

    case 'blog': {
      const actions: Action[] = [];
      actions.push({ label: 'Add New Comment',       name: 'comment',  onPress: commentStub });
      actions.push({ label: 'Save this Post',        name: 'save',     onPress: stub });
      if (readAloudAction) actions.push(readAloudAction);
      actions.push({ label: 'Copy Link to this Post', name: 'copyLink', onPress: () => copyLink(item.data.url) });
      actions.push(shareAction);
      return actions;
    }
  }
}

// ─── Component ────────────────────────────────────────────────────────────────

type Props = {
  item: FeedItem;
  onPress: () => void;
};

export const FeedCard = memo(function FeedCard({ item, onPress }: Props) {
  const router               = useRouter();
  const { colors, styles }   = useTheme();
  const { announcementLevel } = usePreferences();
  const auth                 = useAuth();
  const player               = usePlayer();
  const { showToast }        = useToast();
  const a11y                 = useAccessibilityPreferences();
  const savedTopics          = useSavedItems('forumTopic');
  const [reviewVisible, setReviewVisible] = useState(false);

  const title = getTitle(item);
  const meta  = getMeta(item);
  const badge = KIND_LABELS[item.kind];
  const icon  = KIND_ICONS[item.kind] as any;
  const isNew = item.kind === 'podcast' &&
    Date.now() - new Date(item.activityAt).getTime() < 7 * 24 * 60 * 60 * 1000;

  const isQueued     = item.kind === 'podcast' && player.queue.some(q => q.id === item.data.id);
  const isSavedTopic = item.kind === 'topic'   && savedTopics.isSaved(item.data.id);

  function handleQueue() {
    if (item.kind !== 'podcast') return;
    if (isQueued) {
      player.removeFromQueue(item.data.id);
      showToast('Removed from queue.', 'success');
    } else {
      player.enqueue(item.data);
      showToast('Added to queue.', 'success');
    }
  }

  function handlePlayNext() {
    if (item.kind !== 'podcast') return;
    player.playNext(item.data);
    showToast('Will play next.', 'success');
  }

  function handleReply() {
    if (item.kind !== 'topic') return;
    if (!auth.isSignedIn) { showToast('Sign in to add a new comment.', 'warning'); return; }
    router.push({
      pathname: '/compose' as any,
      params: { topicId: item.data.id, topicTitle: item.data.title },
    });
  }

  function handleSaveTopic() {
    if (item.kind !== 'topic') return;
    if (isSavedTopic) {
      savedTopics.unsave(item.data.id);
      showToast('Removed from saved.', 'success');
    } else {
      savedTopics.save({ id: item.data.id, kind: 'forumTopic', title: item.data.title, savedAt: new Date().toISOString() });
      showToast('Topic saved.', 'success');
    }
  }

  function handleFollowTopic() {
    if (!auth.isSignedIn) {
      showToast('Sign in to follow topics.', 'warning');
      return;
    }
    showToast('Topic follow notifications — coming once the Drupal Flags API endpoint is confirmed.', 'warning');
  }

  function handleOpenTopicInBrowser() {
    if (item.kind !== 'topic') return;
    const url = item.data.url;
    if (url) Linking.openURL(url).catch(() => showToast('Could not open browser.', 'error'));
    else showToast('URL not available yet.', 'warning');
  }

  const actions = buildActions(item, {
    isSignedIn: auth.isSignedIn,
    voiceOverOn: a11y.screenReaderEnabled,
    isQueued,
    isSavedTopic,
    showToast,
    onQueue: handleQueue,
    onPlayNext: handlePlayNext,
    onReply: handleReply,
    onWriteReview: () => {
      if (!auth.isSignedIn) { showToast('Sign in to write a review.', 'warning'); return; }
      setReviewVisible(true);
    },
    onSaveTopic: handleSaveTopic,
    onFollowTopic: handleFollowTopic,
    onOpenTopicInBrowser: handleOpenTopicInBrowser,
  });

  const label = announcementLevel === 'simple'
    ? `${badge}. ${title}`
    : `${badge}. ${title}. ${meta}`;

  function handleLongPress() {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    if (Platform.OS === 'ios') {
      ActionSheetIOS.showActionSheetWithOptions(
        {
          title,
          options: ['Cancel', ...actions.map(a => a.label)],
          cancelButtonIndex: 0,
        },
        (index) => {
          if (index > 0) actions[index - 1].onPress();
        },
      );
    } else {
      // Android: fall through to accessibility action handler or show first action
      actions[0]?.onPress();
    }
  }

  return (
    <>
    {item.kind === 'app' && (
      <WriteReviewModal
        visible={reviewVisible}
        appId={item.data.id}
        appName={item.data.name}
        onClose={() => setReviewVisible(false)}
        onSubmitted={() => { setReviewVisible(false); showToast('Review submitted! It will appear after moderation.', 'success'); }}
      />
    )}
    <Pressable
      onPress={onPress}
      onLongPress={handleLongPress}
      delayLongPress={400}
      accessible
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityHint={announcementLevel === 'simple' ? undefined : 'Double tap to open. Hold for options.'}
      accessibilityActions={actions.map(a => ({ name: a.name, label: a.label }))}
      onAccessibilityAction={({ nativeEvent }) => {
        const action = actions.find(a => a.name === nativeEvent.actionName);
        action?.onPress();
      }}
      style={({ pressed }) => [
        styles.card,
        { marginBottom: 10, opacity: pressed ? 0.75 : 1 },
      ]}
    >
      {/* Badge row */}
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, marginBottom: 8 }}>
        <Ionicons name={icon} size={13} color={colors.accent} accessibilityElementsHidden />
        <Text
          style={{
            fontSize: 11,
            fontWeight: '700',
            color: colors.accent,
            textTransform: 'uppercase',
            letterSpacing: 0.6,
          }}
          accessibilityElementsHidden
        >
          {badge}
        </Text>
        {isNew && (
          <View
            style={{
              paddingHorizontal: 5, paddingVertical: 2,
              backgroundColor: '#34C759', borderRadius: 4,
            }}
            accessibilityElementsHidden
          >
            <Text style={{ fontSize: 10, fontWeight: '800', color: '#FFF', letterSpacing: 0.3 }}>
              NEW
            </Text>
          </View>
        )}
      </View>

      {/* Title */}
      <Text
        style={{ fontSize: 16, fontWeight: '600', color: colors.text, marginBottom: 5, lineHeight: 22 }}
        numberOfLines={2}
        accessibilityElementsHidden
      >
        {title}
      </Text>

      {/* Meta */}
      <Text
        style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 18 }}
        numberOfLines={1}
        accessibilityElementsHidden
      >
        {meta}
      </Text>
    </Pressable>
    </>
  );
});
