import { Pressable, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { WizardLayout } from '../../src/components/WizardLayout';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useWizard, type WizardPlatform } from '../../src/contexts/SubmitWizardContext';
import { useAlert } from '../../src/contexts/AccessibleAlertContext';
import { sounds } from '../../src/services/sounds';

// ─── Step 2: Platform ─────────────────────────────────────────────────────────

type PlatformChoice = {
  value:    WizardPlatform;
  label:    string;
  subtitle: string;
  icon:     string;
  note?:    string;
};

const PLATFORMS: PlatformChoice[] = [
  {
    value:    'ios',
    label:    'iOS / iPadOS',
    subtitle: 'iPhone and iPad apps',
    icon:     'phone-portrait-outline',
    note:     'Watch and Vision Pro companion support detected automatically',
  },
  {
    value:    'macos',
    label:    'macOS',
    subtitle: 'Mac apps from the Mac App Store',
    icon:     'laptop-outline',
  },
  {
    value:    'tvos',
    label:    'Apple TV',
    subtitle: 'tvOS apps from the App Store',
    icon:     'tv-outline',
  },
];

export default function PlatformScreen() {
  const { colors }    = useTheme();
  const { state, update, reset } = useWizard();
  const { showAlert } = useAlert();

  const accent = colors.accent;

  function handleSelect(p: WizardPlatform) {
    sounds.pickerTick().catch(() => {});
    update({ platform: p, searchHit: null, fullMeta: null, duplicateStatus: 'idle' });
  }

  function handleNext() {
    sounds.articleOpen().catch(() => {});
    router.push('/submit-wizard/search' as any);
  }

  function handleCancel() {
    showAlert({
      title: 'Discard this submission?',
      message: 'Your progress will be discarded.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep Editing',
      type: 'warning',
      onConfirm: () => {
        reset();
        router.replace('/(tabs)/discover' as any);
      },
    });
  }

  return (
    <WizardLayout
      step={2}
      totalSteps={5}
      title="What platform?"
      description="Choose the primary platform this app runs on."
      onNext={handleNext}
      nextLabel="Continue to App Search"
      nextDisabled={!state.platform}
      hideSkip
      onCancel={handleCancel}
    >
      <View accessibilityRole="radiogroup" accessibilityLabel="Platform selection">
        {PLATFORMS.map((p) => {
          const selected = state.platform === p.value;
          return (
            <Pressable
              key={p.value}
              onPress={() => handleSelect(p.value)}
              accessible
              accessibilityRole="radio"
              accessibilityLabel={p.label}
              accessibilityHint={p.subtitle + (p.note ? '. Note: ' + p.note : '')}
              accessibilityState={{ selected }}
              style={({ pressed }) => ({ opacity: pressed ? 0.88 : 1, marginBottom: 10 })}
            >
              <View style={{
                flexDirection: 'row', alignItems: 'center', gap: 14,
                backgroundColor: colors.card, borderRadius: 16, padding: 16,
                borderWidth: 2, borderColor: selected ? accent : colors.border,
              }}>
                <View style={{
                  width: 50, height: 50, borderRadius: 14, flexShrink: 0,
                  backgroundColor: selected ? accent : colors.border,
                  justifyContent: 'center', alignItems: 'center',
                }} accessibilityElementsHidden>
                  <Ionicons name={p.icon as any} size={26} color={selected ? '#fff' : colors.textSecondary} />
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={{ fontSize: 18, fontWeight: '700', color: colors.text }}>{p.label}</Text>
                  <Text style={{ fontSize: 14, color: colors.textSecondary, marginTop: 2 }}>{p.subtitle}</Text>
                  {p.note && (
                    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4, marginTop: 6 }} accessibilityElementsHidden>
                      <Ionicons name="information-circle-outline" size={13} color={colors.textSecondary} />
                      <Text style={{ fontSize: 12, color: colors.textSecondary, flex: 1, lineHeight: 16 }}>{p.note}</Text>
                    </View>
                  )}
                </View>
                <View style={{
                  width: 24, height: 24, borderRadius: 12, flexShrink: 0,
                  borderWidth: 2, borderColor: selected ? accent : colors.border,
                  justifyContent: 'center', alignItems: 'center',
                  backgroundColor: selected ? accent : 'transparent',
                }} accessibilityElementsHidden>
                  {selected && <View style={{ width: 10, height: 10, borderRadius: 5, backgroundColor: '#fff' }} />}
                </View>
              </View>
            </Pressable>
          );
        })}
      </View>
    </WizardLayout>
  );
}
