import { forwardRef } from 'react';
import { AccessibilityActionEvent, Text, View } from 'react-native';
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
 */
export const AccessibleCard = forwardRef<View, Props>(
  function AccessibleCard({ title, meta, hint = 'Double tap to open.', actions = [], onAction }, ref) {
    function handleAccessibilityAction(event: AccessibilityActionEvent) {
      onAction?.(event.nativeEvent.actionName);
    }

    return (
      <View
        ref={ref}
        accessible
        accessibilityRole="button"
        accessibilityLabel={`${title}. ${meta}`}
        accessibilityHint={hint}
        accessibilityActions={actions.map((name) => ({ name, label: name }))}
        onAccessibilityAction={handleAccessibilityAction}
        style={styles.card}
      >
        <Text style={styles.cardTitle}>{title}</Text>
        <Text style={styles.cardMeta}>{meta}</Text>
      </View>
    );
  },
);
