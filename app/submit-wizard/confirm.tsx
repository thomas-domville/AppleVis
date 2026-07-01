import { useEffect } from 'react';
import { AccessibilityInfo, ActivityIndicator, Image, Pressable, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { WizardLayout } from '../../src/components/WizardLayout';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useWizard } from '../../src/contexts/SubmitWizardContext';
import { useAlert } from '../../src/contexts/AccessibleAlertContext';
import { fetchItunesMetadata } from '../../src/services/itunesApi';
import { sounds } from '../../src/services/sounds';

// ─── Step 4: Confirm ──────────────────────────────────────────────────────────

const DEVICE_ICONS: Record<string, string> = {
  'iPhone':      'phone-portrait-outline',
  'iPad':        'tablet-portrait-outline',
  'Mac':         'laptop-outline',
  'Apple Watch': 'watch-outline',
  'Apple TV':    'tv-outline',
  'Vision Pro':  'glasses-outline',
};

async function checkForDuplicate(
  appStoreId: string,
): Promise<{ status: 'clear' | 'duplicate' | 'unknown'; entryId?: string; entryTitle?: string }> {
  if (!appStoreId) return { status: 'unknown' };
  try {
    const res = await fetch(
      `https://www.applevis.com/jsonapi/node/ios_app_directory?` +
      `filter[field_link2.uri][operator]=CONTAINS&filter[field_link2.uri][value]=/id${appStoreId}&` +
      `page[limit]=1&fields[node--ios_app_directory]=title,drupal_internal__nid,path`,
      {
        headers: {
          'Accept':          'application/vnd.api+json',
          'User-Agent':      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 AppleVis/2026',
          'Accept-Language': 'en-US,en;q=0.9',
          'Origin':          'https://www.applevis.com',
          'Referer':         'https://www.applevis.com/',
          'X-App-Auth':      '2ff01dc7bf35469d93c6',
        },
      },
    );
    if (!res.ok) return { status: 'unknown' };
    const json = await res.json() as { data: unknown[] };
    if (json.data.length > 0) {
      const node = json.data[0] as { attributes: { title?: string; drupal_internal__nid?: number } };
      return { status: 'duplicate', entryId: String(node.attributes.drupal_internal__nid ?? ''), entryTitle: node.attributes.title ?? '' };
    }
    return { status: 'clear' };
  } catch {
    return { status: 'unknown' };
  }
}

function DeviceBadge({ label, icon, highlight }: { label: string; icon: string; highlight?: boolean }) {
  const { colors } = useTheme();
  return (
    <View accessible accessibilityLabel={label} style={{
      flexDirection: 'row', alignItems: 'center', gap: 5,
      paddingHorizontal: 10, paddingVertical: 5, borderRadius: 20,
      backgroundColor: highlight ? colors.accent : colors.border,
    }}>
      <Ionicons name={icon as any} size={13} color={highlight ? '#fff' : colors.textSecondary} />
      <Text style={{ fontSize: 12, fontWeight: '600', color: highlight ? '#fff' : colors.textSecondary }}>{label}</Text>
    </View>
  );
}

