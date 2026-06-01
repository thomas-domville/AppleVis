import { useRef } from 'react';
import { ActivityIndicator, Pressable, RefreshControl, ScrollView, Share, Text, View } from 'react-native';
import { Screen } from '../../src/components/Screen';
import { AccessibleCard } from '../../src/components/AccessibleCard';
import { OfflineBanner } from '../../src/components/OfflineBanner';
import { LoadMoreButton } from '../../src/components/LoadMoreButton';
import { useForumState, FORUM_FILTERS } from '../../src/hooks/useForumState';
import { useSavedItems } from '../../src/hooks/useSavedItems';
import { useRefreshFeedback } from '../../src/hooks/useRefreshFeedback';
import { useFocusRestore } from '../../src/hooks/useFocusRestore';
import { useHandoff } from '../../src/hooks/useHandoff';
import { useAuth } from '../../src/contexts/AuthContext';
import { useToast } from '../../src/contexts/ToastContext';
import { translateContent, donateSiriActivity, readAloud, summariseText, simplifyText } from '../../src/services/intelligenceService';
import { styles, colors } from '../../src/theme/styles';

export default function Forums() {
  const auth  = useAuth();
  const forum = useForumState();
  const saved = useSavedItems('forumTopic');
  const { showToast } = useToast();
  const topicRefs = useRef<Map<string, View>>(new Map());
  const { save }  = useFocusRestore();

  useHandoff({
    activityType: 'com.applevis.app.viewForums',
    title: 'AppleVis Forums',
    webpageURL: 'https://www.applevis.com/forum',
  });

  useRefreshFeedback(forum.refreshing, 'Forums', forum.loading,
    () => topicRefs.current.get(forum.topics[0]?.id ?? '') ?? null);

  function handleAction(topicId: string, topicTitle: string, actionName: string) {
    if (actionName === 'Open') {
      save(topicRefs.current.get(topicId) ?? null);
      donateSiriActivity({ type: 'openForums' });
      // router.push(`/topic/${topicId}`); — wire in when detail screen exists
    } else if (actionName === 'Translate') {
      const topic = forum.topics.find((t) => t.id === topicId);
      translateContent([topicTitle, topic?.meta ?? ''].filter(Boolean).join('\n'), topicTitle);
    } else if (actionName === 'Read Aloud') {
      const topic = forum.topics.find((t) => t.id === topicId);
      readAloud([topicTitle, topic?.meta ?? ''].filter(Boolean).join('. '));
    } else if (actionName === 'Summarise') {
      const topic = forum.topics.find((t) => t.id === topicId);
      summariseText([topicTitle, topic?.meta ?? ''].filter(Boolean).join('\n')).then((s) => {
        if (s) showToast(s, 'success');
        else showToast('Summarisation coming when Apple Intelligence Foundation Models support is added.', 'warning');
      });
    } else if (actionName === 'Simplify') {
      const topic = forum.topics.find((t) => t.id === topicId);
      simplifyText([topicTitle, topic?.meta ?? ''].filter(Boolean).join('\n')).then((s) => {
        if (s) showToast(s, 'success');
        else showToast('Plain-language simplification coming when Apple Intelligence Foundation Models support is added.', 'warning');
      });
    } else if (actionName === 'Mark as Read') {
      forum.markRead(topicId);
    } else if (actionName === 'Follow Topic' || actionName === 'Unfollow Topic') {
      const isFollowing = forum.topics.find((t) => t.id === topicId)?.isFollowing ?? false;
      forum.toggleFollow(topicId, isFollowing);
    } else if (actionName === 'Sign in to Follow') {
      showToast('Sign in required. Visit Settings to sign in.', 'warning');
    } else if (actionName === 'Save Topic' || actionName === 'Unsave Topic') {
      if (saved.isSaved(topicId)) {
        saved.unsave(topicId);
        showToast('Removed from saved.', 'success');
      } else {
        saved.save({ id: topicId, kind: 'forumTopic', title: topicTitle, savedAt: new Date().toISOString() });
        showToast('Topic saved.', 'success');
      }
    } else if (actionName === 'Share') {
      Share.share({
        title: topicTitle,
        message: `${topicTitle} — https://www.applevis.com/forum`,
      }).catch(() => {});
    }
  }

  return (
    <Screen title="Forums" refreshing={forum.refreshing} showSearch>
      <ScrollView
        showsVerticalScrollIndicator={false}
        refreshControl={
          <RefreshControl
            refreshing={forum.refreshing}
            onRefresh={forum.refresh}
            tintColor={colors.appleVisBlue}
            accessibilityLabel="Pull to refresh forums"
          />
        }
      >
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

        <OfflineBanner fromCache={forum.fromCache} cachedAt={forum.cachedAt} />

        {/* Filter descriptions */}
        {forum.filter === 'Since Last Visit' && (
          <Text style={[styles.lede, { marginBottom: 12 }]}>Topics that changed since you last opened AppleVis.</Text>
        )}
        {forum.filter === 'Unread' && (
          <Text style={[styles.lede, { marginBottom: 12 }]}>Topics you have not opened yet on this device.</Text>
        )}
        {forum.filter === 'Following' && (
          <Text style={[styles.lede, { marginBottom: 12 }]}>Topics you are following. Saved locally and synced via iCloud.</Text>
        )}
        {forum.filter === 'Saved' && (
          <Text style={[styles.lede, { marginBottom: 12 }]}>Topics you saved for later. Synced via iCloud.</Text>
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
              accessibilityLabel="Retry loading topics"
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
              {forum.filter === 'Unread'           && 'You are all caught up.'}
              {forum.filter === 'Following'        && 'You are not following any topics yet.'}
              {forum.filter === 'Saved'            && 'You have not saved any topics yet.'}
              {forum.filter === 'Since Last Visit' && 'No new activity since your last visit.'}
            </Text>
          </View>
        )}

        {/* Topic list */}
        {!forum.loading && forum.topics.map((topic) => (
          <AccessibleCard
            key={topic.id}
            ref={(el) => {
              if (el) topicRefs.current.set(topic.id, el);
              else topicRefs.current.delete(topic.id);
            }}
            title={topic.title}
            meta={[
              topic.isUnread    ? 'Unread'    : null,
              topic.isFollowing ? 'Following' : null,
              topic.isSaved     ? 'Saved'     : null,
              topic.meta,
            ].filter(Boolean).join(' · ')}
            actions={[
              'Open',
              topic.isSaved ? 'Unsave Topic' : 'Save Topic',
              auth.isSignedIn
                ? (topic.isFollowing ? 'Unfollow Topic' : 'Follow Topic')
                : 'Sign in to Follow',
              'Mark as Read',
              'Read Aloud',
              'Translate',
              'Summarise',
              'Simplify',
              'Share',
            ]}
            onAction={(action) => handleAction(topic.id, topic.title, action)}
          />
        ))}

        <LoadMoreButton
          hasMore={forum.hasMore}
          isLoadingMore={forum.isLoadingMore}
          onPress={forum.loadMore}
        />

        <View style={{ height: 160 }} />
      </ScrollView>
    </Screen>
  );
}
