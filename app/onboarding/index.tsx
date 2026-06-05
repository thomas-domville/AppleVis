import { useEffect } from 'react';
import { Image, Text, View } from 'react-native';
import { router } from 'expo-router';
import { useTheme } from '../../src/contexts/ThemeContext';
import { WizardLayout } from '../../src/components/WizardLayout';
import { sounds } from '../../src/services/sounds';

export default function WelcomeStep() {
  const { colors } = useTheme();

  useEffect(() => { sounds.welcome().catch(() => {}); }, []);

  return (
    <WizardLayout
      step={1}
      totalSteps={5}
      title="Welcome to AppleVis"
      description="The premier community for blind, DeafBlind, and low vision Apple users — empowering you to get the most from every Apple product and service."
      onNext={() => router.push('/onboarding/sign-in')}
      nextLabel="Get Started"
    >
      {/* Logo */}
      <View
        style={{
          backgroundColor: '#ffffff',
          borderRadius: 16,
          paddingHorizontal: 20,
          paddingVertical: 18,
          marginBottom: 32,
          alignSelf: 'center',
          shadowColor: '#000',
          shadowOpacity: 0.08,
          shadowRadius: 8,
          shadowOffset: { width: 0, height: 2 },
          elevation: 2,
        }}
        accessible
        accessibilityLabel="AppleVis — a Be My Eyes company"
      >
        <Image
          source={require('../../assets/images/applevis-logo.png')}
          style={{ width: 240, height: 69 }}
          resizeMode="contain"
          accessibilityElementsHidden
        />
      </View>

      {/* Feature highlights */}
      {[
        { icon: '🗣️', text: 'Built for VoiceOver from the ground up — every element labelled, every action accessible to blind, DeafBlind, and low vision users.' },
        { icon: '🤝', text: 'An active, engaged community where members empower each other with their collective understanding of Apple accessibility.' },
        { icon: '🎙️', text: 'Forum discussions, app reviews, podcast episodes, and guides — the knowledge of the AppleVis community in one place.' },
        { icon: '🎨', text: '13 themes including high contrast, Mouse, and OLED Midnight — choose yours in the next few steps.' },
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
