import { ReactNode } from 'react';
import { Pressable, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useTranslation } from 'react-i18next';
import { RefreshBar } from './RefreshBar';
import { useTheme } from '../contexts/ThemeContext';

type Props = {
  title: string;
  children: ReactNode;
  showSettings?: boolean;
  showSearch?: boolean;
  refreshing?: boolean;
};

export function Screen({ title, children, showSettings = true, showSearch = false, refreshing }: Props) {
  const router             = useRouter();
  const { t }              = useTranslation();
  const { colors, styles } = useTheme();

  const showActionRow = showSearch || showSettings;

  return (
    <SafeAreaView
      style={styles.screen}
      accessibilityLanguage="en"
      onAccessibilityEscape={() => { if (router.canGoBack()) router.back(); }}
    >
      <View style={styles.content}>

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
                onPress={() => router.push('/settings')}
                accessibilityRole="button"
                accessibilityLabel={t('screen.a11ySettings')}
                accessibilityHint={t('screen.a11ySettingsHint')}
                hitSlop={8}
                style={{
                  padding: 8,
                  borderRadius: 10,
                  backgroundColor: colors.inputBackground,
                  borderWidth: 1,
                  borderColor: colors.border,
                }}
              >
                <Ionicons name="settings-outline" size={20} color={colors.accent} accessibilityElementsHidden />
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
