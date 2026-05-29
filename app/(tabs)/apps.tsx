import { ScrollView, Text, View } from 'react-native';
import { Screen } from '../../src/components/Screen';
import { AccessibleCard } from '../../src/components/AccessibleCard';
import { apps } from '../../src/data/sampleData';
import { styles } from '../../src/theme/styles';

export default function Apps() {
  return (
    <Screen title="Apps">
      <ScrollView>
        <Text style={styles.lede}>Browse app directory listings, reviews, updates, saved apps, and followed apps.</Text>
        {apps.map((item) => <AccessibleCard key={item.title} title={item.title} meta={item.meta} actions={['Open App Page', 'Save App', 'Follow App', 'Share', 'View Reviews']} />)}
        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
