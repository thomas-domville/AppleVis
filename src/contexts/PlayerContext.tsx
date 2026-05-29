import { createContext, ReactNode, useContext } from 'react';
import { usePodcastPlayer } from '../hooks/usePodcastPlayer';

type PlayerContextValue = ReturnType<typeof usePodcastPlayer>;

const PlayerContext = createContext<PlayerContextValue | null>(null);

export function PlayerProvider({ children }: { children: ReactNode }) {
  const player = usePodcastPlayer();
  return <PlayerContext.Provider value={player}>{children}</PlayerContext.Provider>;
}

export function usePlayer(): PlayerContextValue {
  const ctx = useContext(PlayerContext);
  if (!ctx) throw new Error('usePlayer must be used within PlayerProvider');
  return ctx;
}
