import { forwardRef } from 'react';
import { AccessibilityActionEvent, ActionSheetIOS, Image, Platform, Pressable, Text, View } from 'react-native';
import { useTheme } from '../contexts/ThemeContext';
import { usePreferences } from '../contexts/PreferencesContext';
import { sounds } from '../services/sounds';

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
  /** Which sound plays on press — 'none' and 'external' stay silent (leaving the app already has its own transition). Defaults to 'general'. */
  openSound?: 'general' | 'article' | 'podcast' | 'app' | 'external' | 'none';
  /** Structured state (e.g. "Saved", "Downloaded", "Following") exposed via accessibilityValue, in addition to any visual badge. */
  stateValue?: string;
};

export const AccessibleCard = forwardRef<View, Props>(
  function AccessibleCard({ title, meta, authorLabel, hint = 'Double tap to open.', actions = [], onAction, iconUrl, badge, badgeColor, openSound = 'general', stateValue }, ref) {
    const { styles, colors }    = useTheme();
    const { announcementLevel } = usePreferences();
    const metaLines = meta.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
    const spokenMeta = metaLines.join('. ');

    // Three announcement levels:
    //   simple — title only, no hint (quick scanning)
    //   normal — title + meta, with hint
    //   all    — title + author + meta, with hint (default)
    // Badge (e.g. "NEW") is visual-only below (accessibilityElementsHidden), so its
    // meaning must be folded into the label here — otherwise VoiceOver users never hear it.
    let label: string;
    if (announcementLevel === 'simple') {
      label = [title, badge].filter(Boolean).join('. ');
    } else if (announcementLevel === 'all' && authorLabel) {
      label = [title, badge, authorLabel, spokenMeta].filter(Boolean).join('. ');
    } else {
      label = [title, badge, spokenMeta].filter(Boolean).join('. ');
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

    function handlePress() {
      if (openSound !== 'none' && openSound !== 'external') {
        sounds.articleOpen().catch(() => {});
      }
      onAction?.(actions[0] ?? 'Open');
    }

    return (
      <Pressable
        ref={ref}
        accessible
        accessibilityRole="button"
        accessibilityLabel={label}
        accessibilityHint={resolvedHint}
        accessibilityValue={stateValue ? { text: stateValue } : undefined}
        accessibilityActions={actions.map((name) => ({ name, label: name }))}
        onAccessibilityAction={handleAccessibilityAction}
        onPress={handlePress}
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
            {metaLines.length > 0 ? (
              <View style={{ marginTop: 2 }} accessibilityElementsHidden>
                {metaLines.map((line, index) => (
                  <Text
                    key={`${line}-${index}`}
                    style={[styles.cardMeta, index > 0 && { marginTop: 2 }]}
                    numberOfLines={line.startsWith('Preview:') ? 5 : undefined}
                  >
                    {line}
                  </Text>
                ))}
              </View>
            ) : null}
          </View>
        </View>
      </Pressable>
    );
  },
);
