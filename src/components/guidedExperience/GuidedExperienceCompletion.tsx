import { Pressable, Text, View } from 'react-native';
import { useTheme } from '../../contexts/ThemeContext';
import type { GuidedExperienceCompletionAction } from '../../guidedExperience/types';

type Props = {
  actions: GuidedExperienceCompletionAction[];
  onFinish: () => void;
  onOpenHelp: () => void;
  onReplay: () => void;
  onRoute: (route: string) => void;
};

export function GuidedExperienceCompletion({ actions, onFinish, onOpenHelp, onReplay, onRoute }: Props) {
  const { colors } = useTheme();

  function handlePress(action: GuidedExperienceCompletionAction) {
    switch (action.kind) {
      case 'finish':  onFinish(); break;
      case 'openHelp': onOpenHelp(); break;
      case 'replay':  onReplay(); break;
      case 'route':   if (action.route) onRoute(action.route); break;
    }
  }

  return (
    <View style={{ gap: 12 }}>
      {actions.map((action, i) => (
        <Pressable
          key={i}
          onPress={() => handlePress(action)}
          accessible
          accessibilityRole="button"
          accessibilityLabel={action.label}
          style={({ pressed }) => [
            i === 0
              ? { backgroundColor: colors.accent }
              : { backgroundColor: 'transparent', borderWidth: 1.5, borderColor: colors.border },
            { borderRadius: 14, paddingVertical: 16, alignItems: 'center', opacity: pressed ? 0.8 : 1 },
          ]}
        >
          <Text style={{
            color: i === 0 ? colors.accentText : colors.text,
            fontWeight: '700', fontSize: 17,
          }}>
            {action.label}
          </Text>
        </Pressable>
      ))}
    </View>
  );
}
