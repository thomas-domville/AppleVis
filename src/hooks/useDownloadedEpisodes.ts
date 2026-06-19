import { useEffect, useState } from 'react';
import { persistence } from '../services/persistence';

export function useDownloadedEpisodes() {
  const [ids, setIds] = useState<Set<string>>(new Set());

  useEffect(() => {
    persistence.getDownloadedEpisodes().then((map) => {
      setIds(new Set(Object.keys(map)));
    });
  }, []);

  return (id: string) => ids.has(id);
}
