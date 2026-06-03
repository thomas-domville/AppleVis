import { useEffect, useRef, useState } from 'react';
import { AccessibilityInfo, ActivityIndicator, Pressable, ScrollView, Text, View } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../../src/components/Screen';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { useAuth } from '../../src/contexts/AuthContext';
import { useToast } from '../../src/contexts/ToastContext';
import { useSavedItems } from '../../src/hooks/useSavedItems';
import { useHandoff } from '../../src/hooks/useHandoff';
import { readAloud, translateContent } from '../../src/services/intelligenceService';
import { api } from '../../src/services/api';
import type { ForumTopicDetail, ForumReply } from '../../src/types/content';

function formatDate(iso: string): string {
  if (!iso) return '';
  return new Date(iso).toLocaleDateString(undefined, { year: 'numeric', month: 'long', day: 'numeric' });
}

function stripHtml(html: string): string {
  return html.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
}

function ReplyCard({ reply, colors, styles }: {
  reply: ForumReply;
  colors: ReturnType<typeof useTheme>['colors'];
  styles: ReturnType<typeof useTheme>['styles'];
}) {
  const plain = stripHtml(reply.body);
  return (
    <View
      style={[styles.card, reply.isNew && { borderLeftWidth: 3, borderLeftColor: colors.accent }]}
      accessible
      accessibilityLabel={`Reply by ${reply.authorName}, ${formatDate(reply.createdAt)}. ${plain}`}
    >
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 8 }}>
        <View style={{ width: 28, height: 28, borderRadius: 14, backgroundColor: colors.pill,
          alignItems: 'center', justifyContent: 'center' }} accessibilityElementsHidden>
          <Text style={{ fontSize: 13, fontWeight: '700', color: colors.pillText }}>
            {reply.authorName.charAt(0).toUpperCase()}
          </Text>
        </View>
        <View style={{ flex: 1 }}>
          <Text style={{ fontSize: 14, fontWeight: '700', color: colors.text }}>{reply.authorName}</Text>
          <Text style={{ fontSize: 12, color: colors.textSecondary }}>{formatDate(reply.createdAt)}</Text>
        </View>
        {reply.isNew && (
          <View style={{ backgroundColor: colors.accent, borderRadius: 6, paddingHorizontal: 6, paddingVertical: 2 }}>
            <Text style={{ color: colors.accentText, fontSize: 10, fontWeight: '700' }}>NEW</Text>
          </View>
        )}
      </View>
      <Text style={{ fontSize: 15, lineHeight: 23, color: colors.text }}>{plain}</Text>
    </View>
  );
}

