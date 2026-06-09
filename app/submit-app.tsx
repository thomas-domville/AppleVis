import { useCallback, useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator, Alert, Clipboard, Image, Keyboard,
  KeyboardAvoidingView, Platform, Pressable, ScrollView, Text,
  TextInput, View,
} from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { useToast } from '../src/contexts/ToastContext';
import { isAppleIntelligenceAvailable, summariseText } from '../src/services/intelligenceService';
import { fetchItunesMetadata } from '../src/services/itunesApi';
import type { ItunesMetadata } from '../src/services/itunesApi';

// ─── Types ────────────────────────────────────────────────────────────────────

type AppPlatform = 'iOS' | 'macOS' | 'watchOS' | 'Apple TV' | 'Vision Pro';
const ALL_PLATFORMS: AppPlatform[] = ['iOS', 'macOS', 'watchOS', 'Apple TV', 'Vision Pro'];

type LookupState = 'idle' | 'loading' | 'done' | 'error';

// ─── Helpers ──────────────────────────────────────────────────────────────────

function isAppStoreUrl(url: string): boolean {
  return /apps\.apple\.com|itunes\.apple\.com/.test(url);
}

function stripDescription(html: string): string {
  return html
    .replace(/<[^>]+>/g, ' ')
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&nbsp;/g, ' ').replace(/\s+/g, ' ')
    .trim();
}

// ─── Sub-components ───────────────────────────────────────────────────────────

function FieldLabel({ text, required }: { text: string; required?: boolean }) {
  const { colors } = useTheme();
  return (
    <Text style={{ fontSize: 13, fontWeight: '600', color: colors.textSecondary, marginBottom: 6, textTransform: 'uppercase', letterSpacing: 0.5 }}>
      {text}{required ? <Text style={{ color: colors.accent }}> *</Text> : null}
    </Text>
  );
}

function SectionDivider({ label }: { label: string }) {
  const { colors } = useTheme();
  return (
    <View
      accessible
      accessibilityRole="header"
      style={{ flexDirection: 'row', alignItems: 'center', marginVertical: 20 }}
    >
      <View style={{ flex: 1, height: 1, backgroundColor: colors.border }} />
      <Text style={{ marginHorizontal: 12, fontSize: 11, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 1 }}>
        {label}
      </Text>
      <View style={{ flex: 1, height: 1, backgroundColor: colors.border }} />
    </View>
  );
}

// ─── Main screen ──────────────────────────────────────────────────────────────

