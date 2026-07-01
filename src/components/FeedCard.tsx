import { memo, useMemo, useState, useEffect, type Ref } from 'react';
import { AccessibilityInfo, ActionSheetIOS, Clipboard, Linking, Platform, Pressable, Share, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { useRouter } from 'expo-router';
import { useTheme } from '../contexts/ThemeContext';
import { usePreferences } from '../contexts/PreferencesContext';
import { useAuth } from '../contexts/AuthContext';
import { useAlert } from '../contexts/AccessibleAlertContext';
import { usePlayer } from '../contexts/PlayerContext';
import { useToast } from '../contexts/ToastContext';
import { useAccessibilityPreferences } from '../hooks/useAccessibilityPreferences';
import { useDynamicType } from '../hooks/useDynamicType';
import { useSavedItems } from '../hooks/useSavedItems';
import { useFollowedItem } from '../hooks/useFollowedItem';
import { persistence } from '../services/persistence';
import { downloadEpisode, deleteDownload } from '../services/downloads';
import { api } from '../services/api';
import { readAloud } from '../services/intelligenceService';
import { sounds } from '../services/sounds';
import { relativeTime } from '../utils/relativeTime';
import { WriteReviewModal } from './WriteReviewModal';
import type { FeedItem, FollowedItem } from '../types/content';

// ─── Helpers ─────────────────────────────────────────────────────────────────

// Compact format for visual display: "4 min", "1h 23m"
function formatDuration(seconds: number): string {
  if (!seconds || seconds <= 0) return '';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return h > 0 ? `${h}h ${m}m` : `${m} min`;
}

// Natural-language format for VoiceOver: "4 minutes and 23 seconds", "1 hour and 23 minutes"
function formatDurationA11y(seconds: number): string {
  if (!seconds || seconds <= 0) return '';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  if (h > 0) {
    const mPart = m > 0 ? ` and ${m} minute${m !== 1 ? 's' : ''}` : '';
    return `${h} hour${h !== 1 ? 's' : ''}${mPart}`;
  }
  if (m > 0 && s > 0) return `${m} minute${m !== 1 ? 's' : ''} and ${s} second${s !== 1 ? 's' : ''}`;
  if (m > 0) return `${m} minute${m !== 1 ? 's' : ''}`;
  return `${s} second${s !== 1 ? 's' : ''}`;
}

// Visual playback position: "4 of 45 minutes played"
function formatPlayedPosition(position: number, duration: number): string {
  const playedMinutes = Math.floor(position / 60);
  const totalMinutes  = Math.floor(duration / 60);
  return `${playedMinutes} of ${totalMinutes} minutes played`;
}

// VoiceOver playback position: "4 minutes and 23 seconds played"
function formatPositionA11y(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  if (m > 0 && s > 0) return `${m} minute${m !== 1 ? 's' : ''} and ${s} second${s !== 1 ? 's' : ''} played`;
  if (m > 0) return `${m} minute${m !== 1 ? 's' : ''} played`;
  return `${s} second${s !== 1 ? 's' : ''} played`;
}

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
  blog:    'Blog',
};

