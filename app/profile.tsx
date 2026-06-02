import { Linking, Pressable, ScrollView, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { useAuth } from '../src/contexts/AuthContext';
import { useToast } from '../src/contexts/ToastContext';
import { useSavedItems } from '../src/hooks/useSavedItems';

const BASE = 'https://www.applevis.com';

export default function Profile() {
  const router        = useRouter();
  const { colors, styles } = useTheme();
  const auth          = useAuth();
  const { showToast } = useToast();

  const savedTopics    = useSavedItems('forumTopic');
  const savedApps      = useSavedItems('appListing');
  const savedResources = useSavedItems('resource');
  // Counts derived from the items array returned by each hook
  const topicCount    = savedTopics.items.length;
  const appCount      = savedApps.items.length;
  const resourceCount = savedResources.items.length;

  async function handleSignOut() {
    await auth.signOut();
    showToast('Signed out.', 'success');
    router.replace('/(tabs)');
  }

  if (!auth.isSignedIn || !auth.user) {
    return (
      <Screen title="Profile" showSettings={false}>
        <ScrollView>
          <View style={[styles.card, { alignItems: 'center', paddingVertical: 32 }]}
            accessible accessibilityLabel="You are not signed in. Sign in to view your profile.">
            <Ionicons name="person-circle-outline" size={56} color={colors.textSecondary} />
            <Text style={[styles.cardTitle, { marginTop: 12, textAlign: 'center' }]}>Not signed in</Text>
            <Text style={[styles.cardMeta, { textAlign: 'center', marginTop: 4 }]}>
              Sign in to see your profile, saved items, and post history.
            </Text>
            <Pressable
              onPress={() => router.push('/settings')}
              accessible accessibilityRole="button" accessibilityLabel="Go to Settings to sign in"
              style={{ marginTop: 16, backgroundColor: colors.accent, borderRadius: 12,
                paddingHorizontal: 24, paddingVertical: 12 }}
            >
              <Text style={{ color: colors.accentText, fontWeight: '700', fontSize: 15 }}>Sign In</Text>
            </Pressable>
          </View>
        </ScrollView>
      </Screen>
    );
  }

  const profileUrl = `${BASE}/users/${encodeURIComponent(auth.user.name)}`;

  return (
    <Screen title="Profile" showSettings={false}>
      <ScrollView showsVerticalScrollIndicator={false}>

        {/* Identity card */}
        <View style={[styles.card, { marginBottom: 8 }]}
          accessible
          accessibilityLabel={`Signed in as ${auth.user.name}. AppleVis community member.`}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 14 }}>
            <View style={{ width: 52, height: 52, borderRadius: 26,
              backgroundColor: colors.accent, alignItems: 'center', justifyContent: 'center' }}
              accessibilityElementsHidden>
              <Text style={{ fontSize: 22, fontWeight: '700', color: colors.accentText }}>
                {auth.user.name.charAt(0).toUpperCase()}
              </Text>
            </View>
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: 20, fontWeight: '700', color: colors.text }}>{auth.user.name}</Text>
              <Text style={{ fontSize: 14, color: colors.textSecondary }}>AppleVis community member</Text>
            </View>
          </View>

          {/* Profile link */}
          <Pressable
            onPress={() => Linking.openURL(profileUrl)}
            accessible accessibilityRole="button"
            accessibilityLabel="View full profile on applevis.com"
            accessibilityHint="Opens your AppleVis profile page in Safari."
            style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
              backgroundColor: colors.pill, borderRadius: 8,
              paddingHorizontal: 12, paddingVertical: 8, alignSelf: 'flex-start' }}
          >
            <Ionicons name="open-outline" size={14} color={colors.pillText} />
            <Text style={{ color: colors.pillText, fontWeight: '600', fontSize: 13 }}>View on applevis.com</Text>
          </Pressable>
        </View>

        {/* Saved items summary */}
        <Text style={[styles.cardTitle, { marginBottom: 8 }]} accessibilityRole="header">
          Saved Items
        </Text>
        {[
          { label: 'Forum Topics', count: topicCount,    icon: 'chatbubbles-outline', route: '/(tabs)/forums' },
          { label: 'Apps',         count: appCount,      icon: 'apps-outline',        route: '/(tabs)/apps' },
          { label: 'Resources',    count: resourceCount, icon: 'library-outline',     route: '/(tabs)/resources' },
        ].map(({ label, count, icon, route }) => (
          <Pressable
            key={label}
            onPress={() => router.push(route as any)}
            accessible accessibilityRole="button"
            accessibilityLabel={`${label}: ${count} saved. Tap to view.`}
            style={({ pressed }) => [styles.card, { marginBottom: 8 }, pressed && { opacity: 0.85 }]}
          >
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
              <Ionicons name={icon as any} size={22} color={colors.accent} />
              <View style={{ flex: 1 }}>
                <Text style={styles.cardTitle}>{label}</Text>
                <Text style={styles.cardMeta}>{count} saved</Text>
              </View>
              <Ionicons name="chevron-forward" size={16} color={colors.textSecondary} />
            </View>
          </Pressable>
        ))}

        {/* Account actions */}
        <Text style={[styles.cardTitle, { marginTop: 8, marginBottom: 8 }]} accessibilityRole="header">
          Account
        </Text>

        <Pressable
          onPress={() => Linking.openURL(`${BASE}/user`)}
          accessible accessibilityRole="button"
          accessibilityLabel="Account settings on applevis.com"
          accessibilityHint="Opens your account settings in Safari."
          style={({ pressed }) => [styles.card, { marginBottom: 8 }, pressed && { opacity: 0.85 }]}
        >
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
            <Ionicons name="settings-outline" size={22} color={colors.accent} />
            <View style={{ flex: 1 }}>
              <Text style={styles.cardTitle}>Account Settings</Text>
              <Text style={styles.cardMeta}>Manage your profile, email, and password on applevis.com.</Text>
            </View>
            <Ionicons name="open-outline" size={16} color={colors.textSecondary} />
          </View>
        </Pressable>

        <Pressable
          onPress={handleSignOut}
          accessible accessibilityRole="button"
          accessibilityLabel="Sign out of AppleVis"
          accessibilityHint="Removes your account session from this device."
          style={({ pressed }) => [styles.card, { backgroundColor: '#FFF0F0', borderColor: '#FCA5A5',
            borderWidth: 1, marginBottom: 8 }, pressed && { opacity: 0.85 }]}
        >
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
            <Ionicons name="log-out-outline" size={22} color="#B91C1C" />
            <View style={{ flex: 1 }}>
              <Text style={[styles.cardTitle, { color: '#B91C1C' }]}>Sign Out</Text>
              <Text style={styles.cardMeta}>Removes your session from this device only.</Text>
            </View>
          </View>
        </Pressable>

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
