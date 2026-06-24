import { useCallback, useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActivityIndicator, Animated,
  findNodeHandle, Image, Keyboard, KeyboardAvoidingView,
  Platform, Pressable, ScrollView, Text, TextInput, View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useWizard } from '../../src/contexts/SubmitWizardContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { searchItunesApps, type ItunesSearchHit, type ItunesSearchEntity } from '../../src/services/itunesApi';
import { sounds } from '../../src/services/sounds';

// ─── Step 3: Search & Pick ─────────────────────────────────────────────────────

const ENTITY_MAP: Record<string, ItunesSearchEntity> = {
  ios:   'software',
  macos: 'macSoftware',
  tvos:  'tvSoftware',
};

const PLATFORM_LABEL: Record<string, string> = {
  ios:   'iOS / iPadOS',
  macos: 'macOS',
  tvos:  'Apple TV',
};

type SearchStatus = 'idle' | 'loading' | 'done' | 'error';

function ResultCard({
  hit,
  onPress,
}: {
  hit: ItunesSearchHit;
  onPress: () => void;
}) {
  const { colors } = useTheme();
  return (
    <Pressable
      onPress={onPress}
      accessible
      accessibilityRole="button"
      accessibilityLabel={`${hit.appName} by ${hit.developerName}. ${hit.price}. ${hit.category}.`}
      accessibilityHint="Select this app"
      style={({ pressed }) => ({
        flexDirection: 'row', alignItems: 'center', gap: 12,
        backgroundColor: colors.card,
        borderRadius: 14, padding: 12, marginBottom: 8,
        opacity: pressed ? 0.8 : 1,
      })}
    >
      {hit.artworkUrl ? (
        <Image
          source={{ uri: hit.artworkUrl }}
          style={{ width: 52, height: 52, borderRadius: 12 }}
          accessibilityElementsHidden
        />
      ) : (
        <View
          style={{ width: 52, height: 52, borderRadius: 12, backgroundColor: colors.border, justifyContent: 'center', alignItems: 'center' }}
          accessibilityElementsHidden
        >
          <Ionicons name="phone-portrait-outline" size={24} color={colors.textSecondary} />
        </View>
      )}
      <View style={{ flex: 1 }}>
        <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text }} numberOfLines={1}>{hit.appName}</Text>
        <Text style={{ fontSize: 13, color: colors.textSecondary, marginTop: 1 }} numberOfLines={1}>{hit.developerName}</Text>
        <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 1 }}>{hit.price} · {hit.category}</Text>
      </View>
      <Ionicons name="chevron-forward" size={18} color={colors.textSecondary} accessibilityElementsHidden />
    </Pressable>
  );
}

