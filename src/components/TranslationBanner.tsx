import { Pressable, Text, View } from 'react-native';

type Props = {
  onTranslate: () => void;
  onDismiss: () => void;
};

/**
 * Shown in a compose or reply screen when non-English text is detected.
 * Prompts the user to use Writing Tools to translate before posting.
 */
export function TranslationBanner({ onTranslate, onDismiss }: Props) {
  return (
    <View
      accessible={false}
      style={{
        backgroundColor: '#FFF8E1',
        borderRadius: 10,
        paddingHorizontal: 14,
        paddingVertical: 12,
        marginBottom: 12,
        gap: 10,
      }}
    >
      <Text
        accessible
        accessibilityRole="text"
        style={{ fontSize: 14, lineHeight: 20, color: '#856404' }}
      >
        Your message appears to be in another language. AppleVis is an English community — would you like to translate it before posting?
      </Text>

      <View style={{ flexDirection: 'row', gap: 10 }}>
        <Pressable
          onPress={onTranslate}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Translate with Writing Tools"
          accessibilityHint="Opens translation options for your message."
          style={{
            flex: 1, alignItems: 'center', backgroundColor: '#856404',
            borderRadius: 8, paddingVertical: 9,
          }}
        >
          <Text style={{ color: '#FFF', fontWeight: '700', fontSize: 14 }}>Translate</Text>
        </Pressable>

        <Pressable
          onPress={onDismiss}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Dismiss translation suggestion"
          style={{
            flex: 1, alignItems: 'center', backgroundColor: '#F3F4F6',
            borderRadius: 8, paddingVertical: 9,
          }}
        >
          <Text style={{ color: '#374151', fontWeight: '600', fontSize: 14 }}>Post as-is</Text>
        </Pressable>
      </View>
    </View>
  );
}
