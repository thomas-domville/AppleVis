import { useMemo, useRef, useState } from 'react';
import { ActivityIndicator, Clipboard, Pressable, RefreshControl, ScrollView, Share, Text, TextInput, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../../src/components/Screen';
import { AccessibleCard } from '../../src/components/AccessibleCard';
import { LoadMoreButton } from '../../src/components/LoadMoreButton';
import { useResourceList } from '../../src/hooks/useResourceList';
import { useRefreshFeedback } from '../../src/hooks/useRefreshFeedback';
import { useFocusRestore } from '../../src/hooks/useFocusRestore';
import { useHandoff } from '../../src/hooks/useHandoff';
import { useToast } from '../../src/contexts/ToastContext';
import { translateContent, readAloud, summariseText, simplifyText } from '../../src/services/intelligenceService';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';

export default function Resources() {
  const router             = useRouter();
  const { colors, styles } = useTheme();
  const { screenReaderEnabled } = useAccessibilityPreferences();
  const list               = useResourceList();
  const { showToast }      = useToast();
  const resourceRefs       = useRef<Map<string, View>>(new Map());
  const { save }           = useFocusRestore();

  const [searchQuery, setSearchQuery] = useState('');

  const visibleResources = useMemo(() => {
    if (!searchQuery.trim()) return list.resources;
    const q = searchQuery.toLowerCase();
    return list.resources.filter(r =>
      r.title.toLowerCase().includes(q) ||
      r.kind.toLowerCase().includes(q));
  }, [list.resources, searchQuery]);

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

        {!list.loading && list.resources.length > 0 && visibleResources.length === 0 && searchQuery.trim() && (
          <View style={[styles.card, { alignItems: 'center', paddingVertical: 32 }]}>
            <Text style={styles.cardTitle}>No results</Text>
            <Text style={[styles.cardMeta, { textAlign: 'center', marginTop: 4 }]}>
              No resources match "{searchQuery}". Try a different search.
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
