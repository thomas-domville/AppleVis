import { Audio } from 'expo-av';

// ─── Types ────────────────────────────────────────────────────────────────────

type SoundKey = 'refreshStart' | 'refreshComplete';

// ─── Asset map ────────────────────────────────────────────────────────────────

// open-section for "begin" (subtle ping), download-complete for "done".
// When the Sounds & Haptics setting is implemented, gate playback on
// persistence.getSetting('appSounds', true) here.
const ASSETS: Record<SoundKey, ReturnType<typeof require>> = {
  refreshStart:    require('../../assets/sounds/open-section.wav'),
  refreshComplete: require('../../assets/sounds/download-complete.wav'),
};

// ─── Module-level cache ───────────────────────────────────────────────────────

const cache: Partial<Record<SoundKey, Audio.Sound>> = {};

async function play(key: SoundKey): Promise<void> {
  try {
    if (!cache[key]) {
      const { sound } = await Audio.Sound.createAsync(ASSETS[key]);
      cache[key] = sound;
    }
    // Rewind to start so rapid successive calls work correctly.
    await cache[key]!.setPositionAsync(0);
    await cache[key]!.playAsync();
  } catch {}
}

// ─── Public API ───────────────────────────────────────────────────────────────

export const sounds = {
  refreshStart:    (): Promise<void> => play('refreshStart'),
  refreshComplete: (): Promise<void> => play('refreshComplete'),

  // Call once on app start so first-play has no loading delay.
  async preload(): Promise<void> {
    await Promise.allSettled(
      (Object.keys(ASSETS) as SoundKey[]).map((key) => play(key)),
    );
  },
};
