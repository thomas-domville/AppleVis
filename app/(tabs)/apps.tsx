import { useRef } from 'react';
import { ActivityIndicator, Pressable, RefreshControl, ScrollView, Share, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Screen } from '../../src/components/Screen';
import { AccessibleCard } from '../../src/components/AccessibleCard';
import { OfflineBanner } from '../../src/components/OfflineBanner';
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
  const router         = useRouter();
  const { colors, styles } = useTheme();
  const { screenReaderEnabled } = useAccessibilityPreferences();
  const list           = useAppList();
  const { showToast }  = useToast();
  const appRefs = useRef<Map<string, View>>(new Map());
  const { save } = useFocusRestore();
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

        {!list.loading && list.apps.map((app) => (
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
