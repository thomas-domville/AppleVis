import { Audio, InterruptionModeIOS } from 'expo-av';

type SoundKey =
  | 'tabChange'
  | 'articleOpen'
  | 'screenClose'
  | 'pickerTick'
  | 'downloadComplete'
  | 'podcastPlay'
  | 'podcastPause'
  | 'refresh'
  | 'success'
  | 'error'
  | 'reply'
  | 'tipPopup'
  | 'bookmarkSaved'
  | 'searchComplete'
  | 'syncComplete'
  | 'offline'
  | 'loadingStart'
  | 'mouseSqueak'
  | 'appleCrunch'
  | 'goldenRetrieverBark'
  | 'welcome';

// React Native asset bundling requires static require() calls for audio files.
/* eslint-disable @typescript-eslint/no-require-imports */
const ASSETS: Record<SoundKey, number> = {
  tabChange:           require('../../assets/sounds/tab_change.wav'),
  articleOpen:         require('../../assets/sounds/article_open.wav'),
  screenClose:         require('../../assets/sounds/screen_close.wav'),
  pickerTick:          require('../../assets/sounds/picker_tick.wav'),
  downloadComplete:    require('../../assets/sounds/download_complete.wav'),
  podcastPlay:         require('../../assets/sounds/podcast_play.wav'),
  podcastPause:        require('../../assets/sounds/podcast_pause.wav'),
  refresh:             require('../../assets/sounds/refresh.wav'),
  success:             require('../../assets/sounds/success.wav'),
  error:               require('../../assets/sounds/error.wav'),
  reply:               require('../../assets/sounds/reply.wav'),
  tipPopup:            require('../../assets/sounds/tip_popup.wav'),
  bookmarkSaved:       require('../../assets/sounds/bookmark_saved.wav'),
  searchComplete:      require('../../assets/sounds/search_complete.wav'),
  syncComplete:        require('../../assets/sounds/sync_complete.wav'),
  offline:             require('../../assets/sounds/offline.wav'),
  loadingStart:        require('../../assets/sounds/loading_start.wav'),
  mouseSqueak:         require('../../assets/sounds/Mouse Squeak.wav'),
  appleCrunch:         require('../../assets/sounds/Apple Crunch.wav'),
  goldenRetrieverBark: require('../../assets/sounds/Golden Retriever Bark.wav'),
  welcome:             require('../../assets/sounds/welcome.wav'),
};
/* eslint-enable @typescript-eslint/no-require-imports */

const cache: Partial<Record<SoundKey, Audio.Sound>> = {};

// Preview sounds temporarily claim the playback session so users hear them at
// media volume. Short UI event sounds stay ambient and non-disruptive.
const PREVIEW_KEYS = new Set<SoundKey>([
  'mouseSqueak',
  'appleCrunch',
  'goldenRetrieverBark',
  'welcome',
]);

const EVENT_VOLUME = 0.7;
const VOLUMES: Partial<Record<SoundKey, number>> = {
  tabChange:           EVENT_VOLUME,
  articleOpen:         EVENT_VOLUME,
  screenClose:         EVENT_VOLUME,
  pickerTick:          EVENT_VOLUME,
  downloadComplete:    EVENT_VOLUME,
  podcastPlay:         EVENT_VOLUME,
  podcastPause:        EVENT_VOLUME,
  refresh:             EVENT_VOLUME,
  success:             EVENT_VOLUME,
  error:               EVENT_VOLUME,
  reply:               EVENT_VOLUME,
  tipPopup:            EVENT_VOLUME,
  bookmarkSaved:       EVENT_VOLUME,
  searchComplete:      EVENT_VOLUME,
  syncComplete:        EVENT_VOLUME,
  offline:             EVENT_VOLUME,
  loadingStart:        EVENT_VOLUME,
  welcome:             0.15,
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
      setTimeout(async () => {
        try {
          await Audio.setAudioModeAsync({
            playsInSilentModeIOS: false,
            interruptionModeIOS: InterruptionModeIOS.MixWithOthers,
            shouldDuckAndroid: true,
            staysActiveInBackground: false,
          });
        } catch (_e) {
          // Non-critical: future playback calls reset the audio mode if needed.
        }
      }, 3000);
    }
  } catch (_e) {
    // UI sounds should never block the action that triggered them.
  }
}

export const sounds = {
  tabChange:        (): Promise<void> => play('tabChange'),
  articleOpen:      (): Promise<void> => play('articleOpen'),
  screenClose:      (): Promise<void> => play('screenClose'),
  pickerTick:       (): Promise<void> => play('pickerTick'),
  downloadComplete: (): Promise<void> => play('downloadComplete'),
  podcastPlay:      (): Promise<void> => play('podcastPlay'),
  podcastPause:     (): Promise<void> => play('podcastPause'),
  refresh:          (): Promise<void> => play('refresh'),
  success:          (): Promise<void> => play('success'),
  error:            (): Promise<void> => play('error'),
  reply:            (): Promise<void> => play('reply'),
  tipPopup:         (): Promise<void> => play('tipPopup'),
  bookmarkSaved:    (): Promise<void> => play('bookmarkSaved'),
  searchComplete:   (): Promise<void> => play('searchComplete'),
  syncComplete:     (): Promise<void> => play('syncComplete'),
  offline:          (): Promise<void> => play('offline'),
  loadingStart:     (): Promise<void> => play('loadingStart'),

  // Backward-compatible names used by existing refresh hooks.
  refreshStart:     (): Promise<void> => play('refresh'),
  refreshComplete:  (): Promise<void> => play('success'),

  mouseSqueak:         (): Promise<void> => play('mouseSqueak'),
  appleCrunch:         (): Promise<void> => play('appleCrunch'),
  goldenRetrieverBark: (): Promise<void> => play('goldenRetrieverBark'),
  welcome:             (): Promise<void> => play('welcome'),

  async preload(): Promise<void> {
    await Promise.allSettled(
      (Object.keys(ASSETS) as SoundKey[]).map(async (key) => {
        if (!cache[key]) {
          const volume = VOLUMES[key] ?? 1.0;
          const { sound } = await Audio.Sound.createAsync(ASSETS[key], { shouldPlay: false, volume });
          cache[key] = sound;
        }
      }),
    );
  },
};
