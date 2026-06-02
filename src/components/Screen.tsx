import { ReactNode } from 'react';
import { Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Link, useRouter } from 'expo-router';
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
  const router        = useRouter();
  const { t }         = useTranslation();
  const { colors, styles } = useTheme();

  return (
    <SafeAreaView
      style={styles.screen}
      accessibilityLanguage="en"
      onAccessibilityEscape={() => { if (router.canGoBack()) router.back(); }}
    >
      <View style={styles.content}>
        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
          <Text accessibilityRole="header" style={styles.title}>{title}</Text>
          <View style={{ flexDirection: 'row', gap: 16, alignItems: 'center' }}>
            {showSearch ? (
              <Link href="/search" accessibilityRole="button"
                accessibilityLabel={t('screen.a11ySearch')}
                accessibilityHint={t('screen.a11ySearchHint')}>
                <Text style={{ fontSize: 17, color: colors.accent, fontWeight: '700' }}>{t('common.search')}</Text>
              </Link>
            ) : null}
            {showSettings ? (
              <Link href="/settings" accessibilityRole="button"
                accessibilityLabel={t('screen.a11ySettings')}
                accessibilityHint={t('screen.a11ySettingsHint')}>
                <Text style={{ fontSize: 17, color: colors.accent, fontWeight: '700' }}>{t('common.settings')}</Text>
              </Link>
            ) : null}
          </View>
        </View>
        {refreshing !== undefined && <RefreshBar refreshing={refreshing} />}
        {children}
      </View>
    </SafeAreaView>
  );
}
