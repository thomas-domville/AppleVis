import { useEffect, useRef, useState } from 'react';
import { AccessibilityInfo, ActivityIndicator, ScrollView, Text, TextInput, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Screen } from '../src/components/Screen';
import { AccessibleCard } from '../src/components/AccessibleCard';
import { useSearch } from '../src/hooks/useSearch';
import { useLanguageDetection } from '../src/hooks/useLanguageDetection';
import { TranslationBanner } from '../src/components/TranslationBanner';
import { translateContent, readAloud } from '../src/services/intelligenceService';
import { useTheme } from '../src/contexts/ThemeContext';
import { useAccessibilityPreferences } from '../src/hooks/useAccessibilityPreferences';

export default function SearchScreen() {
  const router = useRouter();
  const { colors, styles } = useTheme();
  const { screenReaderEnabled } = useAccessibilityPreferences();
  const { results, loading, error, hasQuery, totalCount, search } = useSearch();
  const inputRef   = useRef<TextInput>(null);
  const queryRef   = useRef('');
  // Separate state for language detection so the hook receives a stable
  // render-time value, not a ref (refs must not be read during render).
  const [detectionQuery, setDetectionQuery] = useState('');
  const { isNonEnglish, isConfident } = useLanguageDetection(detectionQuery);

  // Auto-focus the input on mount.
  useEffect(() => {
    const timer = setTimeout(() => inputRef.current?.focus(), 300);
    return () => clearTimeout(timer);
  }, []);

  // Announce result count to VoiceOver when results change.
  useEffect(() => {
    if (!hasQuery || loading) return;
    const msg = totalCount === 0
      ? 'No results found.'
      : `${totalCount} result${totalCount === 1 ? '' : 's'} found: ` +
        [
          results.forums.length    > 0 ? `${results.forums.length} forum topic${results.forums.length    === 1 ? '' : 's'}`    : '',
          results.apps.length      > 0 ? `${results.apps.length} app${results.apps.length      === 1 ? '' : 's'}`              : '',
          results.resources.length > 0 ? `${results.resources.length} resource${results.resources.length === 1 ? '' : 's'}`    : '',
        ].filter(Boolean).join(', ');
    AccessibilityInfo.announceForAccessibility(msg);
  }, [totalCount, hasQuery, loading, results]);

  function handleChange(text: string) {
    queryRef.current = text;
    setDetectionQuery(text);
    search(text);
  }

  return (
    <Screen title="Search" showSettings={false}>
      {/* ── Search field ──────────────────────────────────────────────────── */}
      <View style={{ marginBottom: 12 }}>
        <TextInput
          ref={inputRef}
          onChangeText={handleChange}
          placeholder="Search forums, apps, resources…"
          placeholderTextColor={colors.secondary}
          returnKeyType="search"
          clearButtonMode="while-editing"
          accessible
          accessibilityLabel="Search AppleVis"
          accessibilityHint="Type to search forum topics, app listings, and resources."
          style={{
            borderWidth: 1.5,
            borderColor: colors.border,
            borderRadius: 12,
            paddingHorizontal: 14,
            paddingVertical: 12,
            fontSize: 17,
            color: colors.text,
            backgroundColor: '#FAFAFA',
          }}
        />
      </View>

      {/* ── Non-English query detection ───────────────────────────────────── */}
      {isNonEnglish && isConfident && (
        <TranslationBanner
          onTranslate={() => translateContent(queryRef.current, 'Search query')}
          onDismiss={() => {}}
        />
      )}

      <ScrollView showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">

        {/* ── Loading ───────────────────────────────────────────────────────── */}
        {loading && (
          <View style={{ alignItems: 'center', paddingVertical: 32 }}>
            <ActivityIndicator size="large" color={colors.appleVisBlue} />
            <Text style={[styles.lede, { marginTop: 10, textAlign: 'center' }]}>Searching…</Text>
          </View>
        )}

        {/* ── Error ─────────────────────────────────────────────────────────── */}
        {!loading && error && (
          <View style={[styles.card, { backgroundColor: '#FFF8E1' }]}>
            <Text style={[styles.cardMeta, { color: '#856404' }]}>{error}</Text>
          </View>
        )}

        {/* ── Empty state ───────────────────────────────────────────────────── */}
        {!loading && hasQuery && totalCount === 0 && !error && (
          <View style={[styles.card, { alignItems: 'center', paddingVertical: 32 }]}>
            <Text style={styles.cardTitle}>No results</Text>
            <Text style={[styles.cardMeta, { textAlign: 'center', marginTop: 4 }]}>
              Try different keywords or check your spelling.
            </Text>
          </View>
        )}

        {/* ── Prompt when no query yet ──────────────────────────────────────── */}
        {!hasQuery && !loading && (
          <Text style={styles.lede}>
            Search across forum topics, app directory listings, and resources. Results appear as you type.
          </Text>
        )}

        {/* ── Forum results ─────────────────────────────────────────────────── */}
        {!loading && results.forums.length > 0 && (
          <>
            <Text
              style={[styles.cardTitle, { marginBottom: 8, marginTop: 4 }]}
              accessibilityRole="header"
            >
              Forum Topics ({results.forums.length})
            </Text>
            {results.forums.map((topic) => (
              <AccessibleCard
                key={topic.id}
                title={topic.title}
                meta={topic.meta}
                actions={['Open', ...(!screenReaderEnabled ? ['Read Aloud'] : []), 'Translate']}
                onAction={(action) => {
                  if (action === 'Open') router.push({ pathname: '/topic/[id]' as any, params: { id: topic.id, title: topic.title } });
                  if (action === 'Read Aloud') readAloud(`${topic.title}. ${topic.meta}`);
                  if (action === 'Translate')  translateContent(`${topic.title}\n${topic.meta}`, topic.title);
                }}
              />
            ))}
          </>
        )}

        {/* ── App results ───────────────────────────────────────────────────── */}
        {!loading && results.apps.length > 0 && (
          <>
            <Text
              style={[styles.cardTitle, { marginBottom: 8, marginTop: 12 }]}
              accessibilityRole="header"
            >
              Apps ({results.apps.length})
            </Text>
            {results.apps.map((app) => (
              <AccessibleCard
                key={app.id}
                title={app.name}
                meta={[
                  app.developer   || null,
                  app.reviewCount > 0 ? `${app.reviewCount} reviews` : null,
                ].filter(Boolean).join(' · ')}
                actions={['Open App Page', ...(!screenReaderEnabled ? ['Read Aloud'] : []), 'Translate']}
                onAction={(action) => {
                  if (action === 'Open App Page') router.push({ pathname: '/app-detail/[id]' as any, params: { id: app.id, name: app.name } });
                  if (action === 'Read Aloud') readAloud(`${app.name}. ${app.summary}`);
                  if (action === 'Translate')  translateContent(`${app.name}\n\n${app.summary}`, app.name);
                }}
              />
            ))}
          </>
        )}

        {/* ── Resource results ──────────────────────────────────────────────── */}
        {!loading && results.resources.length > 0 && (
          <>
            <Text
              style={[styles.cardTitle, { marginBottom: 8, marginTop: 12 }]}
              accessibilityRole="header"
            >
              Resources ({results.resources.length})
            </Text>
            {results.resources.map((item) => (
              <AccessibleCard
                key={item.id}
                title={item.title}
                meta={`${item.kind} · Updated ${new Date(item.updatedAt).toLocaleDateString()}`}
                actions={['Open', ...(!screenReaderEnabled ? ['Read Aloud'] : []), 'Translate']}
                onAction={(action) => {
                  if (action === 'Open') router.push({ pathname: '/resource-detail/[id]' as any, params: { id: item.id, title: item.title, url: item.url } });
                  if (action === 'Read Aloud') readAloud(`${item.title}. ${item.summary}`);
                  if (action === 'Translate')  translateContent(`${item.title}\n\n${item.summary}`, item.title);
                }}
              />
            ))}
          </>
        )}

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
