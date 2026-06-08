import { useEffect, useState } from 'react';
import {
  ActivityIndicator, Image, Linking, Pressable,
  ScrollView, Share, Text, View,
} from 'react-native';
import { useLocalSearchParams } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../../src/components/Screen';
import { WriteReviewModal } from '../../src/components/WriteReviewModal';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { useToast } from '../../src/contexts/ToastContext';
import { useSavedItems } from '../../src/hooks/useSavedItems';
import { useHandoff } from '../../src/hooks/useHandoff';
import { readAloud, accessibilityConsensus } from '../../src/services/intelligenceService';
import { api } from '../../src/services/api';
import { fetchItunesMetadata } from '../../src/services/itunesApi';
import { relativeTime } from '../../src/utils/relativeTime';
import type { AppDetail, AppReview } from '../../src/types/content';
import type { ItunesMetadata } from '../../src/services/itunesApi';

function stripHtml(html: string): string {
  return html.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
}

function formatLanguages(codes: string[]): string {
  if (codes.length === 0) return '';
  const names = codes.slice(0, 5).map((c) => {
    try { return new Intl.DisplayNames(['en'], { type: 'language' }).of(c) ?? c; }
    catch { return c; }
  });
  const extra = codes.length - names.length;
  return extra > 0 ? `${names.join(', ')} and ${extra} more` : names.join(', ');
}

// ─── Sub-components ───────────────────────────────────────────────────────────

function StarRow({ rating, size = 14, color = '#F5A623' }: {
  rating: number; size?: number; color?: string;
}) {
  return (
    <View style={{ flexDirection: 'row', gap: 2 }} accessibilityElementsHidden>
      {[1, 2, 3, 4, 5].map((s) => (
        <Ionicons
          key={s}
          name={s <= Math.round(rating) ? 'star' : 'star-outline'}
          size={size}
          color={color}
        />
      ))}
    </View>
  );
}

function MetaPill({ label, colors }: {
  label: string;
  colors: ReturnType<typeof useTheme>['colors'];
}) {
  return (
    <View style={{ backgroundColor: colors.pill, borderRadius: 8,
      paddingHorizontal: 10, paddingVertical: 4 }}>
      <Text style={{ color: colors.pillText, fontSize: 13, fontWeight: '600' }}>{label}</Text>
    </View>
  );
}

function SectionHeader({ title, colors, styles }: {
  title: string;
  colors: ReturnType<typeof useTheme>['colors'];
  styles: ReturnType<typeof useTheme>['styles'];
}) {
  return (
    <Text style={[styles.cardTitle, { marginTop: 8, marginBottom: 8 }]}
      accessibilityRole="header">
      {title}
    </Text>
  );
}

function ReviewCard({ review, colors, styles }: {
  review: AppReview;
  colors: ReturnType<typeof useTheme>['colors'];
  styles: ReturnType<typeof useTheme>['styles'];
}) {
  const plain = stripHtml(review.body);
  return (
    <View style={[styles.card, { marginBottom: 10 }]}
      accessible
      accessibilityLabel={[
        `Review by ${review.authorName}`,
        review.rating ? `${review.rating} out of 5 stars` : null,
        review.appVersion ? `Version ${review.appVersion}` : null,
        relativeTime(review.createdAt),
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
          <Text style={{ fontSize: 14, fontWeight: '700', color: colors.text }}>
            {review.authorName}
          </Text>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, marginTop: 2 }}>
            {review.rating ? <StarRow rating={review.rating} size={12} /> : null}
            <Text style={{ fontSize: 12, color: colors.textSecondary }}>
              {review.appVersion ? `v${review.appVersion}  ·  ` : ''}{relativeTime(review.createdAt)}
            </Text>
          </View>
        </View>
        {review.platform ? (
          <View style={{ backgroundColor: colors.pill, borderRadius: 6,
            paddingHorizontal: 6, paddingVertical: 2 }}>
            <Text style={{ color: colors.pillText, fontSize: 11, fontWeight: '600' }}>
              {review.platform}
            </Text>
          </View>
        ) : null}
      </View>
      <Text style={{ fontSize: 15, lineHeight: 23, color: colors.text }}>{plain}</Text>
    </View>
  );
}

// ─── iTunes metadata section ──────────────────────────────────────────────────

