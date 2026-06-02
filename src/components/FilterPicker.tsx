import { useState } from 'react';
import { Modal, Pressable, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../contexts/ThemeContext';

type Props<T extends string> = {
  label: string;
  value: T;
  options: readonly T[];
  onChange: (value: T) => void;
};

export function FilterPicker<T extends string>({ label, value, options, onChange }: Props<T>) {
  const [open, setOpen] = useState(false);
  const { colors } = useTheme();

  function select(option: T) {
    onChange(option);
    setOpen(false);
  }

  return (
    <>
      {/* Trigger button */}
      <Pressable
        onPress={() => setOpen(true)}
        accessibilityRole="combobox"
        accessibilityLabel={`${label}: ${value}`}
        accessibilityHint="Double tap to change filter"
        accessibilityState={{ expanded: open }}
        style={{
          flexDirection: 'row',
          alignItems: 'center',
          gap: 6,
          alignSelf: 'flex-start',
          backgroundColor: colors.inputBackground,
          borderWidth: 1,
          borderColor: colors.border,
          borderRadius: 10,
          paddingHorizontal: 12,
          paddingVertical: 9,
          marginBottom: 12,
        }}
      >
        <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>{value}</Text>
        <Ionicons
          name={open ? 'chevron-up' : 'chevron-down'}
          size={14}
          color={colors.textSecondary}
          accessibilityElementsHidden
        />
      </Pressable>

      {/* Options modal */}
      <Modal
        visible={open}
        transparent
        animationType="slide"
        onRequestClose={() => setOpen(false)}
        accessibilityViewIsModal
      >
        {/* Backdrop — tap to dismiss */}
        <Pressable
          style={{ flex: 1, backgroundColor: 'rgba(0,0,0,0.45)' }}
          onPress={() => setOpen(false)}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Close filter picker"
        />

        {/* Sheet */}
        <View
          style={{
            backgroundColor: colors.card,
            borderTopLeftRadius: 20,
            borderTopRightRadius: 20,
            paddingTop: 8,
            paddingBottom: 40,
            paddingHorizontal: 0,
          }}
        >
          {/* Handle */}
          <View
            style={{ width: 36, height: 4, borderRadius: 2, backgroundColor: colors.border, alignSelf: 'center', marginBottom: 12 }}
            accessible={false}
          />

          <Text
            accessibilityRole="header"
            style={{
              fontSize: 17, fontWeight: '700', color: colors.text,
              paddingHorizontal: 20, marginBottom: 8,
            }}
          >
            {label}
          </Text>

          {options.map((option) => {
            const isSelected = option === value;
            return (
              <Pressable
                key={option}
                onPress={() => select(option)}
                accessibilityRole="button"
                accessibilityLabel={isSelected ? `${option}, selected` : option}
                style={({ pressed }) => ({
                  flexDirection: 'row',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  paddingHorizontal: 20,
                  paddingVertical: 15,
                  backgroundColor: pressed ? colors.inputBackground : 'transparent',
                })}
              >
                <Text
                  style={{
                    fontSize: 17,
                    color: isSelected ? colors.accent : colors.text,
                    fontWeight: isSelected ? '600' : '400',
                  }}
                >
                  {option}
                </Text>
                {isSelected && (
                  <Ionicons name="checkmark" size={20} color={colors.accent} accessibilityElementsHidden />
                )}
              </Pressable>
            );
          })}
        </View>
      </Modal>
    </>
  );
}
