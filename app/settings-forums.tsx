import { ScrollView, Text, View } from 'react-native';
import { Screen } from '../src/components/Screen';
import { SettingsPickerRow } from '../src/components/SettingsPickerRow';
import { useTheme } from '../src/contexts/ThemeContext';
import { usePreferences } from '../src/contexts/PreferencesContext';
import type { DefaultForumFilter } from '../src/contexts/PreferencesContext';

const FORUM_FILTER_OPTIONS: { value: DefaultForumFilter; label: string }[] = [
  { value: 'Recent',          label: 'Recent'          },
  { value: 'Since Last Visit', label: 'Since Last Visit' },
  { value: 'Unread',          label: 'Unread'          },
];

export default function ForumSettings() {
  const { styles } = useTheme();
  const { defaultForumFilter, setDefaultForumFilter } = usePreferences();

  return (
    <Screen title="Forums" showSettings={false}>
      <ScrollView showsVerticalScrollIndicator={false}>
        <Text style={styles.lede}>
          Set your preferred default view when you open the Forums tab.
          You can always switch the filter while browsing.
        </Text>

        <SettingsPickerRow
          label="Default Forum View"
          description="Which forum filter is active when you open the Forums tab."
          value={defaultForumFilter}
          options={FORUM_FILTER_OPTIONS}
          onSelect={setDefaultForumFilter}
        />

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
