import { forwardRef } from 'react';
import { AccessibilityActionEvent, ActionSheetIOS, Platform, Pressable, Text, View } from 'react-native';
import { useTheme } from '../contexts/ThemeContext';
import { usePreferences } from '../contexts/PreferencesContext';

type Props = {
  title: string;
  meta: string;
  hint?: string;
  actions?: string[];
  onAction?: (actionName: string) => void;
};

export const AccessibleCard = forwardRef<View, Props>(
  function AccessibleCard({ title, meta, hint = 'Double tap to open.', actions = [], onAction }, ref) {
    const { styles }           = useTheme();
    const { announcementLevel } = usePreferences();

    // Build the VoiceOver label from the announcement level preference.
    const label = announcementLevel === 'simple'
      ? title
      : [title, meta].filter(Boolean).join('. ');

    const resolvedHint = announcementLevel === 'simple' ? undefined : hint;

    function handleAccessibilityAction(event: AccessibilityActionEvent) {
      onAction?.(event.nativeEvent.actionName);
    }

    function handleLongPress() {
      if (actions.length === 0 || !onAction) return;
      if (Platform.OS === 'ios') {
        ActionSheetIOS.showActionSheetWithOptions(
          { title, options: ['Cancel', ...actions], cancelButtonIndex: 0 },
          (i) => { if (i > 0) onAction(actions[i - 1]); },
        );
      }
    }

    return (
      <Pressable
        ref={ref}
        accessible
        accessibilityRole="button"
        accessibilityLabel={label}
        accessibilityHint={resolvedHint}
        accessibilityActions={actions.map((name) => ({ name, label: name }))}
        onAccessibilityAction={handleAccessibilityAction}
        onPress={() => onAction?.('Open')}
        onLongPress={handleLongPress}
        delayLongPress={500}
        style={({ pressed }) => [styles.card, pressed && { opacity: 0.85 }]}
      >
        <Text style={styles.cardTitle}>{title}</Text>
        {meta ? <Text style={styles.cardMeta}>{meta}</Text> : null}
      </Pressable>
    );
  },
);
