import { useEffect, useMemo, useRef } from 'react';
import { AccessibilityInfo, findNodeHandle, ScrollView, Text, View } from 'react-native';
import { useLocalSearchParams } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { findHelpArticle } from '../src/data/helpContent';
import type { ContentBlock } from '../src/data/helpContent';

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
          accessibilityLabel={`Article summary. ${article.summary}`}
          style={[styles.card, { marginBottom: 18, borderLeftWidth: 4, borderLeftColor: colors.accent }]}
        >
          <View style={{ flexDirection: 'row', gap: 10, alignItems: 'flex-start' }}>
            <Ionicons name="document-text-outline" size={22} color={colors.accent} accessibilityElementsHidden />
            <Text style={{ flex: 1, fontSize: 15, lineHeight: 22, color: colors.textSecondary }}>
              {article.summary}
            </Text>
          </View>
        </View>

        {article.content.map((block, i) => (
          <Block key={i} block={block} colors={colors} />
        ))}

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
