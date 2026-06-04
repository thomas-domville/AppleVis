import { Audio, InterruptionModeIOS } from 'expo-av';

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

// Keys that are played as standalone previews (not background music/podcasts).
// These temporarily claim the Playback audio session so they use media volume,
// not the ringer volume, which is often much lower.
const PREVIEW_KEYS = new Set<SoundKey>(['mouseSqueak', 'appleCrunch']);

async function play(key: SoundKey): Promise<void> {
  try {
    const isPreview = PREVIEW_KEYS.has(key);

    if (isPreview) {
      await Audio.setAudioModeAsync({
        playsInSilentModeIOS: true,
        interruptionModeIOS: InterruptionModeIOS.DoNotMix,
        shouldDuckAndroid: false,
        staysActiveInBackground: false,
      });
    }

    if (!cache[key]) {
      const { sound } = await Audio.Sound.createAsync(ASSETS[key], { volume: 1.0 });
      cache[key] = sound;
    }
    await cache[key]!.setVolumeAsync(1.0);
    await cache[key]!.setPositionAsync(0);
    await cache[key]!.playAsync();

    if (isPreview) {
      // Restore ambient mode after the clip finishes so the podcast player
      // isn't affected. 3 s covers the longest preview clip with headroom.
      setTimeout(async () => {
        try {
          await Audio.setAudioModeAsync({
            playsInSilentModeIOS: false,
            interruptionModeIOS: InterruptionModeIOS.MixWithOthers,
            shouldDuckAndroid: true,
            staysActiveInBackground: false,
          });
        } catch (_e) { /* non-critical */ }
      }, 3000);
    }
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
