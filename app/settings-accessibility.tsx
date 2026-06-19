import { Pressable, ScrollView, Switch, Text, View } from 'react-native';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { usePreferences } from '../src/contexts/PreferencesContext';
import type { AnnouncementLevel } from '../src/contexts/PreferencesContext';

type LevelOption = {
  id: AnnouncementLevel;
  label: string;
  badge: string;
  description: string;
  preview: string;
};

const LEVELS: LevelOption[] = [
  {
    id: 'simple',
    label: 'Simple',
    badge: 'Minimal',
    description: 'Title and content type only. Fast to scan -- author, date, and comment count are a swipe away.',
    preview: '"iOS 18 VoiceOver Tips. Forum."',
  },
  {
    id: 'normal',
    label: 'Normal',
    badge: 'Balanced',
    description: 'Title plus author and comment count -- the most useful details without the full date history.',
    preview: '"iOS 18 VoiceOver Tips. Forum. By JaneD. 14 comments."',
  },
  {
    id: 'all',
    label: 'All',
    badge: 'Recommended',
    description: 'Everything at once -- title, author, comment count, posted date, and last comment time.',
    preview: '"iOS 18 VoiceOver Tips. Forum. By JaneD. 14 comments. Posted 2 days ago. Last comment 3 hours ago."',
  },
];

export default function AccessibilitySettings() {
  const { colors, styles }  = useTheme();
  const {
    announcementLevel,
    setAnnouncementLevel,
    helpfulTipsEnabled,
    setHelpfulTipsEnabled,
    welcomeSummaryEnabled,
    setWelcomeSummaryEnabled,
  } = usePreferences();

  return (
    <Screen title="Accessibility" showSettings={false}>
      <ScrollView showsVerticalScrollIndicator={false}>
        <Text style={styles.lede}>
          VoiceOver detail level controls how much information is read when
          you navigate to a content card. All other iOS accessibility settings
          (Dynamic Type, Reduce Motion, Bold Text, Increase Contrast) are
          respected automatically from iOS Settings.
        </Text>

        <Pressable
          onPress={() => setHelpfulTipsEnabled(!helpfulTipsEnabled)}
          accessible
          accessibilityRole="switch"
          accessibilityState={{ checked: helpfulTipsEnabled }}
          accessibilityLabel="AppleVis Tips. Shows short contextual tips and reminders throughout AppleVis."
          style={({ pressed }) => [styles.cardSmall, {
            flexDirection: 'row',
            alignItems: 'center',
            gap: 12,
            marginBottom: 16,
            opacity: pressed ? 0.85 : 1,
          }]}
        >
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text, marginBottom: 3 }}>
              AppleVis Tips
            </Text>
            <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>
              Shows short contextual tips and friendly reminders where they can save time.
            </Text>
          </View>
          <Switch
            value={helpfulTipsEnabled}
            onValueChange={setHelpfulTipsEnabled}
            accessibilityElementsHidden
            importantForAccessibility="no-hide-descendants"
            trackColor={{ false: colors.border, true: colors.appleVisBlue }}
            thumbColor="#FFFFFF"
          />
        </Pressable>

        <Pressable
          onPress={() => setWelcomeSummaryEnabled(!welcomeSummaryEnabled)}
          accessible
          accessibilityRole="switch"
          accessibilityState={{ checked: welcomeSummaryEnabled }}
          accessibilityLabel="Welcome summary. Shows a short since your last visit summary on Home."
          style={({ pressed }) => [styles.cardSmall, {
            flexDirection: 'row',
            alignItems: 'center',
            gap: 12,
            marginBottom: 16,
            opacity: pressed ? 0.85 : 1,
          }]}
        >
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text, marginBottom: 3 }}>
              Welcome Summary
            </Text>
            <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>
              Shows a brief Home update with new AppleVis activity since your last visit.
            </Text>
          </View>
          <Switch
            value={welcomeSummaryEnabled}
            onValueChange={setWelcomeSummaryEnabled}
            accessibilityElementsHidden
            importantForAccessibility="no-hide-descendants"
            trackColor={{ false: colors.border, true: colors.appleVisBlue }}
            thumbColor="#FFFFFF"
          />
        </Pressable>

        {/* iOS settings note */}
        <View style={{ backgroundColor: colors.card, borderRadius: 12, padding: 14,
          borderWidth: 1, borderColor: colors.border, marginBottom: 20 }}>
          <Text style={{ fontSize: 14, fontWeight: '700', color: colors.text, marginBottom: 6 }}>
            iOS Settings already applied
          </Text>
          {[
            'Dynamic Type -- all text scales with your preferred size',
            'Reduce Motion -- animations shortened or removed',
            'Bold Text -- all fonts are bolder',
            'Button Shapes -- underlines added to tappable text',
            'Increase Contrast -- try High Contrast themes in Appearance',
          ].map((item) => (
            <View key={item} style={{ flexDirection: 'row', gap: 8, marginBottom: 5 }}
              accessible accessibilityLabel={item}>
              <Text style={{ color: colors.accent }} accessibilityElementsHidden>•</Text>
              <Text style={{ flex: 1, fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>{item}</Text>
            </View>
          ))}
        </View>

        {/* Announcement level */}
        <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
          textTransform: 'uppercase', letterSpacing: 0, marginBottom: 12 }}
          accessibilityRole="header">VoiceOver Detail Level</Text>

        {LEVELS.map((opt) => {
          const isSelected = announcementLevel === opt.id;
          return (
            <Pressable
              key={opt.id}
              onPress={() => setAnnouncementLevel(opt.id)}
              accessible accessibilityRole="button"
              accessibilityState={{ selected: isSelected }}
              accessibilityLabel={`${opt.label} -- ${opt.badge}. ${opt.description}`}
              accessibilityHint={`VoiceOver will read: ${opt.preview}`}
              style={[styles.cardSmall, {
                borderWidth: isSelected ? 2 : 1,
                borderColor: isSelected ? colors.accent : colors.border,
                marginBottom: 10,
              }]}
            >
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 6 }}>
                <Text style={{ fontSize: 17, fontWeight: '700', color: colors.text }}>{opt.label}</Text>
                <View style={{
                  backgroundColor: isSelected ? colors.accent : colors.pill,
                  borderRadius: 8, paddingHorizontal: 8, paddingVertical: 2,
                }}>
                  <Text style={{ color: isSelected ? colors.accentText : colors.pillText,
                    fontSize: 11, fontWeight: '700' }}>{opt.badge}</Text>
                </View>
              </View>
              <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20, marginBottom: 10 }}>
                {opt.description}
              </Text>
              <View style={{ backgroundColor: colors.background, borderRadius: 8, padding: 10,
                borderWidth: 1, borderColor: colors.border }}>
                <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary,
                  textTransform: 'uppercase', letterSpacing: 0, marginBottom: 4 }}>
                  VoiceOver reads:
                </Text>
                <Text style={{ fontSize: 14, color: colors.text, lineHeight: 20, fontStyle: 'italic' }}>
                  {opt.preview}
                </Text>
              </View>
            </Pressable>
          );
        })}

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
