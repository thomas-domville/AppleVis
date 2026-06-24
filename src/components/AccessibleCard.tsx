import { forwardRef } from 'react';
import { AccessibilityActionEvent, ActionSheetIOS, Image, Platform, Pressable, Text, View } from 'react-native';
import { useTheme } from '../contexts/ThemeContext';
import { usePreferences } from '../contexts/PreferencesContext';

type Props = {
  title: string;
  meta: string;
  /** Author / submitter name — announced in 'all' level only. Pass e.g. "By JohnDoe". */
  authorLabel?: string;
  hint?: string;
  actions?: string[];
  onAction?: (actionName: string) => void;
  /** Optional app icon shown as a 44pt rounded thumbnail beside the title. */
  iconUrl?: string;
  /** Short badge label (e.g. "NEW") rendered as a colored pill in the top-right corner. */
  badge?: string;
  /** Background color for the badge pill. Defaults to the theme accent color. */
  badgeColor?: string;
};

export const AccessibleCard = forwardRef<View, Props>(
  function AccessibleCard({ title, meta, authorLabel, hint = 'Double tap to open.', actions = [], onAction, iconUrl, badge, badgeColor }, ref) {
    const { styles, colors }    = useTheme();
    const { announcementLevel } = usePreferences();

    // Three announcement levels:
    //   simple — title only, no hint (quick scanning)
    //   normal — title + meta, with hint
    //   all    — title + author + meta, with hint (default)
    let label: string;
    if (announcementLevel === 'simple') {
      label = title;
    } else if (announcementLevel === 'all' && authorLabel) {
      label = [title, authorLabel, meta].filter(Boolean).join('. ');
    } else {
      label = [title, meta].filter(Boolean).join('. ');
    }

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
        onPress={() => onAction?.(actions[0] ?? 'Open')}
        onLongPress={handleLongPress}
        delayLongPress={500}
        style={({ pressed }) => [styles.card, pressed && { opacity: 0.85 }]}
      >
        <View style={iconUrl ? { flexDirection: 'row', alignItems: 'flex-start', gap: 12 } : undefined}>
          {iconUrl && (
            <Image
              source={{ uri: iconUrl }}
              style={{ width: 44, height: 44, borderRadius: 10 }}
              accessibilityElementsHidden
            />
          )}
          <View style={iconUrl ? { flex: 1 } : undefined}>
            <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 8 }}>
              <Text style={[styles.cardTitle, { flex: 1 }]}>{title}</Text>
              {badge && (
                <View
                  style={{
                    backgroundColor: badgeColor ?? colors.accent,
                    borderRadius: 6, paddingHorizontal: 6, paddingVertical: 2,
                    alignSelf: 'flex-start',
                  }}
                  accessibilityElementsHidden
                >
                  <Text style={{ fontSize: 10, fontWeight: '700', color: '#FFF', letterSpacing: 0.5 }}>
                    {badge}
                  </Text>
                </View>
              )}
            </View>
            {meta ? <Text style={styles.cardMeta}>{meta}</Text> : null}
          </View>
        </View>
      </Pressable>
    );
  },
);
