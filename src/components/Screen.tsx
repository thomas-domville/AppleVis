import { ReactNode, useCallback } from 'react';
import { Pressable, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useTranslation } from 'react-i18next';
import { RefreshBar } from './RefreshBar';
import { useTheme } from '../contexts/ThemeContext';
import { usePlayer } from '../contexts/PlayerContext';

type Props = {
  title: string;
  children: ReactNode;
  showSettings?: boolean;
  showSearch?: boolean;
  showBack?: boolean;
  refreshing?: boolean;
};

export function Screen({ title, children, showSettings = true, showSearch = false, showBack = true, refreshing }: Props) {
  const router             = useRouter();
  const { t }              = useTranslation();
  const { colors, styles } = useTheme();
  const player             = usePlayer();

  // VoiceOver magic tap (two-finger double-tap): play/pause from any screen.
  // Returns without handling when no episode is loaded so iOS can pass the
  // event to the next responder (e.g. a system media control).
  const onMagicTap = useCallback(() => {
    if (!player.episode) return;
    if (player.isPlaying) player.pause();
    else player.play();
  }, [player]);

  const showActionRow = showSearch || showSettings;

  return (
    <SafeAreaView
      style={styles.screen}
      accessibilityLanguage="en"
      onAccessibilityEscape={() => { if (showBack && router.canGoBack()) router.back(); }}
      onMagicTap={onMagicTap}
    >
      <View style={styles.content}>

        {/* Back button — shown on pushed screens, suppressed on tab root screens */}
        {showBack && router.canGoBack() && (
          <Pressable
            onPress={() => router.back()}
            accessibilityRole="button"
            accessibilityLabel="Go back"
            hitSlop={8}
            style={{ flexDirection: 'row', alignItems: 'center', gap: 2, marginBottom: 2, alignSelf: 'flex-start' }}
          >
            <Ionicons name="chevron-back" size={20} color={colors.accent} accessibilityElementsHidden />
            <Text style={{ fontSize: 17, color: colors.accent, fontWeight: '400' }}>Back</Text>
          </Pressable>
        )}

        {/* Screen title */}
        <Text accessibilityRole="header" style={styles.title}>{title}</Text>

        {/* Search bar + Settings button — each a single focusable Pressable */}
        {showActionRow && (
          <View
            style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginTop: 8, marginBottom: 4 }}
            accessible={false}
          >
            {showSearch && (
              <Pressable
                onPress={() => router.push('/search')}
                accessibilityRole="search"
                accessibilityLabel={t('screen.a11ySearch')}
                accessibilityHint={t('screen.a11ySearchHint')}
                style={{
                  flex: 1,
                  flexDirection: 'row',
                  alignItems: 'center',
                  gap: 8,
                  backgroundColor: colors.inputBackground,
                  borderRadius: 10,
                  borderWidth: 1,
                  borderColor: colors.border,
                  paddingHorizontal: 10,
                  paddingVertical: 9,
                }}
              >
                <Ionicons name="search-outline" size={16} color={colors.textSecondary} accessibilityElementsHidden />
                <Text style={{ fontSize: 15, color: colors.textSecondary }}>
                  {t('screen.a11ySearch')}
                </Text>
              </Pressable>
            )}

            {showSettings && (
              <Pressable
                onPress={() => router.push('/profile')}
                accessibilityRole="button"
                accessibilityLabel="Profile and Settings"
                accessibilityHint="Opens your profile, account, and app settings."
                hitSlop={8}
                style={{
                  padding: 8,
                  borderRadius: 10,
                  backgroundColor: colors.inputBackground,
                  borderWidth: 1,
                  borderColor: colors.border,
                }}
              >
                <Ionicons name="person-circle-outline" size={20} color={colors.accent} accessibilityElementsHidden />
              </Pressable>
            )}
          </View>
        )}

        {refreshing !== undefined && <RefreshBar refreshing={refreshing} />}
        {children}
      </View>
    </SafeAreaView>
  );
}
