import { useEffect } from 'react';
import { AccessibilityInfo, Image, Linking, Pressable, Text, View } from 'react-native';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../src/contexts/ThemeContext';
import { usePreferences } from '../../src/contexts/PreferencesContext';
import { useAuth } from '../../src/contexts/AuthContext';
import { useAlert } from '../../src/contexts/AccessibleAlertContext';
import { WizardLayout } from '../../src/components/WizardLayout';
import { onboarding } from '../../src/services/onboarding';
import { tour } from '../../src/services/tour';
import { guidedExperienceStore } from '../../src/services/guidedExperienceStore';
import { THEMES } from '../../src/theme/themes';

export default function ReadyStep() {
  const { colors, themeId } = useTheme();
  const { announcementLevel, notificationPrefs } = usePreferences();
  const auth = useAuth();
  const { showAlert } = useAlert();

  const themeName    = THEMES[themeId].name;
  const levelLabels  = { simple: 'Simple', normal: 'Normal', all: 'All' };
  const levelLabel   = levelLabels[announcementLevel];
  const notifCount   = Object.values(notificationPrefs).filter(Boolean).length;

  const summaryItems = [
    auth.isSignedIn && `Signed in as ${auth.user?.name ?? 'you'}`,
    `Theme: ${themeName}`,
    `VoiceOver detail: ${levelLabel}`,
    notifCount > 0 ? `${notifCount} notification type${notifCount === 1 ? '' : 's'} enabled` : 'Notifications off — enable any time in Settings',
  ].filter(Boolean) as string[];

  useEffect(() => {
    const summary = summaryItems.join('. ');
    const t = setTimeout(() => {
      AccessibilityInfo.announceForAccessibility(`Setup complete. ${summary}.`);
    }, 1500);
    return () => clearTimeout(t);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <WizardLayout
      step={6}
      totalSteps={6}
      title="You're all set!"
      description="You're now part of the premier community for blind, DeafBlind, and low vision Apple users. Everything you chose here can be changed any time in Settings."
      onNext={async () => {
        await onboarding.markComplete().catch(() => {});
        router.replace('/(tabs)');

        // Let Home's own welcome sound/announcement/focus settle first, then
        // — if the user hasn't finished/skipped the tour and hasn't opted out — offer it.
        const [autoPromptEnabled, welcomeProgress] = await Promise.all([
          tour.autoPromptEnabled(),
          guidedExperienceStore.getProgress('welcome'),
        ]);
        const shouldPrompt = autoPromptEnabled && !welcomeProgress.completed && !welcomeProgress.skipped;
        if (shouldPrompt) {
          setTimeout(() => {
            showAlert({
              title: 'Take a quick tour of AppleVis?',
              message: 'See a short, skippable walkthrough of Home, Discover, For You, Search, Profile, and Settings.',
              buttons: [
                { label: 'Start Tour', onPress: () => router.push({ pathname: '/guided-experience/[experienceId]', params: { experienceId: 'welcome' } } as any) },
                { label: 'Maybe Later', style: 'cancel' },
                {
                  label: 'No Thanks',
                  onPress: () => { tour.disableAutoPrompt().catch(() => {}); },
                },
              ],
            });
          }, 2500);
        }
      }}
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
            <Ionicons name="checkmark-circle" size={18} color={colors.accent}
              style={{ marginTop: 2 }} accessibilityElementsHidden />
            <Text style={{ flex: 1, fontSize: 15, color: colors.textSecondary, lineHeight: 22 }}
              accessibilityElementsHidden>{item}</Text>
          </View>
        ))}
      </View>

      {/* What's next hints */}
      <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text, marginBottom: 12 }}>
        Where to start
      </Text>
      {[
        { icon: '🏠', text: 'Home — Catch up on the latest AppleVis activity.' },
        { icon: '🧭', text: 'Discover — Browse apps, community discussions, guides, podcasts, the bug tracker, and more.' },
        { icon: '⭐', text: 'For You — Return to your queue, downloads, saved items, and followed content.' },
        { icon: '🔎', text: 'Search — Find discussions, apps, guides, podcast episodes, and help.' },
      ].map(({ icon, text }) => (
        <View key={text} style={{ flexDirection: 'row', gap: 12, marginBottom: 14, alignItems: 'flex-start' }}
          accessible accessibilityLabel={text}>
          <Text style={{ fontSize: 20 }} accessibilityElementsHidden>{icon}</Text>
          <Text style={{ flex: 1, fontSize: 15, color: colors.textSecondary, lineHeight: 22 }}>{text}</Text>
        </View>
      ))}
      {/* Be My Eyes link */}
      <Pressable
        onPress={() => Linking.openURL('https://apps.apple.com/us/app/be-my-eyes/id905177575')}
        accessible
        accessibilityRole="link"
        accessibilityLabel="Get free visual assistance with the Be My Eyes app"
        accessibilityHint="Opens the Be My Eyes app page in the App Store"
        style={({ pressed }) => ({
          flexDirection: 'row', alignItems: 'center', gap: 10,
          marginBottom: 24, opacity: pressed ? 0.6 : 1,
        })}
      >
        <Text style={{ fontSize: 20 }} accessibilityElementsHidden>👁️</Text>
        <Text style={{ flex: 1, fontSize: 15, color: colors.appleVisBlue, lineHeight: 22, textDecorationLine: 'underline' }}>
          Get free visual assistance with the Be My Eyes app
        </Text>
      </Pressable>

      {/* Brand close */}
      <View style={{ alignItems: 'center', marginTop: 16, paddingVertical: 20,
        backgroundColor: colors.card, borderRadius: 14 }}
        accessible accessibilityLabel="AppleVis logo on a white background. To the left is a stylized zigzag A shape made of two angular lines, one in blue and one in gold. To the right is the word AppleVis in bold blue text. Beneath AppleVis, in smaller black text, is the tagline a Be My Eyes company, with a gold underline beneath the words Be My Eyes.">
        <Image
          source={require('../../assets/images/applevis-logo.png')}
          style={{ width: 200, height: 57 }}
          resizeMode="contain"
          accessibilityElementsHidden
          accessibilityIgnoresInvertColors
        />
      </View>
    </WizardLayout>
  );
}
