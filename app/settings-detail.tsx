import { useLocalSearchParams } from 'expo-router';
import { ScrollView, Text, View } from 'react-native';
import { Screen } from '../src/components/Screen';
import { settingsSections } from '../src/data/settings';
import { useTheme } from '../src/contexts/ThemeContext';

export default function SettingsDetail() {
  const { styles } = useTheme();
  const { title } = useLocalSearchParams<{ title: string }>();
  const section = settingsSections.find((item) => item.title === title) ?? settingsSections[0];
  return (
    <Screen title={section.title} showSettings={false}>
      <ScrollView>
        {section.items.map((item) => (
          <View key={item} accessible accessibilityRole="button" accessibilityLabel={item} style={styles.cardSmall}>
            <Text style={styles.body}>{item}</Text>
          </View>
        ))}
      </ScrollView>
    </Screen>
  );
}
