import { useRef, useState } from 'react';
import { AccessibilityInfo, Animated, Modal, PanResponder, Pressable, Text, View } from 'react-native';
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

  const sheetY = useRef(new Animated.Value(0)).current;
  const pan = useRef(
    PanResponder.create({
      onMoveShouldSetPanResponder: (_, { dy, dx }) => dy > 8 && dy > Math.abs(dx),
      onPanResponderMove: (_, { dy }) => { if (dy > 0) sheetY.setValue(dy); },
      onPanResponderRelease: (_, { dy, vy }) => {
        if (dy > 80 || vy > 1.5) {
          Animated.timing(sheetY, { toValue: 600, duration: 200, useNativeDriver: true })
            .start(() => { sheetY.setValue(0); setOpen(false); });
        } else {
          Animated.spring(sheetY, { toValue: 0, useNativeDriver: true }).start();
        }
      },
      onPanResponderTerminate: () => {
        Animated.spring(sheetY, { toValue: 0, useNativeDriver: true }).start();
      },
    })
  ).current;

  const currentIdx = options.indexOf(value);

  function select(option: T) {
    onChange(option);
    setOpen(false);
  }

  function cycleBy(delta: 1 | -1) {
    const nextIdx = Math.max(0, Math.min(options.length - 1, currentIdx + delta));
    const next = options[nextIdx];
    if (next !== value) {
      onChange(next);
      AccessibilityInfo.announceForAccessibility(`${label}: ${next}`);
    }
  }

  return (
    <>
      {/*
        accessibilityRole="adjustable" lets VoiceOver users swipe up/down to
        cycle through options without opening the modal. Double-tap still opens
        the sheet so sighted users (and VoiceOver users who want to jump) can
        pick directly.
      */}
      <Pressable
        onPress={() => setOpen(true)}
        accessible
        accessibilityRole="adjustable"
        accessibilityLabel={label}
        accessibilityValue={{ text: value }}
        accessibilityHint="Swipe up or down to change. Double tap to see all options."
        onAccessibilityAction={({ nativeEvent }) => {
          if (nativeEvent.actionName === 'increment') cycleBy(1);
          if (nativeEvent.actionName === 'decrement') cycleBy(-1);
        }}
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

      {/* Options modal — for sighted users or VoiceOver users who want to jump */}
      <Modal
        visible={open}
        transparent
        animationType="slide"
        onRequestClose={() => setOpen(false)}
        accessibilityViewIsModal
      >
        <View style={{ flex: 1 }} onAccessibilityEscape={() => setOpen(false)}>
        <Pressable
          style={{ flex: 1, backgroundColor: 'rgba(0,0,0,0.45)' }}
          onPress={() => setOpen(false)}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Close filter picker"
        />

        <Animated.View
          {...pan.panHandlers}
          style={{
            backgroundColor: colors.card,
            borderTopLeftRadius: 20,
            borderTopRightRadius: 20,
            paddingTop: 8,
            paddingBottom: 40,
            paddingHorizontal: 0,
            transform: [{ translateY: sheetY }],
          }}
        >
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
                accessibilityLabel={option}
                accessibilityState={{ selected: isSelected }}
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
        </Animated.View>
        </View>
      </Modal>
    </>
  );
}
