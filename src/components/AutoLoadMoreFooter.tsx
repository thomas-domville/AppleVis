import { ActivityIndicator, Text, View } from 'react-native';
import { useTheme } from '../contexts/ThemeContext';

type Props = {
  isLoadingMore: boolean;
  label?: string;
};

export function AutoLoadMoreFooter({ isLoadingMore, label = 'Loading more' }: Props) {
  const { colors } = useTheme();

  if (!isLoadingMore) return null;

  return (
    <View
      accessible
      accessibilityLiveRegion="polite"
      accessibilityLabel={label}
      style={{ alignItems: 'center', paddingVertical: 20 }}
    >
      <ActivityIndicator color={colors.appleVisBlue} />
      <Text style={{ color: colors.textSecondary, fontSize: 13, marginTop: 8 }}>
        {label}
      </Text>
    </View>
  );
}
