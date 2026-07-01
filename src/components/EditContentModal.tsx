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
  /** Called with the new body (and optional new title for topic mode) after a successful save. */
  onSaved: (newBody: string, newTitle?: string) => void;
  csrfToken: string;
  /** Pre-rendered HTML body already in state — shown as placeholder while raw loads. */
  initialBody: string;
  label: string;
  // ── Comment mode (commentId + commentType required) ──
  /** JSON:API UUID of the comment/reply (not the numeric cid). */
  commentId?: string;
  /** JSON:API bundle name, e.g. 'comment_forum', 'comment_node_blog2'. */
  commentType?: string;
  // ── Topic/node mode (nodeId + initialTitle required) ──
  /** JSON:API UUID of the forum node being edited. */
  nodeId?: string;
  /** Current topic title — shown in an editable field above the body. */
  initialTitle?: string;
  /**
   * Drupal JSON:API type suffix for the node, e.g. 'forum', 'podcast',
   * 'ios_app_directory', 'guides', 'blog2'. Defaults to 'forum'.
   */
  nodeType?: string;
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
  visible, onClose, onSaved,
  commentId, commentType, nodeId, initialTitle, nodeType = 'forum',
  csrfToken, initialBody, label,
}: EditContentModalProps) {
  const { colors } = useTheme();
  const isTopicMode           = !!nodeId;
  const [titleText, setTitleText] = useState('');
  const [text, setText]       = useState('');
  const [format, setFormat]   = useState('basic_html');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving]   = useState(false);
  const [error, setError]     = useState('');
  const titleInputRef         = useRef<TextInput>(null);
  const inputRef              = useRef<TextInput>(null);

  useEffect(() => {
    if (!visible) return;
    setError('');
    setSaving(false);
    setText(stripHtmlBasic(initialBody));
    setTitleText(initialTitle ?? '');

    if (isTopicMode) {
      // Topic bodies are already stripped from the detail screen — no separate raw fetch needed.
      setLoading(false);
      setTimeout(() => (initialTitle ? titleInputRef.current?.focus() : inputRef.current?.focus()), 100);
      return;
    }

    setLoading(true);
    api.content.fetchRawComment(commentType!, commentId!, csrfToken).then((res) => {
      if (res.ok) {
        setText(res.data.rawValue);
        setFormat(res.data.format);
      }
      setLoading(false);
      setTimeout(() => inputRef.current?.focus(), 100);
    }).catch(() => {
      setLoading(false);
    });
  }, [visible, commentId, nodeId]);

  async function handleSave() {
    const trimmedBody  = text.trim();
    const trimmedTitle = titleText.trim();
    if (!trimmedBody)  { setError(`${label} cannot be empty.`); return; }
    if (isTopicMode && !trimmedTitle) { setError('Title cannot be empty.'); return; }
    setSaving(true);
    setError('');

    if (isTopicMode) {
      const res = await api.content.editNode(nodeId!, nodeType, trimmedTitle, trimmedBody, csrfToken);
      setSaving(false);
      if (res.ok) { onSaved(trimmedBody, trimmedTitle); onClose(); }
      else { setError(res.error ?? 'Could not save. Please try again.'); }
      return;
    }

    const res = await api.content.editComment(commentType!, commentId!, trimmedBody, format, csrfToken);
    setSaving(false);
    if (res.ok) { onSaved(trimmedBody); onClose(); }
    else { setError(res.error ?? 'Could not save. Please try again.'); }
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
        onAccessibilityEscape={onClose}
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
              {isTopicMode && (
                <TextInput
                  ref={titleInputRef}
                  value={titleText}
                  onChangeText={setTitleText}
                  returnKeyType="next"
                  onSubmitEditing={() => inputRef.current?.focus()}
                  style={[ss.titleInput, {
                    color: colors.text,
                    backgroundColor: colors.card,
                    borderColor: colors.border,
                  }]}
                  accessibilityLabel="Edit topic title"
                  placeholder="Topic title…"
                  placeholderTextColor={colors.textSecondary}
                />
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
  titleInput:    { fontSize: 17, fontWeight: '600', padding: 12, borderRadius: 10,
    borderWidth: 1, marginBottom: 10 },
  input:         { flex: 1, fontSize: 16, lineHeight: 24, padding: 12, borderRadius: 10,
    borderWidth: 1, minHeight: 200 },
});
