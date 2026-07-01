import { Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

export function SearchErrorState({ message }: { message: string }) {
  return (
    <View
      style={{
        flexDirection: 'row', gap: 8, alignItems: 'flex-start',
        backgroundColor: '#FFF8F0', borderRadius: 10, padding: 12, marginBottom: 10,
      }}
      accessible
      accessibilityLabel={message}
    >
      <Ionicons name="warning-outline" size={16} color="#C05000"
        accessibilityElementsHidden style={{ marginTop: 1 }} />
      <Text style={{ flex: 1, fontSize: 13, color: '#C05000', lineHeight: 18 }}>
        {message}
      </Text>
    </View>
  );
}
