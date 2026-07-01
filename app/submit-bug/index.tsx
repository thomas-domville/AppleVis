import { KeyboardAvoidingView, Platform, Pressable, Text, TextInput, View } from 'react-native';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { WizardLayout } from '../../src/components/WizardLayout';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useBugWizard, PLATFORM_OPTIONS, type BugPlatform } from '../../src/contexts/BugWizardContext';
import { useAlert } from '../../src/contexts/AccessibleAlertContext';
import { sounds } from '../../src/services/sounds';

// ─── Step 1: Platform + OS version ────────────────────────────────────────────

const PLATFORM_ICONS: Record<BugPlatform, string> = {
  iOS:    'phone-portrait-outline',
  iPadOS: 'tablet-portrait-outline',
  macOS:  'laptop-outline',
};

const PLATFORM_DESCRIPTIONS: Record<BugPlatform, string> = {
  iOS:    'iPhone, iPod touch',
  iPadOS: 'iPad',
  macOS:  'Mac computers',
};

export default function BugStep1() {
  const { colors }      = useTheme();
  const { state, update, reset } = useBugWizard();
  const { showAlert }   = useAlert();

  const canContinue = !!state.platform && !!state.softwareVersion.trim();

  function handleNext() {
    sounds.articleOpen().catch(() => {});
    router.push('/submit-bug/details' as any);
  }

  function handleCancel() {
    showAlert({
      title: 'Discard this report?',
      message: 'Your bug report details will be discarded.',
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
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined} keyboardVerticalOffset={60}>
      <WizardLayout
        step={1}
        totalSteps={4}
        title="Report a bug"
        description="Help improve accessibility by reporting bugs in Apple's platforms. Your report will be reviewed by the community team."
        onNext={handleNext}
        nextLabel="Next: Bug Details"
        nextDisabled={!canContinue}
        hideSkip
        onCancel={handleCancel}
      >
        {/* Platform */}
        <FieldLabel text="Platform" required />
        <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 19, marginBottom: 12 }}>
          Which Apple platform does this bug affect?
        </Text>
        <View style={{ gap: 10, marginBottom: 28 }}
          accessibilityRole="radiogroup" accessibilityLabel="Platform options">
          {PLATFORM_OPTIONS.map(platform => {
            const selected = state.platform === platform;
            return (
              <Pressable
                key={platform}
                onPress={() => { sounds.pickerTick().catch(() => {}); update({ platform }); }}
                accessible
                accessibilityRole="radio"
                accessibilityLabel={`${platform} — ${PLATFORM_DESCRIPTIONS[platform]}`}
                accessibilityState={{ selected }}
                style={({ pressed }) => ({
                  flexDirection: 'row', alignItems: 'center', gap: 14, padding: 16,
                  borderRadius: 16, borderWidth: 2,
                  borderColor: selected ? colors.accent : colors.border,
                  backgroundColor: selected ? `${colors.accent}12` : colors.card,
                  opacity: pressed ? 0.8 : 1,
                })}
              >
                <View style={{
                  width: 44, height: 44, borderRadius: 12,
                  backgroundColor: selected ? colors.accent : `${colors.accent}18`,
                  justifyContent: 'center', alignItems: 'center',
                }} accessibilityElementsHidden>
                  <Ionicons name={PLATFORM_ICONS[platform] as any} size={22} color={selected ? '#fff' : colors.accent} />
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={{ fontSize: 17, fontWeight: selected ? '700' : '500', color: selected ? colors.accent : colors.text }}>
                    {platform}
                  </Text>
                  <Text style={{ fontSize: 13, color: colors.textSecondary, marginTop: 2 }}>
                    {PLATFORM_DESCRIPTIONS[platform]}
                  </Text>
                </View>
                {selected && <Ionicons name="checkmark-circle" size={22} color={colors.accent} accessibilityElementsHidden />}
              </Pressable>
            );
          })}
        </View>

        {/* Software version */}
        <FieldLabel text="Software version" required />
        <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 19, marginBottom: 8 }}>
          Which OS version are you running? e.g. "iOS 18.4", "macOS 15.2"
        </Text>
        <TextInput
          value={state.softwareVersion}
          onChangeText={v => update({ softwareVersion: v })}
          placeholder={state.platform === 'macOS' ? 'e.g. macOS 15.2 Sequoia' : 'e.g. iOS 18.4'}
          placeholderTextColor={colors.textSecondary}
          style={{
            backgroundColor: colors.card, borderRadius: 12,
            paddingHorizontal: 14, paddingVertical: 12,
            fontSize: 17, color: colors.text,
            borderWidth: 1.5, borderColor: state.softwareVersion.trim() ? colors.accent : colors.border,
          }}
          accessible
          accessibilityLabel="Software version"
          accessibilityHint="Required. Enter the operating system version where the bug occurs."
          returnKeyType="done"
        />
      </WizardLayout>
    </KeyboardAvoidingView>
  );
}

function FieldLabel({ text, required }: { text: string; required?: boolean }) {
  const { colors } = useTheme();
  return (
    <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8 }}>
      {text}{required && <Text style={{ color: colors.accent }}> *</Text>}
    </Text>
  );
}
