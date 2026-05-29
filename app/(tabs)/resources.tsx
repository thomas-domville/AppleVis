import { ScrollView, Text, View } from 'react-native';
import { Screen } from '../../src/components/Screen';
import { AccessibleCard } from '../../src/components/AccessibleCard';
import { resources } from '../../src/data/sampleData';
import { styles } from '../../src/theme/styles';

export default function Resources() {
  return (
    <Screen title="Resources">
      <ScrollView>
        <Text style={styles.lede}>Guides, tutorials, how-to articles, accessibility resources, events, developer resources, and getting-started content.</Text>
        {resources.map((item) => <AccessibleCard key={item.title} title={item.title} meta={item.meta} actions={['Open', 'Save', 'Share', 'Copy Link']} />)}
        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
