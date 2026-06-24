import {
  createContext,
  useCallback,
  useContext,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import {
  AccessibilityInfo,
  Animated,
  findNodeHandle,
  Modal,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { useTheme } from './ThemeContext';
import { sounds } from '../services/sounds';

// ─── Types ────────────────────────────────────────────────────────────────────

export type AlertType = 'info' | 'success' | 'warning' | 'error';

export type AlertOptions = {
  title: string;
  message: string;
  confirmLabel?: string;
  cancelLabel?: string;
  onConfirm?: () => void;
  onCancel?: () => void;
  type?: AlertType;
};

type AlertContextValue = {
  showAlert: (options: AlertOptions) => void;
};

// ─── Context ──────────────────────────────────────────────────────────────────

const AlertContext = createContext<AlertContextValue>({ showAlert: () => {} });

export function useAlert(): AlertContextValue {
  return useContext(AlertContext);
}

// ─── Type config ──────────────────────────────────────────────────────────────

type TypeConfig = {
  icon: React.ComponentProps<typeof Ionicons>['name'];
  iconColor: string;
  bgColor: string;
  confirmBg: string;
  haptic: () => void;
};

const TYPE_CONFIG: Record<AlertType, TypeConfig> = {
  info: {
    icon: 'information-circle',
    iconColor: '#0A84FF',
    bgColor: '#EFF6FF',
    confirmBg: '#0A84FF',
    haptic: () => Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning),
  },
  success: {
    icon: 'checkmark-circle',
    iconColor: '#1A7F4B',
    bgColor: '#F0FDF4',
    confirmBg: '#1A7F4B',
    haptic: () => Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success),
  },
  warning: {
    icon: 'warning',
    iconColor: '#92400E',
    bgColor: '#FFF3E0',
    confirmBg: '#92400E',
    haptic: () => Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning),
  },
  error: {
    icon: 'alert-circle',
    iconColor: '#B91C1C',
    bgColor: '#FEF2F2',
    confirmBg: '#B91C1C',
    haptic: () => Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error),
  },
};

// ─── Alert modal ──────────────────────────────────────────────────────────────

