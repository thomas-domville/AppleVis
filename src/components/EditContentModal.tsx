import { useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator, KeyboardAvoidingView, Modal, Platform,
  Pressable, StyleSheet, Text, TextInput, View,
} from 'react-native';
import { useTheme } from '../contexts/ThemeContext';
import { api } from '../services/api';

export type EditContentModalProps = {
  visible: boolean;
  onClose: () => void;
  /** Called with the new body text after a successful save. */
  onSaved: (newBody: string) => void;
  /** JSON:API UUID of the comment/reply (not the numeric cid). */
  commentId: string;
  /** JSON:API bundle name, e.g. 'comment_forum', 'comment_node_blog2'. */
  commentType: string;
  csrfToken: string;
  /** Pre-rendered HTML body already in state — shown as placeholder while raw loads. */
  initialBody: string;
  label: string;
};

function stripHtmlBasic(html: string): string {
  return html
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n\n')
    .replace(/<[^>]*>/g, '')
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&#039;/g, "'").replace(/&apos;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

export function EditContentModal({
  visible, onClose, onSaved, commentId, commentType, csrfToken, initialBody, label,
}: EditContentModalProps) {
  const { colors } = useTheme();
  const [text, setText]       = useState('');
  const [format, setFormat]   = useState('basic_html');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving]   = useState(false);
  const [error, setError]     = useState('');
  const inputRef              = useRef<TextInput>(null);

  useEffect(() => {
    if (!visible) return;
    setError('');
    setSaving(false);
    // Optimistically populate from the already-loaded HTML body
    setText(stripHtmlBasic(initialBody));
    setLoading(true);

    api.content.fetchRawComment(commentType, commentId, csrfToken).then((res) => {
      if (res.ok) {
        setText(res.data.rawValue);
        setFormat(res.data.format);
      }
      setLoading(false);
      setTimeout(() => inputRef.current?.focus(), 100);
    }).catch(() => {
      setLoading(false);
    });
  }, [visible, commentId]);

  async function handleSave() {
    const trimmed = text.trim();
    if (!trimmed) { setError('Comment cannot be empty.'); return; }
    setSaving(true);
    setError('');
    const res = await api.content.editComment(commentType, commentId, trimmed, format, csrfToken);
    setSaving(false);
    if (res.ok) {
      onSaved(trimmed);
      onClose();
    } else {
      setError(res.error ?? 'Could not save. Please try again.');
    }
  }

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={onClose}
      accessible={false}
    >
      <KeyboardAvoidingView
        style={{ flex: 1, backgroundColor: colors.background }}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        {/* Header */}
        <View style={[ss.header, { borderBottomColor: colors.border, backgroundColor: colors.card }]}>
          <Pressable
            onPress={onClose}
            accessible accessibilityRole="button" accessibilityLabel="Cancel"
            style={({ pressed }) => [ss.headerBtn, pressed && { opacity: 0.6 }]}
          >
            <Text style={[ss.headerBtnText, { color: colors.accent }]}>Cancel</Text>
          </Pressable>
          <Text
            style={[ss.headerTitle, { color: colors.text }]}
            accessibilityRole="header"
            numberOfLines={1}
          >
            Edit {label}
          </Text>
          <Pressable
            onPress={handleSave}
            disabled={saving || loading}
            accessible accessibilityRole="button" accessibilityLabel={saving ? 'Saving' : 'Save'}
            style={({ pressed }) => [ss.headerBtn, pressed && { opacity: 0.6 }]}
          >
            {saving
              ? <ActivityIndicator size="small" color={colors.accent} />
              : <Text style={[ss.headerBtnText, { color: colors.accent, fontWeight: '700' }]}>Save</Text>
            }
          </Pressable>
        </View>

        {loading
          ? (
            <View style={ss.center}>
              <ActivityIndicator size="large" color={colors.accent} />
              <Text style={[ss.loadingText, { color: colors.textSecondary }]}>Loading…</Text>
            </View>
          )
          : (
            <View style={{ flex: 1, padding: 16 }}>
              {!!error && (
                <Text
                  style={[ss.error, { color: '#B91C1C', backgroundColor: '#FFF0F0',
                    borderColor: '#FCA5A5' }]}
                  accessibilityRole="alert"
                  accessibilityLiveRegion="assertive"
                >
                  {error}
                </Text>
              )}
              <TextInput
                ref={inputRef}
                value={text}
                onChangeText={setText}
                multiline
                textAlignVertical="top"
                style={[ss.input, {
                  color: colors.text,
                  backgroundColor: colors.card,
                  borderColor: colors.border,
                }]}
                accessibilityLabel={`Edit ${label} text`}
                accessibilityHint="Double-tap to edit. Swipe down with three fingers or tap Cancel when done."
                placeholder="Write your text here…"
                placeholderTextColor={colors.textSecondary}
                scrollEnabled
              />
            </View>
          )
        }
      </KeyboardAvoidingView>
    </Modal>
  );
}

const ss = StyleSheet.create({
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingTop: 16,
    paddingBottom: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  headerBtn:     { minWidth: 64, alignItems: 'center' },
  headerBtnText: { fontSize: 17 },
  headerTitle:   { fontSize: 17, fontWeight: '600', flex: 1, textAlign: 'center', marginHorizontal: 8 },
  center:        { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 12 },
  loadingText:   { fontSize: 15 },
  error:         { fontSize: 14, padding: 12, borderRadius: 10, borderWidth: 1, marginBottom: 12 },
  input:         { flex: 1, fontSize: 16, lineHeight: 24, padding: 12, borderRadius: 10,
    borderWidth: 1, minHeight: 200 },
});
