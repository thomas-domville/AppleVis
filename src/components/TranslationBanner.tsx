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
      accessibilityLabel="Your message appears to be in another language. AppleVis is an English community. Options: Translate, or Post as-is."
      style={{
        backgroundColor: colors.pill, borderRadius: 10,
        paddingHorizontal: 14, paddingVertical: 12, marginBottom: 12, gap: 10,
        borderWidth: 1, borderColor: colors.border,
      }}
    >
      <Text style={{ fontSize: 14, lineHeight: 20, color: colors.text }}
        importantForAccessibility="no">
        Your message appears to be in another language. AppleVis is an English community — would you like to translate it before posting?
      </Text>
      <View style={{ flexDirection: 'row', gap: 10 }}>
        <Pressable
          onPress={onTranslate}
          accessible accessibilityRole="button"
          accessibilityLabel="Translate with Writing Tools"
          accessibilityHint="Opens translation options for your message."
          style={{ flex: 1, alignItems: 'center', backgroundColor: colors.accent,
            borderRadius: 8, paddingVertical: 9 }}
        >
          <Text style={{ color: colors.accentText, fontWeight: '700', fontSize: 14 }}>Translate</Text>
        </Pressable>
        <Pressable
          onPress={onDismiss}
          accessible accessibilityRole="button"
          accessibilityLabel="Dismiss translation suggestion and post in original language"
          style={{ flex: 1, alignItems: 'center', backgroundColor: colors.card,
            borderWidth: 1, borderColor: colors.border, borderRadius: 8, paddingVertical: 9 }}
        >
          <Text style={{ color: colors.text, fontWeight: '600', fontSize: 14 }}>Post as-is</Text>
        </Pressable>
      </View>
    </View>
  );
}
