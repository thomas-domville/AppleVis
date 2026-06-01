import { AccessibilityInfo, Text, View } from 'react-native';
import { useEffect } from 'react';

type Props = {
  fromCache: boolean;
  cachedAt?: number;
};

function formatAge(ms: number): string {
  const minutes = Math.floor(ms / 60_000);
  if (minutes < 1)  return 'just now';
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24)   return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

export function OfflineBanner({ fromCache, cachedAt }: Props) {
  const age   = cachedAt != null ? formatAge(Date.now() - cachedAt) : null;
  const label = age
    ? `Showing saved content from ${age}. Pull down to refresh when online.`
    : 'Showing saved content. Pull down to refresh when online.';

  // Announce to VoiceOver the moment cached data appears, using the same
  // reliable mechanism as the toast system.
  useEffect(() => {
    if (fromCache) {
      AccessibilityInfo.announceForAccessibility(label);
    }
  }, [fromCache, label]);

  if (!fromCache) return null;

  return (
    <View
      accessible
      accessibilityRole="alert"
      accessibilityLiveRegion="assertive"
      accessibilityLabel={label}
      style={{
        backgroundColor: '#FFF8E1',
        borderRadius: 10,
        paddingHorizontal: 14,
        paddingVertical: 10,
        marginBottom: 12,
      }}
    >
      <Text style={{ fontSize: 14, lineHeight: 20, color: '#856404' }}>{label}</Text>
    </View>
  );
}
