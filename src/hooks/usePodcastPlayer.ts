import { Audio, AVPlaybackStatus } from 'expo-av';
import { AccessibilityInfo, AppState, Platform } from 'react-native';
import { useCallback, useEffect, useRef, useState } from 'react';
import type { PodcastEpisode, Chapter } from '../types/content';
import { persistence } from '../services/persistence';
import { getLocalUri } from '../services/downloads';
import { usePreferences } from '../contexts/PreferencesContext';
import {
  updateNowPlayingInfo, clearNowPlayingInfo,
  setupRemoteCommands, setVoiceBoostEnabled, setTrimSilenceEnabled,
} from '../native/nativeModules';

export type PlaybackSpeed = 0.5 | 0.75 | 1.0 | 1.25 | 1.5 | 1.75 | 2.0 | 2.5 | 3.0;
export const SPEED_OPTIONS: PlaybackSpeed[] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0];
export const SLEEP_TIMER_OPTIONS = [15, 30, 45, 60, 90] as const;
// Sentinel value meaning "stop at end of this episode"
export const SLEEP_END_OF_EPISODE = -1 as const;

export interface PlayerState {
  episode: PodcastEpisode | null;
  isPlaying: boolean;
  isLoading: boolean;
  isBuffering: boolean;
  position: number;
  duration: number;
  speed: PlaybackSpeed;
  skipBackSeconds: number;
  skipForwardSeconds: number;
  volume: number;
  sleepTimerRemaining: number | null;
  sleepAtEndOfEpisode: boolean;
  queue: PodcastEpisode[];
  currentChapter: Chapter | null;
  error: string | null;
}

const DEFAULT: PlayerState = {
  episode: null,
  isPlaying: false,
  isLoading: false,
  isBuffering: false,
  position: 0,
  duration: 0,
  speed: 1.0,
  skipBackSeconds: 15,
  skipForwardSeconds: 30,
  volume: 1.0,
  sleepTimerRemaining: null,
  sleepAtEndOfEpisode: false,
  queue: [],
  currentChapter: null,
  error: null,
};

function resolveChapter(episode: PodcastEpisode | null, positionSeconds: number): Chapter | null {
  if (!episode?.chapters?.length) return null;
  for (let i = episode.chapters.length - 1; i >= 0; i--) {
    if (positionSeconds >= episode.chapters[i].startTime) return episode.chapters[i];
  }
  return episode.chapters[0] ?? null;
}

