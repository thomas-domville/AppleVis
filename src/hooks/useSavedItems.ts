import { useCallback, useEffect, useState } from 'react';
import { persistence } from '../services/persistence';
import type { SavedItem, ContentKind } from '../types/content';

export function useSavedItems(filterKind?: ContentKind) {
  const [items, setItems] = useState<SavedItem[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    persistence.getSavedItems().then((all) => {
      setItems(filterKind ? all.filter((i) => i.kind === filterKind) : all);
      setLoading(false);
    });
  }, [filterKind]);

  const save = useCallback(
    async (item: SavedItem) => {
      const updated = await persistence.saveItem(item);
      setItems(filterKind ? updated.filter((i) => i.kind === filterKind) : updated);
    },
    [filterKind],
  );

  const unsave = useCallback(
    async (id: string) => {
      const updated = await persistence.unsaveItem(id);
      setItems(filterKind ? updated.filter((i) => i.kind === filterKind) : updated);
    },
    [filterKind],
  );

  const isSaved = useCallback(
    (id: string) => items.some((i) => i.id === id),
    [items],
  );

  return { items, loading, save, unsave, isSaved };
}