function ItunesSection({ meta, appStoreUrl, colors, styles }: {
  meta: ItunesMetadata;
  appStoreUrl: string;
  colors: ReturnType<typeof useTheme>['colors'];
  styles: ReturnType<typeof useTheme>['styles'];
}) {
  const [showAllNotes, setShowAllNotes] = useState(false);

  const notes = meta.releaseNotes.trim();
  const notesTruncated = notes.length > 280 && !showAllNotes;
  const notesDisplay   = notesTruncated ? notes.slice(0, 280).trimEnd() + '…' : notes;

  // Quick-facts grid: price, version, size, min iOS, age rating
  const facts: { label: string; value: string }[] = [
    { label: 'Price',       value: meta.price },
    { label: 'Version',     value: meta.version },
    ...(meta.fileSizeMb     ? [{ label: 'Size',       value: meta.fileSizeMb }]            : []),
    ...(meta.minimumOsVersion ? [{ label: 'Requires', value: `iOS ${meta.minimumOsVersion}+` }] : []),
    ...(meta.ageRating      ? [{ label: 'Rated',      value: meta.ageRating }]              : []),
    ...(meta.versionDate    ? [{ label: 'Released',   value: relativeTime(meta.versionDate) }] : []),
  ].filter((f) => f.value);

  const langs = formatLanguages(meta.languages);

  return (
    <>
      <SectionHeader title="App Store Information" colors={colors} styles={styles} />

      {/* Quick facts card */}
      <View style={[styles.card, { marginBottom: 10 }]}
        accessible
        accessibilityLabel={facts.map((f) => `${f.label}: ${f.value}`).join('. ')}>
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', rowGap: 14, columnGap: 0 }}>
          {facts.map((fact, i) => (
            <View key={i} style={{ width: '33.33%', paddingRight: 8 }}>
              <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary,
                textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 3 }}>
                {fact.label}
              </Text>
              <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>
                {fact.value}
              </Text>
            </View>
          ))}
        </View>
      </View>

      {/* App Store rating */}
      {meta.appStoreRating != null && meta.appStoreRatingCount > 0 ? (
        <View style={[styles.card, { marginBottom: 10, flexDirection: 'row',
          alignItems: 'center', gap: 12 }]}
          accessible
          accessibilityLabel={`App Store rating: ${meta.appStoreRating.toFixed(1)} out of 5 stars from ${meta.appStoreRatingCount.toLocaleString()} ratings. Note: this is the general App Store rating, not the AppleVis accessibility rating.`}>
          <View style={{ alignItems: 'center', minWidth: 56 }}>
            <Text style={{ fontSize: 36, fontWeight: '800', color: colors.text, lineHeight: 40 }}>
              {meta.appStoreRating.toFixed(1)}
            </Text>
            <StarRow rating={meta.appStoreRating} size={13} />
          </View>
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: 14, fontWeight: '700', color: colors.text }}>
              App Store Rating
            </Text>
            <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2, lineHeight: 17 }}>
              {meta.appStoreRatingCount.toLocaleString()} ratings · General quality rating, separate from the AppleVis accessibility score
            </Text>
          </View>
        </View>
      ) : null}

      {/* Languages */}
      {langs ? (
        <View style={[styles.card, { marginBottom: 10 }]}
          accessible
          accessibilityLabel={`Supported languages: ${langs}`}>
          <Text style={{ fontSize: 12, fontWeight: '700', color: colors.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 6 }}>
            Languages
          </Text>
          <Text style={{ fontSize: 14, color: colors.text, lineHeight: 20 }}>{langs}</Text>
        </View>
      ) : null}

      {/* Developer website */}
      {meta.developerWebsite ? (
        <Pressable
          onPress={() => Linking.openURL(meta.developerWebsite!).catch(() => {})}
          accessible accessibilityRole="link"
          accessibilityLabel="Developer website"
          accessibilityHint="Opens the developer's website in Safari"
          style={({ pressed }) => [styles.card, {
            flexDirection: 'row', alignItems: 'center', gap: 10,
            marginBottom: 10, opacity: pressed ? 0.75 : 1,
          }]}>
          <Ionicons name="globe-outline" size={20} color={colors.accent} accessibilityElementsHidden />
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: 14, fontWeight: '700', color: colors.accent }}>
              Developer Website
            </Text>
            <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 1 }}
              numberOfLines={1}>
              {meta.developerWebsite.replace(/^https?:\/\//, '')}
            </Text>
          </View>
          <Ionicons name="open-outline" size={16} color={colors.textSecondary} accessibilityElementsHidden />
        </Pressable>
      ) : null}

      {/* What's new */}
      {notes ? (
        <>
          <SectionHeader title={`What's New in v${meta.version}`} colors={colors} styles={styles} />
          <View style={[styles.card, { marginBottom: 10 }]}
            accessible
            accessibilityLabel={`What's new in version ${meta.version}: ${notes}`}>
            <Text style={{ fontSize: 15, lineHeight: 23, color: colors.text }}>
              {notesDisplay}
            </Text>
            {notes.length > 280 ? (
              <Pressable
                onPress={() => setShowAllNotes((v) => !v)}
                accessible accessibilityRole="button"
                accessibilityLabel={showAllNotes ? 'Show less' : 'Read more release notes'}
                style={{ marginTop: 10 }}>
                <Text style={{ fontSize: 14, fontWeight: '700', color: colors.accent }}>
                  {showAllNotes ? 'Show less' : 'Read more'}
                </Text>
              </Pressable>
            ) : null}
          </View>
        </>
      ) : null}

      {/* Screenshots — useful for low-vision users */}
      {meta.screenshotUrls.length > 0 ? (
        <>
          <SectionHeader title="Screenshots" colors={colors} styles={styles} />
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={{ gap: 10, paddingBottom: 4 }}
            accessibilityLabel="App screenshots"
            style={{ marginBottom: 10 }}
          >
            {meta.screenshotUrls.map((url, i) => (
              <Image
                key={url}
                source={{ uri: url }}
                style={{ width: 160, height: 284, borderRadius: 12 }}
                accessible
                accessibilityLabel={`Screenshot ${i + 1} of ${meta.screenshotUrls.length}`}
              />
            ))}
          </ScrollView>
        </>
      ) : null}
    </>
  );
}

