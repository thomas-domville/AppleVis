import { useMemo, useRef, useState } from 'react';
import { ActivityIndicator, Clipboard, Pressable, RefreshControl, ScrollView, Share, Text, TextInput, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../../src/components/Screen';
import { AccessibleCard } from '../../src/components/AccessibleCard';
import { OfflineBanner } from '../../src/components/OfflineBanner';
import { LoadMoreButton } from '../../src/components/LoadMoreButton';
import { useResourceList } from '../../src/hooks/useResourceList';
import { useRefreshFeedback } from '../../src/hooks/useRefreshFeedback';
import { useFocusRestore } from '../../src/hooks/useFocusRestore';
import { useHandoff } from '../../src/hooks/useHandoff';
import { GlassView } from '../../src/components/GlassView';
import { useToast } from '../../src/contexts/ToastContext';
import { translateContent, readAloud, summariseText, simplifyText } from '../../src/services/intelligenceService';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';

type ResourceSortOrder = 'updated' | 'oldest' | 'az';
const RESOURCE_SORT_OPTIONS: { value: ResourceSortOrder; label: string }[] = [
  { value: 'updated', label: 'Recently updated' },
  { value: 'oldest',  label: 'Oldest first' },
  { value: 'az',      label: 'A–Z' },
];

const KIND_LABELS: Record<string, string> = {
  guide: 'Guide', tutorial: 'Tutorial', article: 'Article',
  event: 'Event', developer: 'Developer',
};

export default function Resources() {
  const router        = useRouter();
  const { colors, styles } = useTheme();
  const { screenReaderEnabled } = useAccessibilityPreferences();
  const list          = useResourceList();
  const { showToast } = useToast();
  const resourceRefs = useRef<Map<string, View>>(new Map());
  const { save }     = useFocusRestore();

  const [searchQuery, setSearchQuery]         = useState('');
  const [sortOrder, setSortOrder]             = useState<ResourceSortOrder>('updated');
  const [kindFilter, setKindFilter]           = useState<string>('All Types');
  const [showSortSheet, setShowSortSheet]     = useState(false);
  const [showKindPicker, setShowKindPicker]   = useState(false);

  const kindOptions = useMemo(() => {
    const kinds = new Set<string>();
    list.resources.forEach(r => kinds.add(r.kind));
    return ['All Types', ...Array.from(kinds).sort()];
  }, [list.resources]);

  const visibleResources = useMemo(() => {
    let result = list.resources;
    if (kindFilter !== 'All Types') {
      result = result.filter(r => r.kind === kindFilter);
    }
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      result = result.filter(r =>
        r.title.toLowerCase().includes(q) ||
        r.kind.toLowerCase().includes(q) ||
        (KIND_LABELS[r.kind] ?? '').toLowerCase().includes(q));
    }
    switch (sortOrder) {
      case 'oldest': return [...result].sort((a, b) =>
        new Date(a.updatedAt).getTime() - new Date(b.updatedAt).getTime());
      case 'az':     return [...result].sort((a, b) => a.title.localeCompare(b.title));
      default:       return [...result].sort((a, b) =>
        new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime());
    }
  }, [list.resources, searchQuery, sortOrder, kindFilter]);

  useRefreshFeedback(list.refreshing, 'Resources', list.loading,
    () => resourceRefs.current.get(list.resources[0]?.id ?? '') ?? null);

  useHandoff({
    activityType: 'com.applevis.app.viewResources',
    title: 'AppleVis Resources',
    webpageURL: 'https://www.applevis.com/resources',
  });

  return (
    <Screen title="Resources" refreshing={list.refreshing} showSearch showBack={false}>
      <ScrollView
        refreshControl={
          <RefreshControl
            refreshing={list.refreshing}
            onRefresh={list.refresh}
            tintColor={colors.appleVisBlue}
            accessibilityLabel="Pull to refresh resources"
          />
        }
      >
        <Text style={styles.lede}>
          Guides, tutorials, how-to articles, accessibility resources, events, developer resources, and getting-started content.
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
            placeholder="Search resources…"
            placeholderTextColor={colors.textSecondary}
            style={{ flex: 1, fontSize: 15, color: colors.text }}
            accessible
            accessibilityLabel="Search resources"
            accessibilityHint="Type to filter resources by title or type"
            returnKeyType="search"
            clearButtonMode="while-editing"
          />
        </View>

        {/* ── Action bar: sort + type filter + count ───────────────────── */}
        <View style={{ flexDirection: 'row', alignItems: 'center',
          gap: 8, marginBottom: 8, flexWrap: 'wrap' }}>

          {/* Sort pill */}
          <Pressable
            onPress={() => { setShowKindPicker(false); setShowSortSheet(v => !v); }}
            accessible accessibilityRole="button"
            accessibilityLabel={`Sort: ${RESOURCE_SORT_OPTIONS.find(s => s.value === sortOrder)?.label ?? sortOrder}. Double tap to change.`}
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
              {RESOURCE_SORT_OPTIONS.find(s => s.value === sortOrder)?.label ?? 'Sort'}
            </Text>
            {sortOrder !== 'updated' && (
              <View style={{ width: 6, height: 6, borderRadius: 3,
                backgroundColor: colors.accent }} accessibilityElementsHidden />
            )}
          </Pressable>

          {/* Type filter pill */}
          {kindOptions.length > 2 && (
            kindFilter !== 'All Types' ? (
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4,
                backgroundColor: colors.accent + '22', borderRadius: 20,
                paddingVertical: 6, paddingLeft: 12, paddingRight: 6,
                borderWidth: 1, borderColor: colors.accent }}>
                <Text style={{ fontSize: 13, fontWeight: '500', color: colors.accent }}>
                  {KIND_LABELS[kindFilter] ?? kindFilter}
                </Text>
                <Pressable
                  onPress={() => setKindFilter('All Types')}
                  accessible accessibilityRole="button"
                  accessibilityLabel={`Clear type filter: ${KIND_LABELS[kindFilter] ?? kindFilter}`}
                  hitSlop={10}>
                  <Ionicons name="close-circle" size={17} color={colors.accent} />
                </Pressable>
              </View>
            ) : (
              <Pressable
                onPress={() => { setShowSortSheet(false); setShowKindPicker(v => !v); }}
                accessible accessibilityRole="button"
                accessibilityLabel="Filter by type. Double tap to pick a resource type."
                style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                  backgroundColor: colors.pill, borderRadius: 20,
                  paddingHorizontal: 12, paddingVertical: 6,
                  borderWidth: 1, borderColor: colors.border }}
              >
                <Ionicons name="bookmark-outline" size={14} color={colors.textSecondary}
                  accessibilityElementsHidden />
                <Text style={{ fontSize: 13, fontWeight: '500', color: colors.text }}>All Types</Text>
                <Ionicons name="chevron-down" size={12} color={colors.textSecondary}
                  accessibilityElementsHidden />
              </Pressable>
            )
          )}

          {/* Resource count */}
          <Text style={{ marginLeft: 'auto', fontSize: 13, color: colors.textSecondary }}
            accessibilityElementsHidden>
            {visibleResources.length} resource{visibleResources.length === 1 ? '' : 's'}
          </Text>
        </View>

        {/* Sort sheet */}
        {showSortSheet && (
          <GlassView intensity={60} style={[styles.card, { marginBottom: 10, padding: 4 }]}
            accessible accessibilityRole="menu" accessibilityLabel="Sort order">
            {RESOURCE_SORT_OPTIONS.map(opt => (
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

        {/* Type picker sheet */}
        {showKindPicker && kindOptions.length > 2 && (
          <GlassView intensity={60} style={[styles.card, { marginBottom: 10, padding: 4 }]}
            accessible accessibilityRole="menu" accessibilityLabel="Filter by type">
            {kindOptions.map(kind => (
              <Pressable
                key={kind}
                onPress={() => { setKindFilter(kind); setShowKindPicker(false); }}
                accessible accessibilityRole="menuitem"
                accessibilityLabel={kind === 'All Types' ? 'All Types' : (KIND_LABELS[kind] ?? kind)}
                accessibilityState={{ selected: kindFilter === kind }}
                style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
                  paddingHorizontal: 12, paddingVertical: 12 }}
              >
                <Text style={{ fontSize: 15,
                  color: kindFilter === kind ? colors.accent : colors.text,
                  fontWeight: kindFilter === kind ? '600' : '400' }}>
                  {kind === 'All Types' ? 'All Types' : (KIND_LABELS[kind] ?? kind)}
                </Text>
                {kindFilter === kind && (
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
            <Text style={[styles.lede, { marginTop: 12, textAlign: 'center' }]}>Loading resources…</Text>
          </View>
        )}

        {!list.loading && list.error && (
          <View style={[styles.card, { backgroundColor: '#FFF0F0' }]}>
            <Text style={[styles.cardTitle, { color: '#D00' }]}>Could not load resources</Text>
            <Text style={styles.cardMeta}>{list.error}</Text>
            <Pressable
              onPress={list.refresh}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Retry loading resources"
              style={{ marginTop: 12 }}
            >
              <Text style={{ color: colors.appleVisBlue, fontWeight: '700' }}>Retry</Text>
            </Pressable>
          </View>
        )}

        {!list.loading && !list.error && list.resources.length === 0 && (
          <View style={[styles.card, { alignItems: 'center', paddingVertical: 32 }]}>
            <Text style={styles.cardTitle}>No resources yet</Text>
          </View>
        )}

        {!list.loading && list.resources.length > 0 && visibleResources.length === 0 && (
          <View style={[styles.card, { alignItems: 'center', paddingVertical: 32 }]}>
            <Text style={styles.cardTitle}>No results</Text>
            <Text style={[styles.cardMeta, { textAlign: 'center', marginTop: 4 }]}>
              {searchQuery.trim()
                ? `No resources match "${searchQuery}". Try a different search.`
                : `No ${KIND_LABELS[kindFilter] ?? kindFilter} resources yet.`}
            </Text>
          </View>
        )}

        {!list.loading && visibleResources.map((item) => (
          <AccessibleCard
            key={item.id}
            ref={(el) => {
              if (el) resourceRefs.current.set(item.id, el);
              else resourceRefs.current.delete(item.id);
            }}
            title={item.title}
            meta={[item.kind, `Updated ${new Date(item.updatedAt).toLocaleDateString()}`].join(' · ')}
            actions={['Open', 'Save', ...(!screenReaderEnabled ? ['Read Aloud'] : []), 'Translate', 'Summarise', 'Simplify', 'Share', 'Copy Link']}
            onAction={(action) => {
              if (action === 'Open') {
                save(resourceRefs.current.get(item.id) ?? null);
                router.push({ pathname: '/resource-detail/[id]' as any, params: { id: item.id, title: item.title, url: item.url } });
              } else if (action === 'Read Aloud') {
                readAloud([item.title, item.summary].filter(Boolean).join('. '));
              } else if (action === 'Translate') {
                translateContent([item.title, item.summary].filter(Boolean).join('\n\n'), item.title);
              } else if (action === 'Summarise') {
                summariseText([item.title, item.summary].filter(Boolean).join('\n')).then((s) => {
                  if (s) showToast(s, 'success');
                  else showToast('Summarisation coming when Apple Intelligence Foundation Models support is added.', 'warning');
                });
              } else if (action === 'Simplify') {
                simplifyText([item.title, item.summary].filter(Boolean).join('\n')).then((s) => {
                  if (s) showToast(s, 'success');
                  else showToast('Plain-language simplification coming when Apple Intelligence Foundation Models support is added.', 'warning');
                });
              } else if (action === 'Share') {
                Share.share({
                  title: item.title,
                  message: `${item.title} — https://www.applevis.com/resources`,
                }).catch(() => {});
              } else if (action === 'Copy Link') {
                Clipboard.setString(`https://www.applevis.com/resources`);
                showToast('Link copied.', 'success');
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
