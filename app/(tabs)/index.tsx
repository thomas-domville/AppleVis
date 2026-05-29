import { ScrollView, Text, View } from 'react-native';
import { Screen } from '../../src/components/Screen';
import { AccessibleCard } from '../../src/components/AccessibleCard';
import { styles } from '../../src/theme/styles';

export default function Home() {
  return (
    <Screen title="Home">
      <ScrollView>
        <Text style={styles.lede}>
          Good evening. Resume where you left off or jump into what changed since your last visit.
        </Text>

        <AccessibleCard
          title="Since Last Visit"
          meta="3 unread forum topics, 2 new podcast episodes, and 4 app updates."
          actions={['Open', 'Mark All Read']}
        />

        <AccessibleCard
          title="Resume Where You Left Off"
          meta="Forums. AppleVis app feedback and suggestions. Last item read restored by content ID."
          actions={['Resume', 'Jump to New Activity']}
        />

        <AccessibleCard
          title="Saved"
          meta="Saved topics, podcasts, apps, and resources in one place."
          actions={['Open Saved', 'Search Saved']}
        />

        <AccessibleCard
          title="Continue Listening"
          meta="AppleVis Podcast. 12 minutes remaining."
          actions={['Play', 'Play Next', 'Download']}
        />

        <AccessibleCard
          title="New Forum Activity"
          meta="3 new topics and 8 new replies in forums you follow or have read."
          actions={['Open Forums', 'Mark All Read', 'Open Since Last Visit']}
        />

        <AccessibleCard
          title="New Podcast Episodes"
          meta="2 new episodes available. AppleVis Podcast and AppleVis Extra."
          actions={['Play Latest', 'Open Podcasts', 'Download All']}
        />

        <AccessibleCard
          title="Recently Updated Apps"
          meta="4 app updates in the AppleVis directory. Be My Eyes, Seeing AI, and 2 more."
          actions={['Open Apps', 'View Updates', 'Save All']}
        />

        <AccessibleCard
          title="New Resources and Guides"
          meta="1 new guide and 2 updated articles in Resources."
          actions={['Open Resources', 'Save', 'Share']}
        />

        <AccessibleCard
          title="Notifications"
          meta="You have 2 unread notifications. Tap to review."
          actions={['Open Notifications', 'Mark All Read', 'Notification Settings']}
        />

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
