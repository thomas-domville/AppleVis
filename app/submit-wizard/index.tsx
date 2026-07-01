import { useRef } from 'react';
import { Animated, Pressable, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { WizardLayout } from '../../src/components/WizardLayout';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useWizard } from '../../src/contexts/SubmitWizardContext';
import { useAlert } from '../../src/contexts/AccessibleAlertContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { sounds } from '../../src/services/sounds';

// ─── Step 1: Before You Begin ─────────────────────────────────────────────────

const GUIDELINES_URL = 'https://www.applevis.com/submitting-app-applevis-community-app-directory-guidelines';

type CheckRowProps = {
  checked:     boolean;
  onToggle:    () => void;
  title:       string;
  body:        string;
  iconName:    string;
  accentColor: string;
};

function CheckRow({ checked, onToggle, title, body, iconName, accentColor }: CheckRowProps) {
  const { colors }       = useTheme();
  const { reduceMotion } = useAccessibilityPreferences();
  const scaleAnim        = useRef(new Animated.Value(1)).current;

  function handlePress() {
    if (!reduceMotion) {
      Animated.sequence([
        Animated.timing(scaleAnim, { toValue: 0.95, duration: 80,  useNativeDriver: true }),
        Animated.timing(scaleAnim, { toValue: 1,    duration: 120, useNativeDriver: true }),
      ]).start();
    }
    sounds.pickerTick().catch(() => {});
    onToggle();
  }

  return (
    <Pressable
      onPress={handlePress}
      accessible
      accessibilityRole="checkbox"
      accessibilityLabel={title}
      accessibilityHint={body}
      accessibilityState={{ checked }}
      style={({ pressed }) => ({ opacity: pressed ? 0.85 : 1 })}
    >
      <Animated.View style={[{
        flexDirection: 'row', alignItems: 'flex-start', gap: 14,
        backgroundColor: colors.card, borderRadius: 14, padding: 16, marginBottom: 10,
        borderWidth: 2, borderColor: checked ? accentColor : colors.border,
      }, { transform: [{ scale: scaleAnim }] }]}>
        <View style={{
          width: 40, height: 40, borderRadius: 20, flexShrink: 0,
          backgroundColor: checked ? accentColor : colors.border,
          justifyContent: 'center', alignItems: 'center',
        }} accessibilityElementsHidden>
          <Ionicons name={checked ? 'checkmark' : iconName as any} size={20} color="#fff" />
        </View>
        <View style={{ flex: 1 }}>
          <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text, marginBottom: 3 }}>{title}</Text>
          <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>{body}</Text>
        </View>
      </Animated.View>
    </Pressable>
  );
}

export default function BeforeYouBeginScreen() {
  const { colors }    = useTheme();
  const { state, update, reset } = useWizard();
  const { showAlert } = useAlert();

  const canContinue = state.agreedPersonalUse && state.agreedNotDeveloper;
  const accent      = colors.accent;

  function handleNext() {
    sounds.articleOpen().catch(() => {});
    router.push('/submit-wizard/platform' as any);
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
      step={1}
      totalSteps={5}
      title="Before You Submit"
      description="The AppleVis App Directory is a community resource. Please read and confirm the following before adding an app."
      onNext={handleNext}
      nextLabel="Continue"
      nextDisabled={!canContinue}
      hideSkip
      onCancel={handleCancel}
    >
      <CheckRow
        checked={state.agreedPersonalUse}
        onToggle={() => update({ agreedPersonalUse: !state.agreedPersonalUse })}
        title="I have used this app"
        body="I have personally used this app and can describe its accessibility — I am not submitting based on the App Store description alone."
        iconName="hand-right-outline"
        accentColor={accent}
      />
      <CheckRow
        checked={state.agreedNotDeveloper}
        onToggle={() => update({ agreedNotDeveloper: !state.agreedNotDeveloper })}
        title="I am not the developer"
        body="I am not the developer, publisher, or otherwise affiliated with this app. Developers may not submit their own apps per AppleVis guidelines."
        iconName="person-outline"
        accentColor={accent}
      />

      {/* Guidelines link */}
      <Pressable
        accessible accessibilityRole="link"
        accessibilityLabel="Read the full AppleVis submission guidelines"
        accessibilityHint="Opens in Safari"
        onPress={() => void import('expo-linking').then(({ default: L }) => L.openURL(GUIDELINES_URL))}
        style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', gap: 6, marginTop: 4, opacity: pressed ? 0.7 : 1 })}
      >
        <Ionicons name="open-outline" size={14} color={accent} accessibilityElementsHidden />
        <Text style={{ fontSize: 14, color: accent, fontWeight: '600' }}>Read submission guidelines</Text>
      </Pressable>

      {!canContinue && (
        <Text style={{ fontSize: 13, color: colors.textSecondary, marginTop: 12 }} accessibilityLiveRegion="polite">
          Confirm both checkboxes to continue
        </Text>
      )}
    </WizardLayout>
  );
}
