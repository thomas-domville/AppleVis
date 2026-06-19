import { useEffect, useState } from 'react';
import { Pressable, Text, View } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../contexts/ThemeContext';
import { usePreferences } from '../contexts/PreferencesContext';
import { icloudStorage } from '../services/icloudStorage';

export type HelpfulTipVariant = 'tip' | 'warning' | 'error';

type Props = {
  id?: string;
  title?: string;
  message: string;
  accessibilityLabel?: string;
  variant?: HelpfulTipVariant;
  dismissible?: boolean;
  syncDismissal?: boolean;
  actionLabel?: string;
  actionAccessibilityHint?: string;
  onAction?: () => void;
  onDismiss?: () => void;
};

const DISMISSED_PREFIX = 'applevis:helpfulTipDismissed:';
const ICLOUD_DISMISSED_SET = 'applevis:helpfulTipDismissedIds';

const VARIANTS: Record<HelpfulTipVariant, {
  icon: keyof typeof Ionicons.glyphMap;
  label: string;
  bg: string;
  border: string;
  accent: string;
}> = {
  tip: {
    icon: 'information-circle-outline',
    label: 'AppleVis Tip',
    bg: '#F0F9FF',
    border: '#BAE6FD',
    accent: '#0369A1',
  },
  warning: {
    icon: 'alert-circle-outline',
    label: 'Helpful reminder',
    bg: '#FFFBEB',
    border: '#FCD34D',
    accent: '#B45309',
  },
  error: {
    icon: 'warning-outline',
    label: 'Problem found',
    bg: '#FFF0F0',
    border: '#FCA5A5',
    accent: '#B91C1C',
  },
};

export function HelpfulTip({
  id,
  title,
  message,
  accessibilityLabel,
  variant = 'tip',
  dismissible = true,
  syncDismissal = false,
  actionLabel,
  actionAccessibilityHint,
  onAction,
  onDismiss,
}: Props) {
  const { colors, isDark } = useTheme();
  const { helpfulTipsEnabled } = usePreferences();
  const [isDismissed, setIsDismissed] = useState(false);
  const config = VARIANTS[variant];
  const canPersistDismissal = dismissible && !!id;

  useEffect(() => {
    let mounted = true;
    if (!canPersistDismissal) {
      setIsDismissed(false);
      return () => { mounted = false; };
    }

    const localKey = `${DISMISSED_PREFIX}${id}`;
    Promise.all([
      AsyncStorage.getItem(localKey),
      syncDismissal ? icloudStorage.isInSet(ICLOUD_DISMISSED_SET, id) : Promise.resolve(false),
    ]).then(([localValue, cloudDismissed]) => {
      const dismissed = localValue === 'true' || cloudDismissed;
      if (mounted) setIsDismissed(dismissed);
      if (syncDismissal && localValue === 'true' && !cloudDismissed) {
        icloudStorage.addToSet(ICLOUD_DISMISSED_SET, id).catch(() => {});
      }
    }).catch(() => {});

    return () => { mounted = false; };
  }, [canPersistDismissal, id, syncDismissal]);

  if (!helpfulTipsEnabled || isDismissed) return null;

  const hasActions = dismissible || !!(actionLabel && onAction);
  const label = accessibilityLabel ?? `${title ?? config.label}. ${message}`;

  async function dismiss() {
    setIsDismissed(true);
    if (canPersistDismissal) {
      if (syncDismissal) {
        await icloudStorage.addToSet(ICLOUD_DISMISSED_SET, id).catch(() => {});
      } else {
        await AsyncStorage.setItem(`${DISMISSED_PREFIX}${id}`, 'true').catch(() => {});
      }
    }
    onDismiss?.();
  }

  return (
    <View
      accessible={!hasActions}
      accessibilityRole={variant === 'tip' ? 'text' : 'alert'}
      accessibilityLabel={label}
      style={{
        backgroundColor: isDark ? colors.card : config.bg,
        borderWidth: 1.5,
        borderColor: config.border,
        borderRadius: 10,
        paddingHorizontal: 14,
        paddingVertical: 12,
        marginBottom: 12,
        gap: 10,
      }}
    >
      <View
        accessible={hasActions}
        accessibilityRole={variant === 'tip' ? 'text' : 'alert'}
        accessibilityLabel={label}
        style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 10 }}
      >
        <Ionicons
          name={config.icon}
          size={18}
          color={config.accent}
          accessibilityElementsHidden
        />
        <View style={{ flex: 1 }}>
          {!!title && (
            <Text style={{ fontSize: 13, fontWeight: '700', color: config.accent, marginBottom: 3 }}>
              {title}
            </Text>
          )}
          <Text style={{ fontSize: 14, lineHeight: 20, color: colors.text }}>
            {message}
          </Text>
        </View>
      </View>

      {(dismissible || (actionLabel && onAction)) && (
        <View
          style={{ flexDirection: 'row', gap: 10 }}
        >
          {actionLabel && onAction && (
            <Pressable
              onPress={onAction}
              accessible
              accessibilityRole="button"
              accessibilityLabel={actionLabel}
              accessibilityHint={actionAccessibilityHint}
              style={{
                flex: 1,
                alignItems: 'center',
                backgroundColor: config.accent,
                borderRadius: 8,
                paddingVertical: 9,
              }}
            >
              <Text style={{ color: '#FFFFFF', fontWeight: '700', fontSize: 14 }}>
                {actionLabel}
              </Text>
            </Pressable>
          )}
          {dismissible && (
            <Pressable
              onPress={dismiss}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Dismiss this AppleVis Tip"
              style={{
                flex: 1,
                alignItems: 'center',
                backgroundColor: 'transparent',
                borderWidth: 1.5,
                borderColor: config.border,
                borderRadius: 8,
                paddingVertical: 9,
              }}
            >
              <Text style={{ color: config.accent, fontWeight: '600', fontSize: 14 }}>
                Dismiss
              </Text>
            </Pressable>
          )}
        </View>
      )}
    </View>
  );
}
