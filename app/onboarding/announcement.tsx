import { Pressable, Text, View } from 'react-native';
import { router } from 'expo-router';
import { useTheme } from '../../src/contexts/ThemeContext';
import { usePreferences } from '../../src/contexts/PreferencesContext';
import { WizardLayout } from '../../src/components/WizardLayout';
import type { AnnouncementLevel } from '../../src/contexts/PreferencesContext';

type Option = {
  id: AnnouncementLevel;
  label: string;
  badge: string;
  description: string;
  preview: string; // What VoiceOver actually reads on a sample card
};

const OPTIONS: Option[] = [
  {
    id: 'simple',
    label: 'Simple',
    badge: 'Minimal',
    description: 'Title and content type only. Fast to scan — author, date, and comment count are a swipe away.',
    preview: '"iOS 18 VoiceOver Tips. Forum."',
  },
  {
    id: 'normal',
    label: 'Normal',
    badge: 'Balanced',
    description: 'Title plus author and comment count — the most useful details without the full date history.',
    preview: '"iOS 18 VoiceOver Tips. Forum. By JaneD. 14 comments."',
  },
  {
    id: 'all',
    label: 'All',
    badge: 'Recommended',
    description: 'Everything at once — title, author, comment count, posted date, and last comment time.',
    preview: '"iOS 18 VoiceOver Tips. Forum. By JaneD. 14 comments. Posted 2 days ago. Last comment 3 hours ago."',
  },
];

export default function AnnouncementStep() {
  const { colors }                               = useTheme();
  const { announcementLevel, setAnnouncementLevel } = usePreferences();

  return (
    <WizardLayout
      step={4}
      totalSteps={5}
      title="Item detail level"
      description="Choose how much detail AppleVis shows when you navigate forum topics, apps, and podcast episodes. This affects every item card — useful whether you read the screen yourself or use VoiceOver, Apple's built-in screen reader. You can change this any time in Settings → Accessibility."
      onNext={() => router.push('/onboarding/notifications')}
    >
      <View accessibilityRole="radiogroup" accessibilityLabel="Item detail level">
      {OPTIONS.map((opt) => {
        const isSelected = announcementLevel === opt.id;
        return (
          <Pressable
            key={opt.id}
            onPress={() => setAnnouncementLevel(opt.id)}
            accessible
            accessibilityRole="radio"
            accessibilityState={{ checked: isSelected }}
            accessibilityLabel={`${opt.label} — ${opt.badge}. ${opt.description}`}
            accessibilityHint={`Example: ${opt.preview}`}
            style={{
              backgroundColor: colors.card,
              borderRadius: 14,
              padding: 16,
              marginBottom: 10,
              borderWidth: isSelected ? 2 : 1,
              borderColor: isSelected ? colors.accent : colors.border,
            }}
          >
            {/* Label row */}
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 6 }}>
              <Text style={{ fontSize: 18, fontWeight: '700', color: colors.text }}>{opt.label}</Text>
              <View style={{
                backgroundColor: isSelected ? colors.accent : colors.pill,
                borderRadius: 8, paddingHorizontal: 8, paddingVertical: 2,
              }}>
                <Text style={{ color: isSelected ? colors.accentText : colors.pillText,
                  fontSize: 11, fontWeight: '700' }}>
                  {opt.badge}
                </Text>
              </View>
            </View>

            {/* Description */}
            <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20, marginBottom: 10 }}>
              {opt.description}
            </Text>

            {/* Preview box */}
            <View style={{ backgroundColor: colors.background, borderRadius: 8,
              padding: 10, borderWidth: 1, borderColor: colors.border }}>
              <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary,
                textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 4 }}>
                Example:
              </Text>
              <Text style={{ fontSize: 14, color: colors.text, lineHeight: 20, fontStyle: 'italic' }}>
                {opt.preview}
              </Text>
            </View>
          </Pressable>
        );
      })}
      </View>
    </WizardLayout>
  );
}