export default function SearchScreen() {
  const { colors }                     = useTheme();
  const router                         = useRouter();
  const { state, update }              = useWizard();
  const { screenReaderEnabled, reduceMotion } = useAccessibilityPreferences();

  const headingRef     = useRef<Text>(null);
  const searchInputRef = useRef<TextInput>(null);
  const contentAnim    = useRef(new Animated.Value(0)).current;

  const [query,    setQuery]    = useState('');
  const [results,  setResults]  = useState<ItunesSearchHit[]>([]);
  const [status,   setStatus]   = useState<SearchStatus>('idle');
  const [urlMode,  setUrlMode]  = useState(false);
  const [urlInput, setUrlInput] = useState('');
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const entity = ENTITY_MAP[state.platform ?? 'ios'];
  const platformLabel = PLATFORM_LABEL[state.platform ?? 'ios'];

  useEffect(() => {
    if (reduceMotion || screenReaderEnabled) {
      contentAnim.setValue(1);
    } else {
      Animated.timing(contentAnim, { toValue: 1, duration: 360, useNativeDriver: true }).start();
    }
    if (screenReaderEnabled) {
      const id = setTimeout(() => {
        const node = findNodeHandle(headingRef.current);
        if (node) AccessibilityInfo.setAccessibilityFocus(node);
      }, 350);
      return () => clearTimeout(id);
    }
  }, []);

  const runSearch = useCallback(async (q: string) => {
    if (!q.trim()) {
      setResults([]);
      setStatus('idle');
      return;
    }
    setStatus('loading');
    const hits = await searchItunesApps(q, entity);
    if (hits === null) {
      setStatus('error');
    } else {
      setResults(hits);
      setStatus('done');
      if (screenReaderEnabled && hits.length > 0) {
        AccessibilityInfo.announceForAccessibility(`${hits.length} result${hits.length === 1 ? '' : 's'} found.`);
      }
    }
  }, [entity, screenReaderEnabled]);

  function handleQueryChange(text: string) {
    setQuery(text);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => void runSearch(text), 350);
  }

  function handleSelectHit(hit: ItunesSearchHit) {
    sounds.articleOpen().catch(() => {});
    update({ searchHit: hit, fullMeta: null, duplicateStatus: 'idle' });
    router.push('/submit-wizard/confirm' as any);
  }

  function handleUrlContinue() {
    if (!urlInput.trim()) return;
    sounds.articleOpen().catch(() => {});
    update({
      searchHit: {
        appStoreId:    '',
        appName:       'Loading…',
        developerName: '',
        category:      '',
        price:         '',
        artworkUrl:    '',
        appStoreUrl:   urlInput.trim(),
        bundleId:      '',
      },
      fullMeta:        null,
      duplicateStatus: 'idle',
    });
    router.push('/submit-wizard/confirm' as any);
  }

  return (
    <KeyboardAvoidingView
      style={{ flex: 1 }}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      keyboardVerticalOffset={100}
    >
      <ScrollView
        contentContainerStyle={{ padding: 20, paddingBottom: 48 }}
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
      >
        <Animated.View style={{ opacity: contentAnim, transform: [{ translateY: contentAnim.interpolate({ inputRange: [0, 1], outputRange: [18, 0] }) }] }}>

          {/* ── Back ──────────────────────────────────────────────────────── */}
          <Pressable
            onPress={() => router.back()}
            accessible
            accessibilityRole="button"
            accessibilityLabel="Back to platform selection"
            style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', gap: 4, marginBottom: 20, opacity: pressed ? 0.7 : 1 })}
          >
            <Ionicons name="chevron-back" size={18} color={colors.accent} />
            <Text style={{ fontSize: 15, color: colors.accent, fontWeight: '600' }}>Back</Text>
          </Pressable>

          {/* ── Heading ───────────────────────────────────────────────────── */}
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 8 }}>
            <View
              style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: colors.accent, justifyContent: 'center', alignItems: 'center' }}
              accessibilityElementsHidden
            >
              <Ionicons name="search-outline" size={24} color="#fff" />
            </View>
            <Text
              ref={headingRef}
              style={{ fontSize: 26, fontWeight: '800', color: colors.text, flex: 1, lineHeight: 32 }}
              accessibilityRole="header"
            >
              Search for the app
            </Text>
          </View>
          <Text style={{ fontSize: 15, color: colors.textSecondary, lineHeight: 22, marginBottom: 20 }}>
            Searching the {platformLabel} App Store.
          </Text>

          {/* ── Search bar ────────────────────────────────────────────────── */}
          {!urlMode && (
            <>
              <View
                style={{
                  flexDirection: 'row', alignItems: 'center', gap: 10,
                  backgroundColor: colors.card,
                  borderRadius: 14, paddingHorizontal: 12, paddingVertical: 10,
                  borderWidth: 1.5, borderColor: colors.border,
                  marginBottom: 4,
                }}
              >
                <Ionicons name="search" size={18} color={colors.textSecondary} accessibilityElementsHidden />
                <TextInput
                  ref={searchInputRef}
                  style={{ flex: 1, fontSize: 17, color: colors.text, padding: 0 }}
                  value={query}
                  onChangeText={handleQueryChange}
                  placeholder="App name or keyword…"
                  placeholderTextColor={colors.textSecondary}
                  returnKeyType="search"
                  autoCapitalize="none"
                  autoCorrect={false}
                  onSubmitEditing={() => { if (debounceRef.current) clearTimeout(debounceRef.current); void runSearch(query); }}
                  accessible
                  accessibilityLabel="Search for an app"
                  accessibilityHint="Type the app name to search the App Store"
                />
                {status === 'loading' && <ActivityIndicator size="small" color={colors.accent} />}
                {query.length > 0 && status !== 'loading' && (
                  <Pressable
                    onPress={() => { setQuery(''); setResults([]); setStatus('idle'); searchInputRef.current?.focus(); }}
                    accessible
                    accessibilityRole="button"
                    accessibilityLabel="Clear search"
                  >
                    <Ionicons name="close-circle" size={18} color={colors.textSecondary} />
                  </Pressable>
                )}
              </View>

              {/* Results count live region */}
              {status === 'done' && (
                <Text
                  style={{ fontSize: 12, color: colors.textSecondary, marginBottom: 10 }}
                  accessibilityLiveRegion="polite"
                  accessibilityElementsHidden={!screenReaderEnabled}
                >
                  {results.length === 0
                    ? 'No results found.'
                    : `${results.length} result${results.length === 1 ? '' : 's'}`}
                </Text>
              )}
              {status === 'error' && (
                <Text
                  style={{ fontSize: 14, color: '#e44', marginBottom: 10 }}
                  accessibilityRole="alert"
                >
                  Search failed. Check your connection and try again.
                </Text>
              )}

              {/* Results */}
              {results.map(hit => (
                <ResultCard key={hit.appStoreId} hit={hit} onPress={() => handleSelectHit(hit)} />
              ))}

              {status === 'done' && results.length === 0 && query.trim() && (
                <View
                  style={{ backgroundColor: colors.card, borderRadius: 14, padding: 20, alignItems: 'center', marginBottom: 12 }}
                  accessible
                  accessibilityLabel="No apps found. Try a different search term or use the App Store URL option below."
                >
                  <Ionicons name="search-outline" size={32} color={colors.textSecondary} accessibilityElementsHidden />
                  <Text style={{ fontSize: 15, color: colors.textSecondary, textAlign: 'center', marginTop: 10, lineHeight: 22 }}>
                    No apps found for "{query}".{'\n'}Try a different search term.
                  </Text>
                </View>
              )}
            </>
          )}

          {/* ── URL fallback ──────────────────────────────────────────────── */}
          {urlMode ? (
            <View style={{ backgroundColor: colors.card, borderRadius: 14, padding: 16, marginBottom: 12 }}>
              <Text style={{ fontSize: 15, fontWeight: '700', color: colors.text, marginBottom: 10 }}>
                Paste an App Store URL
              </Text>
              <TextInput
                style={{
                  backgroundColor: colors.background,
                  borderRadius: 10, paddingHorizontal: 12, paddingVertical: 10,
                  fontSize: 15, color: colors.text,
                  borderWidth: 1.5, borderColor: colors.border,
                  marginBottom: 12,
                }}
                value={urlInput}
                onChangeText={setUrlInput}
                placeholder="https://apps.apple.com/app/id…"
                placeholderTextColor={colors.textSecondary}
                autoCapitalize="none"
                autoCorrect={false}
                keyboardType="url"
                returnKeyType="go"
                onSubmitEditing={handleUrlContinue}
                accessible
                accessibilityLabel="App Store URL"
                accessibilityHint="Paste the App Store link for this app"
              />
              <View style={{ flexDirection: 'row', gap: 10 }}>
                <Pressable
                  onPress={() => setUrlMode(false)}
                  accessible
                  accessibilityRole="button"
                  accessibilityLabel="Cancel, go back to search"
                  style={({ pressed }) => ({
                    flex: 1, paddingVertical: 12, borderRadius: 10,
                    backgroundColor: colors.border,
                    alignItems: 'center', opacity: pressed ? 0.8 : 1,
                  })}
                >
                  <Text style={{ fontSize: 15, fontWeight: '600', color: colors.textSecondary }}>Cancel</Text>
                </Pressable>
                <Pressable
                  onPress={handleUrlContinue}
                  disabled={!urlInput.trim()}
                  accessible
                  accessibilityRole="button"
                  accessibilityLabel="Continue with this URL"
                  accessibilityState={{ disabled: !urlInput.trim() }}
                  style={({ pressed }) => ({
                    flex: 1, paddingVertical: 12, borderRadius: 10,
                    backgroundColor: urlInput.trim() ? colors.accent : colors.border,
                    alignItems: 'center', opacity: pressed ? 0.85 : 1,
                  })}
                >
                  <Text style={{ fontSize: 15, fontWeight: '700', color: urlInput.trim() ? '#fff' : colors.textSecondary }}>
                    Continue
                  </Text>
                </Pressable>
              </View>
            </View>
          ) : (
            <Pressable
              onPress={() => { setUrlMode(true); Keyboard.dismiss(); }}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Use App Store URL instead"
              accessibilityHint="Paste a URL directly if search doesn't find the app"
              style={({ pressed }) => ({
                flexDirection: 'row', alignItems: 'center', justifyContent: 'center',
                gap: 8, paddingVertical: 14,
                borderRadius: 14, borderWidth: 1.5, borderColor: colors.border,
                marginTop: 8, opacity: pressed ? 0.8 : 1,
              })}
            >
              <Ionicons name="link-outline" size={18} color={colors.textSecondary} accessibilityElementsHidden />
              <Text style={{ fontSize: 15, fontWeight: '600', color: colors.textSecondary }}>
                Use an App Store URL instead
              </Text>
            </Pressable>
          )}
        </Animated.View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
