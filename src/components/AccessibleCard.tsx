import { AccessibilityActionEvent, Text, View } from 'react-native';
import { styles } from '../theme/styles';

type Props = { title: string; meta: string; hint?: string; actions?: string[]; onAction?: (actionName: string) => void };

export function AccessibleCard({ title, meta, hint = 'Double tap to open.', actions = [], onAction }: Props) {
  function handleAccessibilityAction(event: AccessibilityActionEvent) {
    onAction?.(event.nativeEvent.actionName);
  }

  return (
    <View
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
}
