import { Pressable, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../contexts/ThemeContext';

type Action = { label: string; onPress: () => void };

export function EmptyState({
  icon,
  title,
  subtitle,
  action,
}: {
  icon: string;
  title: string;
  subtitle: string;
  action?: Action;
}) {
  const { colors, styles } = useTheme();
  return (
    <View
      style={[styles.card, { alignItems: 'center', paddingVertical: 36 }]}
      accessible
      accessibilityLabel={`${title}. ${subtitle}`}
    >
      <Ionicons
        name={icon as any}
        size={40}
        color={colors.textSecondary}
        accessibilityElementsHidden
        style={{ marginBottom: 12 }}
      />
      <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text,
        marginBottom: 6, textAlign: 'center' }}>
        {title}
      </Text>
      <Text style={{ fontSize: 14, color: colors.textSecondary,
        textAlign: 'center', lineHeight: 20 }}>
        {subtitle}
      </Text>
      {action && (
        <Pressable
          onPress={action.onPress}
          accessible
          accessibilityRole="button"
          accessibilityLabel={action.label}
          style={{
            marginTop: 16,
            backgroundColor: colors.accent,
            paddingHorizontal: 20,
            paddingVertical: 10,
            borderRadius: 10,
          }}
        >
          <Text style={{ color: '#FFF', fontWeight: '700', fontSize: 15 }}>
            {action.label}
          </Text>
        </Pressable>
      )}
    </View>
  );
}
