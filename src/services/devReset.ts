import AsyncStorage from '@react-native-async-storage/async-storage';
import { icloudStorage } from './icloudStorage';

function isAppleVisKey(key: string): boolean {
  return (
    key.startsWith('@applevis') ||
    key.startsWith('applevis:') ||
    key === 'i18nextLng'
  );
}

export async function resetAppStateForDevelopment(): Promise<void> {
  if (process.env.EXPO_PUBLIC_RESET_APP_STATE !== 'true') return;

  const [localKeys, cloudKeys] = await Promise.all([
    AsyncStorage.getAllKeys().catch(() => [] as string[]),
    icloudStorage.getAllKeys(),
  ]);

  const localAppleVisKeys = localKeys.filter(isAppleVisKey);
  const cloudAppleVisKeys = cloudKeys.filter(isAppleVisKey);

  await Promise.all([
    localAppleVisKeys.length > 0 ? AsyncStorage.multiRemove(localAppleVisKeys) : Promise.resolve(),
    ...cloudAppleVisKeys.map((key) => icloudStorage.remove(key)),
  ]);
}
