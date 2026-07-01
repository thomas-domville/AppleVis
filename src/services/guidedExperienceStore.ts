import AsyncStorage from '@react-native-async-storage/async-storage';
import type { GuidedExperienceProgress } from '../guidedExperience/types';

const KEY_PREFIX = '@applevis_guided_experience_';

const DEFAULT_PROGRESS: GuidedExperienceProgress = {
  completed: false,
  skipped: false,
  dismissed: false,
  lastStepIndex: 0,
  replayCount: 0,
};

export const guidedExperienceStore = {
  async getProgress(experienceId: string): Promise<GuidedExperienceProgress> {
    try {
      const raw = await AsyncStorage.getItem(KEY_PREFIX + experienceId);
      if (!raw) return { ...DEFAULT_PROGRESS };
      return { ...DEFAULT_PROGRESS, ...(JSON.parse(raw) as Partial<GuidedExperienceProgress>) };
    } catch {
      return { ...DEFAULT_PROGRESS };
    }
  },

  async saveProgress(experienceId: string, progress: GuidedExperienceProgress): Promise<void> {
    await AsyncStorage.setItem(KEY_PREFIX + experienceId, JSON.stringify(progress)).catch(() => {});
  },

  async markStep(experienceId: string, stepIndex: number): Promise<void> {
    const current = await guidedExperienceStore.getProgress(experienceId);
    await guidedExperienceStore.saveProgress(experienceId, { ...current, lastStepIndex: stepIndex });
  },

  async markCompleted(experienceId: string): Promise<void> {
    const current = await guidedExperienceStore.getProgress(experienceId);
    await guidedExperienceStore.saveProgress(experienceId, {
      ...current, completed: true, dismissed: false, lastStepIndex: 0,
    });
  },

  async markSkipped(experienceId: string): Promise<void> {
    const current = await guidedExperienceStore.getProgress(experienceId);
    await guidedExperienceStore.saveProgress(experienceId, { ...current, skipped: true });
  },

  /** Called when the user pauses via Explore This Screen without finishing or skipping. */
  async markDismissedForNow(experienceId: string, stepIndex: number): Promise<void> {
    const current = await guidedExperienceStore.getProgress(experienceId);
    await guidedExperienceStore.saveProgress(experienceId, { ...current, dismissed: true, lastStepIndex: stepIndex });
  },

  /** Resets progress so the experience starts from step 0 again (Replay). */
  async restart(experienceId: string): Promise<void> {
    const current = await guidedExperienceStore.getProgress(experienceId);
    await guidedExperienceStore.saveProgress(experienceId, {
      ...current,
      completed: false,
      skipped: false,
      dismissed: false,
      lastStepIndex: 0,
      replayCount: current.replayCount + 1,
    });
  },

  /** For testing/Reset Tips-style entry points. */
  async reset(experienceId: string): Promise<void> {
    await AsyncStorage.removeItem(KEY_PREFIX + experienceId);
  },
};
