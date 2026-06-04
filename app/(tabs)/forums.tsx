import { useCallback, useMemo, useRef, useState } from 'react';
import { ActivityIndicator, Pressable, RefreshControl, ScrollView, Share, Text, TextInput, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../../src/components/Screen';
import { AccessibleCard } from '../../src/components/AccessibleCard';
import { FilterPicker } from '../../src/components/FilterPicker';
import { OfflineBanner } from '../../src/components/OfflineBanner';
import { LoadMoreButton } from '../../src/components/LoadMoreButton';
import { useForumState, FORUM_FILTERS } from '../../src/hooks/useForumState';
import { useSavedItems } from '../../src/hooks/useSavedItems';
import { useRefreshFeedback } from '../../src/hooks/useRefreshFeedback';
import { useFocusRestore } from '../../src/hooks/useFocusRestore';
import { useHandoff } from '../../src/hooks/useHandoff';
import { GlassView } from '../../src/components/GlassView';
import { useAuth } from '../../src/contexts/AuthContext';
import { useToast } from '../../src/contexts/ToastContext';
import { translateContent, donateSiriActivity, readAloud, summariseText, simplifyText } from '../../src/services/intelligenceService';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';

type ForumSortOrder = 'recent' | 'oldest' | 'az' | 'za';
const FORUM_SORT_OPTIONS: { value: ForumSortOrder; label: string }[] = [
  { value: 'recent', label: 'Most recent first' },
  { value: 'oldest', label: 'Oldest first' },
  { value: 'az',     label: 'A–Z' },
  { value: 'za',     label: 'Z–A' },
];

export default function Forums() {
  const router = useRouter();
  const { colors, styles } = useTheme();
  const { screenReaderEnabled } = useAccessibilityPreferences();
  const auth  = useAuth();
  const forum = useForumState();
  const saved = useSavedItems('forumTopic');
  const { showToast } = useToast();
  const topicRefs = useRef<Map<string, View>>(new Map());
  const { save }  = useFocusRestore();

  const [searchQuery, setSearchQuery]     = useState('');
  const [sortOrder, setSortOrder]         = useState<ForumSortOrder>('recent');
  const [showSortSheet, setShowSortSheet] = useState(false);

  // Wrap setFilter so sheets close and search/sort reset on view change.
  const setFilter = useCallback((f: typeof forum.filter) => {
    forum.setFilter(f);
    setSearchQuery('');
    setSortOrder('recent');
    setShowSortSheet(false);
  }, [forum]);

  const visibleTopics = useMemo(() => {
    let result = forum.topics;
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      result = result.filter(t =>
        t.title.toLowerCase().includes(q) ||
        t.authorName.toLowerCase().includes(q));
    }
    switch (sortOrder) {
      case 'oldest': return [...result].sort((a, b) =>
        new Date(a.lastActivityAt).getTime() - new Date(b.lastActivityAt).getTime());
      case 'az': return [...result].sort((a, b) => a.title.localeCompare(b.title));
      case 'za': return [...result].sort((a, b) => b.title.localeCompare(a.title));
      default:   return [...result].sort((a, b) =>
        new Date(b.lastActivityAt).getTime() - new Date(a.lastActivityAt).getTime());
    }
  }, [forum.topics, searchQuery, sortOrder]);

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
      router.push({ pathname: '/topic/[id]' as any, params: { id: topicId, title: topicTitle } });
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
    <Screen title="Forums" refreshing={forum.refreshing} showSearch showBack={false}>
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
        {/* ── Search bar ───────────────────────────────────────────────── */}
        <View style={{ flexDirection: 'row', alignItems: 'center',
          backgroundColor: colors.inputBackground, borderRadius: 10, borderWidth: 1,
          borderColor: colors.border, paddingHorizontal: 10, paddingVertical: 8, marginBottom: 10 }}>
          <Ionicons name="search" size={16} color={colors.textSecondary} style={{ marginRight: 6 }}
            accessibilityElementsHidden />
          <TextInput
            value={searchQuery}
            onChangeText={setSearchQuery}
            placeholder="Search topics…"
            placeholderTextColor={colors.textSecondary}
            style={{ flex: 1, fontSize: 15, color: colors.text }}
            accessible
            accessibilityLabel="Search topics"
            accessibilityHint="Type to filter topics by title or author name"
            returnKeyType="search"
            clearButtonMode="while-editing"
          />
        </View>

        {/* Filter picker */}
        <FilterPicker
          label="Filter Forums"
          value={forum.filter}
          options={FORUM_FILTERS}
          onChange={setFilter}
        />

        {/* ── Action bar: sort + topic count ───────────────────────────── */}
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 8 }}>
          <Pressable
            onPress={() => setShowSortSheet(v => !v)}
            accessible accessibilityRole="button"
            accessibilityLabel={`Sort: ${FORUM_SORT_OPTIONS.find(s => s.value === sortOrder)?.label ?? sortOrder}. Double tap to change.`}
            style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
              backgroundColor: sortOrder !== 'recent' ? colors.accent + '22' : colors.pill,
              borderRadius: 20, paddingHorizontal: 12, paddingVertical: 6,
              borderWidth: 1, borderColor: sortOrder !== 'recent' ? colors.accent : colors.border }}
          >
            <Ionicons name="swap-vertical-outline" size={14}
              color={sortOrder !== 'recent' ? colors.accent : colors.textSecondary}
              accessibilityElementsHidden />
            <Text style={{ fontSize: 13, fontWeight: '500',
              color: sortOrder !== 'recent' ? colors.accent : colors.text }}>
              {FORUM_SORT_OPTIONS.find(s => s.value === sortOrder)?.label ?? 'Sort'}
            </Text>
            {sortOrder !== 'recent' && (
              <View style={{ width: 6, height: 6, borderRadius: 3,
                backgroundColor: colors.accent }} accessibilityElementsHidden />
            )}
          </Pressable>

          <Text style={{ marginLeft: 'auto', fontSize: 13, color: colors.textSecondary }}
            accessibilityElementsHidden>
            {visibleTopics.length} topic{visibleTopics.length === 1 ? '' : 's'}
          </Text>
        </View>

        {/* Sort sheet */}
        {showSortSheet && (
          <GlassView intensity={60} style={[styles.card, { marginBottom: 10, padding: 4 }]}
            accessible accessibilityRole="menu" accessibilityLabel="Sort order">
            {FORUM_SORT_OPTIONS.map(opt => (
              <Pressable
                key={opt.value}
                onPress={() => { setSortOrder(opt.value); setShowSortSheet(false); }}
                accessible accessibilityRole="menuitem"
                accessibilityLabel={opt.label}
                accessibilityState={{ selected: sortOrder === opt.value }}
                style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
                  paddingHorizontal: 12, paddingVertical: 12 }}
              >
                <Text style={{ fontSize: 15,
                  color: sortOrder === opt.value ? colors.accent : colors.text,
                  fontWeight: sortOrder === opt.value ? '600' : '400' }}>
                  {opt.label}
                </Text>
                {sortOrder === opt.value && (
                  <Ionicons name="checkmark" size={18} color={colors.accent} accessibilityElementsHidden />
                )}
              </Pressable>
            ))}
          </GlassView>
        )}

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

        {/* Search empty state */}
        {!forum.loading && forum.topics.length > 0 && visibleTopics.length === 0 && searchQuery.trim() && (
          <View style={[styles.card, { alignItems: 'center', paddingVertical: 32 }]}>
            <Text style={styles.cardTitle}>No results</Text>
            <Text style={[styles.cardMeta, { textAlign: 'center', marginTop: 4 }]}>
              No topics match "{searchQuery}". Try a different search.
            </Text>
          </View>
        )}

        {/* Topic list */}
        {!forum.loading && visibleTopics.map((topic) => (
          <AccessibleCard
            key={topic.id}
            ref={(el) => {
              if (el) topicRefs.current.set(topic.id, el);
              else topicRefs.current.delete(topic.id);
            }}
            title={topic.title}
            authorLabel={topic.authorName ? `By ${topic.authorName}` : undefined}
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
              ...(!screenReaderEnabled ? ['Read Aloud'] : []),
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
