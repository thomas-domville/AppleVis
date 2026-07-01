import { Pressable, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '../../contexts/ThemeContext';
import { useGuidedExperiencePause } from '../../contexts/GuidedExperienceContext';

/**
 * Small floating affordance shown app-wide while a guided experience is paused
 * for "Explore This Screen." Mounted once near the root layout.
 */
export function GuidedExperienceResumePrompt() {
  const { paused, clearPaused } = useGuidedExperiencePause();
  const { colors } = useTheme();
  const router = useRouter();
  const insets = useSafeAreaInsets();

  if (!paused) return null;

  return (
    <View
      pointerEvents="box-none"
      style={{ position: 'absolute', left: 0, right: 0, bottom: insets.bottom + 76, alignItems: 'center' }}
    >
      <View style={{
        flexDirection: 'row', alignItems: 'center', gap: 2,
        backgroundColor: colors.accent, borderRadius: 24,
        paddingLeft: 18, paddingRight: 8, paddingVertical: 8,
        shadowColor: '#000', shadowOpacity: 0.25, shadowRadius: 10, shadowOffset: { width: 0, height: 4 },
      }}>
        <Pressable
          onPress={() => router.push({ pathname: '/guided-experience/[experienceId]', params: { experienceId: paused.experienceId } } as any)}
          accessible
          accessibilityRole="button"
          accessibilityLabel={`Resume Tour: ${paused.experienceTitle}`}
          accessibilityHint="Returns to the guided tour where you left off."
          style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', gap: 8, paddingVertical: 4, opacity: pressed ? 0.7 : 1 })}
        >
          <Ionicons name="play-circle" size={18} color={colors.accentText} accessibilityElementsHidden />
          <Text style={{ color: colors.accentText, fontWeight: '700', fontSize: 14 }}>Resume Tour</Text>
        </Pressable>
        <Pressable
          onPress={clearPaused}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Dismiss Resume Tour"
          hitSlop={10}
          style={{ padding: 8 }}
        >
          <Ionicons name="close" size={16} color={colors.accentText} />
        </Pressable>
      </View>
    </View>
  );
}
