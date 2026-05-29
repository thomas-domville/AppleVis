export type SyncPayload = {
  settings: Record<string, unknown>;
  savedItemIds: string[];
  followedItemIds: string[];
  podcastPositions: Record<string, number>;
  listPositions: Record<string, { itemId: string; offsetHint?: number }>;
};

export async function syncWithICloudPlaceholder(_payload: SyncPayload) {
  // Expo managed apps do not provide full CloudKit/iCloud key-value syncing out of the box.
  // Production options:
  // 1. Apple iCloud key-value store via native module.
  // 2. CloudKit via native Swift bridge.
  // 3. AppleVis account API sync, with iCloud used only for device preferences.
  return { ok: true, note: 'Placeholder sync complete.' };
}
