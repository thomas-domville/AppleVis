import { useEffect, useState } from 'react';
import { ActivityIndicator, Linking, Pressable, ScrollView, Text, View } from 'react-native';
import { useLocalSearchParams } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../../src/components/Screen';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { useToast } from '../../src/contexts/ToastContext';
import { useSavedItems } from '../../src/hooks/useSavedItems';
import { useHandoff } from '../../src/hooks/useHandoff';
import { readAloud, accessibilityConsensus } from '../../src/services/intelligenceService';
import { api } from '../../src/services/api';
import type { AppDetail, AppReview } from '../../src/types/content';

function formatDate(iso: string): string {
  if (!iso) return '';
  return new Date(iso).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
}

function stripHtml(html: string): string {
  return html.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
}

function ReviewCard({ review, colors, styles }: {
  review: AppReview;
  colors: ReturnType<typeof useTheme>['colors'];
  styles: ReturnType<typeof useTheme>['styles'];
}) {
  const plain = stripHtml(review.body);
  return (
    <View style={styles.card}
      accessible
      accessibilityLabel={[
        `Review by ${review.authorName}`,
        review.appVersion ? `Version ${review.appVersion}` : null,
        formatDate(review.createdAt),
        plain,
      ].filter(Boolean).join('. ')}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 8 }}>
        <View style={{ width: 28, height: 28, borderRadius: 14, backgroundColor: colors.pill,
          alignItems: 'center', justifyContent: 'center' }} accessibilityElementsHidden>
          <Text style={{ fontSize: 13, fontWeight: '700', color: colors.pillText }}>
            {review.authorName.charAt(0).toUpperCase()}
          </Text>
        </View>
        <View style={{ flex: 1 }}>
          <Text style={{ fontSize: 14, fontWeight: '700', color: colors.text }}>{review.authorName}</Text>
          <Text style={{ fontSize: 12, color: colors.textSecondary }}>
            {review.appVersion ? `v${review.appVersion}  ·  ` : ''}{formatDate(review.createdAt)}
          </Text>
        </View>
        {review.platform && (
          <View style={{ backgroundColor: colors.pill, borderRadius: 6, paddingHorizontal: 6, paddingVertical: 2 }}>
            <Text style={{ color: colors.pillText, fontSize: 11, fontWeight: '600' }}>{review.platform}</Text>
          </View>
        )}
      </View>
      <Text style={{ fontSize: 15, lineHeight: 23, color: colors.text }}>{plain}</Text>
    </View>
  );
}

