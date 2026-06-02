import { useEffect, useState } from 'react';
import { ActivityIndicator, Linking, Pressable, ScrollView, Text, View } from 'react-native';
import { useLocalSearchParams } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../../src/components/Screen';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useToast } from '../../src/contexts/ToastContext';
import { useSavedItems } from '../../src/hooks/useSavedItems';
import { useHandoff } from '../../src/hooks/useHandoff';
import { readAloud, translateContent, summariseText } from '../../src/services/intelligenceService';
import { api } from '../../src/services/api';
import type { ResourceDetail } from '../../src/types/content';

function formatDate(iso: string): string {
  if (!iso) return '';
  return new Date(iso).toLocaleDateString(undefined, { year: 'numeric', month: 'long', day: 'numeric' });
}

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
  const { showToast }      = useToast();
  const saved              = useSavedItems('resource');

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

  function handleSave() {
    if (!resource) return;
    if (isSaved) {
      saved.unsave(id!);
      showToast('Removed from saved.', 'success');
    } else {
      saved.save({ id: id!, kind: 'resource', title: resource.title, savedAt: new Date().toISOString() });
      showToast('Resource saved.', 'success');
    }
  }

  const openInBrowser = () => {
    const url = resource?.url ?? paramUrl;
    if (url) Linking.openURL(url).catch(() => showToast('Could not open link.', 'error'));
  };

  const displayTitle = resource?.title ?? paramTitle ?? 'Resource';

  return (
    <Screen title={displayTitle} showSettings={false} showSearch={false}>
      <ScrollView showsVerticalScrollIndicator={false}>

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
                `Updated ${formatDate(resource.updatedAt)}`,
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
                    Updated {formatDate(resource.updatedAt)}
                  </Text>
                </View>
              </View>

              {/* Summary */}
              {resource.summary && (
                <Text style={{ fontSize: 15, lineHeight: 23, color: colors.textSecondary, marginBottom: 14 }}>
                  {stripHtml(resource.summary)}
                </Text>
              )}

              {/* Action buttons */}
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
                <Pressable
                  onPress={handleSave}
                  accessible accessibilityRole="button"
                  accessibilityLabel={isSaved ? 'Unsave resource' : 'Save resource'}
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                    backgroundColor: isSaved ? colors.accent : colors.pill,
                    borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8 }}
                >
                  <Ionicons name={isSaved ? 'bookmark' : 'bookmark-outline'} size={14}
                    color={isSaved ? colors.accentText : colors.pillText} />
                  <Text style={{ color: isSaved ? colors.accentText : colors.pillText,
                    fontWeight: '600', fontSize: 13 }}>{isSaved ? 'Saved' : 'Save'}</Text>
                </Pressable>

                <Pressable
                  onPress={() => readAloud(`${resource.title}. ${stripHtml(resource.summary)}`)}
                  accessible accessibilityRole="button" accessibilityLabel="Read aloud"
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                    backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8 }}
                >
                  <Ionicons name="volume-medium-outline" size={14} color={colors.pillText} />
                  <Text style={{ color: colors.pillText, fontWeight: '600', fontSize: 13 }}>Read Aloud</Text>
                </Pressable>

                <Pressable
                  onPress={() => translateContent(`${resource.title}\n\n${stripHtml(resource.body)}`, resource.title)}
                  accessible accessibilityRole="button" accessibilityLabel="Translate"
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                    backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8 }}
                >
                  <Ionicons name="language-outline" size={14} color={colors.pillText} />
                  <Text style={{ color: colors.pillText, fontWeight: '600', fontSize: 13 }}>Translate</Text>
                </Pressable>

                <Pressable
                  onPress={() => summariseText(`${resource.title}\n\n${stripHtml(resource.body)}`).then((s) => {
                    if (s) showToast(s, 'success');
                    else showToast('Summarisation coming with Apple Intelligence.', 'warning');
                  })}
                  accessible accessibilityRole="button" accessibilityLabel="Summarise"
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                    backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8 }}
                >
                  <Ionicons name="newspaper-outline" size={14} color={colors.pillText} />
                  <Text style={{ color: colors.pillText, fontWeight: '600', fontSize: 13 }}>Summarise</Text>
                </Pressable>

                <Pressable
                  onPress={openInBrowser}
                  accessible accessibilityRole="button"
                  accessibilityLabel="Open full article in Safari"
                  accessibilityHint="Opens the full applevis.com article in Safari."
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                    backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8 }}
                >
                  <Ionicons name="open-outline" size={14} color={colors.pillText} />
                  <Text style={{ color: colors.pillText, fontWeight: '600', fontSize: 13 }}>Open in Safari</Text>
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

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
