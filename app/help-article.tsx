import { useEffect, useMemo, useRef } from 'react';
import { AccessibilityInfo, findNodeHandle, Pressable, ScrollView, Text, View } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { findHelpArticle, HELP_CONTENT_TYPE_META } from '../src/data/helpContent';
import type { ContentBlock, RelatedLink, RelatedLinkType } from '../src/data/helpContent';

const RELATED_ICON: Record<RelatedLinkType, React.ComponentProps<typeof Ionicons>['name']> = {
  guide: 'book-outline',
  quickStart: 'flash-outline',
  tutorial: 'walk-outline',
  faq: 'help-circle-outline',
  troubleshooting: 'construct-outline',
  spotlight: 'sparkles-outline',
  accessibilityLesson: 'accessibility-outline',
  whatsNew: 'megaphone-outline',
  releaseNote: 'document-text-outline',
  forum: 'chatbubbles-outline',
  podcast: 'mic-outline',
};

function Block({ block, colors }: { block: ContentBlock; colors: ReturnType<typeof useTheme>['colors'] }) {
  switch (block.type) {
    case 'heading':
      return (
        <Text
          accessibilityRole="header"
          style={{ fontSize: 18, fontWeight: '800', color: colors.text, marginTop: 20, marginBottom: 8, lineHeight: 24 }}
        >
          {block.text}
        </Text>
      );

    case 'body':
      return (
        <Text style={{ fontSize: 16, lineHeight: 25, color: colors.text, marginBottom: 12 }}>
          {block.text}
        </Text>
      );

    case 'bullets':
      return (
        <View style={{ marginBottom: 12 }}>
          {block.items.map((item, i) => (
            <View key={i} style={{ flexDirection: 'row', gap: 8, marginBottom: 7 }} accessible accessibilityRole="text" accessibilityLabel={item}>
              <Text style={{ color: colors.accent, fontSize: 18, lineHeight: 24, marginTop: 0 }} accessibilityElementsHidden>
                {'\u2022'}
              </Text>
              <Text style={{ flex: 1, fontSize: 15, lineHeight: 23, color: colors.text }}>{item}</Text>
            </View>
          ))}
        </View>
      );

    case 'steps':
      return (
        <View style={{ marginBottom: 12 }}>
          {block.items.map((item, i) => (
            <View key={i} style={{ flexDirection: 'row', gap: 12, marginBottom: 10, alignItems: 'flex-start' }} accessible accessibilityRole="text" accessibilityLabel={`Step ${i + 1}. ${item}`}>
              <View style={{ width: 28, height: 28, borderRadius: 14, backgroundColor: colors.accent, alignItems: 'center', justifyContent: 'center', marginTop: 1, flexShrink: 0 }} accessibilityElementsHidden>
                <Text style={{ color: colors.accentText, fontSize: 13, fontWeight: '800' }}>{i + 1}</Text>
              </View>
              <Text style={{ flex: 1, fontSize: 15, lineHeight: 23, color: colors.text }}>{item}</Text>
            </View>
          ))}
        </View>
      );

    case 'tip':
      return <Callout label="Tip" text={block.text} color="#16A34A" background="#F0FDF4" />;
    case 'note':
      return <Callout label="Note" text={block.text} color="#2563EB" background="#EFF6FF" />;
    case 'warning':
      return <Callout label="Important" text={block.text} color="#D97706" background="#FFFBEB" />;
    case 'faq':
      return (
        <View
          style={{ marginBottom: 14 }}
          accessible
          accessibilityLabel={`Question: ${block.question}. Answer: ${block.answer}`}
        >
          <Text
            accessibilityElementsHidden
            style={{ fontSize: 16, fontWeight: '700', color: colors.text, marginBottom: 6, lineHeight: 22 }}
          >
            {block.question}
          </Text>
          <Text accessibilityElementsHidden style={{ fontSize: 15, lineHeight: 22, color: colors.textSecondary }}>
            {block.answer}
          </Text>
        </View>
      );
    default:
      return null;
  }
}

function Callout({ label, text, color, background }: { label: string; text: string; color: string; background: string }) {
  return (
    <View
      accessible
      accessibilityRole="summary"
      accessibilityLabel={`${label}. ${text}`}
      style={{ backgroundColor: background, borderRadius: 10, padding: 14, borderLeftWidth: 4, borderLeftColor: color, marginBottom: 12 }}
    >
      <Text style={{ fontSize: 12, fontWeight: '800', color, textTransform: 'uppercase', letterSpacing: 0, marginBottom: 4 }} accessibilityElementsHidden>
        {label}
      </Text>
      <Text style={{ fontSize: 15, lineHeight: 22, color: '#111827' }}>{text}</Text>
    </View>
  );
}

