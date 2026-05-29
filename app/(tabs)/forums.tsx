import { ActivityIndicator, Pressable, ScrollView, Text, View } from 'react-native';
import { Screen } from '../../src/components/Screen';
import { AccessibleCard } from '../../src/components/AccessibleCard';
import { useForumState, FORUM_FILTERS } from '../../src/hooks/useForumState';
import { useSavedItems } from '../../src/hooks/useSavedItems';
import { styles, colors } from '../../src/theme/styles';

export default function Forums() {
  const forum = useForumState();
  const saved = useSavedItems('forumTopic');

  function handleAction(topicId: string, topicTitle: string, actionName: string) {
    if (actionName === 'Mark as Read') {
      forum.markRead(topicId);
    } else if (actionName === 'Follow Topic') {
      const isFollowing = forum.topics.find((t) => t.id === topicId)?.isFollowing ?? false;
      forum.toggleFollow(topicId, isFollowing);
    } else if (actionName === 'Save Topic') {
      if (saved.isSaved(topicId)) {
        saved.unsave(topicId);
      } else {
        saved.save({ id: topicId, kind: 'forumTopic', title: topicTitle, savedAt: new Date().toISOString() });
      }
    }
  }

  return (
    <Screen title="Forums">
      <ScrollView showsVerticalScrollIndicator={false}>

        {/* Filter bar */}
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          accessibilityLabel="Forum filters"
          accessibilityRole="tablist"
          style={{ marginBottom: 16 }}
          contentContainerStyle={{ gap: 8, paddingRight: 4 }}
        >
          {FORUM_FILTERS.map((f) => {
            const isActive = f === forum.filter;
            return (
              <Pressable
                key={f}
                onPress={() => forum.setFilter(f)}
                accessible
                accessibilityRole="tab"
                accessibilityLabel={f}
                accessibilityState={{ selected: isActive }}
                style={[styles.pill, isActive && { backgroundColor: colors.appleVisBlue }]}
              >
                <Text style={[styles.pillText, isActive && { color: '#FFFFFF' }]}>{f}</Text>
              </Pressable>
            );
          })}
        </ScrollView>

        {/* Filter description */}
        {forum.filter === 'Since Last Visit' && (
          <Text style={[styles.lede, { marginBottom: 12 }]}>
            Topics that changed since you last opened AppleVis.
          </Text>
        )}
        {forum.filter === 'Unread' && (
          <Text style={[styles.lede, { marginBottom: 12 }]}>
            Topics you have not opened yet on this device.
          </Text>
        )}
        {forum.filter === 'Following' && (
          <Text style={[styles.lede, { marginBottom: 12 }]}>
            Topics you are following. Saved locally and synced via iCloud.
          </Text>
        )}
        {forum.filter === 'Saved' && (
          <Text style={[styles.lede, { marginBottom: 12 }]}>
            Topics you saved for later. Synced via iCloud.
          </Text>
        )}

        {/* Loading */}
        {forum.loading && (
          <View style={{ alignItems: 'center', paddingVertical: 32 }}>
            <ActivityIndicator size="large" color={colors.appleVisBlue} />
            <Text style={[styles.lede, { marginTop: 12, textAlign: 'center' }]}>
              Loading {forum.filter.toLowerCase()}…
            </Text>
          </View>
        )}

        {/* Error */}
        {!forum.loading && forum.error && (
          <View style={[styles.card, { backgroundColor: '#FFF0F0' }]}>
            <Text style={[styles.cardTitle, { color: '#D00' }]}>Could not load topics</Text>
            <Text style={styles.cardMeta}>{forum.error}</Text>
            <Pressable
              onPress={forum.refresh}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Retry"
              style={{ marginTop: 12 }}
            >
              <Text style={{ color: colors.appleVisBlue, fontWeight: '700' }}>Retry</Text>
            </Pressable>
          </View>
        )}

        {/* Empty state */}
        {!forum.loading && !forum.error && forum.topics.length === 0 && (
          <View style={[styles.card, { alignItems: 'center', paddingVertical: 32 }]}>
            <Text style={styles.cardTitle}>No topics</Text>
            <Text style={[styles.cardMeta, { textAlign: 'center', marginTop: 4 }]}>
              {forum.filter === 'Unread' && 'You are all caught up.'}
              {forum.filter === 'Following' && 'You are not following any topics yet.'}
              {forum.filter === 'Saved' && 'You have not saved any topics yet.'}
              {forum.filter === 'Since Last Visit' && 'No new activity since your last visit.'}
            </Text>
          </View>
        )}

        {/* Topic list */}
        {!forum.loading && forum.topics.map((topic) => (
          <AccessibleCard
            key={topic.id}
            title={topic.title}
            meta={[
              topic.isUnread ? 'Unread' : null,
              topic.isFollowing ? 'Following' : null,
              topic.isSaved ? 'Saved' : null,
              topic.meta,
            ].filter(Boolean).join(' · ')}
            actions={[
              'Open',
              topic.isSaved ? 'Unsave Topic' : 'Save Topic',
              topic.isFollowing ? 'Unfollow Topic' : 'Follow Topic',
              'Mark as Read',
              'Share',
            ]}
            onAction={(action) => handleAction(topic.id, topic.title, action)}
          />
        ))}

        <View style={{ height: 160 }} />
      </ScrollView>
    </Screen>
  );
}