function AlertModal({
  options,
  onDismiss,
}: {
  options: AlertOptions;
  onDismiss: () => void;
}) {
  const { colors, isDark } = useTheme();
  const scaleAnim   = useRef(new Animated.Value(0.88)).current;
  const opacityAnim = useRef(new Animated.Value(0)).current;
  const titleRef    = useRef<Text>(null);

  const {
    title,
    message,
    confirmLabel = 'OK',
    cancelLabel,
    onConfirm,
    onCancel,
    type = 'info',
  } = options;

  const { icon, iconColor, bgColor, confirmBg } = TYPE_CONFIG[type];

  function handleShow() {
    Animated.parallel([
      Animated.spring(scaleAnim, {
        toValue: 1, useNativeDriver: true,
        damping: 18, stiffness: 280,
      }),
      Animated.timing(opacityAnim, {
        toValue: 1, useNativeDriver: true, duration: 160,
      }),
    ]).start();
    setTimeout(() => {
      const handle = findNodeHandle(titleRef.current);
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
      else AccessibilityInfo.announceForAccessibility(`${title}. ${message}`);
    }, 400);
  }

  function handleConfirm() {
    onDismiss();
    onConfirm?.();
  }

  function handleCancel() {
    onDismiss();
    onCancel?.();
  }

  return (
    <Modal
      visible
      transparent
      animationType="none"
      onShow={handleShow}
      onRequestClose={handleCancel}
    >
      {/* Semi-transparent backdrop — tapping it dismisses (same as cancel) */}
      <Pressable
        style={styles.backdrop}
        onPress={cancelLabel ? handleCancel : handleConfirm}
        accessibilityElementsHidden
        importantForAccessibility="no-hide-descendants"
      />

      {/* Card container — sits on top of backdrop */}
      <View style={styles.container} pointerEvents="box-none">
        <Animated.View
          style={[
            styles.card,
            {
              backgroundColor: isDark ? colors.card : '#FFFFFF',
              transform: [{ scale: scaleAnim }],
              opacity: opacityAnim,
            },
          ]}
          accessibilityViewIsModal
          onAccessibilityEscape={handleCancel}
        >
          {/* Icon circle */}
          <View style={[styles.iconCircle, { backgroundColor: bgColor }]}>
            <Ionicons
              name={icon}
              size={34}
              color={iconColor}
              accessibilityElementsHidden
            />
          </View>

          {/* Title */}
          <Text
            ref={titleRef}
            style={[styles.title, { color: colors.text }]}
            accessibilityRole="header"
            accessibilityLabel={`${title}. ${message}`}
          >
            {title}
          </Text>

          {/* Message */}
          <Text
            style={[styles.message, { color: colors.textSecondary }]}
            accessibilityElementsHidden
            importantForAccessibility="no-hide-descendants"
          >
            {message}
          </Text>

          {/* Buttons */}
          <View style={[styles.buttonRow, cancelLabel ? {} : { justifyContent: 'center' }]}>
            {cancelLabel && (
              <Pressable
                onPress={handleCancel}
                accessible
                accessibilityRole="button"
                accessibilityLabel={cancelLabel}
                style={[styles.button, styles.buttonSecondary, { borderColor: colors.border }]}
              >
                <Text style={[styles.buttonText, { color: colors.text }]}>
                  {cancelLabel}
                </Text>
              </Pressable>
            )}
            <Pressable
              onPress={handleConfirm}
              accessible
              accessibilityRole="button"
              accessibilityLabel={confirmLabel}
              style={[
                styles.button,
                styles.buttonPrimary,
                { backgroundColor: confirmBg, flex: cancelLabel ? 1 : undefined, minWidth: cancelLabel ? undefined : 180 },
              ]}
            >
              <Text style={[styles.buttonText, { color: '#FFFFFF' }]}>
                {confirmLabel}
              </Text>
            </Pressable>
          </View>
        </Animated.View>
      </View>
    </Modal>
  );
}

// ─── Provider ─────────────────────────────────────────────────────────────────

export function AccessibleAlertProvider({ children }: { children: ReactNode }) {
  const [activeAlert, setActiveAlert] = useState<AlertOptions | null>(null);

  const showAlert = useCallback((options: AlertOptions) => {
    TYPE_CONFIG[options.type ?? 'info'].haptic();
    if (options.type === 'success') sounds.success().catch(() => {});
    if (options.type === 'error') sounds.error().catch(() => {});
    setActiveAlert(options);
  }, []);

  return (
    <AlertContext.Provider value={{ showAlert }}>
      {children}
      {activeAlert && (
        <AlertModal
          options={activeAlert}
          onDismiss={() => setActiveAlert(null)}
        />
      )}
    </AlertContext.Provider>
  );
}

// ─── Styles ───────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  backdrop: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.52)',
  },
  container: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 28,
  },
  card: {
    width: '100%',
    borderRadius: 22,
    paddingHorizontal: 24,
    paddingTop: 28,
    paddingBottom: 24,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.2,
    shadowRadius: 28,
    elevation: 14,
  },
  iconCircle: {
    width: 68,
    height: 68,
    borderRadius: 34,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 18,
  },
  title: {
    fontSize: 19,
    fontWeight: '700',
    textAlign: 'center',
    marginBottom: 10,
    lineHeight: 25,
  },
  message: {
    fontSize: 15,
    lineHeight: 23,
    textAlign: 'center',
    marginBottom: 26,
  },
  buttonRow: {
    flexDirection: 'row',
    gap: 12,
    width: '100%',
  },
  button: {
    flex: 1,
    borderRadius: 13,
    paddingVertical: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  buttonPrimary: {},
  buttonSecondary: {
    borderWidth: 1.5,
  },
  buttonText: {
    fontSize: 16,
    fontWeight: '700',
  },
});
