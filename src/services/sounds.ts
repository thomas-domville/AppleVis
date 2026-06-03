import { Audio } from 'expo-av';

// ─── Types ────────────────────────────────────────────────────────────────────

type SoundKey = 'refreshStart' | 'refreshComplete' | 'mouseSqueak' | 'appleCrunch';

// ─── Asset map ────────────────────────────────────────────────────────────────

// open-section for "begin" (subtle ping), download-complete for "done".
// When the Sounds & Haptics setting is implemented, gate playback on
// persistence.getSetting('appSounds', true) here.
// React Native asset bundling requires require() — ES import is not supported
// for audio files resolved at runtime by the Metro bundler.
/* eslint-disable @typescript-eslint/no-require-imports */
const ASSETS: Record<SoundKey, number> = {
  refreshStart:    require('../../assets/sounds/open-section.wav'),
  refreshComplete: require('../../assets/sounds/download-complete.wav'),
  mouseSqueak:     require('../../assets/sounds/Mouse Squeak.wav'),
  appleCrunch:     require('../../assets/sounds/Apple Crunch.wav'),
};
/* eslint-enable @typescript-eslint/no-require-imports */

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
  } catch (_e) { /* non-critical */ }
}

// ─── Public API ───────────────────────────────────────────────────────────────

export const sounds = {
  refreshStart:    (): Promise<void> => play('refreshStart'),
  refreshComplete: (): Promise<void> => play('refreshComplete'),
  mouseSqueak:     (): Promise<void> => play('mouseSqueak'),
  appleCrunch:     (): Promise<void> => play('appleCrunch'),

  // Call once on app start so first-play has no loading delay.
  // Loads audio into cache without playing it.
  async preload(): Promise<void> {
    await Promise.allSettled(
      (Object.keys(ASSETS) as SoundKey[]).map(async (key) => {
        if (!cache[key]) {
          const { sound } = await Audio.Sound.createAsync(ASSETS[key], { shouldPlay: false });
          cache[key] = sound;
        }
      }),
    );
  },
};
