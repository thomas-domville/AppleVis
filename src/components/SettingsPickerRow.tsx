import { useState } from 'react';
import { Modal, Pressable, ScrollView, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../contexts/ThemeContext';

type Props<T extends string | number> = {
  label: string;
  description: string;
  value: T;
  options: { value: T; label: string }[];
  onSelect: (v: T) => void;
};

export function SettingsPickerRow<T extends string | number>({
  label, description, value, options, onSelect,
}: Props<T>) {
  const { colors, styles } = useTheme();
  const [open, setOpen] = useState(false);
  const currentLabel = options.find(o => o.value === value)?.label ?? String(value);

  return (
    <>
      <Pressable
        onPress={() => setOpen(true)}
        accessible
        accessibilityRole="button"
        accessibilityLabel={`${label}: ${currentLabel}. ${description}. Double tap to change.`}
        style={[styles.cardSmall, { flexDirection: 'row', alignItems: 'center', gap: 12 }]}
      >
        <View style={{ flex: 1 }}>
          <Text style={{ fontSize: 16, fontWeight: '600', color: colors.text }}>{label}</Text>
          <Text style={{ fontSize: 13, color: colors.textSecondary, marginTop: 2, lineHeight: 18 }}>
            {description}
          </Text>
        </View>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
          <Text style={{ fontSize: 15, color: colors.accent, fontWeight: '600' }}>{currentLabel}</Text>
          <Ionicons name="chevron-forward" size={16} color={colors.textSecondary} accessibilityElementsHidden />
        </View>
      </Pressable>

      <Modal
        visible={open}
        transparent
        animationType="slide"
        onRequestClose={() => setOpen(false)}
        accessibilityViewIsModal
      >
        <Pressable
          style={{ flex: 1, backgroundColor: 'rgba(0,0,0,0.45)' }}
          onPress={() => setOpen(false)}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Dismiss picker"
        />
        <View style={{
          backgroundColor: colors.card,
          borderTopLeftRadius: 22, borderTopRightRadius: 22,
          borderTopWidth: 1, borderTopColor: colors.border,
          maxHeight: '70%',
        }}>
          {/* Handle + header */}
          <View style={{ alignItems: 'center', paddingTop: 10, paddingBottom: 4 }}>
            <View style={{ width: 36, height: 4, borderRadius: 2, backgroundColor: colors.border }} />
          </View>
          <View style={{
            flexDirection: 'row', alignItems: 'center',
            paddingHorizontal: 20, paddingBottom: 12,
            borderBottomWidth: 1, borderBottomColor: colors.border,
          }}>
            <Text style={{ flex: 1, fontSize: 17, fontWeight: '700', color: colors.text }}
              accessibilityRole="header">{label}</Text>
            <Pressable
              onPress={() => setOpen(false)}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Close"
              hitSlop={10}
            >
              <Ionicons name="close-circle" size={28} color={colors.textSecondary} />
            </Pressable>
          </View>

          {/* Option list */}
          <ScrollView showsVerticalScrollIndicator={false}>
            {options.map((opt) => {
              const isSelected = opt.value === value;
              return (
                <Pressable
                  key={String(opt.value)}
                  onPress={() => { onSelect(opt.value); setOpen(false); }}
                  accessible
                  accessibilityRole="menuitem"
                  accessibilityState={{ selected: isSelected }}
                  accessibilityLabel={`${opt.label}${isSelected ? ', currently selected' : ''}`}
                  style={({ pressed }) => ({
                    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
                    paddingHorizontal: 22, paddingVertical: 15,
                    borderBottomWidth: 1, borderBottomColor: colors.border,
                    backgroundColor: pressed ? colors.pill : 'transparent',
                  })}
                >
                  <Text style={{
                    fontSize: 17,
                    color: isSelected ? colors.accent : colors.text,
                    fontWeight: isSelected ? '700' : '400',
                  }}>
                    {opt.label}
                  </Text>
                  {isSelected && (
                    <Ionicons name="checkmark" size={20} color={colors.accent} accessibilityElementsHidden />
                  )}
                </Pressable>
              );
            })}
            <View style={{ height: 40 }} />
          </ScrollView>
        </View>
      </Modal>
    </>
  );
}
