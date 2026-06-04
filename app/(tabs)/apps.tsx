import { useMemo, useRef, useState } from 'react';
import { ActivityIndicator, Pressable, RefreshControl, ScrollView, Share, Text, TextInput, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../../src/components/Screen';
import { AccessibleCard } from '../../src/components/AccessibleCard';
import { OfflineBanner } from '../../src/components/OfflineBanner';
import { LoadMoreButton } from '../../src/components/LoadMoreButton';
import { useAppList } from '../../src/hooks/useAppList';
import { useRefreshFeedback } from '../../src/hooks/useRefreshFeedback';
import { useFocusRestore } from '../../src/hooks/useFocusRestore';
import { useHandoff } from '../../src/hooks/useHandoff';
import { GlassView } from '../../src/components/GlassView';
import { useToast } from '../../src/contexts/ToastContext';
import { translateContent, donateSiriActivity, readAloud, summariseText, simplifyText, accessibilityConsensus } from '../../src/services/intelligenceService';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';

type AppSortOrder = 'updated' | 'az' | 'za' | 'reviewed';
const APP_SORT_OPTIONS: { value: AppSortOrder; label: string }[] = [
  { value: 'updated',  label: 'Recently updated' },
  { value: 'az',       label: 'A–Z' },
  { value: 'za',       label: 'Z–A' },
  { value: 'reviewed', label: 'Most reviewed' },
];

export default function Apps() {
  const router         = useRouter();
  const { colors, styles } = useTheme();
  const { screenReaderEnabled } = useAccessibilityPreferences();
  const list           = useAppList();
  const { showToast }  = useToast();
  const appRefs = useRef<Map<string, View>>(new Map());
  const { save } = useFocusRestore();

  const [searchQuery, setSearchQuery]         = useState('');
  const [sortOrder, setSortOrder]             = useState<AppSortOrder>('updated');
  const [categoryFilter, setCategoryFilter]   = useState<string>('All Categories');
  const [showSortSheet, setShowSortSheet]     = useState(false);
  const [showCategoryPicker, setShowCategoryPicker] = useState(false);

  const allCategories = useMemo(() => {
    const cats = new Set<string>();
    list.apps.forEach(app => { if (app.category) cats.add(app.category); });
    return ['All Categories', ...Array.from(cats).sort()];
  }, [list.apps]);

  const visibleApps = useMemo(() => {
    let result = list.apps;
    if (categoryFilter !== 'All Categories') {
      result = result.filter(app => app.category === categoryFilter);
    }
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      result = result.filter(app =>
        app.name.toLowerCase().includes(q) ||
        app.developer.toLowerCase().includes(q) ||
        app.category.toLowerCase().includes(q));
    }
    switch (sortOrder) {
      case 'az':       return [...result].sort((a, b) => a.name.localeCompare(b.name));
      case 'za':       return [...result].sort((a, b) => b.name.localeCompare(a.name));
      case 'reviewed': return [...result].sort((a, b) => b.reviewCount - a.reviewCount);
      default:         return [...result].sort((a, b) =>
        new Date(b.lastUpdatedAt).getTime() - new Date(a.lastUpdatedAt).getTime());
    }
  }, [list.apps, searchQuery, sortOrder, categoryFilter]);

  useRefreshFeedback(list.refreshing, 'Apps', list.loading,
    () => appRefs.current.get(list.apps[0]?.id ?? '') ?? null);

  useHandoff({
    activityType: 'com.applevis.app.viewApps',
    title: 'AppleVis App Directory',
    webpageURL: 'https://www.applevis.com/accessibility-apps',
  });

  return (
    <Screen title="Apps" refreshing={list.refreshing} showSearch showBack={false}>
      <ScrollView
        refreshControl={
          <RefreshControl
            refreshing={list.refreshing}
            onRefresh={list.refresh}
            tintColor={colors.appleVisBlue}
            accessibilityLabel="Pull to refresh apps"
          />
        }
      >
        <Text style={styles.lede}>
          Browse app directory listings, reviews, updates, saved apps, and followed apps.
        </Text>

        {/* ── Search bar ───────────────────────────────────────────────── */}
        <View style={{ flexDirection: 'row', alignItems: 'center',
          backgroundColor: colors.inputBackground, borderRadius: 10, borderWidth: 1,
          borderColor: colors.border, paddingHorizontal: 10, paddingVertical: 8, marginBottom: 10 }}>
          <Ionicons name="search" size={16} color={colors.textSecondary} style={{ marginRight: 6 }}
            accessibilityElementsHidden />
          <TextInput
            value={searchQuery}
            onChangeText={setSearchQuery}
            placeholder="Search apps, developers, categories…"
            placeholderTextColor={colors.textSecondary}
            style={{ flex: 1, fontSize: 15, color: colors.text }}
            accessible
            accessibilityLabel="Search apps"
            accessibilityHint="Type to filter apps by name, developer, or category"
            returnKeyType="search"
            clearButtonMode="while-editing"
          />
        </View>

        {/* ── Action bar: sort + category filter + count ───────────────── */}
        <View style={{ flexDirection: 'row', alignItems: 'center',
          gap: 8, marginBottom: 8, flexWrap: 'wrap' }}>

          {/* Sort pill */}
          <Pressable
            onPress={() => { setShowCategoryPicker(false); setShowSortSheet(v => !v); }}
            accessible accessibilityRole="button"
            accessibilityLabel={`Sort: ${APP_SORT_OPTIONS.find(s => s.value === sortOrder)?.label ?? sortOrder}. Double tap to change.`}
            style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
              backgroundColor: sortOrder !== 'updated' ? colors.accent + '22' : colors.pill,
              borderRadius: 20, paddingHorizontal: 12, paddingVertical: 6,
              borderWidth: 1, borderColor: sortOrder !== 'updated' ? colors.accent : colors.border }}
          >
            <Ionicons name="swap-vertical-outline" size={14}
              color={sortOrder !== 'updated' ? colors.accent : colors.textSecondary}
              accessibilityElementsHidden />
            <Text style={{ fontSize: 13, fontWeight: '500',
              color: sortOrder !== 'updated' ? colors.accent : colors.text }}>
              {APP_SORT_OPTIONS.find(s => s.value === sortOrder)?.label ?? 'Sort'}
            </Text>
            {sortOrder !== 'updated' && (
              <View style={{ width: 6, height: 6, borderRadius: 3,
                backgroundColor: colors.accent }} accessibilityElementsHidden />
            )}
          </Pressable>

          {/* Category filter pill */}
          {allCategories.length > 2 && (
            categoryFilter !== 'All Categories' ? (
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4,
                backgroundColor: colors.accent + '22', borderRadius: 20,
                paddingVertical: 6, paddingLeft: 12, paddingRight: 6,
                borderWidth: 1, borderColor: colors.accent }}>
                <Text style={{ fontSize: 13, fontWeight: '500', color: colors.accent }}
                  numberOfLines={1}>
                  {categoryFilter}
                </Text>
                <Pressable
                  onPress={() => setCategoryFilter('All Categories')}
                  accessible accessibilityRole="button"
                  accessibilityLabel={`Clear category filter: ${categoryFilter}`}
                  hitSlop={10}>
                  <Ionicons name="close-circle" size={17} color={colors.accent} />
                </Pressable>
              </View>
            ) : (
              <Pressable
                onPress={() => { setShowSortSheet(false); setShowCategoryPicker(v => !v); }}
                accessible accessibilityRole="button"
                accessibilityLabel="Filter by category. Double tap to pick a category."
                style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                  backgroundColor: colors.pill, borderRadius: 20,
                  paddingHorizontal: 12, paddingVertical: 6,
                  borderWidth: 1, borderColor: colors.border }}
              >
                <Ionicons name="grid-outline" size={14} color={colors.textSecondary}
                  accessibilityElementsHidden />
                <Text style={{ fontSize: 13, fontWeight: '500', color: colors.text }}>
                  All Categories
                </Text>
                <Ionicons name="chevron-down" size={12} color={colors.textSecondary}
                  accessibilityElementsHidden />
              </Pressable>
            )
          )}

          {/* App count */}
          <Text style={{ marginLeft: 'auto', fontSize: 13, color: colors.textSecondary }}
            accessibilityElementsHidden>
            {visibleApps.length} app{visibleApps.length === 1 ? '' : 's'}
          </Text>
        </View>

        {/* Sort sheet */}
        {showSortSheet && (
          <GlassView intensity={60} style={[styles.card, { marginBottom: 10, padding: 4 }]}
            accessible accessibilityRole="menu" accessibilityLabel="Sort order">
            {APP_SORT_OPTIONS.map(opt => (
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

        {/* Category picker sheet */}
        {showCategoryPicker && allCategories.length > 2 && (
          <GlassView intensity={60} style={[styles.card, { marginBottom: 10, padding: 4 }]}
            accessible accessibilityRole="menu" accessibilityLabel="Filter by category">
            {allCategories.map(cat => (
              <Pressable
                key={cat}
                onPress={() => { setCategoryFilter(cat); setShowCategoryPicker(false); }}
                accessible accessibilityRole="menuitem"
                accessibilityLabel={cat}
                accessibilityState={{ selected: categoryFilter === cat }}
                style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
                  paddingHorizontal: 12, paddingVertical: 12 }}
              >
                <Text style={{ fontSize: 15,
                  color: categoryFilter === cat ? colors.accent : colors.text,
                  fontWeight: categoryFilter === cat ? '600' : '400' }}>
                  {cat}
                </Text>
                {categoryFilter === cat && (
                  <Ionicons name="checkmark" size={18} color={colors.accent} accessibilityElementsHidden />
                )}
              </Pressable>
            ))}
          </GlassView>
        )}

        <OfflineBanner fromCache={list.fromCache} cachedAt={list.cachedAt} />

        {list.loading && (
          <View style={{ alignItems: 'center', paddingVertical: 32 }}>
            <ActivityIndicator size="large" color={colors.appleVisBlue} />
            <Text style={[styles.lede, { marginTop: 12, textAlign: 'center' }]}>Loading apps…</Text>
          </View>
        )}

        {!list.loading && list.error && (
          <View style={[styles.card, { backgroundColor: '#FFF0F0' }]}>
            <Text style={[styles.cardTitle, { color: '#D00' }]}>Could not load apps</Text>
            <Text style={styles.cardMeta}>{list.error}</Text>
            <Pressable
              onPress={list.refresh}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Retry loading apps"
              style={{ marginTop: 12 }}
            >
              <Text style={{ color: colors.appleVisBlue, fontWeight: '700' }}>Retry</Text>
            </Pressable>
          </View>
        )}

        {!list.loading && !list.error && list.apps.length === 0 && (
          <View style={[styles.card, { alignItems: 'center', paddingVertical: 32 }]}>
            <Text style={styles.cardTitle}>No apps yet</Text>
          </View>
        )}

        {!list.loading && list.apps.length > 0 && visibleApps.length === 0 && (
          <View style={[styles.card, { alignItems: 'center', paddingVertical: 32 }]}>
            <Text style={styles.cardTitle}>No results</Text>
            <Text style={[styles.cardMeta, { textAlign: 'center', marginTop: 4 }]}>
              {searchQuery.trim()
                ? `No apps match "${searchQuery}". Try a different search.`
                : `No apps in the "${categoryFilter}" category yet.`}
            </Text>
          </View>
        )}

        {!list.loading && visibleApps.map((app) => (
          <AccessibleCard
            key={app.id}
            ref={(el) => {
              if (el) appRefs.current.set(app.id, el);
              else appRefs.current.delete(app.id);
            }}
            title={app.name}
            meta={[
              app.developer || null,
              app.category  || null,
              app.reviewCount > 0 ? `${app.reviewCount} reviews` : null,
              `Updated ${new Date(app.lastUpdatedAt).toLocaleDateString()}`,
            ].filter(Boolean).join(' · ')}
            actions={['Open App Page', 'Save App', ...(!screenReaderEnabled ? ['Read Aloud'] : []), 'Translate', 'Summarise Reviews', 'Accessibility Consensus', 'Simplify', 'Share', 'View Reviews']}
            onAction={(action) => {
              if (action === 'Open App Page') {
                save(appRefs.current.get(app.id) ?? null);
                donateSiriActivity({ type: 'searchApps', query: app.name });
                router.push({ pathname: '/app-detail/[id]' as any, params: { id: app.id, name: app.name } });
              } else if (action === 'Read Aloud') {
                readAloud([app.name, app.summary].filter(Boolean).join('. '));
              } else if (action === 'Translate') {
                translateContent([app.name, app.summary].filter(Boolean).join('\n\n'), app.name);
              } else if (action === 'Summarise Reviews') {
                summariseText(`Summarise accessibility reviews for ${app.name}: ${app.summary}`).then((s) => {
                  if (s) showToast(s, 'success');
                  else showToast('Review summarisation coming when Apple Intelligence Foundation Models support is added.', 'warning');
                });
              } else if (action === 'Accessibility Consensus') {
                accessibilityConsensus([app.summary]).then((s) => {
                  if (s) showToast(s, 'success');
                  else showToast('Accessibility consensus coming when Apple Intelligence Foundation Models support is added.', 'warning');
                });
              } else if (action === 'Simplify') {
                simplifyText(app.summary).then((s) => {
                  if (s) showToast(s, 'success');
                  else showToast('Plain-language simplification coming when Apple Intelligence Foundation Models support is added.', 'warning');
                });
              } else if (action === 'Share') {
                Share.share({
                  title: app.name,
                  message: `${app.name} on AppleVis — https://www.applevis.com/accessibility-apps`,
                }).catch(() => {});
              }
            }}
          />
        ))}

        <LoadMoreButton
          hasMore={list.hasMore}
          isLoadingMore={list.isLoadingMore}
          onPress={list.loadMore}
        />

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
