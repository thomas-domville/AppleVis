import { useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActionSheetIOS, ActivityIndicator, Clipboard,
  findNodeHandle, Image, Linking, Platform, Pressable,
  ScrollView, Share, StyleSheet, Text, View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { Screen } from '../../src/components/Screen';
import { WriteReviewModal } from '../../src/components/WriteReviewModal';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { useAuth } from '../../src/contexts/AuthContext';
import { useToast } from '../../src/contexts/ToastContext';
import { useSavedItems } from '../../src/hooks/useSavedItems';
import { useHandoff } from '../../src/hooks/useHandoff';
import {
  readAloud, accessibilityConsensus, summariseText, isAppleIntelligenceAvailable,
} from '../../src/services/intelligenceService';
import { api } from '../../src/services/api';
import { fetchItunesMetadata } from '../../src/services/itunesApi';
import { relativeTime } from '../../src/utils/relativeTime';
import type { AppDetail, AppReview } from '../../src/types/content';
import type { ItunesMetadata } from '../../src/services/itunesApi';

// ─── HTML stripper — preserves link text and block structure ──────────────────

function stripHtml(html: string): string {
  return html
    .replace(/<a[^>]*href="([^"]*)"[^>]*>(.*?)<\/a>/gis, (_, href, inner) => {
      const t = inner.replace(/<[^>]*>/g, '').trim();
      return t ? `${t} (${href})` : href;
    })
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n\n')
    .replace(/<\/li>/gi, '\n')
    .replace(/<\/h[1-6]>/gi, '\n\n')
    .replace(/<[^>]*>/g, '')
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&#039;/g, "'").replace(/&apos;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
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

// ─── Bottom toolbar button ────────────────────────────────────────────────────

function ToolbarButton({
  icon, activeIcon, label, onPress, active, accent, disabled,
}: {
  icon: string; activeIcon?: string; label: string; onPress: () => void;
  active?: boolean; accent?: boolean; disabled?: boolean;
}) {
  const { colors } = useTheme();
  const resolvedIcon = (active && activeIcon) ? activeIcon : icon;
  const color = disabled
    ? colors.textSecondary
    : accent ? colors.accent
    : active ? colors.accent
    : colors.textSecondary;
  return (
    <Pressable
      onPress={disabled ? undefined : onPress}
      accessible
      accessibilityRole="button"
      accessibilityLabel={label.replace(/\n/g, ' ')}
      accessibilityState={{ selected: active, disabled }}
      style={({ pressed }) => ({
        flex: 1, alignItems: 'center', justifyContent: 'center',
        gap: 4, opacity: disabled ? 0.35 : pressed ? 0.55 : 1, paddingVertical: 10,
      })}
    >
      <Ionicons name={resolvedIcon as any} size={23} color={color} accessibilityElementsHidden />
      <Text
        style={{ fontSize: 10, fontWeight: '600', color, textAlign: 'center', lineHeight: 13 }}
        accessibilityElementsHidden
      >
        {label}
      </Text>
    </Pressable>
  );
}

// ─── Section divider ──────────────────────────────────────────────────────────

function SectionDivider({ label }: { label: string }) {
  const { colors } = useTheme();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginVertical: 16 }}>
      <View style={{ flex: 1, height: 1, backgroundColor: colors.border }} accessibilityElementsHidden />
      <Text
        style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
          textTransform: 'uppercase', letterSpacing: 0.7 }}
        accessibilityRole="header"
      >
        {label}
      </Text>
      <View style={{ flex: 1, height: 1, backgroundColor: colors.border }} accessibilityElementsHidden />
    </View>
  );
}

// ─── Coming-soon shell ────────────────────────────────────────────────────────

function ComingSoonShell({ icon, message }: { icon: string; message: string }) {
  const { colors } = useTheme();
  return (
    <View
      style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 12,
        backgroundColor: colors.pill, borderRadius: 12, padding: 14,
        borderWidth: 1, borderColor: colors.border, opacity: 0.7, marginBottom: 12 }}
      accessible
      accessibilityLabel={`${message} — coming soon.`}
    >
      <Ionicons name={icon as any} size={20} color={colors.textSecondary}
        accessibilityElementsHidden style={{ marginTop: 1 }} />
      <View style={{ flex: 1 }}>
        <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>{message}</Text>
        <View style={{ flexDirection: 'row', marginTop: 6 }}>
          <View style={{ paddingHorizontal: 8, paddingVertical: 2,
            backgroundColor: colors.card, borderRadius: 6, borderWidth: 1, borderColor: colors.border }}>
            <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary }}>COMING SOON</Text>
          </View>
        </View>
      </View>
    </View>
  );
}

// ─── Star row ─────────────────────────────────────────────────────────────────

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

// ─── Review card ─────────────────────────────────────────────────────────────

