import AsyncStorage from '@react-native-async-storage/async-storage';

const AUTO_PROMPT_KEY = '@applevis_welcome_tour_auto_prompt';

/**
 * Whether the post-setup "Take a Quick Tour?" prompt should still offer to
 * start the welcome guided experience automatically. Whether the tour itself
 * has been completed/skipped is tracked separately, per-experience, by
 * guidedExperienceStore (src/services/guidedExperienceStore.ts) — this file
 * only owns the "don't ask me automatically again" opt-out.
 */
export const tour = {
  async autoPromptEnabled(): Promise<boolean> {
    const val = await AsyncStorage.getItem(AUTO_PROMPT_KEY);
    return val !== 'false';
  },

  async disableAutoPrompt(): Promise<void> {
    await AsyncStorage.setItem(AUTO_PROMPT_KEY, 'false');
  },

  /** For testing — lets the auto-prompt show again. */
  async reset(): Promise<void> {
    await AsyncStorage.removeItem(AUTO_PROMPT_KEY);
  },
};
