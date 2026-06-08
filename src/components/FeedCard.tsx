import { memo } from 'react';
import { ActionSheetIOS, Platform, Pressable, Share, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { useTheme } from '../contexts/ThemeContext';
import { usePreferences } from '../contexts/PreferencesContext';
import { relativeTime } from '../utils/relativeTime';
import type { FeedItem } from '../types/content';

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


function getTitle(item: FeedItem): string {
  if (item.kind === 'app') return item.data.name;
  return item.data.title;
}

function getShareMessage(item: FeedItem): string {
  switch (item.kind) {
    case 'topic':   return `${item.data.title} — https://www.applevis.com/forum`;
    case 'podcast': return `${item.data.title} from ${item.data.showTitle} — https://www.applevis.com/podcast`;
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

type Props = {
  item: FeedItem;
  onPress: () => void;
};

export const FeedCard = memo(function FeedCard({ item, onPress }: Props) {
  const { colors, styles } = useTheme();
  const { announcementLevel } = usePreferences();

  const title = getTitle(item);
  const meta  = getMeta(item);
  const badge = KIND_LABELS[item.kind];
  const icon  = KIND_ICONS[item.kind] as any;
  const isNew = item.kind === 'podcast' &&
    Date.now() - new Date(item.activityAt).getTime() < 7 * 24 * 60 * 60 * 1000;

  const label = announcementLevel === 'simple'
    ? `${badge}. ${title}`
    : `${badge}. ${title}. ${meta}`;

  function handleLongPress() {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    const message = getShareMessage(item);
    if (Platform.OS === 'ios') {
      ActionSheetIOS.showActionSheetWithOptions(
        { title, options: ['Cancel', 'Share'], cancelButtonIndex: 0 },
        (i) => { if (i === 1) Share.share({ title, message }); },
      );
    } else {
      Share.share({ title, message });
    }
  }

  return (
    <Pressable
      onPress={onPress}
      onLongPress={handleLongPress}
      delayLongPress={400}
      accessible
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityHint={announcementLevel === 'simple' ? undefined : 'Double tap to open. Hold for options.'}
      accessibilityActions={[{ name: 'share', label: 'Share' }]}
      onAccessibilityAction={() => Share.share({ title, message: getShareMessage(item) })}
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
  );
});