function ReviewCard({
  review, index, total, colors, styles, screenReaderEnabled, showToast,
}: {
  review: AppReview;
  index: number;
  total: number;
  colors: ReturnType<typeof useTheme>['colors'];
  styles: ReturnType<typeof useTheme>['styles'];
  screenReaderEnabled: boolean;
  showToast: (msg: string, type?: 'success' | 'warning' | 'error') => void;
}) {
  const plain = stripHtml(review.body);

  const reviewActions = [
    ...(!screenReaderEnabled
      ? [{ label: 'Read Aloud', action: () => readAloud(`Review by ${review.authorName}. ${plain}`) }]
      : []),
    { label: 'Copy Review Text', action: () => { Clipboard.setString(plain); showToast('Review text copied.', 'success'); } },
    { label: 'Share Review', action: () => Share.share({ message: `${review.authorName} on AppleVis: ${plain}` }).catch(() => {}) },
    { label: 'Mark as Helpful', action: () => showToast('Helpful votes — coming once the Drupal Flags API is confirmed.', 'warning') },
    { label: 'Report Review',   action: () => showToast('Reporting — coming once the Drupal Flags API is confirmed.', 'warning') },
  ];

  function handleLongPress() {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    if (Platform.OS === 'ios') {
      ActionSheetIOS.showActionSheetWithOptions(
        {
          title: `Review by ${review.authorName}`,
          options: ['Cancel', ...reviewActions.map(a => a.label)],
          cancelButtonIndex: 0,
        },
        (i) => { if (i > 0) reviewActions[i - 1].action(); },
      );
    }
  }

  const ratingLabel = review.rating ? `${review.rating} out of 5 stars. ` : '';
  const versionLabel = review.appVersion ? `Version ${review.appVersion}. ` : '';

  return (
    <Pressable
      onLongPress={handleLongPress}
      delayLongPress={400}
      accessible
      accessibilityLabel={
        `Review ${index + 1} of ${total} by ${review.authorName}. ` +
        ratingLabel + versionLabel +
        `${relativeTime(review.createdAt)}. ${plain}. Hold for options.`
      }
      accessibilityActions={reviewActions.map(a => ({ name: a.label, label: a.label }))}
      onAccessibilityAction={({ nativeEvent }) => {
        reviewActions.find(a => a.label === nativeEvent.actionName)?.action();
      }}
      style={[styles.card, { marginBottom: 10 }]}
    >
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 8 }}
        accessibilityElementsHidden>
        <View style={{ width: 32, height: 32, borderRadius: 16, backgroundColor: colors.pill,
          alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
          <Text style={{ fontSize: 14, fontWeight: '700', color: colors.pillText }}>
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
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
          {review.platform ? (
            <View style={{ backgroundColor: colors.pill, borderRadius: 6,
              paddingHorizontal: 6, paddingVertical: 2 }}>
              <Text style={{ color: colors.pillText, fontSize: 11, fontWeight: '600' }}>
                {review.platform}
              </Text>
            </View>
          ) : null}
          <Text style={{ fontSize: 11, color: colors.textSecondary, fontWeight: '500' }}>
            {index + 1}/{total}
          </Text>
        </View>
      </View>
      <Text style={{ fontSize: 15, lineHeight: 23, color: colors.text }} accessibilityElementsHidden>
        {plain}
      </Text>
    </Pressable>
  );
}

// ─── iTunes metadata section ──────────────────────────────────────────────────

