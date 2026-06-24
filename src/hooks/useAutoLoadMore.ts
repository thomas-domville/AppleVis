import { useCallback, useEffect, useRef } from 'react';
import type { NativeScrollEvent, NativeSyntheticEvent } from 'react-native';

type Options = {
  hasMore: boolean;
  isLoadingMore: boolean;
  onLoadMore: () => void;
  disabled?: boolean;
  threshold?: number;
};

export function useAutoLoadMore({
  hasMore,
  isLoadingMore,
  onLoadMore,
  disabled = false,
  threshold = 360,
}: Options) {
  const requestPendingRef = useRef(false);

  useEffect(() => {
    if (!isLoadingMore) requestPendingRef.current = false;
  }, [isLoadingMore]);

  useEffect(() => {
    if (!hasMore || disabled) requestPendingRef.current = false;
  }, [disabled, hasMore]);

  return useCallback((event: NativeSyntheticEvent<NativeScrollEvent>) => {
    if (disabled || !hasMore || isLoadingMore || requestPendingRef.current) return;

    const { contentOffset, contentSize, layoutMeasurement } = event.nativeEvent;
    const distanceFromBottom = contentSize.height - (contentOffset.y + layoutMeasurement.height);
    if (distanceFromBottom > threshold) return;

    requestPendingRef.current = true;
    onLoadMore();
  }, [disabled, hasMore, isLoadingMore, onLoadMore, threshold]);
}
