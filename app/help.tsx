import { useRef } from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { useFocusRestore } from '../src/hooks/useFocusRestore';
import { HELP_SECTIONS } from '../src/data/helpContent';

export default function HelpScreen() {
  const router        = useRouter();
  const { colors, styles } = useTheme();
  const { save }      = useFocusRestore();
  const sectionRefs   = useRef<Map<string, View>>(new Map());

  return (
    <Screen title="Help & Support" showSettings={false}>
      <ScrollView>
        <Text style={[styles.lede]}>
          Everything you need to get the most out of AppleVis — guides, tutorials, VoiceOver tips, and answers to common questions. All content works offline.
        </Text>

        {HELP_SECTIONS.map((section) => (
          <View key={section.id} style={{ marginBottom: 8 }}>
            {/* Section header — shows all articles below */}
            <Text
              style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
                textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 8, marginTop: 4 }}
              accessibilityRole="header"
            >
              {section.icon}  {section.title}
            </Text>

            {section.articles.map((article) => (
              <Pressable
                key={article.id}
                ref={(el) => {
                  if (el) sectionRefs.current.set(article.id, el);
                  else sectionRefs.current.delete(article.id);
                }}
                onPress={() => {
                  save(sectionRefs.current.get(article.id) ?? null);
                  router.push({
                    pathname: '/help-article',
                    params: { articleId: article.id },
                  });
                }}
                accessible
                accessibilityRole="button"
                accessibilityLabel={`${article.title}. ${article.summary}`}
                accessibilityHint="Opens this article."
                style={({ pressed }) => [styles.cardSmall, pressed && { opacity: 0.85 }]}
              >
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
                  <View style={{ flex: 1 }}>
                    <Text style={[styles.cardTitle, { fontSize: 16, marginBottom: 2 }]}>
                      {article.title}
                    </Text>
                    <Text style={[styles.cardMeta, { fontSize: 13, lineHeight: 18 }]}>
                      {article.summary}
                    </Text>
                  </View>
                  <Ionicons name="chevron-forward" size={16} color={colors.textSecondary} />
                </View>
              </Pressable>
            ))}
          </View>
        ))}

        {/* Contact links */}
        <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
          textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 8, marginTop: 4 }}
          accessibilityRole="header">
          🤝  Contact
        </Text>
        {[
          { label: 'Contact AppleVis', hint: 'Opens applevis.com contact form in Safari.' },
          { label: 'Report a Bug',     hint: 'Tell us about something not working correctly.' },
          { label: 'Send Feedback',    hint: 'Suggest a feature or share your experience.' },
        ].map(({ label, hint }) => (
          <Pressable
            key={label}
            accessible accessibilityRole="button"
            accessibilityLabel={label} accessibilityHint={hint}
            style={({ pressed }) => [styles.cardSmall, pressed && { opacity: 0.85 }]}
          >
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
              <Text style={[styles.cardTitle, { fontSize: 16, marginBottom: 0, flex: 1 }]}>{label}</Text>
              <Ionicons name="open-outline" size={16} color={colors.textSecondary} />
            </View>
          </Pressable>
        ))}

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
