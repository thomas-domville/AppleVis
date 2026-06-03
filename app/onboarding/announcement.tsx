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
    description: 'VoiceOver reads only the title of each item. Fast to navigate — details are a swipe away.',
    preview: '"iOS 18 VoiceOver Tips"',
  },
  {
    id: 'normal',
    label: 'Normal',
    badge: 'Balanced',
    description: 'Title plus the most useful status — unread state and reply count. A good middle ground.',
    preview: '"iOS 18 VoiceOver Tips. Unread. 14 replies."',
  },
  {
    id: 'all',
    label: 'All',
    badge: 'Recommended',
    description: 'Everything at a glance — title, unread state, reply count, follow and save status, and author. The richest experience.',
    preview: '"iOS 18 VoiceOver Tips. Unread. 14 replies. Following. Saved. Posted by JaneD, 2 days ago."',
  },
];

export default function AnnouncementStep() {
  const { colors }                               = useTheme();
  const { announcementLevel, setAnnouncementLevel } = usePreferences();

  return (
    <WizardLayout
      step={4}
      totalSteps={5}
      title="VoiceOver detail level"
      description="Choose how much information VoiceOver reads when it lands on a forum topic, app, or podcast episode. You can change this any time in Settings → Accessibility."
      onNext={() => router.push('/onboarding/notifications')}
    >
      {/* System settings note */}
      <View style={{ backgroundColor: colors.card, borderRadius: 12, padding: 14,
        borderWidth: 1, borderColor: colors.border, marginBottom: 22 }}>
        <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>
          Dynamic Type, Reduce Motion, Bold Text, and other iOS accessibility settings are
          already applied automatically — no setup needed here.
        </Text>
      </View>

      {OPTIONS.map((opt) => {
        const isSelected = announcementLevel === opt.id;
        return (
          <Pressable
            key={opt.id}
            onPress={() => setAnnouncementLevel(opt.id)}
            accessible
            accessibilityRole="none"
            accessibilityState={{ selected: isSelected }}
            accessibilityLabel={`${opt.label} — ${opt.badge}. ${opt.description}`}
            accessibilityHint={`VoiceOver example: ${opt.preview}`}
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
                VoiceOver reads:
              </Text>
              <Text style={{ fontSize: 14, color: colors.text, lineHeight: 20, fontStyle: 'italic' }}>
                {opt.preview}
              </Text>
            </View>
          </Pressable>
        );
      })}
    </WizardLayout>
  );
}
