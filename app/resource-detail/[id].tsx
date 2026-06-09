import { useEffect, useState } from 'react';
import { ActivityIndicator, Linking, Pressable, ScrollView, Share, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useLocalSearchParams } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../../src/components/Screen';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { useAuth } from '../../src/contexts/AuthContext';
import { useToast } from '../../src/contexts/ToastContext';
import { useSavedItems } from '../../src/hooks/useSavedItems';
import { useHandoff } from '../../src/hooks/useHandoff';
import { readAloud, summariseText } from '../../src/services/intelligenceService';
import { api } from '../../src/services/api';
import { relativeTime } from '../../src/utils/relativeTime';
import type { ResourceDetail } from '../../src/types/content';

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

const TOOLBAR_H = 58;

function stripHtml(html: string): string {
  return html.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
}

// Naive paragraph splitter for readability.
function renderBody(text: string, colors: ReturnType<typeof useTheme>['colors']) {
  const plain = stripHtml(text);
  if (!plain) return null;
  const paragraphs = plain.split(/\n\n+/).filter(Boolean);
  if (paragraphs.length <= 1) {
    return (
      <Text style={{ fontSize: 16, lineHeight: 26, color: colors.text }}>{plain}</Text>
    );
  }
  return (
    <>
      {paragraphs.map((p, i) => (
        <Text key={i} style={{ fontSize: 16, lineHeight: 26, color: colors.text, marginBottom: 14 }}>
          {p.trim()}
        </Text>
      ))}
    </>
  );
}

