import { Text, View } from 'react-native';

/**
 * Shown near compose / reply text fields.
 * Writing Tools are built into every iOS 18+ TextInput for free —
 * this just makes sure users know they are there.
 */
export function WritingToolsTip() {
  return (
    <View
      accessible
      accessibilityRole="text"
      accessibilityLabel="Apple Intelligence tip: select any text you type to proofread, rewrite, shorten, or translate it using Writing Tools."
      style={{
        flexDirection: 'row',
        alignItems: 'flex-start',
        gap: 8,
        backgroundColor: '#EEF4FF',
        borderRadius: 10,
        paddingHorizontal: 14,
        paddingVertical: 10,
        marginBottom: 12,
      }}
    >
      <Text style={{ fontSize: 16 }} importantForAccessibility="no">✦</Text>
      <Text style={{ flex: 1, fontSize: 14, lineHeight: 20, color: '#1D4ED8' }}>
        <Text style={{ fontWeight: '700' }}>Apple Intelligence: </Text>
        select text you type to proofread, rewrite, or translate using Writing Tools.
      </Text>
    </View>
  );
}
