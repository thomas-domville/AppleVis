import { useEffect, useState } from 'react';
import { ScrollView, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { useTranslation } from 'react-i18next';
import { Screen } from '../../src/components/Screen';
import { AccessibleCard } from '../../src/components/AccessibleCard';
import { useAuth } from '../../src/contexts/AuthContext';
import { persistence } from '../../src/services/persistence';
import { useHandoff } from '../../src/hooks/useHandoff';
import { useTheme } from '../../src/contexts/ThemeContext';

function getGreetingKey(): 'home.greeting.morning' | 'home.greeting.afternoon' | 'home.greeting.evening' | 'home.greeting.night' {
  const hour = new Date().getHours();
  if (hour >= 5  && hour < 12) return 'home.greeting.morning';
  if (hour >= 12 && hour < 17) return 'home.greeting.afternoon';
  if (hour >= 17 && hour < 22) return 'home.greeting.evening';
  return 'home.greeting.night';
}

export default function Home() {
  const router     = useRouter();
  const { colors, styles } = useTheme();
  const auth       = useAuth();
  const { t }      = useTranslation();
  const [lastVisit, setLastVisit] = useState<string | null>(null);

  useHandoff({
    activityType: 'com.applevis.app.viewForums',
    title: 'AppleVis',
    webpageURL: 'https://www.applevis.com',
  });

  useEffect(() => {
    persistence.getLastVisit().then(setLastVisit);
    persistence.stampVisit();
  }, []);

  function formatLastVisit(iso: string | null): string {
    if (!iso) return t('home.firstVisit');
    const diffMs  = Date.now() - new Date(iso).getTime();
    const diffMin = Math.floor(diffMs / 60_000);
    if (diffMin < 1)  return 'just now';
    if (diffMin < 60) return `${diffMin} minute${diffMin === 1 ? '' : 's'} ago`;
    const diffH = Math.floor(diffMin / 60);
    if (diffH < 24)   return `${diffH} hour${diffH === 1 ? '' : 's'} ago`;
    const diffD = Math.floor(diffH / 24);
    return              `${diffD} day${diffD === 1 ? '' : 's'} ago`;
  }

  const greeting     = t(getGreetingKey());
  const name         = auth.user?.name ?? '';
  const lastVisitStr = formatLastVisit(lastVisit);

  return (
    <Screen title="Home" showSearch showBack={false}>
      <ScrollView showsVerticalScrollIndicator={false}>

        {auth.isSignedIn && name ? (
          <View
            style={[styles.card, { marginBottom: 4 }]}
            accessible
            accessibilityLabel={`${greeting}, ${name}. ${t('home.lastVisit')}: ${lastVisitStr}.`}
          >
            <Text
              style={{ fontSize: 20, fontWeight: '300', color: colors.text, letterSpacing: 0.2 }}
              importantForAccessibility="no-hide-descendants"
            >
              {greeting},
            </Text>
            <Text
              style={{ fontSize: 28, fontWeight: '700', color: colors.appleVisBlue, marginBottom: 8 }}
              importantForAccessibility="no-hide-descendants"
            >
              {name}
            </Text>
            <Text
              style={styles.cardMeta}
              importantForAccessibility="no-hide-descendants"
            >
              {t('home.lastVisit')}: {lastVisitStr}
            </Text>
          </View>
        ) : (
          <Text style={styles.lede}>{t('home.lastVisit')}: {lastVisitStr}</Text>
        )}

        <AccessibleCard
          title="Since Last Visit"
          meta="Open Forums and choose Since Last Visit to see everything that changed."
          actions={['Open Forums', 'Mark All Read']}
          onAction={(a) => { if (a === 'Open Forums' || a === 'Open') router.push('/(tabs)/forums'); }}
        />

        <AccessibleCard
          title="Resume Where You Left Off"
          meta="Your reading position and podcast position are saved and synced via iCloud."
          actions={['Resume Podcast', 'Open Forums']}
          onAction={(a) => {
            if (a === 'Resume Podcast' || a === 'Open') router.push('/(tabs)/podcasts');
            if (a === 'Open Forums') router.push('/(tabs)/forums');
          }}
        />

        <AccessibleCard
          title="Saved"
          meta="Your saved topics, podcasts, apps, and resources — stored in iCloud across all your Apple devices."
          actions={['Open Forums', 'Open Apps', 'Open Resources']}
          onAction={(a) => {
            if (a === 'Open Forums' || a === 'Open') router.push('/(tabs)/forums');
            if (a === 'Open Apps') router.push('/(tabs)/apps');
            if (a === 'Open Resources') router.push('/(tabs)/resources');
          }}
        />

        <AccessibleCard
          title="Continue Listening"
          meta="Your podcast queue and playback position are saved and synced via iCloud."
          actions={['Open Podcasts']}
          onAction={(a) => { if (a === 'Open Podcasts' || a === 'Open') router.push('/(tabs)/podcasts'); }}
        />

        <AccessibleCard
          title="New Forum Activity"
          meta="Visit the Forums tab and choose Recent or Since Last Visit to see new topics."
          actions={['Open Forums', 'Since Last Visit']}
          onAction={(a) => { if (a === 'Open Forums' || a === 'Since Last Visit' || a === 'Open') router.push('/(tabs)/forums'); }}
        />

        <AccessibleCard
          title="New Podcast Episodes"
          meta="Open the Podcasts tab to see and play the latest episodes."
          actions={['Open Podcasts']}
          onAction={(a) => { if (a === 'Open Podcasts' || a === 'Open') router.push('/(tabs)/podcasts'); }}
        />

        <AccessibleCard
          title="Recently Updated Apps"
          meta="Browse the Apps tab to see recently updated app listings."
          actions={['Open Apps']}
          onAction={(a) => { if (a === 'Open Apps' || a === 'Open') router.push('/(tabs)/apps'); }}
        />

        <AccessibleCard
          title="New Resources and Guides"
          meta="Visit the Resources tab to see new guides, tutorials, and articles."
          actions={['Open Resources']}
          onAction={(a) => { if (a === 'Open Resources' || a === 'Open') router.push('/(tabs)/resources'); }}
        />

        <AccessibleCard
          title="Notification Settings"
          meta="Push notifications for forum replies and new episodes. Configure in Settings."
          actions={['Open Settings']}
          onAction={(a) => { if (a === 'Open Settings' || a === 'Open') router.push('/settings'); }}
        />

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
