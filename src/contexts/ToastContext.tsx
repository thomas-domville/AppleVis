import {
  AccessibilityInfo,
  Animated,
  Text,
  View,
  type ViewStyle,
} from 'react-native';
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import * as Haptics from 'expo-haptics';

// ─── Types ────────────────────────────────────────────────────────────────────

export type ToastType = 'success' | 'warning' | 'error';

const HAPTIC: Record<ToastType, () => void> = {
  success: () => Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success),
  warning: () => Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning),
  error:   () => Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error),
};

type ToastMessage = {
  id: number;
  message: string;
  type: ToastType;
};

type ToastContextValue = {
  showToast: (message: string, type?: ToastType) => void;
};

// ─── Context ──────────────────────────────────────────────────────────────────

const ToastContext = createContext<ToastContextValue>({ showToast: () => {} });

export function useToast(): ToastContextValue {
  return useContext(ToastContext);
}

// ─── Visual styles per type ───────────────────────────────────────────────────

const TYPE_STYLE: Record<ToastType, { bg: string; fg: string }> = {
  success: { bg: '#1A7F4B', fg: '#FFFFFF' },
  warning: { bg: '#92600A', fg: '#FFFFFF' },
  error:   { bg: '#B91C1C', fg: '#FFFFFF' },
};

// Approximate height of the iOS tab bar. The toast floats above this.
const TAB_BAR_HEIGHT = 49;

// ─── Toast display component ──────────────────────────────────────────────────

function ToastDisplay({ toast, onDone }: { toast: ToastMessage; onDone: () => void }) {
  const insets = useSafeAreaInsets();
  // useMemo with empty deps creates the Animated.Value once per component
  // instance. Using useState(() => ...) would also work but useMemo is more
  // semantically clear that this is a derived value, not state.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const opacity    = useMemo(() => new Animated.Value(0),  []);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const translateY = useMemo(() => new Animated.Value(16), []);

  useEffect(() => {
    // ── VoiceOver: most reliable way to ensure the message is spoken ──
    // announceForAccessibility interrupts whatever VoiceOver is currently
    // reading and speaks the string immediately, independent of focus.
    AccessibilityInfo.announceForAccessibility(toast.message);

    Animated.parallel([
      Animated.timing(opacity,    { toValue: 1, duration: 220, useNativeDriver: true }),
      Animated.timing(translateY, { toValue: 0, duration: 220, useNativeDriver: true }),
    ]).start();

    const timer = setTimeout(() => {
      Animated.parallel([
        Animated.timing(opacity,    { toValue: 0, duration: 180, useNativeDriver: true }),
        Animated.timing(translateY, { toValue: 16, duration: 180, useNativeDriver: true }),
      ]).start(({ finished }) => { if (finished) onDone(); });
    }, 3500);

    return () => clearTimeout(timer);
  }, [toast.id]); // re-runs each time a new toast arrives

  const { bg, fg } = TYPE_STYLE[toast.type];

  const containerStyle: ViewStyle = {
    position: 'absolute',
    // Sit above the tab bar + home indicator
    bottom: insets.bottom + TAB_BAR_HEIGHT + 12,
    left: 16,
    right: 16,
    zIndex: 9999,
  };

  return (
    <Animated.View
      // accessibilityRole="alert" tells VoiceOver this is an alert region.
      // accessibilityLiveRegion="assertive" is a secondary signal that
      // changes to this view should be spoken immediately.
      // The primary guarantee is the announceForAccessibility call above.
      accessible
      accessibilityRole="alert"
      accessibilityLiveRegion="assertive"
      accessibilityLabel={toast.message}
      style={[containerStyle, { opacity, transform: [{ translateY }] }]}
    >
      <View style={{
        backgroundColor: bg,
        borderRadius: 14,
        paddingHorizontal: 18,
        paddingVertical: 13,
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 3 },
        shadowOpacity: 0.22,
        shadowRadius: 10,
        elevation: 8,
      }}>
        <Text style={{ color: fg, fontSize: 15, lineHeight: 21, fontWeight: '600' }}>
          {toast.message}
        </Text>
      </View>
    </Animated.View>
  );
}

// ─── Provider ─────────────────────────────────────────────────────────────────

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toast, setToast] = useState<ToastMessage | null>(null);
  const counter = useRef(0);

  const showToast = useCallback((message: string, type: ToastType = 'success') => {
    HAPTIC[type]();
    setToast({ id: ++counter.current, message, type });
  }, []);

  return (
    <ToastContext.Provider value={{ showToast }}>
      <View style={{ flex: 1 }}>
        {children}
        {toast && (
          <ToastDisplay
            key={toast.id}
            toast={toast}
            onDone={() => setToast(null)}
          />
        )}
      </View>
    </ToastContext.Provider>
  );
}
