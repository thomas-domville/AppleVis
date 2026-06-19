import { Pressable, Text, View } from 'react-native';
import { useTheme } from '../contexts/ThemeContext';

type Props<T extends string | number> = {
  label: string;
  description: string;
  value: T;
  options: { value: T; label: string }[];
  onSelect: (v: T) => void;
};

export function SettingsSegmentedRow<T extends string | number>({
  label, description, value, options, onSelect,
}: Props<T>) {
  const { colors, styles } = useTheme();

  return (
    <View style={styles.cardSmall}>
      <Text style={{ fontSize: 16, fontWeight: '600', color: colors.text, marginBottom: 4 }}>{label}</Text>
      <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 18, marginBottom: 12 }}>
        {description}
      </Text>
      <View
        style={{
          flexDirection: 'row',
          flexWrap: 'wrap',
          borderRadius: 10,
          borderWidth: 1,
          borderColor: colors.border,
          overflow: 'hidden',
        }}
      >
        {options.map((opt, i) => {
          const isSelected = opt.value === value;
          return (
            <Pressable
              key={String(opt.value)}
              onPress={() => onSelect(opt.value)}
              accessible
              accessibilityRole="button"
              accessibilityState={{ selected: isSelected }}
              accessibilityLabel={opt.label}
              style={{
                flexGrow: 1,
                flexBasis: `${100 / Math.min(options.length, 3)}%`,
                paddingVertical: 9,
                paddingHorizontal: 8,
                alignItems: 'center',
                backgroundColor: isSelected ? colors.accent : colors.pill,
                borderRightWidth: i < options.length - 1 ? 1 : 0,
                borderRightColor: colors.border,
                borderBottomWidth: options.length > 3 && i < options.length - 1 ? 1 : 0,
                borderBottomColor: colors.border,
              }}
            >
              <Text style={{
                fontSize: 14,
                fontWeight: '600',
                color: isSelected ? colors.accentText : colors.pillText,
                textAlign: 'center',
              }}>
                {opt.label}
              </Text>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}