const FOLLOW_LABELS: Record<FeedItem['kind'], string> = {
  topic:   'Topic',
  podcast: 'Episode',
  app:     'App',
  guide:   'Guide',
  blog:    'Blog',
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

// Visual meta parts — used for the compact on-screen meta row and Read Aloud.
// Category is intentionally omitted for App and Guide since the type-line already shows it.
function getMetaParts(item: FeedItem): string[] {
  switch (item.kind) {
    case 'topic': {
      const n = item.data.replyCount;
      return [
        item.data.authorName ? `By ${item.data.authorName}` : null,
        n === 1 ? '1 comment' : n > 0 ? `${n} comments` : 'No comments',
        item.data.createdAt ? `Posted ${relativeTime(item.data.createdAt)}` : null,
        n > 0 ? `Last comment ${relativeTime(item.data.lastActivityAt)}` : null,
      ].filter((x): x is string => !!x);
    }
    case 'podcast': {
      const dur = formatDuration(item.data.duration);
      const n   = item.data.commentCount ?? 0;
      return [
        item.data.showTitle,
        dur || null,
        n === 1 ? '1 comment' : n > 0 ? `${n} comments` : 'No comments',
        item.data.publishedAt ? `Posted ${relativeTime(item.data.publishedAt)}` : null,
        n > 0 && item.data.lastActivityAt ? `Last comment ${relativeTime(item.data.lastActivityAt)}` : null,
      ].filter((x): x is string => !!x);
    }
    case 'app': {
      const n = item.data.reviewCount;
      return [
        // Category omitted here — already in the type-line ("APP · CATEGORY")
        item.data.price || null,
        item.data.usabilityNotes ? `Usability: ${item.data.usabilityNotes}` : null,
        item.data.submittedBy ? `By ${item.data.submittedBy}` : null,
        n === 1 ? '1 comment' : n > 0 ? `${n} comments` : 'No comments',
        item.data.createdAt ? `Posted ${relativeTime(item.data.createdAt)}` : null,
        n > 0 ? `Last comment ${relativeTime(item.data.lastActivityAt ?? item.data.lastUpdatedAt)}` : null,
      ].filter((x): x is string => !!x);
    }
    case 'guide': {
      const n = item.data.commentCount;
      return [
        // Category omitted here — already in the type-line ("GUIDE · CATEGORY")
        item.data.authorName ? `By ${item.data.authorName}` : null,
        n === 1 ? '1 comment' : n > 0 ? `${n} comments` : 'No comments',
        item.data.createdAt ? `Posted ${relativeTime(item.data.createdAt)}` : null,
        n > 0 ? `Last comment ${relativeTime(item.activityAt)}` : null,
        n === 0 ? `Updated ${relativeTime(item.data.updatedAt)}` : null,
      ].filter((x): x is string => !!x);
    }
    case 'blog': {
      const n = item.data.commentCount;
      return [
        item.data.authorName ? `By ${item.data.authorName}` : null,
        n === 1 ? '1 comment' : n > 0 ? `${n} comments` : 'No comments',
        item.data.publishedAt ? `Posted ${relativeTime(item.data.publishedAt)}` : null,
        n > 0 && item.data.lastActivityAt ? `Last comment ${relativeTime(item.data.lastActivityAt)}` : null,
      ].filter((x): x is string => !!x);
    }
  }
}

function getMeta(item: FeedItem): string { return getMetaParts(item).join(' · '); }

// ─── VoiceOver meta builder ───────────────────────────────────────────────────
// Single function for all three verbosity levels. Returns the spoken meta string.
// Order: comment count (most actionable) → dates → author (at 'all' for app/podcast)
// Duration is first for podcast at every level so you know the length before deciding to play.
function buildA11yMeta(
  item: FeedItem,
  level: 'simple' | 'normal' | 'all',
  episodeDuration: number,
): string {
  switch (item.kind) {
    case 'topic': {
      if (level === 'simple') return '';
      const n = item.data.replyCount ?? 0;
      const countLabel = n === 1 ? '1 comment' : n > 0 ? `${n} comments` : 'No comments';
      return [
        item.data.authorName ? `By ${item.data.authorName}` : null,
        countLabel,
        // dates only at 'all' — normal stops at author + count
        level === 'all' && item.data.createdAt ? `Posted ${relativeTime(item.data.createdAt)}` : null,
        level === 'all' && n > 0 ? `Last comment ${relativeTime(item.data.lastActivityAt)}` : null,
      ].filter((x): x is string => !!x).join('. ');
    }

    case 'podcast': {
      // Duration present at every level so you know the length before deciding to play.
      const dur = formatDurationA11y(episodeDuration);
      const n   = item.data.commentCount ?? 0;
      const countLabel = n === 1 ? '1 comment' : n > 0 ? `${n} comments` : 'No comments';
      if (level === 'simple') return dur;
      return [
        dur || null,
        countLabel,
        // dates and submitter only at 'all' — normal stops at duration + count
        level === 'all' && item.data.publishedAt ? `Posted ${relativeTime(item.data.publishedAt)}` : null,
        level === 'all' && n > 0 && item.data.lastActivityAt ? `Last comment ${relativeTime(item.data.lastActivityAt)}` : null,
        level === 'all' && item.data.authorName ? `Submitted by ${item.data.authorName}` : null,
      ].filter((x): x is string => !!x).join('. ');
    }

    case 'app': {
      if (level === 'simple') return '';
      const n = item.data.reviewCount ?? 0;
      const countLabel = n === 1 ? '1 comment' : n > 0 ? `${n} comments` : 'No comments';
      return [
        countLabel,
        item.data.price || null,
        item.data.usabilityNotes ? `Usability: ${item.data.usabilityNotes}` : null,
        // dates and submitter only at 'all' — normal stops at count + price + usability
        level === 'all' && item.data.createdAt ? `Posted ${relativeTime(item.data.createdAt)}` : null,
        level === 'all' && n > 0 ? `Last comment ${relativeTime(item.data.lastActivityAt ?? item.data.lastUpdatedAt)}` : null,
        level === 'all' && item.data.submittedBy ? `Submitted by ${item.data.submittedBy}` : null,
      ].filter((x): x is string => !!x).join('. ');
    }

    case 'guide': {
      if (level === 'simple') return '';
      const n = item.data.commentCount ?? 0;
      const countLabel = n === 1 ? '1 comment' : n > 0 ? `${n} comments` : 'No comments';
      return [
        item.data.authorName ? `By ${item.data.authorName}` : null,
        countLabel,
        // dates only at 'all' — normal stops at author + count
        level === 'all' && item.data.createdAt ? `Posted ${relativeTime(item.data.createdAt)}` : null,
        level === 'all' && n > 0 ? `Last comment ${relativeTime(item.activityAt)}` : null,
        level === 'all' && n === 0 ? `Updated ${relativeTime(item.data.updatedAt)}` : null,
      ].filter((x): x is string => !!x).join('. ');
    }

    case 'blog': {
      if (level === 'simple') return '';
      const n = item.data.commentCount ?? 0;
      const countLabel = n === 1 ? '1 comment' : n > 0 ? `${n} comments` : 'No comments';
      return [
        item.data.authorName ? `By ${item.data.authorName}` : null,
        countLabel,
        // dates only at 'all' — normal stops at author + count
        level === 'all' && item.data.publishedAt ? `Posted ${relativeTime(item.data.publishedAt)}` : null,
        level === 'all' && n > 0 && item.data.lastActivityAt ? `Last comment ${relativeTime(item.data.lastActivityAt)}` : null,
      ].filter((x): x is string => !!x).join('. ');
    }
  }
}

function getTypeLine(item: FeedItem): string {
  const kind = KIND_LABELS[item.kind];
  if (item.kind === 'topic' && item.data.category) return `${kind} · ${item.data.category}`;
  if (item.kind === 'app'   && item.data.category) return `${kind} · ${item.data.category}`;
  if (item.kind === 'guide' && item.data.categories?.[0]?.name) return `${kind} · ${item.data.categories[0].name}`;
  return kind;
}

function getA11yType(item: FeedItem): string {
  if (item.kind === 'topic' && item.data.category) return `Forum, ${item.data.category}`;
  if (item.kind === 'app' && item.data.category) return `App, ${item.data.category}`;
  if (item.kind === 'guide' && item.data.categories?.[0]?.name) return `Guide, ${item.data.categories[0].name}`;
  return KIND_LABELS[item.kind];
}

function getFollowNodeType(item: FeedItem): string {
  switch (item.kind) {
    case 'topic':   return 'node--forum';
    case 'podcast': return 'node--podcast';
    case 'app':     return 'node--ios_app_directory';
    case 'guide':   return 'node--guides';
    case 'blog':    return 'node--blog2';
  }
}

// JSON:API node type suffix used for DELETE / PATCH status requests.
function getNodeType(item: FeedItem): string {
  switch (item.kind) {
    case 'topic':   return 'forum';
    case 'podcast': return 'podcast';
    case 'app':     return 'ios_app_directory';
    case 'guide':   return 'guides';
    case 'blog':    return 'blog2';
  }
}

// Human-readable content type label for admin action sheets.
function getContentLabel(item: FeedItem): string {
  switch (item.kind) {
    case 'topic':   return 'Topic';
    case 'podcast': return 'Episode';
    case 'app':     return 'App Entry';
    case 'guide':   return 'Guide';
    case 'blog':    return 'Blog Post';
  }
}

function getFollowKind(item: FeedItem): FollowedItem['kind'] {
  switch (item.kind) {
    case 'topic':   return 'forumTopic';
    case 'podcast': return 'podcastEpisode';
    case 'app':     return 'appListing';
    case 'guide':   return 'resource';
    case 'blog':    return 'blogPost';
  }
}

function getFollowUrl(item: FeedItem): string | undefined {
  switch (item.kind) {
    case 'topic':   return item.data.url;
    case 'podcast': return item.data.url;
    case 'app':     return item.data.url;
    case 'guide':   return item.data.url;
    case 'blog':    return item.data.url;
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
    isCurrentPodcastPlaying: boolean;
    isDownloaded: boolean;
    isDownloading: boolean;
    isSaved: boolean;
    isFollowing: boolean;
    isOwnTopic: boolean;
    isAdmin: boolean;
    showToast: (msg: string, type?: 'success' | 'warning' | 'error') => void;
    onPlay: () => void;
    onQueue: () => void;
    onPlayNext: () => void;
    onDownload: () => void;
    onReply: () => void;
    onWriteReview: () => void;
    onSave: () => void;
    onAddEpisodeComment: () => void;
    onToggleFollow: () => void;
    onOpenTopicInBrowser: () => void;
    onEditOwnTopic: () => void;
    onDeleteOwnTopic: () => void;
    onAdminEdit: () => void;
    onAdminDelete: () => void;
    onAdminUnpublish: () => void;
  },
): Action[] {
  const { isSignedIn, voiceOverOn, isQueued, isCurrentPodcastPlaying, isDownloaded, isDownloading, isSaved, isFollowing, isOwnTopic, isAdmin, showToast, onPlay, onQueue, onPlayNext, onDownload, onReply, onWriteReview, onSave, onAddEpisodeComment, onToggleFollow, onOpenTopicInBrowser, onEditOwnTopic, onDeleteOwnTopic, onAdminEdit, onAdminDelete, onAdminUnpublish } = opts;
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
         : item.kind === 'blog'    ? 'Share this Blog'
         : `Share this ${KIND_LABELS[item.kind]}`,
    name: 'share',
    onPress: () => Share.share({ title, message: getShareMessage(item) }),
  };

  switch (item.kind) {
    case 'topic': {
      const actions: Action[] = [];
      actions.push({ label: 'Add New Comment',                                             name: 'reply',     onPress: onReply });
      if (isOwnTopic) {
        actions.push({ label: 'Edit Topic',      name: 'editTopic',   onPress: onEditOwnTopic });
        actions.push({ label: 'Delete Topic',    name: 'deleteTopic', onPress: onDeleteOwnTopic });
      }
      if (isAdmin) {
        actions.push({ label: 'Unpublish Topic', name: 'unpublish',   onPress: onAdminUnpublish });
      }
      actions.push({ label: isSaved ? 'Remove from Saved' : 'Save this Topic',            name: 'save',      onPress: onSave });
      actions.push({ label: isFollowing ? 'Unfollow this Topic' : 'Follow this Topic',    name: 'follow',    onPress: onToggleFollow });
      if (readAloudAction) actions.push(readAloudAction);
      actions.push({ label: 'Open in Safari',    name: 'browser',     onPress: onOpenTopicInBrowser });
      actions.push(shareAction);
      return actions;
    }

    case 'podcast': {
      const actions: Action[] = [];
      actions.push({ label: isCurrentPodcastPlaying ? 'Stop this Episode' : 'Play this Episode', name: 'play', onPress: onPlay });
      actions.push({ label: isQueued ? 'Remove from Queue' : 'Queue this Episode',               name: 'queue',    onPress: onQueue });
      actions.push({
        label: isDownloading ? 'Downloading' : isDownloaded ? 'Delete Download' : 'Download this Episode',
        name: 'download',
        onPress: onDownload,
      });
      actions.push({ label: 'Play Next',                                                    name: 'playNext',  onPress: onPlayNext });
      actions.push({ label: 'Add New Comment',                                              name: 'comment',   onPress: onAddEpisodeComment });
      actions.push({ label: isSaved ? 'Remove from Saved' : 'Save this Episode',           name: 'save',      onPress: onSave });
      actions.push({ label: isFollowing ? 'Unfollow this Episode' : 'Follow this Episode', name: 'follow',    onPress: onToggleFollow });
      if (isAdmin) {
        actions.push({ label: 'Edit Episode',      name: 'editItem',   onPress: onAdminEdit });
        actions.push({ label: 'Unpublish Episode', name: 'unpublish',  onPress: onAdminUnpublish });
        actions.push({ label: 'Delete Episode',    name: 'deleteItem', onPress: onAdminDelete });
      }
      if (readAloudAction) actions.push(readAloudAction);
      actions.push(shareAction);
      return actions;
    }

    case 'app': {
      const actions: Action[] = [];
      actions.push({ label: 'Add New Comment',                                              name: 'review',    onPress: onWriteReview });
      actions.push({ label: isSaved ? 'Remove from Saved' : 'Save this App Entry',         name: 'save',      onPress: onSave });
      actions.push({ label: isFollowing ? 'Unfollow this App' : 'Follow this App',         name: 'follow',    onPress: onToggleFollow });
      if (readAloudAction) actions.push(readAloudAction);
      if (item.data.appStoreUrl) {
        actions.push({
          label: 'Get in App Store',
          name: 'appStore',
          onPress: () => Linking.openURL(item.data.appStoreUrl).catch(() => showToast('Could not open App Store.', 'error')),
        });
      }
      if (isAdmin) {
        actions.push({ label: 'Edit App Entry',      name: 'editItem',   onPress: onAdminEdit });
        actions.push({ label: 'Unpublish App Entry', name: 'unpublish',  onPress: onAdminUnpublish });
        actions.push({ label: 'Delete App Entry',    name: 'deleteItem', onPress: onAdminDelete });
      }
      actions.push(shareAction);
      return actions;
    }

    case 'guide': {
      const actions: Action[] = [];
      actions.push({ label: 'Add New Comment',                                              name: 'comment',   onPress: commentStub });
      actions.push({ label: isSaved ? 'Remove from Saved' : 'Save this Guide',             name: 'save',      onPress: onSave });
      actions.push({ label: isFollowing ? 'Unfollow this Guide' : 'Follow this Guide',     name: 'follow',    onPress: onToggleFollow });
      if (isAdmin) {
        actions.push({ label: 'Edit Guide',      name: 'editItem',   onPress: onAdminEdit });
        actions.push({ label: 'Unpublish Guide', name: 'unpublish',  onPress: onAdminUnpublish });
        actions.push({ label: 'Delete Guide',    name: 'deleteItem', onPress: onAdminDelete });
      }
      if (readAloudAction) actions.push(readAloudAction);
      actions.push(shareAction);
      return actions;
    }

    case 'blog': {
      const actions: Action[] = [];
      actions.push({ label: 'Add New Comment',                                              name: 'comment',   onPress: commentStub });
      actions.push({ label: isSaved ? 'Remove from Saved' : 'Save this Blog',              name: 'save',      onPress: onSave });
      actions.push({ label: isFollowing ? 'Unfollow this Blog' : 'Follow this Blog',       name: 'follow',    onPress: onToggleFollow });
      if (isAdmin) {
        actions.push({ label: 'Edit Blog Post',      name: 'editItem',   onPress: onAdminEdit });
        actions.push({ label: 'Unpublish Blog Post', name: 'unpublish',  onPress: onAdminUnpublish });
        actions.push({ label: 'Delete Blog Post',    name: 'deleteItem', onPress: onAdminDelete });
      }
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
  onMarkRead?: () => void;
  onItemDeleted?: () => void;
};

export const FeedCard = memo(function FeedCard({ item, onPress, cardRef, newCount = 0, accentColor, onFocus, onMarkRead, onItemDeleted }: Props) {
  const router               = useRouter();
  const { colors, styles }   = useTheme();
  const { announcementLevel } = usePreferences();
  const auth                 = useAuth();
  const player               = usePlayer();
  const { showToast }        = useToast();
  const { showAlert }        = useAlert();
  const a11y                 = useAccessibilityPreferences();
  const { isAccessibilitySize } = useDynamicType();
  const saved                = useSavedItems();
  const [reviewVisible, setReviewVisible] = useState(false);
  const [downloadedIds, setDownloadedIds] = useState<Set<string>>(new Set());
  const [downloading, setDownloading] = useState(false);

  const isAdmin    = !!auth.user?.isAdmin;
  const isOwnTopic = item.kind === 'topic' && (
    isAdmin || (!!auth.user?.uuid && !!item.data.authorId && auth.user.uuid === item.data.authorId)
  );

  const title      = getTitle(item);
  const meta       = getMeta(item);
  const typeLine   = getTypeLine(item);
  const isNew      = item.kind === 'podcast' &&
    Date.now() - new Date(item.activityAt).getTime() < 7 * 24 * 60 * 60 * 1000;

  const isQueued     = item.kind === 'podcast' && player.queue.some(q => q.id === item.data.id);
  const isCurrentPodcast = item.kind === 'podcast' && player.episode?.id === item.data.id;
  const isCurrentPodcastPlaying = isCurrentPodcast && player.isPlaying;
  const playerProgress = isCurrentPodcast && player.duration > 0 ? player.position / player.duration : 0;

  const [savedPos, setSavedPos] = useState(0);
  useEffect(() => {
    if (item.kind !== 'podcast') return;
    persistence.getPodcastPositions().then(pos => {
      setSavedPos(pos[item.data.id] ?? 0);
    }).catch(() => {});
  }, [item]);

  useEffect(() => {
    if (item.kind !== 'podcast') return;
    persistence.getDownloadedEpisodes().then(map => {
      setDownloadedIds(new Set(Object.keys(map)));
    }).catch(() => {});
  }, [item]);

  const episodeDuration = item.kind === 'podcast' ? (item.data.duration ?? 0) : 0;
  const savedProgress = !isCurrentPodcast && savedPos > 30 && episodeDuration > 0
    ? savedPos / episodeDuration
    : undefined;
  const isSavedItem  = saved.isSaved(item.data.id);
  const isDownloaded = item.kind === 'podcast' && downloadedIds.has(item.data.id);
  const followItem = useMemo<FollowedItem>(() => ({
    id: item.data.id,
    kind: getFollowKind(item),
    nodeType: getFollowNodeType(item),
    title,
    followedAt: new Date().toISOString(),
    lastActivityAt: item.activityAt,
    url: getFollowUrl(item),
  }), [item, title]);
  const followed = useFollowedItem(followItem);
  const isFollowingItem = followed.isFollowing || (item.kind === 'topic' && item.data.isFollowing);

  function handlePlay() {
    if (item.kind !== 'podcast') return;
    if (isCurrentPodcastPlaying) {
      player.pause();
      AccessibilityInfo.announceForAccessibility('Paused.');
      return;
    }
    if (isCurrentPodcast && !player.isPlaying) {
      player.play();
      AccessibilityInfo.announceForAccessibility(`Resuming: ${item.data.title}`);
      return;
    }
    sounds.podcastPlay().catch(() => {});
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

  async function handleDownload() {
    if (item.kind !== 'podcast') return;
    if (downloading) {
      showToast('Download already in progress.', 'warning');
      return;
    }

    if (isDownloaded) {
      await deleteDownload(item.data.id);
      setDownloadedIds(prev => { const next = new Set(prev); next.delete(item.data.id); return next; });
      showToast('Download removed.', 'success');
      return;
    }

    setDownloading(true);
    showToast('Downloading...', 'success');
    const result = await downloadEpisode(item.data.id, item.data.audioUrl, item.data);
    setDownloading(false);
    if (!result.ok) {
      showToast('Download failed.', 'error');
      return;
    }
    setDownloadedIds(prev => new Set(prev).add(item.data.id));
    sounds.downloadComplete().catch(() => {});
    showToast('Download complete.', 'success');
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
      sounds.bookmarkSaved().catch(() => {});
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

  async function handleToggleFollow() {
    if (!auth.isSignedIn) {
      showToast(`Sign in to follow this ${FOLLOW_LABELS[item.kind].toLowerCase()}.`, 'warning');
      return;
    }
    if (isFollowingItem) {
      await followed.unfollow();
      showToast(`Unfollowed ${FOLLOW_LABELS[item.kind].toLowerCase()}.`, 'success');
      return;
    }

    const result = await followed.follow();
    if (result === 'followed') showToast(`Following ${FOLLOW_LABELS[item.kind].toLowerCase()}.`, 'success');
    else showToast('Following saved. Server sync is waiting for AppleVis support.', 'warning');
  }

  function handleOpenTopicInBrowser() {
    if (item.kind !== 'topic') return;
    const url = item.data.url;
    if (url) Linking.openURL(url).catch(() => showToast('Could not open Safari.', 'error'));
    else showToast('URL not available yet.', 'warning');
  }

  function handleEditOwnTopic() {
    if (item.kind !== 'topic') return;
    router.push({ pathname: '/topic/[id]' as any, params: { id: item.data.id } });
  }

  function handleAdminEdit() {
    switch (item.kind) {
      case 'topic':   router.push({ pathname: '/topic/[id]' as any,         params: { id: item.data.id } }); break;
      case 'podcast': router.push({ pathname: '/episode/[id]' as any,       params: { id: item.data.id } }); break;
      case 'app':     router.push({ pathname: '/app-detail/[id]' as any,    params: { id: item.data.id } }); break;
      case 'guide':   router.push({ pathname: '/resource-detail/[id]' as any, params: { id: item.data.id } }); break;
      case 'blog':    router.push({ pathname: '/blog-detail/[id]' as any,   params: { id: item.data.id } }); break;
    }
  }

  function handleAdminDelete() {
    if (!auth.user?.csrfToken) return;
    const token       = auth.user.csrfToken;
    const contentLabel = getContentLabel(item);
    showAlert({
      title: `Delete ${contentLabel}`,
      message: `Permanently delete "${title}"? This cannot be undone.`,
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      type: 'error',
      onConfirm: async () => {
        const res = await api.content.deleteNode(item.data.id, getNodeType(item), token);
        if (res.ok) { showToast(`${contentLabel} deleted.`, 'success'); onItemDeleted?.(); }
        else showToast('Could not delete. Please try again.', 'error');
      },
    });
  }

  function handleAdminUnpublish() {
    if (!auth.user?.csrfToken) return;
    const token        = auth.user.csrfToken;
    const contentLabel = getContentLabel(item);
    showAlert({
      title: `Unpublish ${contentLabel}`,
      message: `"${title}" will be hidden from all users but not deleted.`,
      confirmLabel: 'Unpublish',
      cancelLabel: 'Cancel',
      type: 'warning',
      onConfirm: async () => {
        const res = await api.content.unpublishNode(item.data.id, getNodeType(item), token);
        if (res.ok) { showToast(`${contentLabel} unpublished.`, 'success'); onItemDeleted?.(); }
        else showToast('Could not unpublish. Please try again.', 'error');
      },
    });
  }

  function handleDeleteOwnTopic() {
    if (item.kind !== 'topic' || !auth.user?.csrfToken) return;
    const token = auth.user.csrfToken;
    showAlert({
      title: 'Delete Topic',
      message: `Are you sure you want to delete "${item.data.title}"? This cannot be undone.`,
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      type: 'error',
      onConfirm: async () => {
        const res = await api.content.deleteForumPost(item.data.id, token);
        if (res.ok) {
          showToast('Topic deleted.', 'success');
          onItemDeleted?.();
        } else {
          showToast('Could not delete topic. Please try again.', 'error');
        }
      },
    });
  }

  const actions = [
    ...(newCount > 0 && onMarkRead
      ? [{ label: 'Mark as Read', name: 'markRead', onPress: onMarkRead }]
      : []),
    ...buildActions(item, {
      isSignedIn: auth.isSignedIn,
      voiceOverOn: a11y.screenReaderEnabled,
      isQueued,
      isCurrentPodcastPlaying,
      isDownloaded,
      isDownloading: downloading,
      isSaved: isSavedItem,
      isFollowing: isFollowingItem,
      isOwnTopic,
      isAdmin,
      showToast,
      onPlay: handlePlay,
      onQueue: handleQueue,
      onPlayNext: handlePlayNext,
      onDownload: handleDownload,
      onReply: handleReply,
      onWriteReview: () => {
        if (!auth.isSignedIn) { showToast('Sign in to write a review.', 'warning'); return; }
        setReviewVisible(true);
      },
      onSave: handleSaveItem,
      onAddEpisodeComment: handleAddEpisodeComment,
      onToggleFollow: handleToggleFollow,
      onOpenTopicInBrowser: handleOpenTopicInBrowser,
      onEditOwnTopic: handleEditOwnTopic,
      onDeleteOwnTopic: handleDeleteOwnTopic,
      onAdminEdit: handleAdminEdit,
      onAdminDelete: handleAdminDelete,
      onAdminUnpublish: handleAdminUnpublish,
    }),
  ];

  const stateLabels: string[] = [];
  if (isSavedItem)   stateLabels.push('Saved');
  if (isFollowingItem) stateLabels.push('Following');
  if (isQueued)      stateLabels.push('In queue');
  if (isDownloaded)  stateLabels.push('Downloaded');
  const states = stateLabels.length > 0 ? `. ${stateLabels.join('. ')}` : '';

  const a11yType = getA11yType(item);
  // New comments badge comes immediately after type — most actionable signal in the label.
  const newLabel = newCount > 0 ? `. ${newCount} new comment${newCount === 1 ? '' : 's'}.` : '';
  // Unified VoiceOver meta: one function handles all 5 types and 3 verbosity levels.
  const metaStr  = buildA11yMeta(item, announcementLevel, episodeDuration);
  const metaPart = metaStr ? `. ${metaStr}` : '';
  // VoiceOver position uses natural-language seconds; visual position uses compact minutes.
  const positionA11y = isCurrentPodcast && player.duration > 0 && player.position > 30
    ? `${formatPositionA11y(player.position)}. Currently playing`
    : item.kind === 'podcast' && savedPos > 30 && episodeDuration > 0
      ? formatPositionA11y(savedPos)
      : '';
  const positionPart = positionA11y ? `. ${positionA11y}` : '';
  // Visual-only fields for the podcast info row below the meta text.
  const podcastDurationLine = item.kind === 'podcast' && episodeDuration > 0
    ? formatDuration(episodeDuration)
    : '';
  const podcastPositionLine = isCurrentPodcast && player.duration > 0 && player.position > 30
    ? formatPlayedPosition(player.position, player.duration)
    : item.kind === 'podcast' && savedPos > 30 && episodeDuration > 0
      ? formatPlayedPosition(savedPos, episodeDuration)
      : '';
  const podcastInfoLine = [podcastDurationLine, podcastPositionLine].filter(Boolean).join(' · ');
  // Label order: title → type → NEW comments (actionable) → meta → position → state flags.
  const label = `${title}. ${a11yType}${newLabel}${metaPart}${positionPart}${states}`;

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

  function handleOpen() {
    sounds.articleOpen().catch(() => {});
    onPress();
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
      onPress={handleOpen}
      onFocus={onFocus}
      onLongPress={handleLongPress}
      delayLongPress={400}
      accessible
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityHint={announcementLevel === 'simple' ? undefined : 'Double tap to open. Hold for options.'}
      accessibilityActions={actions.map(a => ({ name: a.label, label: a.label }))}
      onAccessibilityAction={({ nativeEvent }) => {
        const action = actions.find(a => a.name === nativeEvent.actionName || a.label === nativeEvent.actionName);
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
        numberOfLines={isAccessibilitySize ? 2 : 1}
        accessibilityElementsHidden
      >
        {meta}
      </Text>

      {item.kind === 'podcast' && podcastInfoLine ? (
        <Text
          style={{ fontSize: 12, color: colors.textSecondary, lineHeight: 17, marginTop: 4 }}
          accessibilityElementsHidden
        >
          {podcastInfoLine}
        </Text>
      ) : null}

      {/* Row 4: Podcast listening progress bar (currently playing or partially played) */}
      {((isCurrentPodcast && player.duration > 0) || savedProgress !== undefined) && (
        <View
          style={{ height: 3, backgroundColor: colors.border, borderRadius: 2, marginTop: 6 }}
          accessibilityElementsHidden
        >
          <View style={{ height: 3, backgroundColor: colors.accent, borderRadius: 2,
            width: `${Math.round(Math.min(isCurrentPodcast ? playerProgress : (savedProgress ?? 0), 1) * 100)}%` }} />
        </View>
      )}

      {/* Row 5: Inline action buttons for podcast items */}
      {item.kind === 'podcast' && (
        <View
          style={{ flexDirection: 'row', gap: 8, marginTop: 10, flexWrap: 'wrap' }}
          accessible={false}
          importantForAccessibility="no-hide-descendants"
        >
          <Pressable
            onPress={handlePlay}
            accessible={false}
            style={{
              flexDirection: 'row', alignItems: 'center', gap: 5,
              paddingHorizontal: 12, paddingVertical: 6,
              backgroundColor: colors.accent, borderRadius: 8,
            }}
          >
            <Ionicons
              name={isCurrentPodcastPlaying ? 'pause' : 'play'}
              size={14} color="#FFF" accessibilityElementsHidden
            />
            <Text style={{ fontSize: 13, fontWeight: '600', color: '#FFF' }}>
              {isCurrentPodcastPlaying ? 'Pause' : 'Play'}
            </Text>
          </Pressable>

          <Pressable
            onPress={handleQueue}
            accessible={false}
            style={{
              flexDirection: 'row', alignItems: 'center', gap: 5,
              paddingHorizontal: 12, paddingVertical: 6,
              backgroundColor: colors.inputBackground,
              borderRadius: 8, borderWidth: 1, borderColor: colors.border,
            }}
          >
            <Ionicons
              name={isQueued ? 'list' : 'add'}
              size={14} color={colors.accent} accessibilityElementsHidden
            />
            <Text style={{ fontSize: 13, fontWeight: '600', color: colors.accent }}>
              {isQueued ? 'Remove' : 'Queue'}
            </Text>
          </Pressable>

          <Pressable
            onPress={handleSaveItem}
            accessible={false}
            style={{
              flexDirection: 'row', alignItems: 'center', gap: 5,
              paddingHorizontal: 12, paddingVertical: 6,
              backgroundColor: colors.inputBackground,
              borderRadius: 8, borderWidth: 1, borderColor: colors.border,
            }}
          >
            <Ionicons
              name={isSavedItem ? 'bookmark' : 'bookmark-outline'}
              size={14} color={colors.accent} accessibilityElementsHidden
            />
            <Text style={{ fontSize: 13, fontWeight: '600', color: colors.accent }}>
              {isSavedItem ? 'Saved' : 'Save'}
            </Text>
          </Pressable>
        </View>
      )}
    </Pressable>
    </>
  );
});