export default function ConfirmScreen() {
  const { colors }    = useTheme();
  const { state, update, reset } = useWizard();
  const { showAlert } = useAlert();

  const hit  = state.searchHit;
  const meta = state.fullMeta;

  // Fetch full metadata + duplicate check on mount
  useEffect(() => {
    if (!hit?.appStoreUrl) return;
    let cancelled = false;
    async function load() {
      update({ duplicateStatus: 'checking' });
      const result = await fetchItunesMetadata(hit!.appStoreUrl);
      if (cancelled) return;
      if (result && result !== 'not-found') update({ fullMeta: result });
      const id  = (result && result !== 'not-found' ? result.appStoreId : hit!.appStoreId);
      const dup = await checkForDuplicate(id);
      if (cancelled) return;
      update({ duplicateStatus: dup.status, existingEntryId: dup.entryId ?? null, existingEntryTitle: dup.entryTitle ?? null });
      if (dup.status === 'duplicate') AccessibilityInfo.announceForAccessibility('Warning: this app is already in the AppleVis directory.');
    }
    void load();
    return () => { cancelled = true; };
  }, [hit?.appStoreUrl]);

  const displayMeta = meta ?? hit;
  const appName     = meta?.appName       ?? hit?.appName       ?? '';
  const developer   = meta?.developerName ?? hit?.developerName ?? '';
  const artworkUrl  = meta?.artworkUrl    ?? hit?.artworkUrl    ?? '';
  const price       = meta?.price         ?? hit?.price         ?? '';
  const category    = meta?.category      ?? hit?.category      ?? '';
  const minOs       = meta?.minimumOsVersion ?? '';
  const version     = meta?.version ?? '';
  const supportedDevices = meta?.supportedDevices ?? [];
  const isUniversal = state.platform === 'ios' && supportedDevices.includes('Mac');
  const hasWatch    = supportedDevices.includes('Apple Watch');
  const hasVision   = supportedDevices.some(d => /vision/i.test(d));
  const dupStatus   = state.duplicateStatus;

  function handleNext() {
    sounds.articleOpen().catch(() => {});
    router.push('/submit-wizard/notes' as any);
  }

  function handleCancel() {
    showAlert({
      title: 'Discard this submission?',
      message: 'Your progress will be discarded.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep Editing',
      type: 'warning',
      onConfirm: () => {
        reset();
        router.replace('/(tabs)/discover' as any);
      },
    });
  }

  return (
    <WizardLayout
      step={4}
      totalSteps={5}
      title="Confirm this app"
      description="Review the details below before continuing."
      onNext={handleNext}
      nextLabel={dupStatus === 'duplicate' ? 'Continue Anyway' : 'Continue to Notes'}
      nextDisabled={!displayMeta}
      hideSkip
      onCancel={handleCancel}
    >
      {/* App card */}
      <View style={{ backgroundColor: colors.card, borderRadius: 18, padding: 18, marginBottom: 14, flexDirection: 'row', alignItems: 'flex-start', gap: 16 }}
        accessible accessibilityLabel={appName ? `${appName} by ${developer}. ${price}. ${category}.` : 'Loading app details…'}>
        {artworkUrl ? (
          <Image source={{ uri: artworkUrl }} style={{ width: 72, height: 72, borderRadius: 16 }} accessibilityElementsHidden />
        ) : (
          <View style={{ width: 72, height: 72, borderRadius: 16, backgroundColor: colors.border, justifyContent: 'center', alignItems: 'center' }} accessibilityElementsHidden>
            <Ionicons name="phone-portrait-outline" size={32} color={colors.textSecondary} />
          </View>
        )}
        <View style={{ flex: 1 }}>
          <Text style={{ fontSize: 19, fontWeight: '800', color: colors.text, lineHeight: 24 }}>{appName || '…'}</Text>
          <Text style={{ fontSize: 14, color: colors.textSecondary, marginTop: 3 }}>{developer}</Text>
          {(price || category) ? (
            <Text style={{ fontSize: 13, color: colors.textSecondary, marginTop: 3 }}>{[price, category].filter(Boolean).join(' · ')}</Text>
          ) : null}
          {(minOs || version) ? (
            <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 3 }} accessibilityElementsHidden>
              {[version ? `v${version}` : null, minOs ? `Requires iOS ${minOs}+` : null].filter(Boolean).join(' · ')}
            </Text>
          ) : null}
        </View>
      </View>

      {/* Supported devices */}
      {supportedDevices.length > 0 && (
        <View style={{ backgroundColor: colors.card, borderRadius: 14, padding: 14, marginBottom: 14 }}>
          <Text style={{ fontSize: 12, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 10 }} accessibilityRole="header">
            Supported Devices
          </Text>
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 6 }}
            accessible accessibilityLabel={`Supported devices: ${supportedDevices.join(', ')}${hasVision ? ', Vision Pro' : ''}`}>
            {supportedDevices.map(d => (
              <DeviceBadge key={d} label={d} icon={DEVICE_ICONS[d] ?? 'hardware-chip-outline'} highlight={d === 'iPhone' || d === 'iPad'} />
            ))}
            {hasWatch && <DeviceBadge label="Apple Watch" icon="watch-outline" />}
            {hasVision && <DeviceBadge label="Vision Pro" icon="glasses-outline" />}
          </View>
        </View>
      )}

      {/* Universal Purchase */}
      {isUniversal && (
        <View accessible accessibilityRole="alert"
          accessibilityLabel="Universal Purchase app. This submission will cover both iOS and Mac."
          style={{ backgroundColor: colors.card, borderRadius: 14, borderLeftWidth: 4, borderLeftColor: colors.accent, padding: 14, marginBottom: 14, flexDirection: 'row', alignItems: 'flex-start', gap: 10 }}>
          <Ionicons name="infinite-outline" size={20} color={colors.accent} style={{ marginTop: 1 }} accessibilityElementsHidden />
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: 14, fontWeight: '700', color: colors.text }}>Universal Purchase</Text>
            <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 19, marginTop: 2 }}>
              This appears to be a Universal Purchase — available on both iOS and Mac. Your submission will cover both platforms.
            </Text>
          </View>
        </View>
      )}

      {/* Duplicate check status */}
      {dupStatus === 'checking' && (
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, backgroundColor: colors.card, borderRadius: 14, padding: 14, marginBottom: 14 }}
          accessible accessibilityLabel="Checking if this app is already in the AppleVis directory…">
          <ActivityIndicator size="small" color={colors.accent} accessibilityElementsHidden />
          <Text style={{ fontSize: 14, color: colors.textSecondary }}>Checking AppleVis directory…</Text>
        </View>
      )}

      {dupStatus === 'duplicate' && (
        <View accessible accessibilityRole="alert"
          accessibilityLabel={`Warning: ${state.existingEntryTitle ?? 'This app'} is already in the AppleVis directory.`}
          style={{ backgroundColor: '#FFF3CD', borderRadius: 14, borderLeftWidth: 4, borderLeftColor: '#F59E0B', padding: 14, marginBottom: 14 }}>
          <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 10 }}>
            <Ionicons name="warning-outline" size={20} color="#92400E" style={{ marginTop: 1 }} accessibilityElementsHidden />
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: 14, fontWeight: '700', color: '#92400E' }}>Already in the Directory</Text>
              <Text style={{ fontSize: 13, color: '#92400E', lineHeight: 19, marginTop: 2 }}>
                {state.existingEntryTitle ? `"${state.existingEntryTitle}" is` : 'This app is'} already listed on AppleVis.
                {' '}You can view the existing entry or continue to add a new one.
              </Text>
            </View>
          </View>
          {state.existingEntryId && (
            <Pressable
              onPress={() => router.push({ pathname: '/app-detail/[id]' as any, params: { id: state.existingEntryId! } })}
              accessible accessibilityRole="button"
              accessibilityLabel={`View existing entry for ${state.existingEntryTitle ?? 'this app'}`}
              style={({ pressed }) => ({ marginTop: 10, paddingVertical: 9, paddingHorizontal: 14, borderRadius: 10, backgroundColor: '#F59E0B', alignSelf: 'flex-start', opacity: pressed ? 0.85 : 1 })}
            >
              <Text style={{ fontSize: 14, fontWeight: '700', color: '#fff' }}>View Existing Entry</Text>
            </Pressable>
          )}
        </View>
      )}

      {dupStatus === 'clear' && (
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, backgroundColor: colors.card, borderRadius: 14, padding: 14, marginBottom: 14 }}
          accessible accessibilityLabel="Great! This app is not yet in the AppleVis directory.">
          <Ionicons name="checkmark-circle" size={20} color="#16a34a" accessibilityElementsHidden />
          <Text style={{ fontSize: 14, color: '#16a34a', fontWeight: '600' }}>Not yet in the AppleVis directory</Text>
        </View>
      )}

      {/* Wrong app? */}
      <Pressable
        onPress={() => router.back()}
        accessible accessibilityRole="button" accessibilityLabel="This is not the right app, go back to search"
        style={({ pressed }) => ({ alignItems: 'center', paddingVertical: 12, opacity: pressed ? 0.7 : 1 })}
      >
        <Text style={{ fontSize: 14, color: colors.textSecondary }}>
          Not the right app? <Text style={{ color: colors.accent, fontWeight: '600' }}>Go back to search</Text>
        </Text>
      </Pressable>
    </WizardLayout>
  );
}
