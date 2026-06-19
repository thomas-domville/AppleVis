import { useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, Switch, Text, View } from 'react-native';
import { router } from 'expo-router';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { useAuth } from '../src/contexts/AuthContext';
import { useToast } from '../src/contexts/ToastContext';
import { useAlert } from '../src/contexts/AccessibleAlertContext';
import { ALERTS } from '../src/data/alertMessages';

export default function DeleteAccount() {
  const { colors, styles } = useTheme();
  const auth               = useAuth();
  const { showToast }      = useToast();
  const { showAlert }      = useAlert();
  const [confirmed, setConfirmed] = useState(false);
  const [loading,   setLoading]   = useState(false);

  async function handleDelete() {
    if (!confirmed || loading) return;
    setLoading(true);
    const result = await auth.deleteAccount();
    setLoading(false);
    if (result.ok) {
      showToast('Your account has been deleted.', 'success');
      router.replace('/(tabs)');
    } else {
      showAlert(ALERTS.account.deleteFailed(result.error));
    }
  }

  return (
    <Screen title="Delete Account" showSettings={false}>
      <ScrollView contentInsetAdjustmentBehavior="automatic">

        {/* Warning card */}
        <View style={[styles.card, { borderColor: '#FCA5A5', borderWidth: 1, marginBottom: 20 }]}>
          <Text style={{ fontSize: 17, fontWeight: '700', color: '#B91C1C', marginBottom: 10 }}>
            This cannot be undone
          </Text>
          <Text style={{ fontSize: 15, lineHeight: 22, color: colors.text, marginBottom: 12 }}>
            Deleting your account permanently removes your profile, posts, forum history, and all other data from applevis.com. This action is immediate and irreversible.
          </Text>
          <Text style={{ fontSize: 15, lineHeight: 22, color: colors.textSecondary }}>
            Your locally stored items — downloads, cache, and settings — are not affected and will remain on this device until you clear them in Storage & Cache.
          </Text>
        </View>

        {/* Confirmation toggle */}
        <Pressable
          onPress={() => setConfirmed(v => !v)}
          accessible
          accessibilityRole="checkbox"
          accessibilityState={{ checked: confirmed }}
          accessibilityLabel="I understand this will permanently delete my account and all my data"
          style={({ pressed }) => ({
            flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 28,
            padding: 16, backgroundColor: colors.card, borderRadius: 12,
            borderWidth: 1, borderColor: confirmed ? '#B91C1C' : colors.border,
            opacity: pressed ? 0.85 : 1,
          })}
        >
          <Switch
            value={confirmed}
            onValueChange={setConfirmed}
            accessibilityElementsHidden
            importantForAccessibility="no-hide-descendants"
            trackColor={{ false: colors.border, true: '#FCA5A5' }}
            thumbColor={confirmed ? '#B91C1C' : colors.textSecondary}
          />
          <Text style={{ flex: 1, fontSize: 15, lineHeight: 22, color: colors.text }}>
            I understand this will permanently delete my account and all my data
          </Text>
        </Pressable>

        {/* Delete button */}
        <Pressable
          onPress={handleDelete}
          disabled={!confirmed || loading}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Delete my account"
          accessibilityState={{ disabled: !confirmed || loading }}
          style={({ pressed }) => ({
            backgroundColor: confirmed && !loading ? '#B91C1C' : '#FCA5A5',
            borderRadius: 12, paddingVertical: 16, alignItems: 'center',
            opacity: pressed ? 0.85 : 1,
          })}
        >
          {loading
            ? <ActivityIndicator color="#FFFFFF" />
            : <Text style={{ color: '#FFFFFF', fontSize: 16, fontWeight: '700' }}>
                Delete My Account
              </Text>
          }
        </Pressable>

        <View style={{ height: 48 }} />
      </ScrollView>
    </Screen>
  );
}
