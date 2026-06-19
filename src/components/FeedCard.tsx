import { memo, useState, type Ref } from 'react';
import { AccessibilityInfo, ActionSheetIOS, Clipboard, Linking, Platform, Pressable, Share, Text, View } from 'react-native';
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
import { useDownloadedEpisodes } from '../hooks/useDownloadedEpisodes';
import { persistence } from '../services/persistence';
import { api } from '../services/api';
import { readAloud } from '../services/intelligenceService';
import { relativeTime } from '../utils/relativeTime';
import { WriteReviewModal } from './WriteReviewModal';
import type { FeedItem } from '../types/content';

// ─── Label / icon maps ────────────────────────────────────────────────────────

const KIND_LABELS: Record<FeedItem['kind'], string> = {
  topic:   'Forum',
  podcast: 'Podcast',
  app:     'App',
  guide:   'Guide',
  blog:    'Blog Post',
};

const SAVE_LABELS: Record<FeedItem['kind'], string> = {
  topic:   'Topic',
  podcast: 'Episode',
  app:     'App entry',
  guide:   'Guide',
  blog:    'Post',
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

function getMetaParts(item: FeedItem): string[] {
  switch (item.kind) {
    case 'topic': {
      const replyCount = item.data.replyCount;
      const replyLabel = replyCount === 1 ? '1 comment' : replyCount > 0 ? `${replyCount} comments` : 'No comments';
      return [
        item.data.authorName ? `By ${item.data.authorName}` : null,
        replyLabel,
        item.data.createdAt ? `Posted ${relativeTime(item.data.createdAt)}` : null,
        replyCount > 0 ? `Last comment ${relativeTime(item.data.lastActivityAt)}` : null,
      ].filter((x): x is string => !!x);
    }
    case 'podcast':
      return [
        item.data.showTitle,
        item.data.authorName ? `Submitted by ${item.data.authorName}` : null,
        item.data.publishedAt ? `Posted ${relativeTime(item.data.publishedAt)}` : null,
        item.data.lastActivityAt ? `Last comment ${relativeTime(item.data.lastActivityAt)}` : null,
      ].filter((x): x is string => !!x);
    case 'app':
      return [
        item.data.submittedBy ? `Submitted by ${item.data.submittedBy}` : null,
        item.data.reviewCount > 0 ? `${item.data.reviewCount} comment${item.data.reviewCount === 1 ? '' : 's'}` : null,
        item.data.createdAt ? `Posted ${relativeTime(item.data.createdAt)}` : null,
        item.data.reviewCount > 0 ? `Last comment ${relativeTime(item.data.lastUpdatedAt)}` : null,
      ].filter((x): x is string => !!x);
    case 'guide':
      return [
        item.data.createdAt ? `Posted ${relativeTime(item.data.createdAt)}` : null,
        item.data.commentCount > 0 ? `${item.data.commentCount} comment${item.data.commentCount === 1 ? '' : 's'}` : null,
        item.data.commentCount > 0 ? `Last comment ${relativeTime(item.activityAt)}` : null,
        item.data.commentCount === 0 ? `Updated ${relativeTime(item.data.updatedAt)}` : null,
      ].filter((x): x is string => !!x);
    case 'blog':
      return [
        item.data.authorName ? `By ${item.data.authorName}` : null,
        item.data.commentCount > 0 ? `${item.data.commentCount} comment${item.data.commentCount === 1 ? '' : 's'}` : null,
        item.data.publishedAt ? `Posted ${relativeTime(item.data.publishedAt)}` : null,
        item.data.commentCount > 0 && item.data.lastActivityAt ? `Last comment ${relativeTime(item.data.lastActivityAt)}` : null,
      ].filter((x): x is string => !!x);
  }
}

function getMeta(item: FeedItem):     string { return getMetaParts(item).join(' · '); }
function getA11yMeta(item: FeedItem): string { return getMetaParts(item).join('. '); }

// Normal level: author + comment/review count only (no dates)
function getA11yMetaNormal(item: FeedItem): string {
  switch (item.kind) {
    case 'topic': {
      const n = item.data.replyCount ?? 0;
      const countLabel = n === 1 ? '1 comment' : n > 0 ? `${n} comments` : 'No comments';
      return [item.data.authorName ? `By ${item.data.authorName}` : null, countLabel]
        .filter((x): x is string => !!x).join('. ');
    }
    case 'podcast':
      return item.data.showTitle ?? '';
    case 'app': {
      const n = item.data.reviewCount ?? 0;
      return n > 0 ? `${n} comment${n === 1 ? '' : 's'}` : '';
    }
    case 'guide': {
      const n = item.data.commentCount ?? 0;
      return n > 0 ? `${n} comment${n === 1 ? '' : 's'}` : '';
    }
    case 'blog': {
      const n = item.data.commentCount ?? 0;
      return [
        item.data.authorName ? `By ${item.data.authorName}` : null,
        n > 0 ? `${n} comment${n === 1 ? '' : 's'}` : null,
      ].filter((x): x is string => !!x).join('. ');
    }
  }
}

function getTypeLine(item: FeedItem): string {
  const kind = KIND_LABELS[item.kind];
  if (item.kind === 'topic' && item.data.category) return `${kind} · ${item.data.category}`;
  return kind;
}

function getA11yType(item: FeedItem): string {
  if (item.kind === 'topic' && item.data.category) return `Forum, ${item.data.category}`;
  return KIND_LABELS[item.kind];
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
    isSaved: boolean;
    showToast: (msg: string, type?: 'success' | 'warning' | 'error') => void;
    onPlay: () => void;
    onQueue: () => void;
    onPlayNext: () => void;
    onReply: () => void;
    onWriteReview: () => void;
    onSave: () => void;
    onAddEpisodeComment: () => void;
    onFollowTopic: () => void;
    onOpenTopicInBrowser: () => void;
  },
): Action[] {
  const { isSignedIn, voiceOverOn, isQueued, isSaved, showToast, onPlay, onQueue, onPlayNext, onReply, onWriteReview, onSave, onAddEpisodeComment, onFollowTopic, onOpenTopicInBrowser } = opts;
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
    label: item.kind === 'topic'   ? 'Share this Topic'
         : item.kind === 'app'     ? 'Share this App Entry'
         : item.kind === 'podcast' ? 'Share this Episode'
         : item.kind === 'blog'    ? 'Share this Post'
         : `Share this ${KIND_LABELS[item.kind]}`,
    name: 'share',
    onPress: () => Share.share({ title, message: getShareMessage(item) }),
  };

  switch (item.kind) {
    case 'topic': {
      const actions: Action[] = [];
      actions.push({ label: 'Add New Comment',                                             name: 'reply',    onPress: onReply });
      actions.push({ label: isSaved ? 'Remove from Saved' : 'Save this Topic',            name: 'save',     onPress: onSave });
      actions.push({ label: 'Follow this Topic',                                           name: 'follow',   onPress: onFollowTopic });
      if (readAloudAction) actions.push(readAloudAction);
      actions.push({ label: 'Open in Safari',  name: 'browser', onPress: onOpenTopicInBrowser });
      actions.push(shareAction);
      return actions;
    }

    case 'podcast': {
      const actions: Action[] = [];
      actions.push({ label: 'Play this Episode', name: 'play', onPress: onPlay });
      actions.push({
        label: isQueued ? 'Remove from Queue' : 'Queue this Episode',
        name: 'queue',
        onPress: onQueue,
      });
      actions.push({ label: 'Play Next',                                                    name: 'playNext', onPress: onPlayNext });
      actions.push({ label: 'Add New Comment',                                              name: 'comment',  onPress: onAddEpisodeComment });
      actions.push({ label: isSaved ? 'Remove from Saved' : 'Save this Episode',           name: 'save',     onPress: onSave });
      if (readAloudAction) actions.push(readAloudAction);
      actions.push(shareAction);
      return actions;
    }

    case 'app': {
      const actions: Action[] = [];
      actions.push({ label: 'Add New Comment',                                              name: 'review',   onPress: onWriteReview });
      actions.push({ label: isSaved ? 'Remove from Saved' : 'Save this App Entry',         name: 'save',     onPress: onSave });
      if (readAloudAction) actions.push(readAloudAction);
      if (item.data.appStoreUrl) {
        actions.push({
          label: 'Get in App Store',
          name: 'appStore',
          onPress: () => Linking.openURL(item.data.appStoreUrl).catch(() => showToast('Could not open App Store.', 'error')),
        });
      }
      actions.push(shareAction);
      return actions;
    }

    case 'guide': {
      const actions: Action[] = [];
      actions.push({ label: 'Add New Comment',                                              name: 'comment',  onPress: commentStub });
      actions.push({ label: isSaved ? 'Remove from Saved' : 'Save this Guide',             name: 'save',     onPress: onSave });
      if (readAloudAction) actions.push(readAloudAction);
      actions.push(shareAction);
      return actions;
    }

    case 'blog': {
      const actions: Action[] = [];
      actions.push({ label: 'Add New Comment',                                              name: 'comment',  onPress: commentStub });
      actions.push({ label: isSaved ? 'Remove from Saved' : 'Save this Post',              name: 'save',     onPress: onSave });
      if (readAloudAction) actions.push(readAloudAction);
      actions.push(shareAction);
      return actions;
    }
  }
}