export default function SubmitAppScreen() {
  const { colors } = useTheme();
  const router     = useRouter();
  const { showToast } = useToast();
  const params     = useLocalSearchParams<{ url?: string }>();

  const scrollRef  = useRef<ScrollView>(null);

  const [storeUrl, setStoreUrl]         = useState(params.url ?? '');
  const [lookupState, setLookupState]   = useState<LookupState>('idle');
  const [meta, setMeta]                 = useState<ItunesMetadata | null>(null);

  // Editable form fields (pre-filled from iTunes, then user-editable)
  const [appName, setAppName]           = useState('');
  const [developer, setDeveloper]       = useState('');
  const [selectedPlatforms, setSelectedPlatforms] = useState<AppPlatform[]>(['iOS']);
  const [category, setCategory]         = useState('');
  const [a11yNotes, setA11yNotes]       = useState('');
  const [shortSummary, setShortSummary] = useState('');

  // AI
  const aiAvailable = isAppleIntelligenceAvailable();
  const [aiDrafting, setAiDrafting]     = useState(false);

  // ── Look Up ─────────────────────────────────────────────────────────────────

  const handleLookUp = useCallback(async (urlOverride?: string) => {
    const target = (urlOverride ?? storeUrl).trim();
    if (!target) {
      showToast('Enter an App Store URL first.', 'error');
      return;
    }
    if (!isAppStoreUrl(target)) {
      showToast('That doesn\'t look like an App Store URL.', 'error');
      return;
    }
    Keyboard.dismiss();
    setLookupState('loading');
    if (!urlOverride) setStoreUrl(target);
    try {
      const data = await fetchItunesMetadata(target);
      if (!data) {
        setLookupState('error');
        showToast('App not found. Check the URL and try again.', 'error');
        return;
      }
      setMeta(data);
      setAppName(data.appName);
      setDeveloper(data.developerName);
      setCategory(data.category);
      // Keep iOS selected; add macOS/other if category hints at it
      if (data.appStoreUrl.includes('macOS') || data.minimumOsVersion === '') {
        // iTunes doesn't flag mac vs iOS clearly in a single field; keep iOS default
      }
      setLookupState('done');
      setTimeout(() => scrollRef.current?.scrollTo({ y: 300, animated: true }), 200);
    } catch {
      setLookupState('error');
      showToast('Network error. Please try again.', 'error');
    }
  }, [storeUrl, showToast]);

  // Auto-look-up when arriving from the Share Extension deep link
  useEffect(() => {
    if (params.url && params.url.trim()) {
      void handleLookUp(params.url.trim());
    }
  // only once on mount
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // ── Platform toggle ─────────────────────────────────────────────────────────

  function togglePlatform(p: AppPlatform) {
    setSelectedPlatforms(prev =>
      prev.includes(p)
        ? prev.length > 1 ? prev.filter(x => x !== p) : prev // keep at least one
        : [...prev, p]
    );
  }

  // ── AI Draft ────────────────────────────────────────────────────────────────

  async function handleAiDraft() {
    if (!meta) return;
    setAiDrafting(true);
    try {
      const desc = stripDescription(meta.appStoreDescription).slice(0, 600);
      const text = await summariseText(
        `Write a 2-sentence accessibility-focused summary for "${meta.appName}" by ${meta.developerName}. ` +
        `Highlight features that benefit blind and low-vision users. App description: ${desc}`
      );
      if (text) setShortSummary(text);
      else showToast('Could not generate summary.', 'error');
    } catch {
      showToast('Apple Intelligence unavailable.', 'error');
    } finally {
      setAiDrafting(false);
    }
  }

  // ── Submit ───────────────────────────────────────────────────────────────────

  async function handleSubmit() {
    if (!meta) {
      showToast('Look up an App Store URL first.', 'error');
      return;
    }
    if (a11yNotes.trim().length < 20) {
      showToast('Accessibility notes must be at least 20 characters.', 'error');
      return;
    }

    // NOTE TO DRUPAL DEVELOPER:
    // When the app submission endpoint is confirmed, replace the web-form fallback
    // below with a real JSON:API POST. Expected payload:
    //   type: 'node--ios_app_directory' (or whichever content type machine name)
    //   attributes:
    //     title:                appName
    //     field_developer:      developer
    //     field_platform:       selectedPlatforms (multi-value)
    //     field_category:       category
    //     field_app_store_url:  meta.appStoreUrl or storeUrl
    //     field_price:          meta.price
    //     field_bundle_id:      meta.bundleId
    //     field_a11y_notes:     { value: a11yNotes, format: 'basic_html' }
    //     field_short_summary:  shortSummary (optional)
    //   Authentication: include CSRF token + session cookie (same as forum reply).

    // Copy notes to clipboard so the user can paste into the web form.
    Clipboard.setString(a11yNotes.trim());

    Alert.alert(
      'Complete Your Submission',
      'Your accessibility notes have been copied to the clipboard.\n\nThe AppleVis web form will open — paste your notes in the Accessibility Notes field to finish.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Open Web Form',
          onPress: () => {
            void import('expo-linking').then(({ default: Linking }) =>
              Linking.openURL('https://www.applevis.com/node/add').catch(() => {
                showToast('Could not open the form.', 'error');
              })
            );
            router.back();
          },
        },
      ]
    );
  }

  // ── Computed ─────────────────────────────────────────────────────────────────

  const canSubmit = !!meta && a11yNotes.trim().length >= 20;

  // ── Styles ───────────────────────────────────────────────────────────────────

  const s = {
    card: {
      backgroundColor: colors.card,
      borderRadius: 14,
      padding: 16,
      marginBottom: 12,
    } as const,
    input: {
      backgroundColor: colors.card,
      borderRadius: 10,
      padding: 12,
      fontSize: 16,
      color: colors.text,
      borderWidth: 1,
      borderColor: colors.border,
    } as const,
    multiline: {
      backgroundColor: colors.card,
      borderRadius: 10,
      padding: 12,
      fontSize: 16,
      color: colors.text,
      borderWidth: 1,
      borderColor: colors.border,
      minHeight: 120,
      textAlignVertical: 'top' as const,
    } as const,
    pill: (active: boolean) => ({
      paddingHorizontal: 14,
      paddingVertical: 7,
      borderRadius: 20,
      borderWidth: 1.5,
      borderColor: active ? colors.accent : colors.border,
      backgroundColor: active ? colors.accent : 'transparent',
      marginRight: 8,
    }) as const,
    pillText: (active: boolean) => ({
      fontSize: 13,
      fontWeight: '600' as const,
      color: active ? '#fff' : colors.textSecondary,
    }),
  };

  // ── Render ───────────────────────────────────────────────────────────────────

  return (
    <Screen title="Submit an App" showSettings={false}>
      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        keyboardVerticalOffset={88}
      >
        <ScrollView
          ref={scrollRef}
          contentContainerStyle={{ padding: 16, paddingBottom: 48 }}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          {/* ── Intro ───────────────────────────────────────────────────────── */}
          <Text style={{ fontSize: 15, color: colors.textSecondary, lineHeight: 22, marginBottom: 20 }}>
            Share an accessible iOS app with the AppleVis community. Paste the App Store link below and we'll pre-fill as much as possible.
          </Text>

          {/* ── Look Up ─────────────────────────────────────────────────────── */}
          <SectionDivider label="Find App" />

          <FieldLabel text="App Store URL" required />
          <View style={{ flexDirection: 'row', gap: 8, marginBottom: 16 }}>
            <TextInput
              style={[s.input, { flex: 1 }]}
              value={storeUrl}
              onChangeText={setStoreUrl}
              placeholder="https://apps.apple.com/app/id..."
              placeholderTextColor={colors.textSecondary}
              autoCapitalize="none"
              autoCorrect={false}
              keyboardType="url"
              returnKeyType="search"
              onSubmitEditing={() => void handleLookUp()}
              accessible
              accessibilityLabel="App Store URL"
              accessibilityHint="Paste the App Store link here"
            />
            <Pressable
              onPress={() => void handleLookUp()}
              disabled={lookupState === 'loading'}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Look Up"
              accessibilityHint="Fetches app details from the App Store"
              style={({ pressed }) => ({
                backgroundColor: lookupState === 'loading' ? colors.border : colors.accent,
                borderRadius: 10,
                paddingHorizontal: 16,
                justifyContent: 'center',
                opacity: pressed ? 0.8 : 1,
              })}
            >
              {lookupState === 'loading'
                ? <ActivityIndicator color="#fff" />
                : <Text style={{ color: '#fff', fontWeight: '700', fontSize: 15 }}>Look Up</Text>
              }
            </Pressable>
          </View>

          {lookupState === 'error' && (
            <Text
              accessible
              accessibilityRole="alert"
              style={{ fontSize: 14, color: '#e44', marginBottom: 12 }}
            >
              App not found. Make sure the URL is a valid App Store link (apps.apple.com/…/id…).
            </Text>
          )}

          {/* ── App Card (post-lookup) ───────────────────────────────────────── */}
          {meta && (
            <View
              accessible
              accessibilityLabel={`Found: ${meta.appName} by ${meta.developerName}. ${meta.price}. Category: ${meta.category}.`}
              style={[s.card, { flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 4 }]}
            >
              {meta.artworkUrl ? (
                <Image
                  source={{ uri: meta.artworkUrl }}
                  style={{ width: 56, height: 56, borderRadius: 12 }}
                  accessibilityElementsHidden
                />
              ) : (
                <View style={{ width: 56, height: 56, borderRadius: 12, backgroundColor: colors.border, justifyContent: 'center', alignItems: 'center' }} accessibilityElementsHidden>
                  <Ionicons name="phone-portrait-outline" size={26} color={colors.textSecondary} />
                </View>
              )}
              <View style={{ flex: 1 }}>
                <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text }}>{meta.appName}</Text>
                <Text style={{ fontSize: 13, color: colors.textSecondary, marginTop: 2 }}>{meta.developerName}</Text>
                <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2 }}>{meta.price} · {meta.category}</Text>
              </View>
              <Ionicons name="checkmark-circle" size={22} color={colors.accent} accessibilityElementsHidden />
            </View>
          )}

          {/* ── App Details ─────────────────────────────────────────────────── */}
          {meta && (
            <>
              <SectionDivider label="App Details" />

              <FieldLabel text="App Name" required />
              <TextInput
                style={[s.input, { marginBottom: 14 }]}
                value={appName}
                onChangeText={setAppName}
                placeholder="App name"
                placeholderTextColor={colors.textSecondary}
                returnKeyType="next"
                accessible
                accessibilityLabel="App name"
              />

              <FieldLabel text="Developer" required />
              <TextInput
                style={[s.input, { marginBottom: 14 }]}
                value={developer}
                onChangeText={setDeveloper}
                placeholder="Developer or publisher name"
                placeholderTextColor={colors.textSecondary}
                returnKeyType="next"
                accessible
                accessibilityLabel="Developer name"
              />

              <FieldLabel text="Category" />
              <TextInput
                style={[s.input, { marginBottom: 14 }]}
                value={category}
                onChangeText={setCategory}
                placeholder="e.g. Productivity, Utilities"
                placeholderTextColor={colors.textSecondary}
                returnKeyType="next"
                accessible
                accessibilityLabel="App category"
              />

              <FieldLabel text="Platform" required />
              <ScrollView
                horizontal
                showsHorizontalScrollIndicator={false}
                contentContainerStyle={{ paddingBottom: 14 }}
                accessible={false}
              >
                {ALL_PLATFORMS.map(p => (
                  <Pressable
                    key={p}
                    onPress={() => togglePlatform(p)}
                    accessible
                    accessibilityRole="checkbox"
                    accessibilityLabel={p}
                    accessibilityState={{ checked: selectedPlatforms.includes(p) }}
                    style={({ pressed }) => [s.pill(selectedPlatforms.includes(p)), { opacity: pressed ? 0.8 : 1 }]}
                  >
                    <Text style={s.pillText(selectedPlatforms.includes(p))}>{p}</Text>
                  </Pressable>
                ))}
              </ScrollView>

              <View style={[s.card, { flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 0 }]} accessibilityElementsHidden>
                <Ionicons name="storefront-outline" size={16} color={colors.textSecondary} />
                <Text style={{ fontSize: 13, color: colors.textSecondary, flex: 1 }} numberOfLines={1}>
                  {meta.price} · v{meta.version} · iOS {meta.minimumOsVersion}+
                </Text>
              </View>
            </>
          )}

          {/* ── Accessibility Notes ──────────────────────────────────────────── */}
          <SectionDivider label="Your Contribution" />

          <FieldLabel text="Accessibility Notes" required />
          <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 19, marginBottom: 10 }}>
            Describe what makes this app useful for blind and low-vision users — VoiceOver support, switch access, Dynamic Type, known issues, etc.
          </Text>
          <TextInput
            style={[s.multiline, { marginBottom: 6 }]}
            value={a11yNotes}
            onChangeText={setA11yNotes}
            placeholder="e.g. Full VoiceOver support with meaningful labels on all interactive elements. Supports Dynamic Type up to Accessibility Extra Large. Compatible with Switch Control…"
            placeholderTextColor={colors.textSecondary}
            multiline
            accessible
            accessibilityLabel="Accessibility notes"
            accessibilityHint="Required. Describe the accessibility features of this app."
          />
          <Text
            style={{ fontSize: 12, color: a11yNotes.trim().length < 20 ? '#e44' : colors.textSecondary, textAlign: 'right', marginBottom: 16 }}
            accessibilityElementsHidden
          >
            {a11yNotes.trim().length} chars {a11yNotes.trim().length < 20 ? '(minimum 20)' : '✓'}
          </Text>

          {/* ── Short Summary ────────────────────────────────────────────────── */}
          <FieldLabel text="Short Summary (optional)" />
          <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 19, marginBottom: 10 }}>
            A brief one- or two-sentence headline for the AppleVis listing.
          </Text>
          <TextInput
            style={[s.multiline, { minHeight: 80, marginBottom: 10 }]}
            value={shortSummary}
            onChangeText={setShortSummary}
            placeholder="A concise overview for sighted and VoiceOver users browsing the directory…"
            placeholderTextColor={colors.textSecondary}
            multiline
            accessible
            accessibilityLabel="Short summary"
            accessibilityHint="Optional. A brief headline description for the listing."
          />

          {aiAvailable && meta && (
            <Pressable
              onPress={() => void handleAiDraft()}
              disabled={aiDrafting}
              accessible
              accessibilityRole="button"
              accessibilityLabel={aiDrafting ? 'Drafting summary with Apple Intelligence…' : 'Draft summary with Apple Intelligence'}
              style={({ pressed }) => ({
                flexDirection: 'row',
                alignItems: 'center',
                gap: 8,
                alignSelf: 'flex-start',
                backgroundColor: colors.card,
                borderRadius: 20,
                paddingVertical: 8,
                paddingHorizontal: 14,
                borderWidth: 1,
                borderColor: colors.border,
                marginBottom: 20,
                opacity: pressed || aiDrafting ? 0.7 : 1,
              })}
            >
              {aiDrafting
                ? <ActivityIndicator size="small" color={colors.accent} />
                : <Ionicons name="sparkles" size={16} color={colors.accent} />
              }
              <Text style={{ fontSize: 14, fontWeight: '600', color: colors.accent }}>
                {aiDrafting ? 'Drafting…' : 'Draft with Apple Intelligence'}
              </Text>
            </Pressable>
          )}

          {/* ── Submit ───────────────────────────────────────────────────────── */}
          <Pressable
            onPress={() => void handleSubmit()}
            disabled={!canSubmit}
            accessible
            accessibilityRole="button"
            accessibilityLabel="Submit App Entry"
            accessibilityHint={canSubmit ? 'Opens the AppleVis web form to complete your submission' : 'Look up an app and add accessibility notes before submitting'}
            style={({ pressed }) => ({
              backgroundColor: canSubmit ? colors.accent : colors.border,
              borderRadius: 14,
              paddingVertical: 16,
              alignItems: 'center',
              marginTop: 8,
              opacity: pressed ? 0.85 : 1,
            })}
          >
            <Text style={{ color: canSubmit ? '#fff' : colors.textSecondary, fontSize: 17, fontWeight: '700' }}>
              Submit App Entry
            </Text>
          </Pressable>

          <Text style={{ fontSize: 12, color: colors.textSecondary, textAlign: 'center', marginTop: 10, lineHeight: 17 }}>
            Your accessibility notes will be copied to the clipboard. You'll be taken to the AppleVis web form to complete the submission.
          </Text>
        </ScrollView>
      </KeyboardAvoidingView>
    </Screen>
  );
}
