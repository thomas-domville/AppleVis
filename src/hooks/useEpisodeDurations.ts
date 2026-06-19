import { useEffect, useState } from 'react';
import { persistence } from '../services/persistence';

/**
 * Returns a map of episode ID → duration (seconds) for episodes whose duration
 * has been resolved from expo-av during a previous playback session.
 * Used to display duration in episode list cards before the episode is played.
 */
export function useEpisodeDurations(): Record<string, number> {
  const [durations, setDurations] = useState<Record<string, number>>({});

  useEffect(() => {
    persistence.getEpisodeDurations().then(setDurations);
  }, []);

  return durations;
}