function ItunesSection({
  meta, colors, styles,
}: {
  meta: ItunesMetadata;
  colors: ReturnType<typeof useTheme>['colors'];
  styles: ReturnType<typeof useTheme>['styles'];
}) {
  const [showAllNotes, setShowAllNotes]   = useState(false);
  const [showFullDesc, setShowFullDesc]   = useState(false);

  const notes = meta.releaseNotes.trim();
  const notesTruncated  = notes.length > 280 && !showAllNotes;
  const notesDisplay    = notesTruncated ? notes.slice(0, 280).trimEnd() + '…' : notes;

  const desc = meta.appStoreDescription.trim();
  const descTruncated   = desc.length > 400 && !showFullDesc;
  const descDisplay     = descTruncated ? desc.slice(0, 400).trimEnd() + '…' : desc;

  const facts: { label: string; value: string }[] = [
    { label: 'Price',    value: meta.price },
    { label: 'Version',  value: meta.version },
    ...(meta.fileSizeMb       ? [{ label: 'Size',    value: meta.fileSizeMb }]              : []),
    ...(meta.minimumOsVersion ? [{ label: 'Requires', value: `iOS ${meta.minimumOsVersion}+` }] : []),
    ...(meta.ageRating        ? [{ label: 'Rated',   value: meta.ageRating }]               : []),
    ...(meta.versionDate      ? [{ label: 'Released', value: relativeTime(meta.versionDate) }] : []),
  ].filter((f) => f.value);

  const langs = formatLanguages(meta.languages);

  return (
    <>
      <SectionDivider label="App Store Information" />

      {/* Quick facts */}
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
        <View style={[styles.card, { marginBottom: 10, flexDirection: 'row', alignItems: 'center', gap: 12 }]}
          accessible
          accessibilityLabel={`App Store rating: ${meta.appStoreRating.toFixed(1)} out of 5 from ${meta.appStoreRatingCount.toLocaleString()} ratings. This is the general App Store rating, separate from the AppleVis accessibility rating.`}>
          <View style={{ alignItems: 'center', minWidth: 56 }}>
            <Text style={{ fontSize: 36, fontWeight: '800', color: colors.text, lineHeight: 40 }}>
              {meta.appStoreRating.toFixed(1)}
            </Text>
            <StarRow rating={meta.appStoreRating} size={13} />
          </View>
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: 14, fontWeight: '700', color: colors.text }}>App Store Rating</Text>
            <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2, lineHeight: 17 }}>
              {meta.appStoreRatingCount.toLocaleString()} ratings · General quality,
              separate from AppleVis accessibility score
            </Text>
          </View>
        </View>
      ) : null}

      {/* Languages */}
      {langs ? (
        <View style={[styles.card, { marginBottom: 10 }]}
          accessible accessibilityLabel={`Supported languages: ${langs}`}>
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
            <Text style={{ fontSize: 14, fontWeight: '700', color: colors.accent }}>Developer Website</Text>
            <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 1 }} numberOfLines={1}>
              {meta.developerWebsite.replace(/^https?:\/\//, '')}
            </Text>
          </View>
          <Ionicons name="open-outline" size={16} color={colors.textSecondary} accessibilityElementsHidden />
        </Pressable>
      ) : null}

      {/* What's new */}
      {notes ? (
        <>
          <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text,
            marginTop: 4, marginBottom: 8 }} accessibilityRole="header">
            What's New in v{meta.version}
          </Text>
          <View style={[styles.card, { marginBottom: 10 }]}
            accessible accessibilityLabel={`What's new in version ${meta.version}: ${notes}`}>
            <Text style={{ fontSize: 15, lineHeight: 23, color: colors.text }}>{notesDisplay}</Text>
            {notes.length > 280 ? (
              <Pressable
                onPress={() => setShowAllNotes((v) => !v)}
                accessible accessibilityRole="button"
                accessibilityLabel={showAllNotes ? 'Show less release notes' : 'Read more release notes'}
                style={{ marginTop: 10 }}>
                <Text style={{ fontSize: 14, fontWeight: '700', color: colors.accent }}>
                  {showAllNotes ? 'Show less' : 'Read more'}
                </Text>
              </Pressable>
            ) : null}
          </View>
        </>
      ) : null}

      {/* App Store description — often different from AppleVis body */}
      {desc ? (
        <>
          <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text,
            marginTop: 4, marginBottom: 8 }} accessibilityRole="header">
            App Store Description
          </Text>
          <View style={[styles.card, { marginBottom: 10 }]}
            accessible accessibilityLabel={`App Store description: ${desc}`}>
            <Text style={{ fontSize: 15, lineHeight: 23, color: colors.text }}>{descDisplay}</Text>
            {desc.length > 400 ? (
              <Pressable
                onPress={() => setShowFullDesc((v) => !v)}
                accessible accessibilityRole="button"
                accessibilityLabel={showFullDesc ? 'Show less of App Store description' : 'Read full App Store description'}
                style={{ marginTop: 10 }}>
                <Text style={{ fontSize: 14, fontWeight: '700', color: colors.accent }}>
                  {showFullDesc ? 'Show less' : 'Read more'}
                </Text>
              </Pressable>
            ) : null}
          </View>
        </>
      ) : null}

      {/* Screenshots */}
      {meta.screenshotUrls.length > 0 ? (
        <>
          <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text,
            marginTop: 4, marginBottom: 8 }} accessibilityRole="header">
            Screenshots
          </Text>
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={{ gap: 10, paddingBottom: 4 }}
            accessibilityLabel={`${meta.screenshotUrls.length} app screenshots`}
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

const TOOLBAR_H = 58;

