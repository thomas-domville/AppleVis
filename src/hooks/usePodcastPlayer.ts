import { Audio, AVPlaybackStatus } from 'expo-av';
import { useCallback, useEffect, useRef, useState } from 'react';
import type { PodcastEpisode, Chapter } from '../types/content';
import { persistence } from '../services/persistence';
import { getLocalUri } from '../services/downloads';
import { usePreferences } from '../contexts/PreferencesContext';

export type PlaybackSpeed = 0.5 | 0.75 | 1.0 | 1.25 | 1.5 | 1.75 | 2.0 | 2.5 | 3.0;
export const SPEED_OPTIONS: PlaybackSpeed[] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0];
export const SLEEP_TIMER_OPTIONS = [15, 30, 45, 60, 90] as const;

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
  const [state, setState] = useState<PlayerState>(DEFAULT);
  const { podcastAutoPlay, podcastSleepTimer } = usePreferences();

  const patch = useCallback((updates: Partial<PlayerState>) => {
    setState((prev) => ({ ...prev, ...updates }));
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
    };
  }, []);

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
      }
      if (sleepRef.current) {
        clearInterval(sleepRef.current);
        sleepRef.current = null;
      }
      const [next, ...rest] = prev.queue;
      if (next) {
        loadEpisode(next, podcastAutoPlay);
        return { ...prev, queue: rest, sleepTimerRemaining: null };
      }
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

    patch({ isLoading: true, error: null, episode, position: 0, duration: episode.duration });

    try {
      const localUri = await getLocalUri(episode.id);
      const uri = localUri ?? episode.audioUrl;
      const savedPositions = await persistence.getPodcastPositions();
      const savedPosition = savedPositions[episode.id] ?? 0;

      const { sound, status } = await Audio.Sound.createAsync(
        { uri },
        {
          shouldPlay: autoPlay,
          rate: state.speed,
          volume: state.volume,
          positionMillis: savedPosition * 1000,
          progressUpdateIntervalMillis: 500,
        },
        onPlaybackStatus,
      );

      soundRef.current = sound;

      if (status.isLoaded) {
        patch({
          isLoading: false,
          isPlaying: autoPlay,
          duration: status.durationMillis ? status.durationMillis / 1000 : episode.duration,
          position: savedPosition,
          currentChapter: resolveChapter(episode, savedPosition),
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
    await soundRef.current?.setPositionAsync(clamped * 1000);
  }

  async function setSpeed(speed: PlaybackSpeed) {
    await soundRef.current?.setRateAsync(speed, true);
    patch({ speed });
  }

  async function setVolume(volume: number) {
    const clamped = Math.max(0, Math.min(1, volume));
    await soundRef.current?.setVolumeAsync(clamped);
    patch({ volume: clamped });
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
    patch({ sleepTimerRemaining: minutes * 60 });
    sleepRef.current = setInterval(() => {
      setState((prev) => {
        const remaining = (prev.sleepTimerRemaining ?? 0) - 1;
        if (remaining <= 0) {
          clearInterval(sleepRef.current!);
          sleepRef.current = null;
          soundRef.current?.pauseAsync();
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
    patch({ sleepTimerRemaining: null });
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
