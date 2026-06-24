import { useEffect, useMemo, useRef, useState } from 'react';
import { AccessibilityInfo, findNodeHandle, Pressable, ScrollView, Text, TextInput, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { useFocusRestore } from '../src/hooks/useFocusRestore';
import { HELP_SECTIONS } from '../src/data/helpContent';

export default function HelpScreen() {
  const router = useRouter();
  const { colors, styles } = useTheme();
  const { save } = useFocusRestore();
  const sectionRefs = useRef<Map<string, View>>(new Map());
  const headingRef = useRef<Text | null>(null);
  const [query, setQuery] = useState('');

  const articleCount = HELP_SECTIONS.reduce((total, section) => total + section.articles.length, 0);
  const helpSummary = `${HELP_SECTIONS.length} help sections and ${articleCount} articles. Includes getting started, tutorials, accessibility, Home and Discover, community posting, apps, podcasts, settings, smart features, troubleshooting, and support.`;
  const filteredSections = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return HELP_SECTIONS;
    return HELP_SECTIONS
      .map((section) => ({
        ...section,
        articles: section.articles.filter((article) =>
          article.title.toLowerCase().includes(q) ||
          article.summary.toLowerCase().includes(q) ||
          section.title.toLowerCase().includes(q),
        ),
      }))
      .filter((section) => section.articles.length > 0);
  }, [query]);

  useEffect(() => {
    const timers = [350, 700].map((delay) => setTimeout(() => {
      const handle = findNodeHandle(headingRef.current);
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, delay));
    return () => timers.forEach(clearTimeout);
  }, []);


  return (
    <Screen title="Help & Support" showSettings={false}>
      <ScrollView showsVerticalScrollIndicator={false} contentInsetAdjustmentBehavior="automatic">
        <Text
          ref={headingRef}
          accessibilityRole="header"
          accessibilityActions={[{ name: 'summary', label: 'Read Help Summary' }]}
          onAccessibilityAction={({ nativeEvent }) => {
            if (nativeEvent.actionName === 'summary') AccessibilityInfo.announceForAccessibility(helpSummary);
          }}
          style={{ fontSize: 24, fontWeight: '800', color: colors.text, marginBottom: 8 }}
        >
          Help Center
        </Text>

        <View
          accessible
          accessibilityRole="summary"
          accessibilityLabel={`Help Center. ${helpSummary}`}
          style={[styles.card, { marginBottom: 12, borderLeftWidth: 4, borderLeftColor: colors.accent }]}
        >
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
            <View
              style={{ width: 44, height: 44, borderRadius: 12, backgroundColor: colors.pill, alignItems: 'center', justifyContent: 'center' }}
              accessibilityElementsHidden
            >
              <Ionicons name="help-buoy-outline" size={24} color={colors.accent} />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: 17, fontWeight: '800', color: colors.text }}>Offline User Guide</Text>
              <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20, marginTop: 2 }}>
                Tutorials, accessibility guidance, settings help, smart features, and troubleshooting for everyone.
              </Text>
            </View>
          </View>
        </View>

        <View
          style={{
            flexDirection: 'row',
            alignItems: 'center',
            gap: 8,
            backgroundColor: colors.inputBackground,
            borderColor: colors.border,
            borderWidth: 1,
            borderRadius: 12,
            paddingHorizontal: 12,
            paddingVertical: 8,
            marginBottom: 12,
          }}
        >
          <Ionicons name="search-outline" size={18} color={colors.textSecondary} accessibilityElementsHidden />
          <TextInput
            value={query}
            onChangeText={setQuery}
            placeholder="Search help..."
            placeholderTextColor={colors.textSecondary}
            clearButtonMode="while-editing"
            returnKeyType="search"
            accessible
            accessibilityLabel="Search help"
            accessibilityHint="Filters help articles by title and summary."
            style={{ flex: 1, color: colors.text, fontSize: 16, paddingVertical: 4 }}
          />
        </View>

        {filteredSections.length === 0 ? (
          <View style={[styles.card, { alignItems: 'center', paddingVertical: 28 }]}>
            <Text style={styles.cardTitle}>No help articles found</Text>
            <Text style={[styles.cardMeta, { marginTop: 4, textAlign: 'center' }]}>
              Try a different word, or contact app support from the bottom of this page.
            </Text>
          </View>
        ) : filteredSections.map((section) => (
          <View key={section.id} style={{ marginBottom: 12 }}>
            <Text
              style={{
                fontSize: 13,
                fontWeight: '800',
                color: colors.textSecondary,
                textTransform: 'uppercase',
                letterSpacing: 0,
                marginBottom: 8,
                marginTop: 8,
              }}
              accessibilityRole="header"
              accessibilityLabel={`${section.title}. ${section.articles.length} articles.`}
            >
              {section.title}
            </Text>

            <View
              ref={(el) => {
                if (el) sectionRefs.current.set(section.id, el);
                else sectionRefs.current.delete(section.id);
              }}
              accessible
              accessibilityRole="summary"
              accessibilityLabel={`${section.title}. ${section.description}. ${section.articles.length} articles.`}
              style={[styles.card, { borderLeftWidth: 4, borderLeftColor: colors.accent, marginBottom: 8 }]}
            >
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
                <View
                  style={{ width: 42, height: 42, borderRadius: 10, backgroundColor: `${colors.accent}22`, alignItems: 'center', justifyContent: 'center' }}
                  accessibilityElementsHidden
                >
                  <Ionicons name={section.icon as any} size={22} color={colors.accent} />
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={styles.cardTitle}>{section.title}</Text>
                  <Text style={[styles.cardMeta, { marginTop: 2, lineHeight: 19 }]}>
                    {section.description}
                  </Text>
                </View>
                <View
                  accessibilityElementsHidden
                  importantForAccessibility="no-hide-descendants"
                  style={{ borderRadius: 8, paddingHorizontal: 8, paddingVertical: 3, backgroundColor: colors.pill }}
                >
                  <Text style={{ color: colors.accent, fontSize: 12, fontWeight: '800' }}>
                    {section.articles.length}
                  </Text>
                </View>
              </View>
            </View>

            {section.articles.map((article) => (
              <Pressable
                key={article.id}
                ref={(el) => {
                  if (el) sectionRefs.current.set(article.id, el);
                  else sectionRefs.current.delete(article.id);
                }}
                onPress={() => {
                  save(sectionRefs.current.get(article.id) ?? null);
                  router.push({ pathname: '/help-article', params: { articleId: article.id } });
                }}
                accessible
                accessibilityRole="button"
                accessibilityLabel={`${article.title}. ${article.summary}`}
                accessibilityHint="Opens this help article."
                style={({ pressed }) => [
                  styles.cardSmall,
                  { marginBottom: 8, borderLeftWidth: 3, borderLeftColor: colors.border },
                  pressed && { opacity: 0.85 },
                ]}
              >
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
                  <View style={{ flex: 1 }}>
                    <Text style={[styles.cardTitle, { fontSize: 16, marginBottom: 2 }]}>{article.title}</Text>
                    <Text style={[styles.cardMeta, { fontSize: 13, lineHeight: 18 }]}>{article.summary}</Text>
                  </View>
                  <Ionicons name="chevron-forward" size={16} color={colors.textSecondary} accessibilityElementsHidden />
                </View>
              </Pressable>
            ))}
          </View>
        ))}

        <Text
          style={{ fontSize: 13, fontWeight: '800', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0, marginTop: 8, marginBottom: 8 }}
          accessibilityRole="header"
        >
          Contact
        </Text>
        <Pressable
          onPress={() => router.push('/contact' as any)}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Contact App Support. Opens the in-app contact wizard."
          accessibilityHint="Use this for app bugs, suggestions, recommendations, and feedback."
          style={({ pressed }) => [styles.card, { flexDirection: 'row', alignItems: 'center', gap: 12, borderLeftWidth: 4, borderLeftColor: colors.accent }, pressed && { opacity: 0.85 }]}
        >
          <Ionicons name="chatbubble-ellipses-outline" size={24} color={colors.accent} accessibilityElementsHidden />
          <View style={{ flex: 1 }}>
            <Text style={styles.cardTitle}>Contact App Support</Text>
            <Text style={[styles.cardMeta, { marginTop: 2 }]}>Send a bug report, feedback, suggestion, or recommendation to the AppleVis team — directly in the app.</Text>
          </View>
          <Ionicons name="chevron-forward" size={16} color={colors.textSecondary} accessibilityElementsHidden />
        </Pressable>

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
