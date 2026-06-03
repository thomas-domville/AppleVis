import { useEffect } from 'react';
import { Image, Text, View } from 'react-native';
import { router } from 'expo-router';
import { useTheme } from '../../src/contexts/ThemeContext';
import { usePreferences } from '../../src/contexts/PreferencesContext';
import { useAuth } from '../../src/contexts/AuthContext';
import { WizardLayout } from '../../src/components/WizardLayout';
import { onboarding } from '../../src/services/onboarding';
import { THEMES } from '../../src/theme/themes';

export default function ReadyStep() {
  const { colors, themeId } = useTheme();
  const { announcementLevel, notificationPrefs } = usePreferences();
  const auth = useAuth();

  useEffect(() => {
    onboarding.markComplete().catch(() => {});
  }, []);

  const themeName    = THEMES[themeId].name;
  const levelLabels  = { simple: 'Simple', normal: 'Normal', all: 'All' };
  const levelLabel   = levelLabels[announcementLevel];
  const notifCount   = Object.values(notificationPrefs).filter(Boolean).length;

  const summaryItems = [
    auth.isSignedIn && `Signed in as ${auth.user?.name ?? 'you'}`,
    `Theme: ${themeName}`,
    `VoiceOver detail: ${levelLabel}`,
    notifCount > 0 ? `${notifCount} notification type${notifCount === 1 ? '' : 's'} enabled` : 'Notifications skipped',
  ].filter(Boolean) as string[];

  return (
    <WizardLayout
      step={5}
      totalSteps={5}
      title="You're all set!"
      description="You're now part of the premier community for blind, DeafBlind, and low vision Apple users. Everything you chose here can be changed any time in Settings."
      onNext={() => router.replace('/(tabs)')}
      nextLabel="Start Exploring"
      hideSkip
      hideStepIndicator
    >
      {/* Summary card */}
      <View style={{
        backgroundColor: colors.card, borderRadius: 16,
        padding: 18, borderWidth: 1, borderColor: colors.border, marginBottom: 24,
      }}>
        <Text style={{ fontSize: 15, fontWeight: '700', color: colors.text, marginBottom: 12 }}>
          Your setup summary
        </Text>
        {summaryItems.map((item) => (
          <View key={item} style={{ flexDirection: 'row', gap: 10, marginBottom: 8, alignItems: 'flex-start' }}
            accessible accessibilityLabel={item}>
            <Text style={{ color: colors.accent, fontSize: 16, lineHeight: 22 }}>✓</Text>
            <Text style={{ flex: 1, fontSize: 15, color: colors.textSecondary, lineHeight: 22 }}>{item}</Text>
          </View>
        ))}
      </View>

      {/* What's next hints */}
      <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text, marginBottom: 12 }}>
        Where to start
      </Text>
      {[
        { icon: '💬', text: 'Forums — browse recent topics, follow discussions, and post your own.' },
        { icon: '📱', text: 'App Directories — find accessibility reviews for thousands of iOS and macOS apps.' },
        { icon: '🎙️', text: 'Podcasts — listen to AppleVis episodes with the built-in accessible player.' },
        { icon: '📖', text: 'Resources — guides, tutorials, and how-to articles for every skill level.' },
      ].map(({ icon, text }) => (
        <View key={text} style={{ flexDirection: 'row', gap: 12, marginBottom: 14, alignItems: 'flex-start' }}
          accessible accessibilityLabel={text}>
          <Text style={{ fontSize: 20 }} accessibilityElementsHidden>{icon}</Text>
          <Text style={{ flex: 1, fontSize: 15, color: colors.textSecondary, lineHeight: 22 }}>{text}</Text>
        </View>
      ))}
      {/* Brand close */}
      <View style={{ alignItems: 'center', marginTop: 16, paddingVertical: 20,
        backgroundColor: '#ffffff', borderRadius: 14 }}
        accessible accessibilityLabel="AppleVis — a Be My Eyes company">
        <Image
          source={require('../../assets/images/applevis-logo.png')}
          style={{ width: 200, height: 57 }}
          resizeMode="contain"
          accessibilityElementsHidden
        />
      </View>
    </WizardLayout>
  );
}
