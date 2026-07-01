import { forwardRef } from 'react';
import { AccessibilityInfo, findNodeHandle, Pressable, TextInput, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../contexts/ThemeContext';

type Props = {
  value: string;
  onChangeText: (text: string) => void;
  onClear: () => void;
  placeholder?: string;
};

/** Standardized search field used by both the Search tab and Discover's embedded search. */
export const AppleVisSearchInput = forwardRef<TextInput, Props>(function AppleVisSearchInput(
  { value, onChangeText, onClear, placeholder = 'Search topics, apps, guides…' },
  ref,
) {
  const { colors } = useTheme();

  function handleClear() {
    onClear();
    // Restore VoiceOver focus to the search field after clearing.
    setTimeout(() => {
      const node = (ref as React.RefObject<TextInput | null> | null)?.current;
      const handle = node ? findNodeHandle(node) : null;
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, 100);
  }

  return (
    <View style={{
      flexDirection: 'row', alignItems: 'center',
      backgroundColor: colors.inputBackground,
      borderRadius: 12, borderWidth: 1, borderColor: colors.border,
      paddingHorizontal: 12, paddingVertical: 10, marginBottom: 4,
    }}>
      <Ionicons name="search" size={17} color={colors.textSecondary}
        style={{ marginRight: 8 }} accessibilityElementsHidden />
      <TextInput
        ref={ref}
        value={value}
        onChangeText={onChangeText}
        placeholder={placeholder}
        placeholderTextColor={colors.textSecondary}
        style={{ flex: 1, fontSize: 16, color: colors.text }}
        accessible
        accessibilityRole="search"
        accessibilityLabel="Search AppleVis"
        accessibilityHint="Type to search forum topics, apps, and guides"
        returnKeyType="search"
        clearButtonMode="while-editing"
        onSubmitEditing={(e) => onChangeText(e.nativeEvent.text)}
      />
      {value.length > 0 && (
        <Pressable
          onPress={handleClear}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Clear search"
          style={{ padding: 4 }}
        >
          <Ionicons name="close-circle" size={18} color={colors.textSecondary} />
        </Pressable>
      )}
    </View>
  );
});
