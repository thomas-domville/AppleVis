import AsyncStorage from '@react-native-async-storage/async-storage';

const KEY = '@applevis_onboarding_complete';

export const onboarding = {
  async isComplete(): Promise<boolean> {
    const val = await AsyncStorage.getItem(KEY);
    return val === 'true';
  },

  async markComplete(): Promise<void> {
    await AsyncStorage.setItem(KEY, 'true');
  },

  /** For testing — resets onboarding so the wizard shows again on next launch. */
  async reset(): Promise<void> {
    await AsyncStorage.removeItem(KEY);
  },
};
