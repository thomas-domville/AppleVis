import { Text, View } from 'react-native';
import { router } from 'expo-router';
import { useTheme } from '../../src/contexts/ThemeContext';
import { WizardLayout } from '../../src/components/WizardLayout';

export default function WelcomeStep() {
  const { colors } = useTheme();

  return (
    <WizardLayout
      step={1}
      totalSteps={5}
      title="Welcome to AppleVis"
      description="The community for blind, low-vision, and sighted Apple users. Let's get you set up in about a minute."
      onNext={() => router.push('/onboarding/sign-in')}
      nextLabel="Get Started"
    >
      {/* Brand mark */}
      <View
        style={{
          width: 96, height: 96, borderRadius: 24,
          backgroundColor: colors.accent,
          alignItems: 'center', justifyContent: 'center',
          marginBottom: 32, alignSelf: 'center',
        }}
        accessible
        accessibilityLabel="AppleVis app icon"
      >
        <Text style={{ fontSize: 44 }} accessibilityElementsHidden>🐭</Text>
      </View>

      {/* Feature highlights */}
      {[
        { icon: '🗣️', text: 'Built for VoiceOver from the ground up — every element labelled, every action accessible.' },
        { icon: '🎙️', text: 'Forum discussions, app reviews, podcast episodes, and guides — all in one place.' },
        { icon: '☁️',  text: 'iCloud sync keeps your saved items, reading position, and podcast queue across all your Apple devices.' },
        { icon: '🎨',  text: '13 themes including high contrast, Mouse, and OLED Midnight — choose yours in the next few steps.' },
      ].map(({ icon, text }) => (
        <View
          key={text}
          style={{ flexDirection: 'row', gap: 14, marginBottom: 18, alignItems: 'flex-start' }}
          accessible
          accessibilityLabel={text}
        >
          <Text style={{ fontSize: 22 }} accessibilityElementsHidden>{icon}</Text>
          <Text style={{ flex: 1, fontSize: 16, lineHeight: 23, color: colors.textSecondary }}>{text}</Text>
        </View>
      ))}
    </WizardLayout>
  );
}
