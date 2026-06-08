import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { useColorScheme } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { createStyles } from '../theme/styles';
import { usePreferences } from './PreferencesContext';
import { THEMES, DEFAULT_THEME_ID } from '../theme/themes';
import type { ThemeId, ThemeColors } from '../theme/themes';

const STORAGE_KEY = '@applevis_theme';

type ThemeContextValue = {
  themeId: ThemeId;
  colors: ThemeColors;
  styles: ReturnType<typeof createStyles>;
  isDark: boolean;
  setTheme: (id: ThemeId) => void;
};

const ThemeContext = createContext<ThemeContextValue | null>(null);

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const systemScheme = useColorScheme();
  const [themeId, setThemeId] = useState<ThemeId>(DEFAULT_THEME_ID);
  const { cardDensity } = usePreferences();

  useEffect(() => {
    AsyncStorage.getItem(STORAGE_KEY).then((saved) => {
      if (saved && saved in THEMES) setThemeId(saved as ThemeId);
    });
  }, []);

  const setTheme = useCallback((id: ThemeId) => {
    setThemeId(id);
    AsyncStorage.setItem(STORAGE_KEY, id).catch(() => {});
  }, []);

  const colors = useMemo<ThemeColors>(() => {
    if (themeId === 'system') {
      return systemScheme === 'dark' ? THEMES.dark.colors : THEMES.light.colors;
    }
    if (themeId === 'oppositeToSystem') {
      return systemScheme === 'dark' ? THEMES.light.colors : THEMES.dark.colors;
    }
    return THEMES[themeId].colors;
  }, [themeId, systemScheme]);

  const isDark = useMemo(() => {
    if (themeId === 'system') return systemScheme === 'dark';
    if (themeId === 'oppositeToSystem') return systemScheme !== 'dark';
    return THEMES[themeId].isDark;
  }, [themeId, systemScheme]);

  const styles = useMemo(() => createStyles(colors, cardDensity), [colors, cardDensity]);

  const value = useMemo<ThemeContextValue>(
    () => ({ themeId, colors, styles, isDark, setTheme }),
    [themeId, colors, styles, isDark, setTheme],
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme(): ThemeContextValue {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error('useTheme must be used inside ThemeProvider');
  return ctx;
}