// ─── Component ────────────────────────────────────────────────────────────────

type Props = {
  item: FeedItem;
  onPress: () => void;
  cardRef?: Ref<View>;
  newCount?: number;
  accentColor?: string;
  onFocus?: () => void;
};

export const FeedCard = memo(function FeedCard({ item, onPress, cardRef, newCount = 0, accentColor, onFocus }: Props) {
  const router               = useRouter();
  const { colors, styles }   = useTheme();
  const { announcementLevel } = usePreferences();
  const auth                 = useAuth();
  const player               = usePlayer();
  const { showToast }        = useToast();
  const a11y                 = useAccessibilityPreferences();
  const saved                = useSavedItems();
  const isEpisodeDownloaded  = useDownloadedEpisodes();
  const [reviewVisible, setReviewVisible] = useState(false);

  const title      = getTitle(item);
  const meta       = getMeta(item);
  const typeLine   = getTypeLine(item);
  const isNew      = item.kind === 'podcast' &&
    Date.now() - new Date(item.activityAt).getTime() < 7 * 24 * 60 * 60 * 1000;

  const isQueued     = item.kind === 'podcast' && player.queue.some(q => q.id === item.data.id);
  const isSavedItem  = saved.isSaved(item.data.id);
  const isDownloaded = item.kind === 'podcast' && isEpisodeDownloaded(item.data.id);

  function handlePlay() {
    if (item.kind !== 'podcast') return;
    player.loadEpisode(item.data);
    AccessibilityInfo.announceForAccessibility(`Now playing: ${item.data.title}`);
  }

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

  function handleSaveItem() {
    const id    = item.data.id;
    const title = getTitle(item);
    if (isSavedItem) {
      saved.unsave(id);
      if (item.kind === 'podcast') persistence.removeSavedEpisodeMeta(id).catch(() => {});
      showToast('Removed from saved.', 'success');
    } else {
      const kind = item.kind === 'topic'   ? 'forumTopic'   as const
                 : item.kind === 'podcast' ? 'podcastEpisode' as const
                 : item.kind === 'app'     ? 'appListing'   as const
                 : item.kind === 'guide'   ? 'resource'     as const
                 :                          'blogPost'      as const;
      saved.save({ id, kind, title, savedAt: new Date().toISOString() });
      if (item.kind === 'podcast') persistence.saveSavedEpisodeMeta(item.data).catch(() => {});
      showToast(`${SAVE_LABELS[item.kind]} saved.`, 'success');
    }
  }

  function handleAddEpisodeComment() {
    if (item.kind !== 'podcast') return;
    if (!auth.isSignedIn) {
      showToast('Sign in to add a new comment.', 'warning');
      return;
    }
    router.push({
      pathname: '/compose' as any,
      params: { episodeId: item.data.id, episodeTitle: item.data.title },
    });
  }

  async function handleFollowTopic() {
    if (!auth.isSignedIn) {
      showToast('Sign in to follow topics.', 'warning');
      return;
    }
    if (item.kind !== 'topic') return;
    const token = await api.account.getSessionToken();
    if (!token) { showToast('Session expired. Please sign in again.', 'error'); return; }
    const res = await api.forums.follow(item.data.id, token);
    if (res.ok) showToast('Now following this topic. You will receive notifications for new replies.', 'success');
    else showToast(`Could not follow: ${res.error}`, 'error');
  }

  function handleOpenTopicInBrowser() {
    if (item.kind !== 'topic') return;
    const url = item.data.url;
    if (url) Linking.openURL(url).catch(() => showToast('Could not open Safari.', 'error'));
    else showToast('URL not available yet.', 'warning');
  }

  const actions = buildActions(item, {
    isSignedIn: auth.isSignedIn,
    voiceOverOn: a11y.screenReaderEnabled,
    isQueued,
    isSaved: isSavedItem,
    showToast,
    onPlay: handlePlay,
    onQueue: handleQueue,
    onPlayNext: handlePlayNext,
    onReply: handleReply,
    onWriteReview: () => {
      if (!auth.isSignedIn) { showToast('Sign in to write a review.', 'warning'); return; }
      setReviewVisible(true);
    },
    onSave: handleSaveItem,
    onAddEpisodeComment: handleAddEpisodeComment,
    onFollowTopic: handleFollowTopic,
    onOpenTopicInBrowser: handleOpenTopicInBrowser,
  });

  const stateLabels: string[] = [];
  if (isSavedItem)   stateLabels.push('Saved');
  if (isQueued)      stateLabels.push('In queue');
  if (isDownloaded)  stateLabels.push('Downloaded');
  const states = stateLabels.length > 0 ? `. ${stateLabels.join('. ')}` : '';

  const a11yType = getA11yType(item);
  const newLabel = newCount > 0 ? `. ${newCount} new comment${newCount === 1 ? '' : 's'}.` : '';
  const metaStr  = announcementLevel === 'normal' ? getA11yMetaNormal(item) : getA11yMeta(item);
  const metaPart = metaStr ? `. ${metaStr}` : '';
  const label = announcementLevel === 'simple'
    ? `${title}. ${a11yType}${newLabel}${states}`
    : `${title}. ${a11yType}${metaPart}${newLabel}${states}`;

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
      ref={cardRef}
      onPress={onPress}
      onFocus={onFocus}
      onLongPress={handleLongPress}
      delayLongPress={400}
      accessible
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityHint={announcementLevel === 'simple' ? undefined : 'Double tap to open. Hold for options.'}
      accessibilityActions={actions.map(a => ({ name: a.label }))}
      onAccessibilityAction={({ nativeEvent }) => {
        const action = actions.find(a => a.label === nativeEvent.actionName);
        action?.onPress();
      }}
      style={({ pressed }) => [
        styles.card,
        { marginBottom: 10, opacity: pressed ? 0.75 : 1 },
        accentColor ? { borderLeftWidth: 3, borderLeftColor: accentColor } : undefined,
      ]}
    >
      {/* Row 1: Title + state icons */}
      <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 8, marginBottom: 4 }}>
        <Text
          style={{ flex: 1, fontSize: 16, fontWeight: '600', color: colors.text, lineHeight: 22 }}
          numberOfLines={2}
          accessibilityElementsHidden
        >
          {title}
        </Text>
        <View style={{ flexDirection: 'row', gap: 5, alignItems: 'center', paddingTop: 3 }}>
          {newCount > 0 && (
            <View
              style={{ paddingHorizontal: 5, paddingVertical: 2, backgroundColor: colors.accent, borderRadius: 4 }}
              accessibilityElementsHidden
            >
              <Text style={{ fontSize: 10, fontWeight: '800', color: '#FFF', letterSpacing: 0.3 }}
                accessibilityElementsHidden>
                {newCount} NEW
              </Text>
            </View>
          )}
          {isNew && (
            <View
              style={{ paddingHorizontal: 5, paddingVertical: 2, backgroundColor: '#34C759', borderRadius: 4 }}
              accessibilityElementsHidden
            >
              <Text style={{ fontSize: 10, fontWeight: '800', color: '#FFF', letterSpacing: 0.3 }}
                accessibilityElementsHidden>
                NEW
              </Text>
            </View>
          )}
          {isSavedItem  && <Ionicons name="bookmark"          size={15} color={colors.accent} accessibilityElementsHidden />}
          {isQueued     && <Ionicons name="list"               size={15} color={colors.accent} accessibilityElementsHidden />}
          {isDownloaded && <Ionicons name="arrow-down-circle"  size={15} color={colors.accent} accessibilityElementsHidden />}
        </View>
      </View>

      {/* Row 2: Type [· Category] */}
      <Text
        style={{ fontSize: 11, fontWeight: '700', color: colors.accent,
          textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 4 }}
        accessibilityElementsHidden
      >
        {typeLine}
      </Text>

      {/* Row 3: Meta */}
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