// ─── Main screen ──────────────────────────────────────────────────────────────

export default function AppDetailScreen() {
  const { id, name: paramName } = useLocalSearchParams<{ id: string; name?: string }>();
  const { colors, styles }      = useTheme();
  const { screenReaderEnabled } = useAccessibilityPreferences();
  const { showToast }           = useToast();
  const saved                   = useSavedItems('appListing');

  const [app,         setApp]         = useState<AppDetail | null>(null);
  const [loading,     setLoading]     = useState(true);
  const [error,       setError]       = useState<string | null>(null);
  const [showReview,  setShowReview]  = useState(false);
  const [itunes,      setItunes]      = useState<ItunesMetadata | null>(null);

  useHandoff(app ? {
    activityType: 'com.applevis.app.viewApp',
    title: app.name,
    webpageURL: 'https://www.applevis.com/accessibility-apps',
  } : null);

  useEffect(() => {
    if (!id) return;
    api.apps.detail(id).then((res) => {
      setLoading(false);
      if (res.ok) {
        setApp(res.data);
        // Fire iTunes lookup in background once we have the App Store URL
        if (res.data.appStoreUrl) {
          fetchItunesMetadata(res.data.appStoreUrl).then(setItunes).catch(() => {});
        }
      } else {
        setError(res.error);
      }
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

  function handleShare() {
    if (!app) return;
    Share.share({
      title: app.name,
      message: `${app.name} on AppleVis — https://www.applevis.com/accessibility-apps`,
    }).catch(() => {});
  }

  const displayTitle = app?.name ?? paramName ?? 'App';

  return (
    <Screen title={displayTitle} showSettings={false} showSearch={false}>
      <ScrollView
        showsVerticalScrollIndicator
        contentContainerStyle={{ padding: 16, paddingBottom: 40 }}
      >

        {/* ── Loading ─────────────────────────────────────────────────── */}
        {loading && (
          <View style={{ alignItems: 'center', paddingVertical: 48 }}>
            <ActivityIndicator size="large" color={colors.accent} />
            <Text style={[styles.cardMeta, { marginTop: 12, textAlign: 'center' }]}>
              Loading app…
            </Text>
          </View>
        )}

        {/* ── Error ───────────────────────────────────────────────────── */}
        {!loading && error && (
          <View style={[styles.card, { borderColor: '#FCA5A5', borderWidth: 1 }]}>
            <Text style={[styles.cardTitle, { color: '#B91C1C' }]}>Could not load app</Text>
            <Text style={styles.cardMeta}>{error}</Text>
          </View>
        )}

        {/* ── App content ─────────────────────────────────────────────── */}
        {app && (
          <>
            {/* Header card — icon, title, developer, ratings */}
            <View style={[styles.card, { marginBottom: 10 }]}
              accessible
              accessibilityLabel={[
                app.name,
                app.developer ? `by ${app.developer}` : null,
                app.category  ? app.category            : null,
                itunes?.price ? itunes.price             : null,
                app.accessibilityRating != null
                  ? `AppleVis accessibility rating: ${app.accessibilityRating} out of 5`
                  : null,
                `${app.reviewCount} community reviews`,
                `Updated ${relativeTime(app.lastUpdatedAt)}`,
              ].filter(Boolean).join('. ')}>

              {/* Icon + name row */}
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 14 }}>
                {app.iconUrl ? (
                  <Image
                    source={{ uri: app.iconUrl }}
                    style={{ width: 72, height: 72, borderRadius: 16 }}
                    accessibilityElementsHidden
                  />
                ) : null}
                <View style={{ flex: 1 }}>
                  <Text style={{ fontSize: 21, fontWeight: '800', color: colors.text, lineHeight: 26 }}>
                    {app.name}
                  </Text>
                  {app.developer ? (
                    <Text style={{ fontSize: 14, color: colors.textSecondary, marginTop: 2 }}>
                      {app.developer}
                    </Text>
                  ) : null}
                  {/* Price badge — shown as soon as iTunes responds */}
                  {itunes?.price ? (
                    <View style={{ alignSelf: 'flex-start', backgroundColor: colors.accent,
                      borderRadius: 6, paddingHorizontal: 8, paddingVertical: 3, marginTop: 6 }}>
                      <Text style={{ color: '#FFF', fontSize: 13, fontWeight: '700' }}>
                        {itunes.price}
                      </Text>
                    </View>
                  ) : null}
                </View>
              </View>

              {/* AppleVis accessibility rating */}
              {app.accessibilityRating != null ? (
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8,
                  marginBottom: 12, paddingBottom: 12, borderBottomWidth: 1,
                  borderBottomColor: colors.border }}
                  accessible
                  accessibilityLabel={`AppleVis community accessibility rating: ${app.accessibilityRating} out of 5 stars`}>
                  <StarRow rating={app.accessibilityRating} size={17} />
                  <Text style={{ fontSize: 14, fontWeight: '700', color: colors.text }}>
                    {app.accessibilityRating}/5
                  </Text>
                  <Text style={{ fontSize: 13, color: colors.textSecondary }}>
                    AppleVis accessibility
                  </Text>
                </View>
              ) : null}

              {/* Meta pills */}
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: 14 }}>
                {app.category ? <MetaPill label={app.category} colors={colors} /> : null}
                {app.platform ? <MetaPill label={app.platform} colors={colors} /> : null}
                <MetaPill
                  label={`${app.reviewCount} ${app.reviewCount === 1 ? 'review' : 'reviews'}`}
                  colors={colors}
                />
                <MetaPill label={`Updated ${relativeTime(app.lastUpdatedAt)}`} colors={colors} />
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
                    borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8 }}>
                  <Ionicons name={isSaved ? 'bookmark' : 'bookmark-outline'} size={14}
                    color={isSaved ? colors.accentText : colors.pillText} accessibilityElementsHidden />
                  <Text style={{ color: isSaved ? colors.accentText : colors.pillText,
                    fontWeight: '600', fontSize: 13 }}>
                    {isSaved ? 'Saved' : 'Save'}
                  </Text>
                </Pressable>

                {app.appStoreUrl ? (
                  <Pressable
                    onPress={() => Linking.openURL(app.appStoreUrl).catch(() => {})}
                    accessible accessibilityRole="button" accessibilityLabel="View in App Store"
                    accessibilityHint="Opens the App Store listing"
                    style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                      backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8 }}>
                    <Ionicons name="logo-apple" size={14} color={colors.pillText} accessibilityElementsHidden />
                    <Text style={{ color: colors.pillText, fontWeight: '600', fontSize: 13 }}>App Store</Text>
                  </Pressable>
                ) : null}

                <Pressable
                  onPress={handleShare}
                  accessible accessibilityRole="button" accessibilityLabel="Share this app"
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                    backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8 }}>
                  <Ionicons name="share-outline" size={14} color={colors.pillText} accessibilityElementsHidden />
                  <Text style={{ color: colors.pillText, fontWeight: '600', fontSize: 13 }}>Share</Text>
                </Pressable>

                {!screenReaderEnabled ? (
                  <Pressable
                    onPress={() => readAloud(`${app.name}. ${stripHtml(app.summary)}`)}
                    accessible accessibilityRole="button" accessibilityLabel="Read description aloud"
                    style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                      backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8 }}>
                    <Ionicons name="volume-medium-outline" size={14} color={colors.pillText} accessibilityElementsHidden />
                    <Text style={{ color: colors.pillText, fontWeight: '600', fontSize: 13 }}>Read Aloud</Text>
                  </Pressable>
                ) : null}

                <Pressable
                  onPress={() =>
                    accessibilityConsensus(app.reviews.map((r) => r.body)).then((s) => {
                      if (s) showToast(s, 'success');
                      else showToast('Accessibility Consensus coming with Apple Intelligence.', 'warning');
                    })
                  }
                  accessible accessibilityRole="button" accessibilityLabel="Accessibility Consensus"
                  accessibilityHint="Uses Apple Intelligence to summarise what reviewers say about VoiceOver support"
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                    backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8 }}>
                  <Ionicons name="eye-outline" size={14} color={colors.pillText} accessibilityElementsHidden />
                  <Text style={{ color: colors.pillText, fontWeight: '600', fontSize: 13 }}>Consensus</Text>
                </Pressable>
              </View>
            </View>

            {/* About this App (AppleVis body) */}
            {app.body && stripHtml(app.body) ? (
              <>
                <SectionHeader title="About this App" colors={colors} styles={styles} />
                <View style={[styles.card, { marginBottom: 10 }]}
                  accessible accessibilityLabel={`About this app: ${stripHtml(app.body)}`}>
                  <Text style={{ fontSize: 15, lineHeight: 23, color: colors.text }}>
                    {stripHtml(app.body)}
                  </Text>
                </View>
              </>
            ) : null}

            {/* iTunes metadata — price, version, rating, languages, developer site, what's new, screenshots */}
            {itunes ? (
              <ItunesSection
                meta={itunes}
                appStoreUrl={app.appStoreUrl}
                colors={colors}
                styles={styles}
              />
            ) : app.appStoreUrl ? (
              /* Subtle loading indicator while iTunes fetch is in flight */
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8,
                paddingVertical: 12, paddingHorizontal: 4, marginBottom: 4 }}>
                <ActivityIndicator size="small" color={colors.textSecondary} />
                <Text style={{ fontSize: 13, color: colors.textSecondary }}>
                  Loading App Store information…
                </Text>
              </View>
            ) : null}

            {/* Community Reviews */}
            <View style={{ flexDirection: 'row', alignItems: 'center',
              justifyContent: 'space-between', marginTop: 8, marginBottom: 8 }}>
              <Text style={styles.cardTitle} accessibilityRole="header">
                {app.reviews.length > 0
                  ? `${app.reviews.length} Community ${app.reviews.length === 1 ? 'Review' : 'Reviews'}`
                  : 'Community Reviews'}
              </Text>
              <Pressable
                onPress={() => setShowReview(true)}
                accessible accessibilityRole="button" accessibilityLabel="Write a review"
                accessibilityHint="Opens a form to submit your accessibility review"
                style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                  backgroundColor: colors.accent, borderRadius: 8,
                  paddingHorizontal: 12, paddingVertical: 7 }}>
                <Ionicons name="pencil-outline" size={13} color="#FFF" accessibilityElementsHidden />
                <Text style={{ color: '#FFF', fontWeight: '700', fontSize: 13 }}>Write a Review</Text>
              </Pressable>
            </View>

            {app.reviews.length > 0
              ? app.reviews.map((review) => (
                <ReviewCard key={review.id} review={review} colors={colors} styles={styles} />
              ))
              : (
                <View style={[styles.card, { alignItems: 'center', paddingVertical: 28, marginBottom: 10 }]}>
                  <Ionicons name="chatbubble-outline" size={32} color={colors.textSecondary}
                    accessibilityElementsHidden style={{ marginBottom: 10 }} />
                  <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text, marginBottom: 6 }}>
                    No reviews yet
                  </Text>
                  <Text style={{ fontSize: 14, color: colors.textSecondary, textAlign: 'center' }}>
                    Be the first to share your accessibility experience.
                  </Text>
                </View>
              )
            }

            <WriteReviewModal
              visible={showReview}
              appId={id ?? ''}
              appName={app.name}
              onClose={() => setShowReview(false)}
              onSubmitted={() => setShowReview(false)}
            />
          </>
        )}

        <View style={{ height: 40 }} />
      </ScrollView>
    </Screen>
  );
}
