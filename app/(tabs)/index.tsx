import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator, FlatList,
  Modal, Pressable, RefreshControl, Text, View,
} from 'react-native';
import { useScrollToTop } from '@react-navigation/native';
import { Tabs, useFocusEffect, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { EmptyState } from '../../src/components/EmptyState';
import { Screen } from '../../src/components/Screen';
import { FeedCard } from '../../src/components/FeedCard';
import { useHomeFeed, DEFAULT_FEED_PREFS } from '../../src/hooks/useHomeFeed';
import { useAuth } from '../../src/contexts/AuthContext';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useHandoff } from '../../src/hooks/useHandoff';
import { persistence } from '../../src/services/persistence';
import type { FeedItem, FeedPrefs } from '../../src/types/content';

// ─── Greeting ─────────────────────────────────────────────────────────────────

function getGreeting(): string {
  const h = new Date().getHours();
  if (h >= 5  && h < 12) return 'Good morning';
  if (h >= 12 && h < 17) return 'Good afternoon';
  if (h >= 17 && h < 22) return 'Good evening';
  return 'Good night';
}

// ─── Filter picker ────────────────────────────────────────────────────────────

type FilterRow = {
  key: keyof FeedPrefs;
  label: string;
  subLabel: string;
  gated?: boolean;  // true = show but disabled (Coming soon)
};

const FILTER_ROWS: FilterRow[] = [
  { key: 'topics',    label: 'Latest Topics & Replies',       subLabel: 'Forum discussions and new replies' },
  { key: 'podcasts',  label: 'Latest Podcasts & Comments',    subLabel: 'New episodes and episode discussion' },
  { key: 'apps',      label: 'Latest App Entries & Reviews',  subLabel: 'New app listings and accessibility reviews' },
  { key: 'guides',    label: 'Latest Guides & Comments',      subLabel: 'Guides, tutorials, and how-tos' },
  { key: 'blogs',     label: 'Latest Blogs & Comments',       subLabel: 'Blog posts and discussion', gated: true },
  { key: 'appleOnly', label: 'Apple-Related Topics Only',     subLabel: 'Filter topics to Apple products and services only', gated: true },
];

function FeedFilterModal({
  visible,
  prefs,
  onUpdate,
  onClose,
}: {
  visible: boolean;
  prefs: FeedPrefs;
  onUpdate: (key: keyof FeedPrefs, val: boolean) => void;
  onClose: () => void;
}) {
  const { colors } = useTheme();
  const insets     = useSafeAreaInsets();

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={onClose}
      accessibilityViewIsModal
    >
      <View style={{ flex: 1, backgroundColor: colors.background }}>
        {/* Header */}
        <View style={{
          flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
          paddingHorizontal: 20, paddingTop: insets.top + 16, paddingBottom: 16,
          borderBottomWidth: 1, borderBottomColor: colors.border,
        }}>
          <Text style={{ fontSize: 18, fontWeight: '700', color: colors.text }}>
            Home Feed
          </Text>
          <Pressable
            onPress={onClose}
            accessible
            accessibilityRole="button"
            accessibilityLabel="Close feed settings"
            style={{ padding: 8 }}
          >
            <Ionicons name="close" size={22} color={colors.text} />
          </Pressable>
        </View>

        <Text style={{
          fontSize: 13, color: colors.textSecondary,
          paddingHorizontal: 20, paddingTop: 14, paddingBottom: 10,
          lineHeight: 18,
        }}>
          Choose what appears in your Home feed. Your preferences are saved automatically.
        </Text>

        {FILTER_ROWS.map((row) => {
          const isOn    = prefs[row.key];
          const isGated = row.gated;

          return (
            <Pressable
              key={row.key}
              onPress={() => {
                if (isGated) return;
                Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                onUpdate(row.key, !isOn);
              }}
              accessible
              accessibilityRole="switch"
              accessibilityLabel={isGated ? `${row.label}, coming soon` : row.label}
              accessibilityHint={isGated ? undefined : row.subLabel}
              accessibilityState={{ checked: isOn, disabled: !!isGated }}
              style={({ pressed }) => ({
                flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
                paddingHorizontal: 20, paddingVertical: 14,
                borderBottomWidth: 1, borderBottomColor: colors.border,
                opacity: pressed && !isGated ? 0.7 : 1,
              })}
            >
              <View style={{ flex: 1, marginRight: 16 }}>
                <Text style={{
                  fontSize: 16, fontWeight: '500',
                  color: isGated ? colors.textSecondary : colors.text,
                }}>
                  {row.label}
                </Text>
                <Text style={{ fontSize: 13, color: colors.textSecondary, marginTop: 2 }}>
                  {isGated ? 'Coming soon' : row.subLabel}
                </Text>
              </View>
              {isGated ? (
                <View style={{
                  paddingHorizontal: 8, paddingVertical: 3,
                  backgroundColor: colors.pill, borderRadius: 6,
                }}>
                  <Text style={{ fontSize: 11, color: colors.textSecondary, fontWeight: '600' }}>
                    Soon
                  </Text>
                </View>
              ) : (
                <Ionicons
                  name={isOn ? 'checkmark-circle' : 'ellipse-outline'}
                  size={24}
                  color={isOn ? colors.accent : colors.border}
                  accessibilityElementsHidden
                />
              )}
            </Pressable>
          );
        })}
      </View>
    </Modal>
  );
}

