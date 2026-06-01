import { createContext, ReactNode, useContext, useEffect } from 'react';
import { usePodcastPlayer } from '../hooks/usePodcastPlayer';
import { usePreferences } from './PreferencesContext';

type PlayerContextValue = ReturnType<typeof usePodcastPlayer>;

const PlayerContext = createContext<PlayerContextValue | null>(null);

export function PlayerProvider({ children }: { children: ReactNode }) {
  const player = usePodcastPlayer();
  const {
    podcastSpeed,
    podcastSkipBack,
    podcastSkipForward,
  } = usePreferences();

  // Apply the user's saved defaults once on mount.
  // The user can adjust speed/skip during a session; defaults restore on next launch.
  useEffect(() => {
    player.setSpeed(podcastSpeed);
    player.setSkipTimes(podcastSkipBack, podcastSkipForward);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []); // intentionally runs once on mount only

  return <PlayerContext.Provider value={player}>{children}</PlayerContext.Provider>;
}

export function usePlayer(): PlayerContextValue {
  const ctx = useContext(PlayerContext);
  if (!ctx) throw new Error('usePlayer must be used within PlayerProvider');
  return ctx;
}
