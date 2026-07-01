import { Image, Text, View } from 'react-native';
import { router } from 'expo-router';
import { useTheme } from '../../src/contexts/ThemeContext';
import { WizardLayout } from '../../src/components/WizardLayout';

// Single welcome/launch sound policy: Home owns the one "welcome" sound moment
// when the user first lands there after finishing or skipping setup — the
// wizard itself stays quiet so users don't hear it twice back to back.

export default function WelcomeStep() {
  const { colors } = useTheme();

  return (
    <WizardLayout
      step={1}
      totalSteps={6}
      title="Welcome to AppleVis"
      description="The premier community for blind, DeafBlind, and low vision Apple users — empowering you to get the most from every Apple product and service."
      onNext={() => router.push('/onboarding/sign-in')}
      nextLabel="Get Started"
    >
      {/* Logo */}
      <View
        style={{
          backgroundColor: colors.card,
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
        accessibilityLabel="AppleVis logo on a white background. To the left is a stylized zigzag A shape made of two angular lines, one in blue and one in gold. To the right is the word AppleVis in bold blue text. Beneath AppleVis, in smaller black text, is the tagline a Be My Eyes company, with a gold underline beneath the words Be My Eyes."
      >
        <Image
          source={require('../../assets/images/applevis-logo.png')}
          style={{ width: 240, height: 69 }}
          resizeMode="contain"
          accessibilityElementsHidden
          accessibilityIgnoresInvertColors
        />
      </View>

      {/* Feature highlights */}
      {[
        { icon: '🗣️', text: 'Built for VoiceOver from the ground up — every element labelled, every action accessible to blind, DeafBlind, and low vision users.' },
        { icon: '🤝', text: 'An active, engaged community where members empower each other with their collective understanding of Apple accessibility.' },
        { icon: '🎙️', text: 'Forum discussions, app reviews, podcast episodes, and guides — the knowledge of the AppleVis community in one place.' },
        { icon: '🎨', text: '14 themes including high contrast, Mouse, and OLED Midnight — choose yours in the next few steps.' },
        { icon: '🔔', text: 'Stay informed with push notifications for new podcast episodes, forum replies, mentions, and AppleVis announcements — you choose exactly what to receive.' },
      ].map(({ icon, text }) => (
        <View
          key={text}
          style={{
            flexDirection: 'row', gap: 14, marginBottom: 12, alignItems: 'flex-start',
            backgroundColor: colors.card, borderRadius: 12, padding: 14,
            borderLeftWidth: 3, borderLeftColor: colors.accent,
          }}
          accessible
          accessibilityLabel={text}
        >
          <Text style={{ fontSize: 20 }} accessibilityElementsHidden>{icon}</Text>
          <Text style={{ flex: 1, fontSize: 15, lineHeight: 22, color: colors.textSecondary }}>{text}</Text>
        </View>
      ))}
    </WizardLayout>
  );
}
