import { ScrollView, Text, View } from 'react-native';
import { Screen } from '../../src/components/Screen';
import { AccessibleCard } from '../../src/components/AccessibleCard';
import { podcasts } from '../../src/data/sampleData';
import { styles } from '../../src/theme/styles';

export default function Podcasts() {
  return (
    <Screen title="Podcasts">
      <ScrollView>
        <Text style={styles.lede}>A full podcast player scaffold with speed, skip times, chapters, queue, downloads, Smart Speed, voice enhancement, and background audio requirements.</Text>
        <AccessibleCard title="Mini Player" meta="Paused. Playback speed 1.25x. Skip back 15 seconds. Skip forward 30 seconds." actions={['Play', 'Skip Back', 'Skip Forward', 'Change Speed', 'Sleep Timer']} />
        {podcasts.map((episode) => <AccessibleCard key={episode.title} title={episode.title} meta={episode.meta} actions={['Play', 'Play Next', 'Save Episode', 'Download', 'View Transcript', 'Share']} />)}
        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