export default function AppDetailScreen() {
  const { id, name: paramName } = useLocalSearchParams<{ id: string; name?: string }>();
  const router                   = useRouter();
  const { colors, styles }       = useTheme();
  const { screenReaderEnabled }  = useAccessibilityPreferences();
  const auth                     = useAuth();
  const { showToast }            = useToast();
  const saved                    = useSavedItems('appListing');
  const aiAvailable              = isAppleIntelligenceAvailable();
  const insets                   = useSafeAreaInsets();

  const [app,          setApp]          = useState<AppDetail | null>(null);
  const [loading,      setLoading]      = useState(true);
  const [error,        setError]        = useState<string | null>(null);
  const [showReview,   setShowReview]   = useState(false);
  const [itunes,       setItunes]       = useState<ItunesMetadata | null>(null);
  const [itunesLoading,setItunesLoading]= useState(false);
  const [aiWorking,    setAiWorking]    = useState<'consensus' | 'summarise' | null>(null);

  const scrollRef  = useRef<ScrollView>(null);
  const heroRef    = useRef<View>(null);
  const reviewsY   = useRef<number>(0);

  useHandoff(app ? {
    activityType: 'com.applevis.app.viewApp',
    title: app.name,
    webpageURL: app.url ?? 'https://www.applevis.com/accessibility-apps',
  } : null);

  function loadApp() {
    if (!id) return;
    setLoading(true);
    setError(null);
    api.apps.detail(id).then((res) => {
      setLoading(false);
      if (res.ok) {
        setApp(res.data);
        setTimeout(() => {
          const node = heroRef.current ? findNodeHandle(heroRef.current) : null;
          if (node) AccessibilityInfo.setAccessibilityFocus(node);
        }, 350);
        if (res.data.appStoreUrl) {
          setItunesLoading(true);
          fetchItunesMetadata(res.data.appStoreUrl)
            .then((meta) => { setItunes(meta); setItunesLoading(false); })
            .catch(() => { setItunesLoading(false); });
        }
      } else {
        setError(res.error);
      }
    }).catch((err: unknown) => {
      setLoading(false);
      setError(err instanceof Error ? err.message : 'Unexpected error');
    });
  }

  useEffect(() => { loadApp(); }, [id]);

  // ── Handlers ────────────────────────────────────────────────────────────────

  const isSaved = saved.isSaved(id ?? '');

  function handleSave() {
    if (!app) return;
    if (isSaved) {
      saved.unsave(id!);
      showToast('Removed from saved.', 'success');
    } else {
      saved.save({ id: id!, kind: 'appListing', title: app.name, savedAt: new Date().toISOString() });
      showToast('App entry saved.', 'success');
    }
  }

  function handleOpenAppStore() {
    if (!app?.appStoreUrl) return;
    Linking.openURL(app.appStoreUrl).catch(() => showToast('Could not open the App Store.', 'error'));
  }

  function handleShare() {
    if (!app) return;
    Share.share({
      title: app.name,
      message: `${app.name} on AppleVis — ${app.url ?? 'https://www.applevis.com/accessibility-apps'}`,
    }).catch(() => {});
  }

  function handleCopyLink() {
    if (!app) return;
    const link = app.url ?? app.appStoreUrl ?? 'https://www.applevis.com/accessibility-apps';
    Clipboard.setString(link);
    showToast('Link copied.', 'success');
  }

  function handleOpenInBrowser() {
    if (!app) return;
    const link = app.url ?? 'https://www.applevis.com/accessibility-apps';
    Linking.openURL(link).catch(() => showToast('Could not open Safari.', 'error'));
  }

  function handleWriteReview() {
    if (!auth.isSignedIn) {
      showToast('Sign in to add a new comment.', 'warning');
      return;
    }
    setShowReview(true);
  }

  function handleReadAloud() {
    if (!app) return;
    readAloud(`${app.name}. ${app.developer ? `By ${app.developer}.` : ''} ${stripHtml(app.summary || app.body)}`);
  }

  function handleReadReviewsAloud() {
    if (!app || app.reviews.length === 0) return;
    const parts = app.reviews.map((r, i) => {
      const rating = r.rating ? `${r.rating} stars.` : '';
      return `Review ${i + 1} by ${r.authorName}. ${rating} ${stripHtml(r.body)}`;
    });
    readAloud(parts.join(' '));
  }

  async function handleAccessibilityConsensus() {
    if (!app) return;
    if (!aiAvailable) {
      showToast('Enable Apple Intelligence in Settings → Apple Intelligence & Siri to use this.', 'warning');
      return;
    }
    if (app.reviews.length === 0) {
      showToast('No reviews yet to analyse.', 'warning');
      return;
    }
    setAiWorking('consensus');
    const result = await accessibilityConsensus(app.reviews.map((r) => stripHtml(r.body)));
    setAiWorking(null);
    if (result) showToast(result, 'success');
    else showToast('Accessibility Consensus requires Apple Intelligence Foundation Models (iOS 18.1+).', 'warning');
  }

  async function handleSummariseReviews() {
    if (!app) return;
    if (!aiAvailable) {
      showToast('Enable Apple Intelligence in Settings → Apple Intelligence & Siri to use this.', 'warning');
      return;
    }
    if (app.reviews.length === 0) {
      showToast('No reviews yet to summarise.', 'warning');
      return;
    }
    setAiWorking('summarise');
    const combined = app.reviews.map((r, i) => `Review ${i + 1}: ${stripHtml(r.body)}`).join('\n');
    const result = await summariseText(`Accessibility reviews for ${app.name}:\n${combined}`);
    setAiWorking(null);
    if (result) showToast(result, 'success');
    else showToast('Summarisation requires Apple Intelligence Foundation Models (iOS 18.1+).', 'warning');
  }

  function handleJumpToReviews() {
    scrollRef.current?.scrollTo({ y: reviewsY.current, animated: true });
  }

  function handleBackToTop() {
    scrollRef.current?.scrollTo({ y: 0, animated: true });
  }

  const displayTitle = app?.name ?? paramName ?? 'App';
  const hasReviews   = (app?.reviews.length ?? 0) > 0;

  return (
    <Screen title={displayTitle} showSettings={false} showSearch={false}>
      <View style={{ flex: 1 }}>
      <ScrollView
        ref={scrollRef}
        showsVerticalScrollIndicator
        style={{ flex: 1 }}
        contentContainerStyle={{ padding: 16, paddingBottom: TOOLBAR_H + 16 }}
      >

        {/* ── Loading ─────────────────────────────────────────────────── */}
        {loading && (
          <View style={{ alignItems: 'center', paddingVertical: 48 }}>
            <ActivityIndicator size="large" color={colors.accent} accessibilityLabel="Loading app" />
            <Text style={[styles.cardMeta, { marginTop: 12, textAlign: 'center' }]}>Loading app…</Text>
          </View>
        )}

        {/* ── Error ───────────────────────────────────────────────────── */}
        {!loading && error && (
          <View style={[styles.card, { borderColor: '#FCA5A5', borderWidth: 1 }]}>
            <Text style={[styles.cardTitle, { color: '#B91C1C' }]}>Could not load app</Text>
            <Text style={styles.cardMeta}>{error}</Text>
            <Pressable onPress={loadApp} accessible accessibilityRole="button"
              accessibilityLabel="Retry loading app" style={{ marginTop: 12 }}>
              <Text style={{ color: colors.accent, fontWeight: '700' }}>Retry</Text>
            </Pressable>
          </View>
        )}

        {/* ── App content ─────────────────────────────────────────────── */}
        {app && (
          <>
            {/* ── Hero header ─────────────────────────────────────────── */}
            <View
              ref={heroRef}
              style={[styles.card, { marginBottom: 10 }]}
              accessible
              accessibilityLabel={[
                app.name,
                app.developer ? `by ${app.developer}` : null,
                app.category  ? app.category : null,
                app.platform  ? app.platform : null,
                itunes?.price ? itunes.price : null,
                app.accessibilityRating != null
                  ? `AppleVis accessibility rating ${app.accessibilityRating} out of 5`
                  : null,
                `${app.reviewCount} community ${app.reviewCount === 1 ? 'review' : 'reviews'}`,
                `Last updated ${relativeTime(app.lastUpdatedAt)}`,
              ].filter(Boolean).join('. ')}
            >
              {/* Icon + name */}
              <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 14, marginBottom: 14 }}
                accessibilityElementsHidden>
                {app.iconUrl ? (
                  <Image
                    source={{ uri: app.iconUrl }}
                    style={{ width: 72, height: 72, borderRadius: 16 }}
                    accessibilityElementsHidden
                  />
                ) : (
                  <View style={{ width: 72, height: 72, borderRadius: 16,
                    backgroundColor: colors.pill, alignItems: 'center', justifyContent: 'center' }}>
                    <Ionicons name="apps-outline" size={32} color={colors.textSecondary} />
                  </View>
                )}
                <View style={{ flex: 1 }}>
                  <Text style={{ fontSize: 21, fontWeight: '800', color: colors.text, lineHeight: 26 }}>
                    {app.name}
                  </Text>
                  {app.developer ? (
                    <Text style={{ fontSize: 14, color: colors.textSecondary, marginTop: 3 }}>
                      {app.developer}
                    </Text>
                  ) : null}
                  {itunes?.price ? (
                    <View style={{ alignSelf: 'flex-start', backgroundColor: colors.accent,
                      borderRadius: 6, paddingHorizontal: 8, paddingVertical: 3, marginTop: 8 }}>
                      <Text style={{ color: colors.accentText, fontSize: 13, fontWeight: '700' }}>
                        {itunes.price}
                      </Text>
                    </View>
                  ) : null}
                </View>
              </View>

              {/* AppleVis accessibility rating */}
              {app.accessibilityRating != null ? (
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8,
                  marginBottom: 12, paddingBottom: 12,
                  borderBottomWidth: 1, borderBottomColor: colors.border }}
                  accessibilityElementsHidden>
                  <StarRow rating={app.accessibilityRating} size={18} />
                  <Text style={{ fontSize: 14, fontWeight: '700', color: colors.text }}>
                    {app.accessibilityRating}/5
                  </Text>
                  <Text style={{ fontSize: 13, color: colors.textSecondary }}>
                    AppleVis accessibility
                  </Text>
                </View>
              ) : null}

              {/* Meta pills */}
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}
                accessibilityElementsHidden>
                {app.category ? (
                  <View style={{ backgroundColor: colors.pill, borderRadius: 8,
                    paddingHorizontal: 10, paddingVertical: 4 }}>
                    <Text style={{ color: colors.pillText, fontSize: 13, fontWeight: '600' }}>
                      {app.category}
                    </Text>
                  </View>
                ) : null}
                {app.platform ? (
                  <View style={{ backgroundColor: colors.pill, borderRadius: 8,
                    paddingHorizontal: 10, paddingVertical: 4 }}>
                    <Text style={{ color: colors.pillText, fontSize: 13, fontWeight: '600' }}>
                      {app.platform}
                    </Text>
                  </View>
                ) : null}
                <View style={{ backgroundColor: colors.pill, borderRadius: 8,
                  paddingHorizontal: 10, paddingVertical: 4 }}>
                  <Text style={{ color: colors.pillText, fontSize: 13, fontWeight: '600' }}>
                    {app.reviewCount} {app.reviewCount === 1 ? 'review' : 'reviews'}
                  </Text>
                </View>
                <View style={{ backgroundColor: colors.pill, borderRadius: 8,
                  paddingHorizontal: 10, paddingVertical: 4 }}>
                  <Text style={{ color: colors.pillText, fontSize: 13, fontWeight: '600' }}>
                    Updated {relativeTime(app.lastUpdatedAt)}
                  </Text>
                </View>
              </View>
            </View>

            {/* ── About this App (AppleVis body) ──────────────────────── */}
            {app.body && stripHtml(app.body) ? (
              <>
                <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text,
                  marginBottom: 8 }} accessibilityRole="header">
                  About this App
                </Text>
                <View style={[styles.card, { marginBottom: 10 }]}
                  accessible accessibilityLabel={`About this app: ${stripHtml(app.body)}`}>
                  <Text style={{ fontSize: 15, lineHeight: 25, color: colors.text }}
                    accessibilityElementsHidden>
                    {stripHtml(app.body)}
                  </Text>
                </View>
              </>
            ) : app.summary ? (
              <>
                <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text,
                  marginBottom: 8 }} accessibilityRole="header">
                  About this App
                </Text>
                <View style={[styles.card, { marginBottom: 10 }]}
                  accessible accessibilityLabel={`About this app: ${stripHtml(app.summary)}`}>
                  <Text style={{ fontSize: 15, lineHeight: 25, color: colors.text }}
                    accessibilityElementsHidden>
                    {stripHtml(app.summary)}
                  </Text>
                </View>
              </>
            ) : null}

            {/* Quick nav row */}
            <View style={{ flexDirection: 'row', gap: 8, marginBottom: 12, flexWrap: 'wrap' }}>
              {!screenReaderEnabled && (
                <Pressable
                  onPress={handleReadAloud}
                  accessible accessibilityRole="button"
                  accessibilityLabel="Read description aloud"
                  accessibilityHint="Reads the app name and description"
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                    backgroundColor: colors.pill, borderRadius: 10,
                    paddingHorizontal: 14, paddingVertical: 10 }}
                >
                  <Ionicons name="volume-medium-outline" size={16} color={colors.pillText} accessibilityElementsHidden />
                  <Text style={{ fontSize: 14, fontWeight: '600', color: colors.pillText }}>Read Aloud</Text>
                </Pressable>
              )}
              {app.reviewCount > 0 && (
                <Pressable
                  onPress={handleJumpToReviews}
                  accessible accessibilityRole="button"
                  accessibilityLabel={`Jump to ${app.reviewCount} community ${app.reviewCount === 1 ? 'review' : 'reviews'}`}
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                    backgroundColor: colors.pill, borderRadius: 10,
                    paddingHorizontal: 14, paddingVertical: 10 }}
                >
                  <Ionicons name="arrow-down-outline" size={16} color={colors.pillText} accessibilityElementsHidden />
                  <Text style={{ fontSize: 14, fontWeight: '600', color: colors.pillText }}>
                    Jump to Reviews
                  </Text>
                </Pressable>
              )}
            </View>

            {/* ── iTunes metadata ──────────────────────────────────────── */}
            {itunesLoading && !itunes ? (
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8,
                paddingVertical: 12, paddingHorizontal: 4, marginBottom: 4 }}>
                <ActivityIndicator size="small" color={colors.textSecondary} accessibilityElementsHidden />
                <Text style={{ fontSize: 13, color: colors.textSecondary }}>
                  Loading App Store information…
                </Text>
              </View>
            ) : null}
            {itunes ? (
              <ItunesSection meta={itunes} colors={colors} styles={styles} />
            ) : null}

            {/* ── Apple Intelligence ───────────────────────────────────── */}
            {(hasReviews || (app.body && stripHtml(app.body))) && (
              <View style={[styles.card, { marginBottom: 10, opacity: aiAvailable ? 1 : 0.55 }]}>
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 12 }}
                  accessibilityElementsHidden>
                  <Ionicons name="sparkles-outline" size={16} color={colors.accent} />
                  <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
                    textTransform: 'uppercase', letterSpacing: 0.6 }}>
                    Apple Intelligence
                  </Text>
                  {!aiAvailable && (
                    <View style={{ backgroundColor: colors.pill, borderRadius: 6,
                      paddingHorizontal: 8, paddingVertical: 2 }}>
                      <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary }}>
                        NOT ENABLED
                      </Text>
                    </View>
                  )}
                </View>

                <View style={{ flexDirection: 'row', gap: 10, flexWrap: 'wrap' }}>
                  {hasReviews && (
                    <Pressable
                      onPress={handleAccessibilityConsensus}
                      disabled={aiWorking === 'consensus'}
                      accessible
                      accessibilityRole="button"
                      accessibilityLabel={
                        aiAvailable
                          ? (aiWorking === 'consensus' ? 'Analysing reviews, please wait' : 'Accessibility Consensus')
                          : 'Accessibility Consensus — enable Apple Intelligence in Settings to use this'
                      }
                      accessibilityHint={aiAvailable ? 'Summarises what all reviewers say about VoiceOver and accessibility' : 'Go to Settings → Apple Intelligence & Siri'}
                      style={{ flexDirection: 'row', alignItems: 'center', gap: 8,
                        backgroundColor: aiAvailable ? colors.accent : colors.pill,
                        borderRadius: 10, paddingHorizontal: 14, paddingVertical: 12, flex: 1 }}
                    >
                      {aiWorking === 'consensus'
                        ? <ActivityIndicator size="small" color={aiAvailable ? colors.accentText : colors.pillText} accessibilityElementsHidden />
                        : <Ionicons name="eye-outline" size={16} color={aiAvailable ? colors.accentText : colors.pillText} accessibilityElementsHidden />
                      }
                      <Text style={{ fontSize: 13, fontWeight: '700',
                        color: aiAvailable ? colors.accentText : colors.pillText, flex: 1 }}>
                        {aiWorking === 'consensus' ? 'Analysing…' : 'Accessibility\nConsensus'}
                      </Text>
                    </Pressable>
                  )}

                  {hasReviews && (
                    <Pressable
                      onPress={handleSummariseReviews}
                      disabled={aiWorking === 'summarise'}
                      accessible
                      accessibilityRole="button"
                      accessibilityLabel={
                        aiAvailable
                          ? (aiWorking === 'summarise' ? 'Summarising reviews, please wait' : 'Summarise reviews')
                          : 'Summarise Reviews — enable Apple Intelligence in Settings to use this'
                      }
                      accessibilityHint={aiAvailable ? 'Creates a brief AI summary of all community reviews' : 'Go to Settings → Apple Intelligence & Siri'}
                      style={{ flexDirection: 'row', alignItems: 'center', gap: 8,
                        backgroundColor: aiAvailable ? colors.pill : colors.pill,
                        borderRadius: 10, paddingHorizontal: 14, paddingVertical: 12, flex: 1,
                        borderWidth: aiAvailable ? 1 : 0, borderColor: colors.border }}
                    >
                      {aiWorking === 'summarise'
                        ? <ActivityIndicator size="small" color={colors.pillText} accessibilityElementsHidden />
                        : <Ionicons name="sparkles" size={16} color={colors.pillText} accessibilityElementsHidden />
                      }
                      <Text style={{ fontSize: 13, fontWeight: '700', color: colors.pillText, flex: 1 }}>
                        {aiWorking === 'summarise' ? 'Summarising…' : 'Summarise\nReviews'}
                      </Text>
                    </Pressable>
                  )}
                </View>

                {!aiAvailable && (
                  <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 10, lineHeight: 17 }}
                    accessibilityElementsHidden>
                    Enable Apple Intelligence in Settings → Apple Intelligence & Siri
                  </Text>
                )}
              </View>
            )}

            {/* ── Reported Accessibility Issues — coming soon ───────────── */}
            <SectionDivider
              label={app.reportedIssueCount != null
                ? `${app.reportedIssueCount} Reported Issues`
                : 'Reported Issues'}
            />
            <ComingSoonShell
              icon="bug-outline"
              message={
                app.reportedIssueCount != null
                  ? `${app.reportedIssueCount} reported accessibility issues — full issue tracker coming once the Drupal field name is confirmed`
                  : 'Track reported VoiceOver and accessibility bugs — coming once the Drupal field name is confirmed with the developer'
              }
            />

            {/* ── Community Reviews ─────────────────────────────────────── */}
            <View onLayout={(e) => { reviewsY.current = e.nativeEvent.layout.y; }}>
              <SectionDivider
                label={`${app.reviewCount} Community ${app.reviewCount === 1 ? 'Comment' : 'Comments'}`}
              />

              {/* Read reviews aloud */}
              {!screenReaderEnabled && hasReviews && (
                <Pressable
                  onPress={handleReadReviewsAloud}
                  accessible accessibilityRole="button"
                  accessibilityLabel={`Read all ${app.reviews.length} reviews aloud`}
                  accessibilityHint="Reads each review in sequence"
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 8,
                    backgroundColor: colors.pill, borderRadius: 10,
                    paddingHorizontal: 14, paddingVertical: 10, alignSelf: 'flex-start', marginBottom: 14 }}
                >
                  <Ionicons name="volume-medium-outline" size={16} color={colors.pillText} accessibilityElementsHidden />
                  <Text style={{ fontSize: 14, fontWeight: '600', color: colors.pillText }}>
                    Read All Reviews
                  </Text>
                </Pressable>
              )}

              {/* No reviews state */}
              {!hasReviews && (
                <View style={[styles.card, { alignItems: 'center', paddingVertical: 28, marginBottom: 12 }]}>
                  <Ionicons name="chatbubble-outline" size={32} color={colors.textSecondary}
                    accessibilityElementsHidden style={{ marginBottom: 10 }} />
                  <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text, marginBottom: 6 }}>
                    No reviews yet
                  </Text>
                  <Text style={{ fontSize: 14, color: colors.textSecondary, textAlign: 'center' }}>
                    Be the first to share your accessibility experience.
                  </Text>
                </View>
              )}

              {/* Review cards */}
              {app.reviews.map((review, i) => (
                <ReviewCard
                  key={review.id}
                  review={review}
                  index={i}
                  total={app.reviews.length}
                  colors={colors}
                  styles={styles}
                  screenReaderEnabled={screenReaderEnabled}
                  showToast={showToast}
                />
              ))}

              {/* Load more — coming soon when reviewCount > loaded */}
              {hasReviews && app.reviews.length < app.reviewCount && (
                <ComingSoonShell
                  icon="ellipsis-horizontal-outline"
                  message={`Load more reviews — ${app.reviewCount - app.reviews.length} more pending pagination support`}
                />
              )}
            </View>

            {/* ── Related Apps — coming soon ───────────────────────────── */}
            <SectionDivider label="Related Apps" />
            <ComingSoonShell
              icon="apps-outline"
              message={
                app.developer
                  ? `More apps by ${app.developer} and in the ${app.category || 'same'} category — coming once the Drupal category API is confirmed`
                  : 'Related apps in the same category — coming once the Drupal category API is confirmed'
              }
            />

            {/* Back to top */}
            <Pressable
              onPress={handleBackToTop}
              accessible accessibilityRole="button"
              accessibilityLabel="Back to top"
              accessibilityHint="Scrolls back to the app header"
              style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center',
                gap: 6, paddingVertical: 16 }}
            >
              <Ionicons name="arrow-up-outline" size={16} color={colors.textSecondary} accessibilityElementsHidden />
              <Text style={{ fontSize: 14, color: colors.textSecondary, fontWeight: '500' }}>Back to Top</Text>
            </Pressable>

          </>
        )}
      </ScrollView>

      {/* ── Fixed bottom toolbar ──────────────────────────────────────────── */}
      {app && (
        <View
          style={{
            flexDirection: 'row',
            height: TOOLBAR_H,
            paddingHorizontal: 4,
            backgroundColor: colors.card,
            borderTopWidth: StyleSheet.hairlineWidth,
            borderTopColor: colors.border,
            alignItems: 'center',
          }}
          accessibilityRole="toolbar"
          accessibilityLabel="App actions"
        >
          <ToolbarButton
            icon="logo-apple"
            label={'Get in\nApp Store'}
            onPress={handleOpenAppStore}
            disabled={!app.appStoreUrl}
          />
          <ToolbarButton
            icon="bookmark-outline"
            activeIcon="bookmark"
            label={isSaved ? 'Saved' : 'Save this\nApp Entry'}
            active={isSaved}
            onPress={handleSave}
          />
          <ToolbarButton
            icon="share-outline"
            label={'Share this\nApp Entry'}
            onPress={handleShare}
          />
          <ToolbarButton
            icon="safari-outline"
            label={'Open in\nSafari'}
            onPress={handleOpenInBrowser}
          />
          <ToolbarButton
            icon="pencil-outline"
            label={'Add New\nComment'}
            onPress={handleWriteReview}
            accent
          />
        </View>
      )}

      {/* Write Review Modal — outside scroll, rendered modally */}
      {app && (
        <WriteReviewModal
          visible={showReview}
          appId={id ?? ''}
          appName={app.name}
          onClose={() => setShowReview(false)}
          onSubmitted={() => {
            setShowReview(false);
            showToast('Review submitted! It will appear after moderation.', 'success');
          }}
        />
      )}
      </View>
    </Screen>
  );
}
