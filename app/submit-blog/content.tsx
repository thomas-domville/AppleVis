import { useRef, useState } from 'react';
import {
  AccessibilityInfo, ActivityIndicator, Clipboard, KeyboardAvoidingView,
  Platform, Pressable, Text, TextInput, View,
} from 'react-native';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { WizardLayout } from '../../src/components/WizardLayout';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useBlogWizard } from '../../src/contexts/BlogWizardContext';
import { usePreferences } from '../../src/contexts/PreferencesContext';
import { useAlert } from '../../src/contexts/AccessibleAlertContext';
import { isAppleIntelligenceAvailable, summariseText } from '../../src/services/intelligenceService';
import { sounds } from '../../src/services/sounds';

// ─── Step 2: Write / Import / Paste blog content ──────────────────────────────

type InputMode = 'write' | 'import' | 'paste';

export default function BlogStep2() {
  const { colors }         = useTheme();
  const { state, update, reset } = useBlogWizard();
  const { aiSummariesEnabled }   = usePreferences();
  const { showAlert }      = useAlert();

  const charCountRef    = useRef(state.blogContent.trim().length);
  const [mode, setMode] = useState<InputMode>('write');
  const [aiDrafting, setAiDrafting] = useState(false);

  const aiAvailable = aiSummariesEnabled && isAppleIntelligenceAvailable();
  const charCount   = state.blogContent.trim().length;
  const canContinue = charCount >= 50;

  function handleNext() {
    sounds.articleOpen().catch(() => {});
    router.push('/submit-blog/review' as any);
  }

  function handleCancel() {
    showAlert({
      title: 'Discard this submission?',
      message: 'Your blog post will be discarded.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep Editing',
      type: 'warning',
      onConfirm: () => {
        reset();
        router.replace('/(tabs)/discover' as any);
      },
    });
  }

  async function handleImport() {
    try {
      const { getDocumentAsync } = await import('expo-document-picker');
      const result = await getDocumentAsync({
        type: ['text/plain', 'text/markdown', 'text/x-markdown'],
        copyToCacheDirectory: true,
      });
      if (result.canceled || !result.assets?.length) return;
      const asset = result.assets[0];
      const { readAsStringAsync } = await import('expo-file-system');
      const content = await readAsStringAsync(asset.uri);
      update({ blogContent: content.trim() });
      setMode('write');
      sounds.bookmarkSaved().catch(() => {});
      AccessibilityInfo.announceForAccessibility(`File imported: ${asset.name}. ${content.trim().length} characters loaded.`);
    } catch {
      AccessibilityInfo.announceForAccessibility('Could not import file. Please try again.');
    }
  }

  async function handlePaste() {
    try {
      const text = await Clipboard.getString();
      if (!text?.trim()) {
        AccessibilityInfo.announceForAccessibility('Clipboard is empty.');
        return;
      }
      update({ blogContent: text.trim() });
      setMode('write');
      sounds.pickerTick().catch(() => {});
      AccessibilityInfo.announceForAccessibility(`${text.trim().length} characters pasted from clipboard.`);
    } catch {
      AccessibilityInfo.announceForAccessibility('Could not read clipboard. Please paste manually into the text field.');
      setMode('write');
    }
  }

  async function handleAiCoverNote() {
    if (!state.blogContent || !state.title) return;
    setAiDrafting(true);
    try {
      const text = await summariseText(
        `Write a 2–3 sentence pitch for an AppleVis blog post titled "${state.title}" in the "${state.category}" category. ` +
        `The post begins: "${state.blogContent.slice(0, 300)}…" ` +
        `The pitch should explain what the post covers and why it is valuable for blind and low-vision users.`
      );
      if (text) update({ coverNote: text });
      else AccessibilityInfo.announceForAccessibility('Could not generate cover note. Please try again.');
    } catch {
      AccessibilityInfo.announceForAccessibility('Apple Intelligence unavailable.');
    } finally {
      setAiDrafting(false);
    }
  }

  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined} keyboardVerticalOffset={60}>
      <WizardLayout
        step={2}
        totalSteps={3}
        title="Your blog post"
        description="Write, import a text file, or paste from another app. Minimum 50 characters required."
        onNext={handleNext}
        nextLabel="Continue to Review"
        nextDisabled={!canContinue}
        hideSkip
        onCancel={handleCancel}
      >
        {/* Mode tabs */}
        <View style={{ flexDirection: 'row', gap: 8, marginBottom: 20, backgroundColor: colors.card, borderRadius: 12, padding: 4 }}
          accessible={false}>
          {([['write', 'pencil-outline', 'Write'], ['import', 'document-text-outline', 'Import file'], ['paste', 'clipboard-outline', 'Paste']] as const).map(([m, icon, label]) => (
            <Pressable
              key={m}
              onPress={() => { setMode(m); sounds.pickerTick().catch(() => {}); }}
              accessible
              accessibilityRole="tab"
              accessibilityLabel={label}
              accessibilityState={{ selected: mode === m }}
              style={({ pressed }) => ({
                flex: 1, flexDirection: 'row', alignItems: 'center', justifyContent: 'center',
                gap: 5, paddingVertical: 10, borderRadius: 10,
                backgroundColor: mode === m ? colors.accent : 'transparent',
                opacity: pressed ? 0.8 : 1,
              })}
            >
              <Ionicons name={icon as any} size={15} color={mode === m ? '#fff' : colors.textSecondary} accessibilityElementsHidden />
              <Text style={{ fontSize: 13, fontWeight: mode === m ? '700' : '400', color: mode === m ? '#fff' : colors.textSecondary }}>
                {label}
              </Text>
            </Pressable>
          ))}
        </View>

        {/* Write mode */}
        {mode === 'write' && (
          <>
            <TextInput
              value={state.blogContent}
              onChangeText={v => update({ blogContent: v })}
              placeholder="Start writing your blog post here…"
              placeholderTextColor={colors.textSecondary}
              multiline
              style={{
                backgroundColor: colors.card, borderRadius: 14, padding: 14,
                fontSize: 16, color: colors.text, lineHeight: 24,
                borderWidth: 1.5, borderColor: canContinue ? colors.accent : colors.border,
                minHeight: 240, textAlignVertical: 'top',
              }}
              accessible
              accessibilityLabel="Blog post content"
              accessibilityHint="Write your full blog post here. Minimum 50 characters required."
            />
            <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginTop: 6, marginBottom: 4 }} accessibilityElementsHidden>
              <Text style={{ fontSize: 12, color: colors.textSecondary }}>
                {charCount < 50 ? `${50 - charCount} more characters needed` : 'Minimum reached ✓'}
              </Text>
              <Text style={{ fontSize: 12, color: canContinue ? colors.accent : colors.textSecondary, fontWeight: '600' }}>
                {charCount} chars
              </Text>
            </View>
          </>
        )}

        {/* Import mode */}
        {mode === 'import' && (
          <View style={{ alignItems: 'center', gap: 16, paddingVertical: 32 }}>
            <View style={{ width: 72, height: 72, borderRadius: 36, backgroundColor: `${colors.accent}18`, justifyContent: 'center', alignItems: 'center' }} accessibilityElementsHidden>
              <Ionicons name="folder-open-outline" size={36} color={colors.accent} />
            </View>
            <Text accessibilityRole="header" style={{ fontSize: 18, fontWeight: '700', color: colors.text, textAlign: 'center' }}>
              Import a text file
            </Text>
            <Text style={{ fontSize: 14, color: colors.textSecondary, textAlign: 'center', lineHeight: 21, maxWidth: 300 }}>
              Choose a .txt or .md file from Files, iCloud Drive, or any document provider.
            </Text>
            <Pressable
              onPress={() => void handleImport()}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Browse for a text or Markdown file"
              style={({ pressed }) => ({
                backgroundColor: colors.accent, borderRadius: 14, paddingVertical: 14, paddingHorizontal: 28,
                flexDirection: 'row', alignItems: 'center', gap: 8, opacity: pressed ? 0.85 : 1,
              })}
            >
              <Ionicons name="document-text-outline" size={18} color="#fff" accessibilityElementsHidden />
              <Text style={{ fontSize: 16, fontWeight: '700', color: '#fff' }}>Browse Files</Text>
            </Pressable>
            {state.blogContent ? (
              <Text style={{ fontSize: 13, color: colors.accent, fontWeight: '600' }} accessibilityLiveRegion="polite">
                File loaded — {state.blogContent.length} characters
              </Text>
            ) : null}
          </View>
        )}

        {/* Paste mode */}
        {mode === 'paste' && (
          <View style={{ alignItems: 'center', gap: 16, paddingVertical: 32 }}>
            <View style={{ width: 72, height: 72, borderRadius: 36, backgroundColor: `${colors.accent}18`, justifyContent: 'center', alignItems: 'center' }} accessibilityElementsHidden>
              <Ionicons name="clipboard-outline" size={36} color={colors.accent} />
            </View>
            <Text accessibilityRole="header" style={{ fontSize: 18, fontWeight: '700', color: colors.text, textAlign: 'center' }}>
              Paste from clipboard
            </Text>
            <Text style={{ fontSize: 14, color: colors.textSecondary, textAlign: 'center', lineHeight: 21, maxWidth: 300 }}>
              Write your post in Notes, Pages, or any other app, then copy and paste it here.
            </Text>
            <Pressable
              onPress={() => void handlePaste()}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Paste text from clipboard"
              style={({ pressed }) => ({
                backgroundColor: colors.accent, borderRadius: 14, paddingVertical: 14, paddingHorizontal: 28,
                flexDirection: 'row', alignItems: 'center', gap: 8, opacity: pressed ? 0.85 : 1,
              })}
            >
              <Ionicons name="clipboard-outline" size={18} color="#fff" accessibilityElementsHidden />
              <Text style={{ fontSize: 16, fontWeight: '700', color: '#fff' }}>Paste from Clipboard</Text>
            </Pressable>
            {state.blogContent ? (
              <Text style={{ fontSize: 13, color: colors.accent, fontWeight: '600' }} accessibilityLiveRegion="polite">
                Content ready — {state.blogContent.length} characters
              </Text>
            ) : null}
          </View>
        )}

        {/* Cover note */}
        <View style={{ marginTop: 28 }}>
          <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 4 }}>
            Note to editors <Text style={{ fontWeight: '400', textTransform: 'none' }}>(optional)</Text>
          </Text>
          <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 19, marginBottom: 8 }}>
            Tell the editorial team anything they should know — background, why you wrote this, related links, etc.
          </Text>
          <TextInput
            value={state.coverNote}
            onChangeText={v => update({ coverNote: v })}
            placeholder="e.g. This is based on my own experience using VoiceOver daily…"
            placeholderTextColor={colors.textSecondary}
            multiline
            style={{
              backgroundColor: colors.card, borderRadius: 14, padding: 14,
              fontSize: 16, color: colors.text, lineHeight: 22,
              borderWidth: 1.5, borderColor: state.coverNote ? colors.accent : colors.border,
              minHeight: 100, textAlignVertical: 'top',
            }}
            accessible
            accessibilityLabel="Note to editors"
            accessibilityHint="Optional. Any context or background you want the editorial team to know."
          />
        </View>

        {/* AI cover note button */}
        {aiAvailable && state.blogContent.length >= 50 && (
          <Pressable
            onPress={() => void handleAiCoverNote()}
            disabled={aiDrafting}
            accessible
            accessibilityRole="button"
            accessibilityLabel={aiDrafting ? 'Drafting cover note with Apple Intelligence…' : 'Draft editor note with Apple Intelligence'}
            style={({ pressed }) => ({
              flexDirection: 'row', alignItems: 'center', gap: 8,
              alignSelf: 'flex-start', marginTop: 10,
              backgroundColor: colors.card, borderRadius: 20,
              paddingVertical: 9, paddingHorizontal: 14,
              borderWidth: 1.5, borderColor: colors.border,
              opacity: pressed || aiDrafting ? 0.7 : 1,
            })}
          >
            {aiDrafting ? <ActivityIndicator size="small" color={colors.accent} /> : <Ionicons name="sparkles" size={15} color={colors.accent} />}
            <Text style={{ fontSize: 14, fontWeight: '600', color: colors.accent }}>
              {aiDrafting ? 'Drafting…' : 'Draft with Apple Intelligence'}
            </Text>
          </Pressable>
        )}
      </WizardLayout>
    </KeyboardAvoidingView>
  );
}
