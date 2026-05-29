import { useEffect, useState } from 'react';
import { ScrollView, Text, View } from 'react-native';
import { Screen } from '../../src/components/Screen';
import { AccessibleCard } from '../../src/components/AccessibleCard';
import { persistence } from '../../src/services/persistence';
import { styles } from '../../src/theme/styles';

export default function Home() {
  const [lastVisit, setLastVisit] = useState<string | null>(null);

  useEffect(() => {
    persistence.getLastVisit().then(setLastVisit);
    // Stamp visit on first open so "Since Last Visit" starts working
    persistence.stampVisit();
  }, []);

  function formatLastVisit(iso: string | null): string {
    if (!iso) return 'your first visit — welcome!';
    const d = new Date(iso);
    const now = new Date();
    const diffMs = now.getTime() - d.getTime();
    const diffH = Math.floor(diffMs / 3600000);
    if (diffH < 1) return 'less than an hour ago';
    if (diffH < 24) return `${diffH} hour${diffH === 1 ? '' : 's'} ago`;
    const diffD = Math.floor(diffH / 24);
    return `${diffD} day${diffD === 1 ? '' : 's'} ago`;
  }

  return (
    <Screen title="Home">
      <ScrollView showsVerticalScrollIndicator={false}>
        <Text style={styles.lede}>
          Last visit: {formatLastVisit(lastVisit)}
        </Text>

        <AccessibleCard
          title="Since Last Visit"
          meta="Open Forums and choose Since Last Visit to see everything that changed."
          actions={['Open Forums', 'Mark All Read']}
        />

        <AccessibleCard
          title="Resume Where You Left Off"
          meta="Your reading position and podcast position are saved and synced via iCloud."
          actions={['Resume', 'Jump to New Activity']}
        />

        <AccessibleCard
          title="Saved"
          meta="Your saved topics, podcasts, apps, and resources — stored in iCloud across all your Apple devices."
          actions={['Open Saved', 'Search Saved']}
        />

        <AccessibleCard
          title="Continue Listening"
          meta="Your podcast queue and playback position are saved and synced via iCloud."
          actions={['Play', 'Play Next', 'Download']}
        />

        <AccessibleCard
          title="New Forum Activity"
          meta="Visit the Forums tab and choose Recent or Since Last Visit to see new topics."
          actions={['Open Forums', 'Open Since Last Visit']}
        />

        <AccessibleCard
          title="New Podcast Episodes"
          meta="Open the Podcasts tab to see and play the latest episodes."
          actions={['Open Podcasts', 'Play Latest']}
        />

        <AccessibleCard
          title="Recently Updated Apps"
          meta="Browse the Apps tab to see recently updated app listings."
          actions={['Open Apps', 'View Updates']}
        />

        <AccessibleCard
          title="New Resources and Guides"
          meta="Visit the Resources tab to see new guides, tutorials, and articles."
          actions={['Open Resources', 'Save', 'Share']}
        />

        <AccessibleCard
          title="Notifications"
          meta="Push notifications for forum replies and new episodes will appear here once your account is set up."
          actions={['Open Notifications', 'Notification Settings']}
        />

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