export default function ResourceDetailScreen() {
  const { id, title: paramTitle, url: paramUrl } = useLocalSearchParams<{
    id: string; title?: string; url?: string;
  }>();
  const { colors, styles } = useTheme();
  const { screenReaderEnabled } = useAccessibilityPreferences();
  const auth               = useAuth();
  const { showToast }      = useToast();
  const saved              = useSavedItems('resource');
  const insets             = useSafeAreaInsets();

  const [resource, setResource] = useState<ResourceDetail | null>(null);
  const [loading,  setLoading]  = useState(true);
  const [error,    setError]    = useState<string | null>(null);

  useHandoff(resource ? {
    activityType: 'com.applevis.app.viewResource',
    title: resource.title,
    webpageURL: resource.url,
  } : null);

  useEffect(() => {
    if (!id) return;
    api.resources.detail(id).then((res) => {
      setLoading(false);
      if (res.ok) setResource(res.data); else setError(res.error);
    }).catch((err: unknown) => {
      setLoading(false);
      setError(err instanceof Error ? err.message : 'Unexpected error');
    });
  }, [id]);

  const isSaved = saved.isSaved(id ?? '');

  // Derive a friendly label from the resource kind (guide → Guide, tutorial → Tutorial, etc.)
  const kindLabel = resource
    ? resource.kind.charAt(0).toUpperCase() + resource.kind.slice(1)
    : 'Resource';

  function handleSave() {
    if (!resource) return;
    if (isSaved) {
      saved.unsave(id!);
      showToast('Removed from saved.', 'success');
    } else {
      saved.save({ id: id!, kind: 'resource', title: resource.title, savedAt: new Date().toISOString() });
      showToast(`${kindLabel} saved.`, 'success');
    }
  }

  function handleShare() {
    if (!resource) return;
    Share.share({
      title: resource.title,
      message: `${resource.title} — ${resource.url}`,
    }).catch(() => {});
  }

  function handleAddComment() {
    if (!auth.isSignedIn) {
      showToast('Sign in to add a new comment.', 'warning');
      return;
    }
    showToast('Comments on guides and blog posts — coming once the Drupal endpoint is confirmed.', 'warning');
  }

  const openInBrowser = () => {
    const url = resource?.url ?? paramUrl;
    if (url) Linking.openURL(url).catch(() => showToast('Could not open Safari.', 'error'));
  };

  const displayTitle = resource?.title ?? paramTitle ?? 'Resource';

  return (
    <Screen title={displayTitle} showSettings={false} showSearch={false}>
      <View style={{ flex: 1 }}>
      <ScrollView showsVerticalScrollIndicator style={{ flex: 1 }} contentContainerStyle={{ paddingBottom: TOOLBAR_H + 16 }}>

        {loading && (
          <View style={{ alignItems: 'center', paddingVertical: 48 }}>
            <ActivityIndicator size="large" color={colors.accent} />
            <Text style={[styles.cardMeta, { marginTop: 12 }]}>Loading...</Text>
          </View>
        )}

        {!loading && error && (
          <View style={[styles.card, { borderColor: '#FCA5A5', borderWidth: 1 }]}>
            <Text style={[styles.cardTitle, { color: '#B91C1C' }]}>Could not load resource</Text>
            <Text style={styles.cardMeta}>{error}</Text>
            {(resource?.url ?? paramUrl) && (
              <Pressable onPress={openInBrowser} accessible accessibilityRole="button"
                accessibilityLabel="Open in Safari instead" style={{ marginTop: 12 }}>
                <Text style={{ color: colors.accent, fontWeight: '700' }}>Open in Safari</Text>
              </Pressable>
            )}
          </View>
        )}

        {resource && (
          <>
            {/* Meta card */}
            <View style={[styles.card, { marginBottom: 8 }]}
              accessible
              accessibilityLabel={[
                resource.title,
                resource.kind,
                resource.authorName ? `by ${resource.authorName}` : null,
                `Updated ${relativeTime(resource.updatedAt)}`,
              ].filter(Boolean).join('. ')}>

              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: 12 }}>
                <View style={{ backgroundColor: colors.pill, borderRadius: 8,
                  paddingHorizontal: 10, paddingVertical: 4 }}>
                  <Text style={{ color: colors.pillText, fontSize: 13, fontWeight: '600',
                    textTransform: 'capitalize' }}>{resource.kind}</Text>
                </View>
                {resource.authorName ? (
                  <View style={{ backgroundColor: colors.pill, borderRadius: 8,
                    paddingHorizontal: 10, paddingVertical: 4 }}>
                    <Text style={{ color: colors.pillText, fontSize: 13, fontWeight: '600' }}>
                      {resource.authorName}
                    </Text>
                  </View>
                ) : null}
                <View style={{ backgroundColor: colors.pill, borderRadius: 8,
                  paddingHorizontal: 10, paddingVertical: 4 }}>
                  <Text style={{ color: colors.pillText, fontSize: 13 }}>
                    Updated {relativeTime(resource.updatedAt)}
                  </Text>
                </View>
              </View>

              {/* Summary */}
              {resource.summary && (
                <Text style={{ fontSize: 15, lineHeight: 23, color: colors.textSecondary, marginBottom: 14 }}>
                  {stripHtml(resource.summary)}
                </Text>
              )}

              {/* Content tools — AI features stay inline */}
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
                {!screenReaderEnabled && (
                  <Pressable
                    onPress={() => readAloud(`${resource.title}. ${stripHtml(resource.summary)}`)}
                    accessible accessibilityRole="button" accessibilityLabel="Read aloud"
                    style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                      backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8 }}
                  >
                    <Ionicons name="volume-medium-outline" size={14} color={colors.pillText} />
                    <Text style={{ color: colors.pillText, fontWeight: '600', fontSize: 13 }}>Read Aloud</Text>
                  </Pressable>
                )}
                <Pressable
                  onPress={() => summariseText(`${resource.title}\n\n${stripHtml(resource.body)}`).then((s) => {
                    if (s) showToast(s, 'success');
                    else showToast('Summarisation coming with Apple Intelligence.', 'warning');
                  })}
                  accessible accessibilityRole="button" accessibilityLabel="Summarise with Apple Intelligence"
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                    backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8 }}
                >
                  <Ionicons name="sparkles-outline" size={14} color={colors.pillText} />
                  <Text style={{ color: colors.pillText, fontWeight: '600', fontSize: 13 }}>Summarise</Text>
                </Pressable>
              </View>
            </View>

            {/* Full body */}
            {resource.body && stripHtml(resource.body) ? (
              <View style={[styles.card, { marginBottom: 16 }]}
                accessible
                accessibilityLabel={`Full article: ${stripHtml(resource.body)}`}>
                {renderBody(resource.body, colors)}
              </View>
            ) : (
              <View style={[styles.card, { alignItems: 'center', paddingVertical: 24 }]}>
                <Text style={styles.cardMeta}>
                  Full article content not available yet.
                </Text>
                <Pressable onPress={openInBrowser} accessible accessibilityRole="button"
                  accessibilityLabel="Read full article on applevis.com"
                  style={{ marginTop: 12 }}>
                  <Text style={{ color: colors.accent, fontWeight: '700' }}>Read on applevis.com</Text>
                </Pressable>
              </View>
            )}
          </>
        )}

      </ScrollView>

      {/* ── Fixed bottom toolbar ──────────────────────────────────────────── */}
      {resource && (
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
          accessibilityLabel="Resource actions"
        >
          <ToolbarButton
            icon="bookmark-outline"
            activeIcon="bookmark"
            label={isSaved ? 'Saved' : `Save this\n${kindLabel}`}
            active={isSaved}
            onPress={handleSave}
          />
          <ToolbarButton
            icon="share-outline"
            label={`Share this\n${kindLabel}`}
            onPress={handleShare}
          />
          <ToolbarButton
            icon="safari-outline"
            label={'Open in\nSafari'}
            onPress={openInBrowser}
          />
          <ToolbarButton
            icon="pencil-outline"
            label={'Add New\nComment'}
            onPress={handleAddComment}
            accent
          />
        </View>
      )}
      </View>
    </Screen>
  );
}
