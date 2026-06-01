import { ActivityIndicator, Pressable, Text, View } from 'react-native';
import { useTheme } from '../contexts/ThemeContext';

type Props = {
  hasMore: boolean;
  isLoadingMore: boolean;
  onPress: () => void;
};

export function LoadMoreButton({ hasMore, isLoadingMore, onPress }: Props) {
  const { colors } = useTheme();
  if (!hasMore && !isLoadingMore) return null;

  return (
    <View style={{ alignItems: 'center', paddingVertical: 16 }}>
      <Pressable
        onPress={onPress}
        disabled={isLoadingMore}
        accessible
        accessibilityRole="button"
        accessibilityLabel={isLoadingMore ? 'Loading more, please wait' : 'Load more'}
        accessibilityState={{ disabled: isLoadingMore }}
        style={{
          backgroundColor: colors.pill,
          borderRadius: 999,
          paddingHorizontal: 24,
          paddingVertical: 12,
          minWidth: 130,
          alignItems: 'center',
        }}
      >
        {isLoadingMore
          ? <ActivityIndicator color={colors.accent} />
          : <Text style={{ color: colors.pillText, fontWeight: '700', fontSize: 15 }}>Load More</Text>
        }
      </Pressable>
    </View>
  );
}
