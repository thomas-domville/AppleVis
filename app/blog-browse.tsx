import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActivityIndicator, findNodeHandle, Pressable,
  RefreshControl, ScrollView, Text, TextInput, View,
} from 'react-native';
import { useFocusEffect, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { EmptyState } from '../src/components/EmptyState';
import { Screen } from '../src/components/Screen';
import { FeedCard } from '../src/components/FeedCard';
import { AutoLoadMoreFooter } from '../src/components/AutoLoadMoreFooter';
import { useBlogList } from '../src/hooks/useBlogList';
import { useAutoLoadMore } from '../src/hooks/useAutoLoadMore';
import { useRefreshFeedback } from '../src/hooks/useRefreshFeedback';
import { useFocusRestore } from '../src/hooks/useFocusRestore';
import { useTheme } from '../src/contexts/ThemeContext';
import { persistence } from '../src/services/persistence';
import { relativeTime } from '../src/utils/relativeTime';
import type { BlogPost } from '../src/types/content';

// Violet — matches home tab blog colour
const BLOG_ACCENT = '#8b5cf6';

export default function BlogBrowse() {
  const router             = useRouter();
  const { colors, styles } = useTheme();
  const blog               = useBlogList();
  const cardRefs           = useRef<Map<string, View>>(new Map());
  const firstBlogRef       = useRef<View | null>(null);
  const didFocusFirstBlog  = useRef(false);
  const { save }           = useFocusRestore();

  const [searchQuery,  setSearchQuery]  = useState('');
  const [itemVisits,   setItemVisits]   = useState<Record<string, { seenAt: string; commentCount: number }>>({});
  const [feedLoadedAt, setFeedLoadedAt] = useState<Date | null>(null);
  const prevLoadingRef = useRef(false);

  // Reload visit history when screen comes into focus
  useFocusEffect(useCallback(() => {
    persistence.getAllItemVisits().then(setItemVisits);
  }, []));

  // Track when data finishes loading
  useEffect(() => {
    if (prevLoadingRef.current && !blog.loading && blog.blogs.length > 0) {
      setFeedLoadedAt(new Date());
    }
    prevLoadingRef.current = blog.loading;
  }, [blog.loading, blog.blogs.length]);

  useRefreshFeedback(
    blog.refreshing, 'Blog', blog.loading,
    () => firstBlogRef.current ?? cardRefs.current.get(blog.blogs[0]?.id ?? '') ?? null,
  );

  // Search filter
  const visibleBlogs = useMemo(() => {
    if (!searchQuery.trim()) return blog.blogs;
    const q = searchQuery.toLowerCase();
    return blog.blogs.filter((b) =>
      b.title.toLowerCase().includes(q) ||
      b.authorName.toLowerCase().includes(q),
    );
  }, [blog.blogs, searchQuery]);

  useEffect(() => {
    if (didFocusFirstBlog.current) return;
    if (blog.loading || visibleBlogs.length === 0) return;

    const timer = setTimeout(() => {
      const handle = findNodeHandle(firstBlogRef.current);
      if (handle) {
        didFocusFirstBlog.current = true;
        AccessibilityInfo.setAccessibilityFocus(handle);
      }
    }, 450);

    return () => clearTimeout(timer);
  }, [blog.loading, visibleBlogs.length]);

  // New-comment count (same logic as Home tab's newCount)
  function getNewCount(post: BlogPost): number {
    const visit = itemVisits[post.id];
    if (!visit) return 0;
    return Math.max(0, post.commentCount - visit.commentCount);
  }

  const feedSummaryLabel = useMemo(() => {
    if (visibleBlogs.length === 0) return 'No posts loaded.';
    const label = `${visibleBlogs.length} post${visibleBlogs.length !== 1 ? 's' : ''}`;
    return feedLoadedAt
      ? `${label}. Updated ${relativeTime(feedLoadedAt.toISOString())}.`
      : `${label}.`;
  }, [visibleBlogs.length, feedLoadedAt]);
  const shouldAutoLoadMore = blog.hasMore && !searchQuery.trim();
  const handleAutoLoadMore = useAutoLoadMore({
    hasMore: shouldAutoLoadMore,
    isLoadingMore: blog.isLoadingMore,
    onLoadMore: blog.loadMore,
  });

  return (
    <Screen
      title="AppleVis Blog"
      refreshing={blog.refreshing}
    >
      <ScrollView
        showsVerticalScrollIndicator
        onScroll={handleAutoLoadMore}
        scrollEventThrottle={120}
        refreshControl={
          <RefreshControl
            refreshing={blog.refreshing}
            onRefresh={blog.refresh}
            tintColor={colors.appleVisBlue}
            accessibilityLabel="Pull to refresh blog posts"
          />
        }
      >
        {/* Search */}
        <View style={{
          flexDirection: 'row', alignItems: 'center',
          backgroundColor: colors.inputBackground, borderRadius: 10, borderWidth: 1,
          borderColor: colors.border, paddingHorizontal: 10, paddingVertical: 8, marginBottom: 10,
        }}>
          <Ionicons name="search" size={16} color={colors.textSecondary}
            style={{ marginRight: 6 }} accessibilityElementsHidden />
          <TextInput
            value={searchQuery}
            onChangeText={setSearchQuery}
            placeholder="Search posts…"
            placeholderTextColor={colors.textSecondary}
            style={{ flex: 1, fontSize: 15, color: colors.text }}
            accessible
            accessibilityLabel="Search blog posts"
            accessibilityHint="Type to filter posts by title or author name"
            returnKeyType="search"
            clearButtonMode="while-editing"
          />
        </View>

        {/* Section header */}
        {!blog.loading && visibleBlogs.length > 0 && (
          <View style={{ flexDirection: 'row', alignItems: 'center', marginBottom: 10, marginTop: 4 }}>
            <Text
              style={{
                flex: 1, fontSize: 13, fontWeight: '700', color: colors.textSecondary,
                textTransform: 'uppercase', letterSpacing: 0.8,
              }}
              accessibilityRole="header"
              accessibilityActions={[{ name: 'feedSummary', label: 'Feed summary' }]}
              onAccessibilityAction={() => AccessibilityInfo.announceForAccessibility(feedSummaryLabel)}
            >
              Latest Blog Posts
            </Text>
            {feedLoadedAt && (
              <Text
                style={{ fontSize: 11, color: colors.textSecondary }}
                accessibilityElementsHidden
              >
                Updated {relativeTime(feedLoadedAt.toISOString())}
              </Text>
            )}
          </View>
        )}

        {/* Loading */}
        {blog.loading && (
          <View
            accessible
            accessibilityLiveRegion="polite"
            accessibilityLabel="Loading blog posts, please wait"
            style={{ alignItems: 'center', paddingVertical: 32 }}
          >
            <ActivityIndicator size="large" color={colors.appleVisBlue} />
            <Text style={[styles.lede, { marginTop: 12, textAlign: 'center' }]}>
              Loading posts…
            </Text>
          </View>
        )}

        {/* Error */}
        {!blog.loading && blog.error && (
          <View style={[styles.card, { backgroundColor: '#FFF0F0' }]}>
            <Text style={[styles.cardTitle, { color: '#D00' }]}>Could not load posts</Text>
            <Text style={styles.cardMeta}>{blog.error}</Text>
            <Pressable
              onPress={blog.refresh}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Retry loading blog posts"
              style={{ marginTop: 12 }}
            >
              <Text style={{ color: colors.appleVisBlue, fontWeight: '700' }}>Retry</Text>
            </Pressable>
          </View>
        )}

        {/* Empty — nothing loaded */}
        {!blog.loading && !blog.error && blog.blogs.length === 0 && (
          <EmptyState
            icon="newspaper-outline"
            title="No posts"
            subtitle="No blog posts could be loaded. Pull down to try again."
          />
        )}

        {/* Empty — search narrowed to zero */}
        {!blog.loading && blog.blogs.length > 0 && visibleBlogs.length === 0 && (
          <EmptyState
            icon="search-outline"
            title="No results"
            subtitle={`No posts match "${searchQuery}".`}
          />
        )}

        {/* Blog post cards */}
        {!blog.loading && visibleBlogs.map((post, index) => (
          <FeedCard
            key={post.id}
            item={{ kind: 'blog', data: post, activityAt: post.lastActivityAt ?? post.publishedAt }}
            cardRef={(el: View | null) => {
              if (el) cardRefs.current.set(post.id, el);
              else cardRefs.current.delete(post.id);
              if (index === 0) firstBlogRef.current = el;
            }}
            accentColor={BLOG_ACCENT}
            newCount={getNewCount(post)}
            onPress={() => {
              save(cardRefs.current.get(post.id) ?? null);
              router.push({
                pathname: '/blog-detail/[id]' as any,
                params: { id: post.id, title: post.title, url: post.url },
              });
            }}
          />
        ))}

        <AutoLoadMoreFooter isLoadingMore={blog.isLoadingMore} label="Loading more blog posts" />

        {/* End-of-feed */}
        {!blog.loading && !blog.hasMore && visibleBlogs.length > 0 && (
          <Text
            style={{ textAlign: 'center', color: colors.textSecondary, fontSize: 13, paddingVertical: 20 }}
            accessible
            accessibilityLabel={`${visibleBlogs.length} post${visibleBlogs.length !== 1 ? 's' : ''} loaded.`}
            accessibilityLiveRegion="polite"
          >
            {visibleBlogs.length} post{visibleBlogs.length !== 1 ? 's' : ''} loaded
          </Text>
        )}

        <View style={{ height: 120 }} />
      </ScrollView>
    </Screen>
  );
}