export default function TopicDetail() {
  const { id, title: paramTitle } = useLocalSearchParams<{ id: string; title?: string }>();
  const router           = useRouter();
  const { colors, styles } = useTheme();
  const { screenReaderEnabled } = useAccessibilityPreferences();
  const auth             = useAuth();
  const { showToast }    = useToast();
  const saved            = useSavedItems('forumTopic');

  const [topic,   setTopic]   = useState<ForumTopicDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error,   setError]   = useState<string | null>(null);
  const headingRef = useRef<Text>(null);

  useHandoff(topic ? {
    activityType: 'com.applevis.app.viewTopic',
    title: topic.title,
    webpageURL: topic.url,
  } : null);

  useEffect(() => {
    if (!id) return;
    api.forums.topicDetail(id).then((res) => {
      setLoading(false);
      if (res.ok) {
        setTopic(res.data);
        setTimeout(() => {
          const node = headingRef.current ? (headingRef.current as any)._nativeTag : null;
          if (node) AccessibilityInfo.setAccessibilityFocus(node);
        }, 300);
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
    if (!topic) return;
    if (isSaved) {
      saved.unsave(id!);
      showToast('Removed from saved.', 'success');
    } else {
      saved.save({ id: id!, kind: 'forumTopic', title: topic.title, savedAt: new Date().toISOString() });
      showToast('Topic saved.', 'success');
    }
  }

  const displayTitle = topic?.title ?? paramTitle ?? 'Topic';

  return (
    <Screen title={displayTitle} showSettings={false} showSearch={false}>
      <ScrollView showsVerticalScrollIndicator={false}>

        {loading && (
          <View style={{ alignItems: 'center', paddingVertical: 48 }}>
            <ActivityIndicator size="large" color={colors.accent} />
            <Text style={[styles.cardMeta, { marginTop: 12, textAlign: 'center' }]}>Loading topic...</Text>
          </View>
        )}

        {!loading && error && (
          <View style={[styles.card, { borderColor: '#FCA5A5', borderWidth: 1 }]}>
            <Text style={[styles.cardTitle, { color: '#B91C1C' }]}>Could not load topic</Text>
            <Text style={styles.cardMeta}>{error}</Text>
            <Text style={[styles.cardMeta, { marginTop: 8 }]}>
              The Drupal API endpoint for topic detail may not be ready yet.
              The Drupal developer needs to confirm the comment entity type and filter path.
            </Text>
            <Pressable
              onPress={() => { setLoading(true); setError(null);
                api.forums.topicDetail(id!).then((res) => {
                  setLoading(false);
                  if (res.ok) setTopic(res.data); else setError(res.error);
                });
              }}
              accessible accessibilityRole="button" accessibilityLabel="Retry loading topic"
              style={{ marginTop: 12 }}
            >
              <Text style={{ color: colors.accent, fontWeight: '700' }}>Retry</Text>
            </Pressable>
          </View>
        )}

        {topic && (
          <>
            {/* Topic meta */}
            <View style={[styles.card, { marginBottom: 8 }]}
              accessible
              accessibilityLabel={`By ${topic.authorName || 'Community member'}. ${topic.replyCount} replies. ${formatDate(topic.createdAt)}.`}>
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 10 }}>
                <Ionicons name="chatbubbles-outline" size={16} color={colors.textSecondary} accessibilityElementsHidden />
                <Text style={{ fontSize: 14, color: colors.textSecondary }}>
                  {topic.replyCount} {topic.replyCount === 1 ? 'reply' : 'replies'}
                  {topic.authorName ? `  ·  by ${topic.authorName}` : ''}
                  {topic.createdAt ? `  ·  ${formatDate(topic.createdAt)}` : ''}
                </Text>
              </View>

              {/* Action buttons */}
              <View style={{ flexDirection: 'row', gap: 8, flexWrap: 'wrap' }}>
                <Pressable
                  onPress={handleSave}
                  accessible accessibilityRole="button"
                  accessibilityLabel={isSaved ? 'Unsave topic' : 'Save topic'}
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                    backgroundColor: isSaved ? colors.accent : colors.pill,
                    borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8 }}
                >
                  <Ionicons name={isSaved ? 'bookmark' : 'bookmark-outline'} size={14}
                    color={isSaved ? colors.accentText : colors.pillText} />
                  <Text style={{ color: isSaved ? colors.accentText : colors.pillText,
                    fontWeight: '600', fontSize: 13 }}>
                    {isSaved ? 'Saved' : 'Save'}
                  </Text>
                </Pressable>

                {!screenReaderEnabled && (
                  <Pressable
                    onPress={() => topic && readAloud(`${topic.title}. ${stripHtml(topic.body)}`)}
                    accessible accessibilityRole="button" accessibilityLabel="Read topic aloud"
                    style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                      backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8 }}
                  >
                    <Ionicons name="volume-medium-outline" size={14} color={colors.pillText} />
                    <Text style={{ color: colors.pillText, fontWeight: '600', fontSize: 13 }}>Read Aloud</Text>
                  </Pressable>
                )}

                <Pressable
                  onPress={() => topic && translateContent(`${topic.title}\n\n${stripHtml(topic.body)}`, topic.title)}
                  accessible accessibilityRole="button" accessibilityLabel="Translate topic"
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                    backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8 }}
                >
                  <Ionicons name="language-outline" size={14} color={colors.pillText} />
                  <Text style={{ color: colors.pillText, fontWeight: '600', fontSize: 13 }}>Translate</Text>
                </Pressable>
              </View>
            </View>

            {/* Topic body */}
            {topic.body ? (
              <View style={[styles.card, { marginBottom: 16 }]}
                accessible accessibilityLabel={`Topic content: ${stripHtml(topic.body)}`}>
                <Text style={{ fontSize: 16, lineHeight: 26, color: colors.text }}>
                  {stripHtml(topic.body)}
                </Text>
              </View>
            ) : null}

            {/* Replies */}
            {topic.replies.length > 0 && (
              <>
                <Text style={[styles.cardTitle, { marginBottom: 8 }]}
                  accessibilityRole="header">
                  {topic.replies.length} {topic.replies.length === 1 ? 'Reply' : 'Replies'}
                </Text>
                {topic.replies.map((reply) => (
                  <ReplyCard key={reply.id} reply={reply} colors={colors} styles={styles} />
                ))}
              </>
            )}

            {topic.replies.length === 0 && !loading && (
              <View style={[styles.card, { alignItems: 'center', paddingVertical: 24 }]}>
                <Text style={styles.cardMeta}>No replies yet. Be the first to reply.</Text>
              </View>
            )}

            {/* Reply button */}
            {auth.isSignedIn ? (
              <Pressable
                onPress={() => router.push({ pathname: '/compose' as any, params: { topicId: id, topicTitle: topic.title } })}
                accessible accessibilityRole="button" accessibilityLabel="Write a reply"
                style={{ backgroundColor: colors.accent, borderRadius: 14,
                  paddingVertical: 16, alignItems: 'center', marginTop: 8 }}
              >
                <Text style={{ color: colors.accentText, fontWeight: '700', fontSize: 16 }}>Reply to Topic</Text>
              </Pressable>
            ) : (
              <View style={[styles.card, { alignItems: 'center' }]}>
                <Text style={styles.cardMeta}>Sign in to reply to this topic.</Text>
                <Pressable
                  onPress={() => router.push('/settings')}
                  accessible accessibilityRole="button" accessibilityLabel="Go to Settings to sign in"
                  style={{ marginTop: 10 }}
                >
                  <Text style={{ color: colors.accent, fontWeight: '700' }}>Sign In</Text>
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