export function usePodcastPlayer() {
  const soundRef = useRef<Audio.Sound | null>(null);
  const sleepRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const nowPlayingTickRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const queueLoadedRef = useRef(false);
  const episodeRef    = useRef<PodcastEpisode | null>(null);
  const volumeRef     = useRef(1.0);
  const [state, setState] = useState<PlayerState>(DEFAULT);
  const {
    podcastAutoPlay, podcastSleepTimer, podcastSpeed, setPodcastSpeed,
    podcastSkipBack, podcastSkipForward, podcastResumeRewind,
    podcastVoiceBoost, podcastTrimSilence,
  } = usePreferences();

  const patch = useCallback((updates: Partial<PlayerState>) => {
    setState((prev) => ({ ...prev, ...updates }));
  }, []);

  // Stable ref so remote command callbacks never go stale.
  const actionsRef = useRef({
    play: () => soundRef.current?.playAsync(),
    pause: async () => {
      await soundRef.current?.pauseAsync();
    },
    skipBack: async () => {
      const s = await soundRef.current?.getStatusAsync();
      if (s?.isLoaded) {
        await soundRef.current?.setPositionAsync(Math.max(0, s.positionMillis - state.skipBackSeconds * 1000));
      }
    },
    skipForward: async () => {
      const s = await soundRef.current?.getStatusAsync();
      if (s?.isLoaded) {
        const dur = s.durationMillis ?? 0;
        await soundRef.current?.setPositionAsync(Math.min(dur, s.positionMillis + state.skipForwardSeconds * 1000));
      }
    },
    seekTo: (seconds: number) => soundRef.current?.setPositionAsync(seconds * 1000),
  });

  // Register lock screen / AirPods / CarPlay remote commands once, re-register on skip interval change.
  useEffect(() => {
    if (Platform.OS !== 'ios') return;
    setupRemoteCommands({
      onPlay:         () => actionsRef.current.play(),
      onPause:        () => actionsRef.current.pause(),
      onSkipBackward: () => actionsRef.current.skipBack(),
      onSkipForward:  () => actionsRef.current.skipForward(),
      onSeek:         (s) => actionsRef.current.seekTo(s),
      skipBackInterval:    podcastSkipBack,
      skipForwardInterval: podcastSkipForward,
    });
  }, [podcastSkipBack, podcastSkipForward]);

  // Sync voice boost native state with preference.
  useEffect(() => {
    if (Platform.OS === 'ios') setVoiceBoostEnabled(podcastVoiceBoost);
  }, [podcastVoiceBoost]);

  // Sync trim silence native state with preference.
  useEffect(() => {
    if (Platform.OS === 'ios') setTrimSilenceEnabled(podcastTrimSilence);
  }, [podcastTrimSilence]);

  // Keep a stable ref to the current episode so AppState callback never goes stale.
  useEffect(() => { episodeRef.current = state.episode; }, [state.episode]);

  // On launch: restore saved volume and the last-played episode (paused at saved position).
  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => {
    Promise.all([persistence.getVolume(), persistence.getLastEpisode()])
      .then(([v, ep]) => {
        volumeRef.current = v;
        patch({ volume: v });
        if (ep) loadEpisode(ep, false).catch(() => {});
      })
      .catch(() => {});
  }, []);

  // Save playback position whenever the app moves to background or becomes inactive.
  // Covers force-close and home-button dismissal that bypass the pause/stop paths.
  useEffect(() => {
    const sub = AppState.addEventListener('change', (nextState) => {
      if (nextState === 'background' || nextState === 'inactive') {
        const ep = episodeRef.current;
        if (!ep || !soundRef.current) return;
        persistence.setLastEpisode(ep).catch(() => {});
        soundRef.current.getStatusAsync().then((s) => {
          if (s.isLoaded && episodeRef.current) {
            persistence.savePodcastPosition(episodeRef.current.id, s.positionMillis / 1000);
          }
        }).catch(() => {});
      }
    });
    return () => sub.remove();
  }, []);

  useEffect(() => {
    Audio.setAudioModeAsync({
      allowsRecordingIOS: false,
      staysActiveInBackground: true,
      playsInSilentModeIOS: true,
      shouldDuckAndroid: true,
      playThroughEarpieceAndroid: false,
    });
    return () => {
      soundRef.current?.unloadAsync();
      if (sleepRef.current) clearInterval(sleepRef.current);
      if (nowPlayingTickRef.current) clearInterval(nowPlayingTickRef.current);
      if (Platform.OS === 'ios') clearNowPlayingInfo();
    };
  }, []);

  // Restore queue from local storage on mount.
  useEffect(() => {
    persistence.getQueue()
      .then(q => {
        if (q.length > 0) patch({ queue: q });
        queueLoadedRef.current = true;
      })
      .catch(() => { queueLoadedRef.current = true; });
  }, [patch]);

  // Persist queue whenever it changes (skip the initial empty state before load).
  useEffect(() => {
    if (!queueLoadedRef.current) return;
    persistence.setQueue(state.queue).catch(() => {});
  }, [state.queue]);

  // Keep skip interval state in sync with saved preferences.
  useEffect(() => {
    patch({ skipBackSeconds: podcastSkipBack, skipForwardSeconds: podcastSkipForward });
  }, [podcastSkipBack, podcastSkipForward, patch]);

  // Push elapsed time to lock screen every 5 seconds while playing.
  useEffect(() => {
    if (nowPlayingTickRef.current) {
      clearInterval(nowPlayingTickRef.current);
      nowPlayingTickRef.current = null;
    }
    if (state.isPlaying && state.episode && Platform.OS === 'ios') {
      nowPlayingTickRef.current = setInterval(() => {
        setState(prev => {
          if (prev.episode && Platform.OS === 'ios') {
            updateNowPlayingInfo({
              title:       prev.episode.title,
              artist:      prev.episode.showTitle,
              artworkUrl:  prev.episode.artworkUrl,
              duration:    prev.duration,
              elapsedTime: prev.position,
              playbackRate: prev.speed,
            });
          }
          return prev;
        });
      }, 5000);
    }
    return () => {
      if (nowPlayingTickRef.current) clearInterval(nowPlayingTickRef.current);
    };
  }, [state.isPlaying, state.episode]);

  function onPlaybackStatus(status: AVPlaybackStatus) {
    if (!status.isLoaded) {
      if (status.error) patch({ error: status.error, isLoading: false });
      return;
    }
    setState((prev) => ({
      ...prev,
      isPlaying: status.isPlaying,
      isBuffering: status.isBuffering ?? false,
      isLoading: false,
      position: status.positionMillis / 1000,
      duration: status.durationMillis ? status.durationMillis / 1000 : prev.duration,
      currentChapter: resolveChapter(prev.episode, status.positionMillis / 1000),
    }));

    if (status.didJustFinish) {
      onEpisodeFinished();
    }
  }

  async function onEpisodeFinished() {
    setState((prev) => {
      if (prev.episode) {
        persistence.clearPodcastPosition(prev.episode.id);
        persistence.addToPlayHistory(prev.episode).catch(() => {});
      }
      if (sleepRef.current) {
        clearInterval(sleepRef.current);
        sleepRef.current = null;
      }

      // Sleep at end of episode — pause and clear the flag.
      if (prev.sleepAtEndOfEpisode) {
        soundRef.current?.pauseAsync();
        if (Platform.OS === 'ios') clearNowPlayingInfo();
        AccessibilityInfo.announceForAccessibility('Sleep timer: episode ended, playback stopped.');
        return { ...prev, isPlaying: false, sleepTimerRemaining: null, sleepAtEndOfEpisode: false };
      }

      const [next, ...rest] = prev.queue;
      if (next) {
        loadEpisode(next, podcastAutoPlay);
        if (Platform.OS === 'ios') {
          AccessibilityInfo.announceForAccessibility(`Now playing: ${next.title}`);
        }
        return { ...prev, queue: rest, sleepTimerRemaining: null };
      }

      if (Platform.OS === 'ios') clearNowPlayingInfo();
      return { ...prev, isPlaying: false, sleepTimerRemaining: null };
    });
  }

  async function loadEpisode(episode: PodcastEpisode, autoPlay = true) {
    // Save position of current episode before unloading
    if (soundRef.current && state.episode) {
      const s = await soundRef.current.getStatusAsync();
      if (s.isLoaded) {
        await persistence.savePodcastPosition(state.episode.id, s.positionMillis / 1000);
      }
      await soundRef.current.unloadAsync();
      soundRef.current = null;
    }

    // Resolve speed: check per-show saved speed first, then fall back to global pref.
    const showSpeed = await persistence.getShowSpeed(episode.showTitle);
    const resolvedSpeed = showSpeed ?? podcastSpeed;

    patch({ isLoading: true, error: null, episode, position: 0, duration: episode.duration, speed: resolvedSpeed });

    try {
      const localUri = await getLocalUri(episode.id);
      const uri = localUri ?? episode.audioUrl;
      const savedPositions = await persistence.getPodcastPositions();
      const rawPosition = savedPositions[episode.id] ?? 0;

      // Resume rewind: subtract N seconds so the listener re-hears the last bit
      // of context after returning to a partially-played episode.
      const savedPosition = rawPosition > 0 && podcastResumeRewind > 0
        ? Math.max(0, rawPosition - podcastResumeRewind)
        : rawPosition;

      const { sound, status } = await Audio.Sound.createAsync(
        { uri },
        {
          shouldPlay: autoPlay,
          rate: resolvedSpeed,
          shouldCorrectPitch: true,
          volume: volumeRef.current,
          positionMillis: savedPosition * 1000,
          progressUpdateIntervalMillis: 500,
        },
        onPlaybackStatus,
      );

      soundRef.current = sound;

      const actualDuration = status.isLoaded && status.durationMillis
        ? status.durationMillis / 1000
        : episode.duration;

      if (status.isLoaded) {
        patch({
          isLoading: false,
          isPlaying: autoPlay,
          duration: actualDuration,
          position: savedPosition,
          currentChapter: resolveChapter(episode, savedPosition),
          speed: resolvedSpeed,
        });
      }

      // Push initial Now Playing metadata to lock screen.
      if (Platform.OS === 'ios') {
        updateNowPlayingInfo({
          title:        episode.title,
          artist:       episode.showTitle,
          artworkUrl:   episode.artworkUrl,
          duration:     actualDuration,
          elapsedTime:  savedPosition,
          playbackRate: resolvedSpeed,
        });
      }

      // Apply default sleep timer when playback starts (if no timer already running).
      if (autoPlay && podcastSleepTimer !== null && sleepRef.current === null) {
        startSleepTimer(podcastSleepTimer);
      }
    } catch (err) {
      patch({ isLoading: false, error: err instanceof Error ? err.message : 'Playback error' });
    }
  }

  async function play() {
    await soundRef.current?.playAsync();
  }

  async function pause() {
    await soundRef.current?.pauseAsync();
    if (state.episode) {
      await persistence.savePodcastPosition(state.episode.id, state.position);
    }
  }

  async function stop() {
    try {
      const s = await soundRef.current?.getStatusAsync();
      if (s?.isLoaded && state.episode) {
        await persistence.savePodcastPosition(state.episode.id, s.positionMillis / 1000);
      }
    } catch {}
    await soundRef.current?.unloadAsync().catch(() => {});
    soundRef.current = null;
    if (sleepRef.current) { clearInterval(sleepRef.current); sleepRef.current = null; }
    if (Platform.OS === 'ios') clearNowPlayingInfo();
    persistence.setLastEpisode(null).catch(() => {});
    setState(DEFAULT);
  }

  async function skipBack() {
    const pos = Math.max(0, state.position - state.skipBackSeconds);
    await soundRef.current?.setPositionAsync(pos * 1000);
  }

  async function skipForward() {
    const pos = Math.min(state.duration, state.position + state.skipForwardSeconds);
    await soundRef.current?.setPositionAsync(pos * 1000);
  }

  async function seekTo(seconds: number) {
    const clamped = Math.max(0, Math.min(state.duration, seconds));
    patch({ position: clamped });
    await soundRef.current?.setPositionAsync(clamped * 1000);
  }

  async function setSpeed(speed: PlaybackSpeed) {
    await soundRef.current?.setRateAsync(speed, true);
    patch({ speed });
    setPodcastSpeed(speed);
    // Also remember this speed for the current show.
    if (state.episode?.showTitle) {
      persistence.saveShowSpeed(state.episode.showTitle, speed).catch(() => {});
    }
  }

  async function setVolume(volume: number) {
    const clamped = Math.max(0, Math.min(1, volume));
    volumeRef.current = clamped;
    await soundRef.current?.setVolumeAsync(clamped);
    patch({ volume: clamped });
    persistence.setVolume(clamped).catch(() => {});
  }

  function enqueue(episode: PodcastEpisode) {
    patch({ queue: [...state.queue, episode] });
  }

  function playNext(episode: PodcastEpisode) {
    patch({ queue: [episode, ...state.queue] });
  }

  function removeFromQueue(id: string) {
    patch({ queue: state.queue.filter((e) => e.id !== id) });
  }

  function clearQueue() {
    patch({ queue: [] });
  }

  function moveQueueItemUp(id: string) {
    const idx = state.queue.findIndex((e) => e.id === id);
    if (idx <= 0) return;
    const q = [...state.queue];
    [q[idx - 1], q[idx]] = [q[idx], q[idx - 1]];
    patch({ queue: q });
  }

  function moveQueueItemDown(id: string) {
    const idx = state.queue.findIndex((e) => e.id === id);
    if (idx < 0 || idx >= state.queue.length - 1) return;
    const q = [...state.queue];
    [q[idx], q[idx + 1]] = [q[idx + 1], q[idx]];
    patch({ queue: q });
  }

  function startSleepTimer(minutes: number) {
    if (sleepRef.current) clearInterval(sleepRef.current);
    if (minutes === SLEEP_END_OF_EPISODE) {
      patch({ sleepAtEndOfEpisode: true, sleepTimerRemaining: null });
      return;
    }
    patch({ sleepAtEndOfEpisode: false, sleepTimerRemaining: minutes * 60 });
    sleepRef.current = setInterval(() => {
      setState((prev) => {
        const remaining = (prev.sleepTimerRemaining ?? 0) - 1;
        if (remaining <= 0) {
          clearInterval(sleepRef.current!);
          sleepRef.current = null;
          soundRef.current?.pauseAsync();
          AccessibilityInfo.announceForAccessibility('Sleep timer ended. Playback paused.');
          return { ...prev, sleepTimerRemaining: null, isPlaying: false };
        }
        return { ...prev, sleepTimerRemaining: remaining };
      });
    }, 1000);
  }

  function cancelSleepTimer() {
    if (sleepRef.current) {
      clearInterval(sleepRef.current);
      sleepRef.current = null;
    }
    patch({ sleepTimerRemaining: null, sleepAtEndOfEpisode: false });
  }

  function setSkipTimes(back: number, forward: number) {
    patch({ skipBackSeconds: back, skipForwardSeconds: forward });
  }

  async function skipToChapter(chapter: Chapter) {
    await seekTo(chapter.startTime);
  }

  return {
    ...state,
    loadEpisode,
    play,
    pause,
    stop,
    skipBack,
    skipForward,
    seekTo,
    setSpeed,
    setVolume,
    enqueue,
    playNext,
    removeFromQueue,
    clearQueue,
    moveQueueItemUp,
    moveQueueItemDown,
    startSleepTimer,
    cancelSleepTimer,
    setSkipTimes,
    skipToChapter,
  };
}
