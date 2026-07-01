import { ActivityIndicator, Text, View } from 'react-native';
import { useTheme } from '../../contexts/ThemeContext';

export function SearchLoadingState() {
  const { colors, styles } = useTheme();
  return (
    <View
      style={{ alignItems: 'center', paddingVertical: 32 }}
      accessible
      accessibilityLiveRegion="polite"
      accessibilityLabel="Searching AppleVis, please wait"
    >
      <ActivityIndicator size="large" color={colors.appleVisBlue} accessibilityElementsHidden />
      <Text style={[styles.lede, { marginTop: 12, textAlign: 'center' }]} accessibilityElementsHidden>
        Searching…
      </Text>
    </View>
  );
}
