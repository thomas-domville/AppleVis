import { Pressable, Text, View } from 'react-native';
import { useTheme } from '../contexts/ThemeContext';

type Props = {
  onTranslate: () => void;
  onDismiss: () => void;
};

export function TranslationBanner({ onTranslate, onDismiss }: Props) {
  const { colors } = useTheme();

  return (
    <View
      accessible
      accessibilityRole="alert"
      accessibilityLabel="This text appears to be in another language. AppleVis requires posts in English. Options: Open in Translate, or Dismiss."
      style={{
        backgroundColor: colors.pill, borderRadius: 10,
        paddingHorizontal: 14, paddingVertical: 12, marginBottom: 12, gap: 10,
        borderWidth: 1, borderColor: colors.border,
      }}
    >
      <Text style={{ fontSize: 14, lineHeight: 20, color: colors.text }}
        importantForAccessibility="no">
        This appears to be non-English. AppleVis requires all posts to be in English — tap to open Google Translate, translate your text, then paste it back.
      </Text>
      <View style={{ flexDirection: 'row', gap: 10 }}>
        <Pressable
          onPress={onTranslate}
          accessible accessibilityRole="button"
          accessibilityLabel="Open in Google Translate"
          accessibilityHint="Opens Google Translate with your text pre-filled. Translate to English, then paste back here."
          style={{ flex: 1, alignItems: 'center', backgroundColor: colors.accent,
            borderRadius: 8, paddingVertical: 9 }}
        >
          <Text style={{ color: colors.accentText, fontWeight: '700', fontSize: 14 }}>Open in Translate</Text>
        </Pressable>
        <Pressable
          onPress={onDismiss}
          accessible accessibilityRole="button"
          accessibilityLabel="Dismiss this warning"
          style={{ flex: 1, alignItems: 'center', backgroundColor: colors.card,
            borderWidth: 1, borderColor: colors.border, borderRadius: 8, paddingVertical: 9 }}
        >
          <Text style={{ color: colors.text, fontWeight: '600', fontSize: 14 }}>Dismiss</Text>
        </Pressable>
      </View>
    </View>
  );
}
