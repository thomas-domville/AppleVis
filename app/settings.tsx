import { ScrollView, Text, View } from 'react-native';
import { Link } from 'expo-router';
import { Screen } from '../src/components/Screen';
import { settingsSections } from '../src/data/settings';
import { styles } from '../src/theme/styles';

export default function Settings() {
  return (
    <Screen title="Settings" showSettings={false}>
      <ScrollView contentInsetAdjustmentBehavior="automatic">
        <Text style={styles.lede}>AppleVis settings are grouped so VoiceOver users do not have to swipe through one long list of switches.</Text>
        {settingsSections.map((section) => (
          <Link key={section.title} href={{ pathname: '/settings-detail', params: { title: section.title } }} asChild>
            <View
              accessible
              accessibilityRole="button"
              accessibilityLabel={`${section.title}. ${section.description}`}
              accessibilityHint="Opens this settings category."
              style={styles.card}
            >
              <Text style={styles.cardTitle}>{section.title}</Text>
              <Text style={styles.cardMeta}>{section.description}</Text>
            </View>
          </Link>
        ))}
      </ScrollView>
    </Screen>
  );
}