// ─── Main screen ──────────────────────────────────────────────────────────────

export default function HomeScreen() {
  const router  = useRouter();
  const { colors, styles } = useTheme();
  const auth    = useAuth();
  const feed    = useHomeFeed();
  const [filterVisible, setFilterVisible] = useState(false);
  const flatListRef   = useRef<FlatList>(null);
  useScrollToTop(flatListRef);
  const unreadCount   = useMemo(
    () => feed.items.filter(i => i.kind === 'topic' && i.data.isUnread).length,
    [feed.items],
  );

  useFocusEffect(useCallback(() => {
    const t = setTimeout(() => flatListRef.current?.flashScrollIndicators(), 350);
    return () => clearTimeout(t);
  }, []));

  useHandoff({
    activityType: 'com.applevis.app.viewHome',
    title: 'AppleVis',
    webpageURL: 'https://www.applevis.com',
  });

  useEffect(() => {
    persistence.stampVisit();
  }, []);

  function handleItemPress(item: FeedItem) {
    switch (item.kind) {
      case 'topic':
        router.push({ pathname: '/topic/[id]' as any, params: { id: item.data.id, title: item.data.title } });
        break;
      case 'podcast':
        router.push({ pathname: '/episode/[id]' as any, params: { id: item.data.id } });
        break;
      case 'app':
        router.push({ pathname: '/app-detail/[id]' as any, params: { id: item.data.id, name: item.data.name } });
        break;
      case 'guide':
        router.push({ pathname: '/resource-detail/[id]' as any, params: { id: item.data.id } });
        break;
    }
  }

  // Greeting card at the top
  const greeting = getGreeting();
  const name     = auth.isSignedIn ? (auth.user?.name ?? '') : '';

  function renderHeader() {
    const anyErrors = Object.keys(feed.errors).length > 0;

    return (
      <>
        {/* Greeting */}
        {name ? (
          <View
            style={[styles.card, { marginBottom: 4 }]}
            accessible
            accessibilityLabel={`${greeting}, ${name}.`}
          >
            <Text style={{ fontSize: 20, fontWeight: '300', color: colors.text, letterSpacing: 0.2 }}
              importantForAccessibility="no-hide-descendants">
              {greeting},
            </Text>
            <Text style={{ fontSize: 26, fontWeight: '700', color: colors.appleVisBlue }}
              importantForAccessibility="no-hide-descendants">
              {name}
            </Text>
          </View>
        ) : null}

        {/* Per-source error banners — only shown if something failed */}
        {anyErrors && (
          <View style={{
            flexDirection: 'row', gap: 8, alignItems: 'flex-start',
            backgroundColor: '#FFF8F0', borderRadius: 10, padding: 12, marginBottom: 10,
          }}
            accessible
            accessibilityLabel={`Some content could not be loaded: ${Object.keys(feed.errors).join(', ')}.`}
          >
            <Ionicons name="warning-outline" size={16} color="#C05000" accessibilityElementsHidden style={{ marginTop: 1 }} />
            <Text style={{ flex: 1, fontSize: 13, color: '#C05000', lineHeight: 18 }}>
              Some sources could not be loaded. Pull down to retry.
            </Text>
          </View>
        )}

        {/* Section header */}
        <Text
          style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 10, marginTop: 4 }}
          accessibilityRole="header"
        >
          Latest Activity
        </Text>
      </>
    );
  }

  function renderFooter() {
    if (feed.isLoadingMore) {
      return (
        <View style={{ paddingVertical: 20, alignItems: 'center' }}>
          <ActivityIndicator color={colors.appleVisBlue} accessibilityLabel="Loading more" />
        </View>
      );
    }
    if (!feed.hasMore && feed.items.length > 0) {
      return (
        <Text style={{ textAlign: 'center', color: colors.textSecondary, fontSize: 13, paddingVertical: 20 }}
          accessible accessibilityLabel="You've reached the end of the feed.">
          You're all caught up.
        </Text>
      );
    }
    return <View style={{ height: 20 }} />;
  }

  return (
    <>
    <Tabs.Screen options={{ tabBarBadge: unreadCount > 0 ? unreadCount : undefined }} />
    <Screen
      title="Home"
      showBack={false}
      headerRight={
        <Pressable
          onPress={() => setFilterVisible(true)}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Feed settings"
          accessibilityHint="Choose what content types appear in your Home feed"
          style={{ padding: 8 }}
        >
          <Ionicons name="options-outline" size={22} color={colors.accent} />
        </Pressable>
      }
    >
      {/* Loading state */}
      {feed.loading && (
        <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', paddingBottom: 80 }}>
          <ActivityIndicator size="large" color={colors.appleVisBlue} accessibilityLabel="Loading feed" />
          <Text style={[styles.lede, { marginTop: 14, textAlign: 'center' }]}>Loading your feed…</Text>
        </View>
      )}

      {/* Empty state — all sources off or all failed */}
      {!feed.loading && feed.items.length === 0 && (
        <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 16 }}>
          <EmptyState
            icon="newspaper-outline"
            title="Nothing to show"
            subtitle="Turn on at least one content type using the feed settings button above."
            action={{ label: 'Feed Settings', onPress: () => setFilterVisible(true) }}
          />
        </View>
      )}

      {/* Feed */}
      {!feed.loading && feed.items.length > 0 && (
        <FlatList
          data={feed.items}
          keyExtractor={(item) => `${item.kind}-${item.data.id}`}
          renderItem={({ item }) => (
            <FeedCard item={item} onPress={() => handleItemPress(item)} />
          )}
          ListHeaderComponent={renderHeader}
          ListFooterComponent={renderFooter}
          contentContainerStyle={{ padding: 16, paddingBottom: 100 }}
          onEndReached={() => feed.loadMore()}
          onEndReachedThreshold={0.3}
          refreshControl={
            <RefreshControl
              refreshing={feed.refreshing}
              onRefresh={feed.refresh}
              tintColor={colors.appleVisBlue}
              accessibilityLabel="Pull to refresh feed"
            />
          }
          ref={flatListRef}
          showsVerticalScrollIndicator
        />
      )}

      {/* Filter modal */}
      <FeedFilterModal
        visible={filterVisible}
        prefs={feed.prefs}
        onUpdate={feed.updatePref}
        onClose={() => setFilterVisible(false)}
      />
    </Screen>
    </>
  );
}
