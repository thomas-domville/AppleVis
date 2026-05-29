import { Text, View } from 'react-native';
import { styles } from '../theme/styles';

type Props = { title: string; meta: string; hint?: string; actions?: string[] };

export function AccessibleCard({ title, meta, hint = 'Double tap to open.', actions = [] }: Props) {
  return (
    <View
      accessible
      accessibilityRole="button"
      accessibilityLabel={`${title}. ${meta}`}
      accessibilityHint={hint}
      accessibilityActions={actions.map((name) => ({ name, label: name }))}
      onAccessibilityAction={() => {}}
      style={styles.card}
    >
      <Text style={styles.cardTitle}>{title}</Text>
      <Text style={styles.cardMeta}>{meta}</Text>
    </View>
  );
}
