import { Audio, InterruptionModeIOS } from 'expo-av';

// ─── Types ────────────────────────────────────────────────────────────────────

type SoundKey = 'refreshStart' | 'refreshComplete' | 'mouseSqueak' | 'appleCrunch' | 'goldenRetrieverBark' | 'welcome';

// ─── Asset map ────────────────────────────────────────────────────────────────

// open-section for "begin" (subtle ping), download-complete for "done".
// When the Sounds & Haptics setting is implemented, gate playback on
// persistence.getSetting('appSounds', true) here.
// React Native asset bundling requires require() — ES import is not supported
// for audio files resolved at runtime by the Metro bundler.
/* eslint-disable @typescript-eslint/no-require-imports */
const ASSETS: Record<SoundKey, number> = {
  refreshStart:         require('../../assets/sounds/open-section.wav'),
  refreshComplete:      require('../../assets/sounds/download-complete.wav'),
  mouseSqueak:          require('../../assets/sounds/Mouse Squeak.wav'),
  appleCrunch:          require('../../assets/sounds/Apple Crunch.wav'),
  goldenRetrieverBark:  require('../../assets/sounds/Golden Retriever Bark.wav'),
  welcome:              require('../../assets/sounds/welcome.wav'),
};
/* eslint-enable @typescript-eslint/no-require-imports */

// ─── Module-level cache ───────────────────────────────────────────────────────

const cache: Partial<Record<SoundKey, Audio.Sound>> = {};

// Keys that are played as standalone previews (not background music/podcasts).
// These temporarily claim the Playback audio session so they use media volume,
// not the ringer volume, which is often much lower.
const PREVIEW_KEYS = new Set<SoundKey>(['mouseSqueak', 'appleCrunch', 'goldenRetrieverBark', 'welcome']);

// Per-key volume overrides (0.0–1.0). Omitted keys default to 1.0.
// All user-facing sounds RMS-normalised to ~−26.6 dBFS (Apple Crunch reference at 1.0).
// Mouse Squeak: −2.15 dB trim; Bark: −19.2 dB trim; Welcome: −16.5 dB trim.
const VOLUMES: Partial<Record<SoundKey, number>> = {
  welcome:             0.15,
  refreshComplete:     0.4,
  mouseSqueak:         0.78,
  goldenRetrieverBark: 0.11,
};

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

    const volume = VOLUMES[key] ?? 1.0;
    if (!cache[key]) {
      const { sound } = await Audio.Sound.createAsync(ASSETS[key], { volume });
      cache[key] = sound;
    }
    await cache[key]!.setVolumeAsync(volume);
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
  mouseSqueak:         (): Promise<void> => play('mouseSqueak'),
  appleCrunch:         (): Promise<void> => play('appleCrunch'),
  goldenRetrieverBark: (): Promise<void> => play('goldenRetrieverBark'),
  welcome:             (): Promise<void> => play('welcome'),

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
