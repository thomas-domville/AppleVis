import type { ReactNode } from 'react';
import { Text, View } from 'react-native';
import { useTheme } from '../../contexts/ThemeContext';

type Props = {
  title: string;
  count: number;
  children: ReactNode;
};

/** One titled, counted group of search results (e.g. "Forum Topics (4)"). */
export function SearchResultSection({ title, count, children }: Props) {
  const { colors } = useTheme();
  if (count === 0) return null;
  return (
    <View style={{ marginBottom: 8 }}>
      <Text
        style={{
          fontSize: 13, fontWeight: '700', color: colors.textSecondary,
          textTransform: 'uppercase', letterSpacing: 0.8,
          marginBottom: 8, marginTop: 4,
        }}
        accessibilityRole="header"
      >
        {title} ({count})
      </Text>
      {children}
    </View>
  );
}
