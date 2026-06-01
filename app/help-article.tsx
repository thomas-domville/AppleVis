import { useLocalSearchParams } from 'expo-router';
import { ScrollView, Text, View } from 'react-native';
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
          style={{ fontSize: 18, fontWeight: '700', color: colors.text,
            marginTop: 20, marginBottom: 8, lineHeight: 24 }}
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
            <View key={i} style={{ flexDirection: 'row', gap: 8, marginBottom: 6 }}
              accessible accessibilityLabel={item}>
              <Text style={{ color: colors.accent, fontSize: 16, lineHeight: 24, marginTop: 1 }}
                accessibilityElementsHidden>•</Text>
              <Text style={{ flex: 1, fontSize: 15, lineHeight: 23, color: colors.text }}>{item}</Text>
            </View>
          ))}
        </View>
      );

    case 'steps':
      return (
        <View style={{ marginBottom: 12 }}>
          {block.items.map((item, i) => (
            <View key={i} style={{ flexDirection: 'row', gap: 12, marginBottom: 10, alignItems: 'flex-start' }}
              accessible accessibilityLabel={`Step ${i + 1}: ${item}`}>
              <View style={{ width: 26, height: 26, borderRadius: 13,
                backgroundColor: colors.accent, alignItems: 'center', justifyContent: 'center',
                marginTop: 2, flexShrink: 0 }}
                accessibilityElementsHidden>
                <Text style={{ color: colors.accentText, fontSize: 13, fontWeight: '700' }}>{i + 1}</Text>
              </View>
              <Text style={{ flex: 1, fontSize: 15, lineHeight: 23, color: colors.text }}>{item}</Text>
            </View>
          ))}
        </View>
      );

    case 'tip':
      return (
        <View style={{ backgroundColor: '#F0FDF4', borderRadius: 10, padding: 14,
          borderLeftWidth: 4, borderLeftColor: '#16A34A', marginBottom: 12 }}
          accessible accessibilityLabel={`Tip: ${block.text}`}>
          <Text style={{ fontSize: 12, fontWeight: '700', color: '#15803D',
            textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 4 }}
            accessibilityElementsHidden>Tip</Text>
          <Text style={{ fontSize: 15, lineHeight: 22, color: '#14532D' }}>{block.text}</Text>
        </View>
      );

    case 'note':
      return (
        <View style={{ backgroundColor: '#EFF6FF', borderRadius: 10, padding: 14,
          borderLeftWidth: 4, borderLeftColor: '#3B82F6', marginBottom: 12 }}
          accessible accessibilityLabel={`Note: ${block.text}`}>
          <Text style={{ fontSize: 12, fontWeight: '700', color: '#1D4ED8',
            textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 4 }}
            accessibilityElementsHidden>Note</Text>
          <Text style={{ fontSize: 15, lineHeight: 22, color: '#1E3A8A' }}>{block.text}</Text>
        </View>
      );

    case 'warning':
      return (
        <View style={{ backgroundColor: '#FFFBEB', borderRadius: 10, padding: 14,
          borderLeftWidth: 4, borderLeftColor: '#D97706', marginBottom: 12 }}
          accessible accessibilityLabel={`Warning: ${block.text}`}>
          <Text style={{ fontSize: 12, fontWeight: '700', color: '#92400E',
            textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 4 }}
            accessibilityElementsHidden>Warning</Text>
          <Text style={{ fontSize: 15, lineHeight: 22, color: '#78350F' }}>{block.text}</Text>
        </View>
      );

    default:
      return null;
  }
}

export default function HelpArticle() {
  const { articleId } = useLocalSearchParams<{ articleId: string }>();
  const { colors }    = useTheme();
  const article       = findHelpArticle(articleId ?? '');

  if (!article) return null;

  return (
    <Screen title={article.title} showSettings={false}>
      <ScrollView showsVerticalScrollIndicator={false}>
        {/* Summary */}
        <View style={{ backgroundColor: colors.card, borderRadius: 14, padding: 14,
          borderWidth: 1, borderColor: colors.border, marginBottom: 20 }}>
          <Text style={{ fontSize: 15, lineHeight: 22, color: colors.textSecondary }}>
            {article.summary}
          </Text>
        </View>

        {/* Content blocks */}
        {article.content.map((block, i) => (
          <Block key={i} block={block} colors={colors} />
        ))}

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