export default function AppDetailScreen() {
  const { id, name: paramName } = useLocalSearchParams<{ id: string; name?: string }>();
  const { colors, styles } = useTheme();
  const { screenReaderEnabled } = useAccessibilityPreferences();
  const { showToast }      = useToast();
  const saved              = useSavedItems('appListing');

  const [app,     setApp]     = useState<AppDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error,   setError]   = useState<string | null>(null);

  useHandoff(app ? {
    activityType: 'com.applevis.app.viewApp',
    title: app.name,
    webpageURL: `https://www.applevis.com/accessibility-apps`,
  } : null);

  useEffect(() => {
    if (!id) return;
    api.apps.detail(id).then((res) => {
      setLoading(false);
      if (res.ok) setApp(res.data); else setError(res.error);
    }).catch((err: unknown) => {
      setLoading(false);
      setError(err instanceof Error ? err.message : 'Unexpected error');
    });
  }, [id]);

  const isSaved = saved.isSaved(id ?? '');

  function handleSave() {
    if (!app) return;
    if (isSaved) {
      saved.unsave(id!);
      showToast('Removed from saved.', 'success');
    } else {
      saved.save({ id: id!, kind: 'appListing', title: app.name, savedAt: new Date().toISOString() });
      showToast('App saved.', 'success');
    }
  }

  const displayTitle = app?.name ?? paramName ?? 'App';

  return (
    <Screen title={displayTitle} showSettings={false} showSearch={false}>
      <ScrollView showsVerticalScrollIndicator={false}>

        {loading && (
          <View style={{ alignItems: 'center', paddingVertical: 48 }}>
            <ActivityIndicator size="large" color={colors.accent} />
            <Text style={[styles.cardMeta, { marginTop: 12, textAlign: 'center' }]}>Loading app...</Text>
          </View>
        )}

        {!loading && error && (
          <View style={[styles.card, { borderColor: '#FCA5A5', borderWidth: 1 }]}>
            <Text style={[styles.cardTitle, { color: '#B91C1C' }]}>Could not load app</Text>
            <Text style={styles.cardMeta}>{error}</Text>
          </View>
        )}

        {app && (
          <>
            {/* App header */}
            <View style={[styles.card, { marginBottom: 8 }]}
              accessible
              accessibilityLabel={[
                app.name,
                app.developer ? `by ${app.developer}` : null,
                app.category,
                `${app.reviewCount} reviews`,
                `Updated ${formatDate(app.lastUpdatedAt)}`,
              ].filter(Boolean).join('. ')}>

              {/* Meta row */}
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: 12 }}>
                {app.developer ? (
                  <View style={{ backgroundColor: colors.pill, borderRadius: 8,
                    paddingHorizontal: 10, paddingVertical: 4 }}>
                    <Text style={{ color: colors.pillText, fontSize: 13, fontWeight: '600' }}>{app.developer}</Text>
                  </View>
                ) : null}
                {app.category ? (
                  <View style={{ backgroundColor: colors.pill, borderRadius: 8,
                    paddingHorizontal: 10, paddingVertical: 4 }}>
                    <Text style={{ color: colors.pillText, fontSize: 13, fontWeight: '600' }}>{app.category}</Text>
                  </View>
                ) : null}
                <View style={{ backgroundColor: colors.pill, borderRadius: 8,
                  paddingHorizontal: 10, paddingVertical: 4 }}>
                  <Text style={{ color: colors.pillText, fontSize: 13, fontWeight: '600' }}>
                    {app.reviewCount} {app.reviewCount === 1 ? 'review' : 'reviews'}
                  </Text>
                </View>
              </View>

              {/* Summary */}
              {app.summary ? (
                <Text style={{ fontSize: 15, lineHeight: 23, color: colors.text, marginBottom: 14 }}>
                  {stripHtml(app.summary)}
                </Text>
              ) : null}

              {/* Action buttons */}
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
                <Pressable
                  onPress={handleSave}
                  accessible accessibilityRole="button"
                  accessibilityLabel={isSaved ? 'Unsave app' : 'Save app'}
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                    backgroundColor: isSaved ? colors.accent : colors.pill,
                    borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8 }}
                >
                  <Ionicons name={isSaved ? 'bookmark' : 'bookmark-outline'} size={14}
                    color={isSaved ? colors.accentText : colors.pillText} />
                  <Text style={{ color: isSaved ? colors.accentText : colors.pillText,
                    fontWeight: '600', fontSize: 13 }}>{isSaved ? 'Saved' : 'Save'}</Text>
                </Pressable>

                {app.appStoreUrl ? (
                  <Pressable
                    onPress={() => Linking.openURL(app.appStoreUrl)}
                    accessible accessibilityRole="button" accessibilityLabel="View in App Store"
                    accessibilityHint="Opens the App Store listing."
                    style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                      backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8 }}
                  >
                    <Ionicons name="logo-apple" size={14} color={colors.pillText} />
                    <Text style={{ color: colors.pillText, fontWeight: '600', fontSize: 13 }}>App Store</Text>
                  </Pressable>
                ) : null}

                {!screenReaderEnabled && (
                  <Pressable
                    onPress={() => readAloud(`${app.name}. ${stripHtml(app.summary)}`)}
                    accessible accessibilityRole="button" accessibilityLabel="Read description aloud"
                    style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                      backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8 }}
                  >
                    <Ionicons name="volume-medium-outline" size={14} color={colors.pillText} />
                    <Text style={{ color: colors.pillText, fontWeight: '600', fontSize: 13 }}>Read Aloud</Text>
                  </Pressable>
                )}

                <Pressable
                  onPress={() => accessibilityConsensus(app.reviews.map((r) => r.body)).then((s) => {
                    if (s) showToast(s, 'success');
                    else showToast('Accessibility Consensus coming with Apple Intelligence.', 'warning');
                  })}
                  accessible accessibilityRole="button" accessibilityLabel="Accessibility Consensus"
                  accessibilityHint="Summarises what reviewers say about VoiceOver support."
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                    backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8 }}
                >
                  <Ionicons name="eye-outline" size={14} color={colors.pillText} />
                  <Text style={{ color: colors.pillText, fontWeight: '600', fontSize: 13 }}>Consensus</Text>
                </Pressable>
              </View>
            </View>

            {/* Full body */}
            {app.body && stripHtml(app.body) ? (
              <>
                <Text style={[styles.cardTitle, { marginBottom: 8 }]} accessibilityRole="header">
                  About this App
                </Text>
                <View style={[styles.card, { marginBottom: 16 }]}
                  accessible accessibilityLabel={`About: ${stripHtml(app.body)}`}>
                  <Text style={{ fontSize: 15, lineHeight: 23, color: colors.text }}>
                    {stripHtml(app.body)}
                  </Text>
                </View>
              </>
            ) : null}

            {/* Reviews */}
            {app.reviews.length > 0 ? (
              <>
                <Text style={[styles.cardTitle, { marginBottom: 8 }]} accessibilityRole="header">
                  {app.reviews.length} Community {app.reviews.length === 1 ? 'Review' : 'Reviews'}
                </Text>
                {app.reviews.map((review) => (
                  <ReviewCard key={review.id} review={review} colors={colors} styles={styles} />
                ))}
              </>
            ) : !loading ? (
              <View style={[styles.card, { alignItems: 'center', paddingVertical: 24 }]}>
                <Text style={styles.cardMeta}>No community reviews yet.</Text>
              </View>
            ) : null}
          </>
        )}

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
