import { useCallback, useEffect, useState } from 'react';
import { api } from '../services/api';
import { persistence } from '../services/persistence';
import type { FollowedItem } from '../types/content';

export function useFollowedItem(item: FollowedItem) {
  const [isFollowing, setIsFollowing] = useState(false);

  useEffect(() => {
    let mounted = true;
    persistence.isFollowingItem(item.id).then((value) => {
      if (mounted) setIsFollowing(value);
    });
    return () => { mounted = false; };
  }, [item.id]);

  const follow = useCallback(async (): Promise<'followed' | 'followed-local'> => {
    await persistence.followItem({ ...item, followedAt: new Date().toISOString() });
    setIsFollowing(true);
    const token = await api.account.getSessionToken();
    if (!token) return 'followed-local';
    const res = await api.follows.follow(item.id, item.nodeType, token);
    return res.ok ? 'followed' : 'followed-local';
  }, [item]);

  const unfollow = useCallback(async (): Promise<'unfollowed'> => {
    await persistence.unfollowItem(item.id);
    setIsFollowing(false);
    const token = await api.account.getSessionToken();
    if (token) await api.follows.unfollow(item.id, token).catch(() => {});
    return 'unfollowed';
  }, [item.id]);

  const toggleFollow = useCallback(async (): Promise<'followed' | 'unfollowed' | 'followed-local'> => {
    return isFollowing ? unfollow() : follow();
  }, [follow, isFollowing, unfollow]);

  return { isFollowing, follow, unfollow, toggleFollow };
}
