import { useMemo, useRef, useState } from 'react';
import { ActivityIndicator, Pressable, RefreshControl, ScrollView, Share, Text, TextInput, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../../src/components/Screen';
import { AccessibleCard } from '../../src/components/AccessibleCard';
import { LoadMoreButton } from '../../src/components/LoadMoreButton';
import { useAppList } from '../../src/hooks/useAppList';
import { useRefreshFeedback } from '../../src/hooks/useRefreshFeedback';
import { useFocusRestore } from '../../src/hooks/useFocusRestore';
import { useHandoff } from '../../src/hooks/useHandoff';
import { useToast } from '../../src/contexts/ToastContext';
import { translateContent, donateSiriActivity, readAloud, summariseText, simplifyText, accessibilityConsensus } from '../../src/services/intelligenceService';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';

export default function Apps() {
  const router             = useRouter();
  const { colors, styles } = useTheme();
  const { screenReaderEnabled } = useAccessibilityPreferences();
  const list               = useAppList();
  const { showToast }      = useToast();
  const appRefs            = useRef<Map<string, View>>(new Map());
  const { save }           = useFocusRestore();

  const [searchQuery, setSearchQuery] = useState('');

  const visibleApps = useMemo(() => {
    if (!searchQuery.trim()) return list.apps;
    const q = searchQuery.toLowerCase();
    return list.apps.filter(app =>
      app.name.toLowerCase().includes(q) ||
      app.developer.toLowerCase().includes(q) ||
      app.category.toLowerCase().includes(q));
  }, [list.apps, searchQuery]);

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

        {!list.loading && list.apps.length > 0 && visibleApps.length === 0 && searchQuery.trim() && (
          <View style={[styles.card, { alignItems: 'center', paddingVertical: 32 }]}>
            <Text style={styles.cardTitle}>No results</Text>
            <Text style={[styles.cardMeta, { textAlign: 'center', marginTop: 4 }]}>
              No apps match "{searchQuery}". Try a different search.
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
