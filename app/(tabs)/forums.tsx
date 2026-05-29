import { ScrollView, Text, View } from 'react-native';
import { Screen } from '../../src/components/Screen';
import { AccessibleCard } from '../../src/components/AccessibleCard';
import { forumFilters, forumTopics } from '../../src/data/sampleData';
import { styles } from '../../src/theme/styles';

export default function Forums() {
  return (
    <Screen title="Forums">
      <ScrollView>
        <Text style={styles.lede}>Forum lists remember your position while still sorting active topics by latest activity.</Text>
        <View style={styles.pillRow} accessibilityLabel="Forum filters">
          {forumFilters.map((filter) => <View key={filter} accessible accessibilityRole="button" accessibilityLabel={`${filter} filter`} style={styles.pill}><Text style={styles.pillText}>{filter}</Text></View>)}
        </View>
        {forumTopics.map((topic) => <AccessibleCard key={topic.title} title={topic.title} meta={topic.meta} actions={['Open', 'Save Topic', 'Follow Topic', 'Mark as Read', 'Share']} />)}
        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