function RelatedLinks({ links, colors, styles }: {
  links: RelatedLink[];
  colors: ReturnType<typeof useTheme>['colors'];
  styles: ReturnType<typeof useTheme>['styles'];
}) {
  const router = useRouter();
  return (
    <View style={{ marginTop: 8, marginBottom: 12 }}>
      <Text
        accessibilityRole="header"
        style={{ fontSize: 13, fontWeight: '800', color: colors.textSecondary, textTransform: 'uppercase', marginBottom: 8 }}
      >
        Related
      </Text>
      {links.map((link, i) => (
        <Pressable
          key={i}
          onPress={() => {
            if (link.helpArticleId) router.push({ pathname: '/help-article', params: { articleId: link.helpArticleId } });
            else if (link.route) router.push({ pathname: link.route as any, params: link.params });
          }}
          accessible
          accessibilityRole="button"
          accessibilityLabel={`${link.label}. ${link.type}.`}
          accessibilityHint="Opens this related content."
          style={({ pressed }) => [
            styles.cardSmall,
            { flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 8 },
            pressed && { opacity: 0.85 },
          ]}
        >
          <Ionicons name={RELATED_ICON[link.type]} size={18} color={colors.accent} accessibilityElementsHidden />
          <Text style={{ flex: 1, fontSize: 15, fontWeight: '600', color: colors.text }}>{link.label}</Text>
          <Ionicons name="chevron-forward" size={16} color={colors.textSecondary} accessibilityElementsHidden />
        </Pressable>
      ))}
    </View>
  );
}

export default function HelpArticle() {
  const { articleId } = useLocalSearchParams<{ articleId: string }>();
  const { colors, styles } = useTheme();
  const article = findHelpArticle(articleId ?? '');
  const headingRef = useRef<Text | null>(null);

  const articleSummary = useMemo(() => {
    if (!article) return '';
    const headings = article.content.filter((block) => block.type === 'heading').length;
    const steps = article.content
      .filter((block): block is Extract<ContentBlock, { type: 'steps' }> => block.type === 'steps')
      .reduce((total, block) => total + block.items.length, 0);
    return `${article.title}. ${article.summary}. ${headings} section headings. ${steps} steps.`;
  }, [article]);

  useEffect(() => {
    const timers = [300, 650].map((delay) => setTimeout(() => {
      const handle = findNodeHandle(headingRef.current);
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, delay));
    return () => timers.forEach(clearTimeout);
  }, [articleId]);

  if (!article) return null;

  return (
    <Screen title={article.title} showSettings={false}>
      <ScrollView showsVerticalScrollIndicator={false} contentInsetAdjustmentBehavior="automatic">
        <Text
          ref={headingRef}
          accessibilityRole="header"
          accessibilityActions={[{ name: 'summary', label: 'Read Article Summary' }]}
          onAccessibilityAction={({ nativeEvent }) => {
            if (nativeEvent.actionName === 'summary') AccessibilityInfo.announceForAccessibility(articleSummary);
          }}
          style={{ fontSize: 24, fontWeight: '800', color: colors.text, marginBottom: 10 }}
        >
          {article.title}
        </Text>

        <View
          accessible
          accessibilityRole="summary"
          accessibilityLabel={`Article summary. ${article.contentType ? HELP_CONTENT_TYPE_META[article.contentType].label + '. ' : ''}${article.summary}`}
          style={[styles.card, { marginBottom: 18, borderLeftWidth: 4, borderLeftColor: colors.accent }]}
        >
          <View style={{ flexDirection: 'row', gap: 10, alignItems: 'flex-start' }}>
            <Ionicons
              name={(article.contentType ? HELP_CONTENT_TYPE_META[article.contentType].icon : 'document-text-outline') as any}
              size={22}
              color={colors.accent}
              accessibilityElementsHidden
            />
            <View style={{ flex: 1 }}>
              {article.contentType && (
                <Text style={{ fontSize: 12, fontWeight: '800', color: colors.accent, textTransform: 'uppercase', marginBottom: 4 }} accessibilityElementsHidden>
                  {HELP_CONTENT_TYPE_META[article.contentType].label}
                </Text>
              )}
              <Text style={{ fontSize: 15, lineHeight: 22, color: colors.textSecondary }}>
                {article.summary}
              </Text>
            </View>
          </View>
        </View>

        {article.content.map((block, i) => (
          <Block key={i} block={block} colors={colors} />
        ))}

        {article.relatedLinks?.length ? (
          <RelatedLinks links={article.relatedLinks} colors={colors} styles={styles} />
        ) : null}

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
