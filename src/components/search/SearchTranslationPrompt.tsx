import { ActivityIndicator, Pressable, Text, View } from 'react-native';
import { useTheme } from '../../contexts/ThemeContext';

type Props = {
  translating: boolean;
  onTranslate: () => void;
};

/** "AppleVis search works best in English" prompt — shown above search results. */
export function SearchTranslationPrompt({ translating, onTranslate }: Props) {
  const { colors } = useTheme();
  return (
    <View
      style={{
        backgroundColor: colors.pill,
        borderRadius: 10,
        borderWidth: 1,
        borderColor: colors.border,
        paddingHorizontal: 12,
        paddingVertical: 10,
        marginBottom: 12,
        gap: 8,
      }}
      accessible
      accessibilityRole="alert"
      accessibilityLabel="AppleVis search works best in English. Translate this search to English?"
    >
      <Text style={{ color: colors.text, fontSize: 14, lineHeight: 20 }} importantForAccessibility="no">
        AppleVis search works best in English. Translate this search to English?
      </Text>
      <Pressable
        onPress={onTranslate}
        disabled={translating}
        accessible
        accessibilityRole="button"
        accessibilityLabel={translating ? 'Translating search, please wait' : 'Translate search to English'}
        accessibilityState={{ disabled: translating }}
        style={{
          alignItems: 'center',
          backgroundColor: colors.accent,
          borderRadius: 8,
          paddingVertical: 9,
          opacity: translating ? 0.7 : 1,
        }}
      >
        {translating
          ? <ActivityIndicator color={colors.accentText} />
          : <Text style={{ color: colors.accentText, fontWeight: '700', fontSize: 14 }}>
              Translate Search
            </Text>
        }
      </Pressable>
    </View>
  );
}
