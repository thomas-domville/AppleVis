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
          borderRadius: 10,
          borderWidth: 1,
          borderColor: colors.border,
          overflow: 'hidden',
        }}
        accessible
        accessibilityRole="none"
        accessibilityLabel={`${label}: ${options.find(o => o.value === value)?.label ?? String(value)}`}
      >
        {options.map((opt, i) => {
          const isSelected = opt.value === value;
          return (
            <Pressable
              key={String(opt.value)}
              onPress={() => onSelect(opt.value)}
              accessible
              accessibilityRole="none"
              accessibilityState={{ selected: isSelected }}
              accessibilityLabel={`${opt.label}${isSelected ? ', selected' : ''}`}
              style={{
                flex: 1,
                paddingVertical: 9,
                alignItems: 'center',
                backgroundColor: isSelected ? colors.accent : colors.pill,
                borderRightWidth: i < options.length - 1 ? 1 : 0,
                borderRightColor: colors.border,
              }}
            >
              <Text style={{
                fontSize: 14,
                fontWeight: '600',
                color: isSelected ? colors.accentText : colors.pillText,
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
