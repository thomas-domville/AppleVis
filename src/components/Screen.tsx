import { ReactNode } from 'react';
import { SafeAreaView, Text, View } from 'react-native';
import { Link } from 'expo-router';
import { styles } from '../theme/styles';

type Props = { title: string; children: ReactNode; showSettings?: boolean };

export function Screen({ title, children, showSettings = true }: Props) {
  return (
    <SafeAreaView style={styles.screen}>
      <View style={styles.content}>
        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
          <Text accessibilityRole="header" style={styles.title}>{title}</Text>
          {showSettings ? (
            <Link href="/settings" accessibilityRole="button" accessibilityLabel="Settings and profile" accessibilityHint="Opens AppleVis settings, profile, help, and support.">
              <Text style={{ fontSize: 17, color: '#0A84FF', fontWeight: '700' }}>Settings</Text>
            </Link>
          ) : null}
        </View>
        {children}
      </View>
    </SafeAreaView>
  );
}
