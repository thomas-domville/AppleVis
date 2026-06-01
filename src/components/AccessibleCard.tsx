import { forwardRef } from 'react';
import { AccessibilityActionEvent, ActionSheetIOS, Platform, Pressable, Text, View } from 'react-native';
import { styles } from '../theme/styles';

type Props = {
  title: string;
  meta: string;
  hint?: string;
  actions?: string[];
  onAction?: (actionName: string) => void;
};

/**
 * forwardRef allows parent screens to hold a ref to the underlying View,
 * which is needed by useFocusRestore to return VoiceOver focus after
 * a child screen is dismissed.
 *
 * Long-pressing the card shows the same actions as the VoiceOver custom-action
 * rotor in a native iOS contextual action sheet (UIContextMenuInteraction
 * equivalent for React Native).
 */
export const AccessibleCard = forwardRef<View, Props>(
  function AccessibleCard({ title, meta, hint = 'Double tap to open.', actions = [], onAction }, ref) {
    function handleAccessibilityAction(event: AccessibilityActionEvent) {
      onAction?.(event.nativeEvent.actionName);
    }

    function handleLongPress() {
      if (actions.length === 0 || !onAction) return;

      if (Platform.OS === 'ios') {
        ActionSheetIOS.showActionSheetWithOptions(
          {
            title,
            options: ['Cancel', ...actions],
            cancelButtonIndex: 0,
          },
          (buttonIndex) => {
            if (buttonIndex === 0) return;
            onAction(actions[buttonIndex - 1]);
          },
        );
      }
    }

    return (
      <Pressable
        ref={ref}
        accessible
        accessibilityRole="button"
        accessibilityLabel={`${title}. ${meta}`}
        accessibilityHint={hint}
        accessibilityActions={actions.map((name) => ({ name, label: name }))}
        onAccessibilityAction={handleAccessibilityAction}
        onPress={() => onAction?.('Open')}
        onLongPress={handleLongPress}
        delayLongPress={500}
        style={({ pressed }) => [
          styles.card,
          pressed && { opacity: 0.85 },
        ]}
      >
        <Text style={styles.cardTitle}>{title}</Text>
        <Text style={styles.cardMeta}>{meta}</Text>
      </Pressable>
    );
  },
);
