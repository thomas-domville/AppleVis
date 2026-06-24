import { useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator, KeyboardAvoidingView, Platform, Pressable,
  ScrollView, StyleSheet, Text, TextInput, View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { useAuth } from '../src/contexts/AuthContext';
import { useToast } from '../src/contexts/ToastContext';
import { api } from '../src/services/api';

type ProfileFields = {
  displayName: string;
  realName: string;
  bio: string;
  location: string;
  homepage: string;
  facebook: string;
  twitter: string;
  mastodon: string;
  interests: string;
};

const EMPTY: ProfileFields = {
  displayName: '', realName: '', bio: '', location: '',
  homepage: '', facebook: '', twitter: '', mastodon: '', interests: '',
};

function Field({
  label, value, onChange, hint, keyboardType = 'default', multiline = false, colors,
}: {
  label: string; value: string; onChange: (v: string) => void;
  hint?: string; keyboardType?: 'default' | 'url' | 'email-address';
  multiline?: boolean;
  colors: ReturnType<typeof useTheme>['colors'];
}) {
  return (
    <View style={{ marginBottom: 20 }}>
      <Text style={[ss.label, { color: colors.textSecondary }]}>{label}</Text>
      {hint && <Text style={[ss.hint, { color: colors.textSecondary }]}>{hint}</Text>}
      <TextInput
        value={value}
        onChangeText={onChange}
        multiline={multiline}
        numberOfLines={multiline ? 4 : 1}
        textAlignVertical={multiline ? 'top' : 'center'}
        keyboardType={keyboardType}
        autoCorrect={!['url', 'email-address'].includes(keyboardType)}
        autoCapitalize={keyboardType === 'default' ? 'sentences' : 'none'}
        style={[
          ss.input,
          multiline && ss.inputMultiline,
          { color: colors.text, backgroundColor: colors.card, borderColor: colors.border },
        ]}
        accessibilityLabel={label}
        accessibilityHint={hint}
        placeholderTextColor={colors.textSecondary}
        placeholder={`Enter ${label.toLowerCase()}`}
      />
    </View>
  );
}

export default function EditProfileScreen() {
  const { colors, styles } = useTheme();
  const { user }           = useAuth();
  const { showToast }      = useToast();
  const router             = useRouter();

  const [fields, setFields]   = useState<ProfileFields>(EMPTY);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving]   = useState(false);
  const [error, setError]     = useState('');

  useEffect(() => {
    if (!user?.csrfToken) return;
    api.account.fetchMyProfile(user.csrfToken).then((res) => {
      if (res.ok) {
        setFields({
          displayName: res.data.displayName,
          realName:    res.data.realName,
          bio:         res.data.bio,
          location:    res.data.location,
          homepage:    res.data.homepage,
          facebook:    res.data.facebook,
          twitter:     res.data.twitter,
          mastodon:    res.data.mastodon,
          interests:   res.data.interests,
        });
      }
      setLoading(false);
    }).catch(() => setLoading(false));
  }, []);

  function set(key: keyof ProfileFields) {
    return (v: string) => setFields((f) => ({ ...f, [key]: v }));
  }

  async function handleSave() {
    if (!user?.csrfToken) return;
    setSaving(true);
    setError('');
    const res = await api.account.editProfile(user.csrfToken, {
      display_name:              fields.displayName || undefined,
      field_profile_realname:    fields.realName    || undefined,
      field_profile_bio:         fields.bio         || undefined,
      field_profile_location:    fields.location    || undefined,
      field_profile_homepage:    fields.homepage    || undefined,
      field_profile_facebook:    fields.facebook    || undefined,
      field_profile_twitter:     fields.twitter     || undefined,
      field_mastodon_username:   fields.mastodon    || undefined,
      field_profile_interests:   fields.interests   || undefined,
    });
    setSaving(false);
    if (res.ok) {
      showToast('Profile updated.', 'success');
      router.back();
    } else {
      setError(res.error ?? 'Could not save profile. Please try again.');
    }
  }

  return (
    <Screen title="Edit Profile" showBack>
      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        keyboardVerticalOffset={90}
      >
        {loading
          ? (
            <View style={ss.center}>
              <ActivityIndicator size="large" color={colors.accent} />
              <Text style={{ color: colors.textSecondary, marginTop: 12 }}>Loading profile…</Text>
            </View>
          )
          : (
            <ScrollView
              contentContainerStyle={{ padding: 20, paddingBottom: 60 }}
              keyboardShouldPersistTaps="handled"
            >
              {!!error && (
                <View style={[ss.errorBox, { backgroundColor: '#FFF0F0', borderColor: '#FCA5A5' }]}>
                  <Ionicons name="alert-circle" size={18} color="#B91C1C" style={{ marginTop: 1 }} />
                  <Text style={[ss.errorText, { color: '#B91C1C' }]}
                    accessibilityRole="alert" accessibilityLiveRegion="assertive"
                  >{error}</Text>
                </View>
              )}

              <Text style={[ss.section, { color: colors.textSecondary }]}>PUBLIC INFO</Text>

              <Field label="Display Name" value={fields.displayName} onChange={set('displayName')} colors={colors} />
              <Field label="Real Name" value={fields.realName} onChange={set('realName')}
                hint="Optional — shown on your profile page." colors={colors} />
              <Field label="Bio" value={fields.bio} onChange={set('bio')} multiline colors={colors}
                hint="Tell the community a bit about yourself." />
              <Field label="Location" value={fields.location} onChange={set('location')} colors={colors} />
              <Field label="Interests" value={fields.interests} onChange={set('interests')}
                hint="Accessibility tools, Apple products, hobbies — anything you like." multiline colors={colors} />

              <Text style={[ss.section, { color: colors.textSecondary, marginTop: 8 }]}>LINKS</Text>

              <Field label="Website" value={fields.homepage} onChange={set('homepage')}
                keyboardType="url" colors={colors} />
              <Field label="Twitter / X Username" value={fields.twitter} onChange={set('twitter')}
                hint="Without the @ symbol." keyboardType="default" colors={colors} />
              <Field label="Mastodon Username" value={fields.mastodon} onChange={set('mastodon')}
                hint="Full address, e.g. user@mastodon.social" colors={colors} />
              <Field label="Facebook" value={fields.facebook} onChange={set('facebook')} colors={colors} />

              <Pressable
                onPress={handleSave}
                disabled={saving}
                accessible
                accessibilityRole="button"
                accessibilityLabel={saving ? 'Saving profile' : 'Save profile'}
                style={({ pressed }) => [
                  ss.saveBtn,
                  { backgroundColor: colors.accent },
                  (pressed || saving) && { opacity: 0.75 },
                ]}
              >
                {saving
                  ? <ActivityIndicator color="#fff" />
                  : <Text style={ss.saveBtnText}>Save Profile</Text>
                }
              </Pressable>
            </ScrollView>
          )
        }
      </KeyboardAvoidingView>
    </Screen>
  );
}

const ss = StyleSheet.create({
  center:        { flex: 1, alignItems: 'center', justifyContent: 'center' },
  section:       { fontSize: 12, fontWeight: '700', letterSpacing: 0.5, marginBottom: 12, marginTop: 4 },
  label:         { fontSize: 13, fontWeight: '600', marginBottom: 4 },
  hint:          { fontSize: 12, marginBottom: 6, opacity: 0.8 },
  input:         { fontSize: 16, paddingHorizontal: 12, paddingVertical: 10,
    borderRadius: 10, borderWidth: 1 },
  inputMultiline:{ minHeight: 100, paddingTop: 10 },
  errorBox:      { flexDirection: 'row', gap: 8, padding: 12, borderRadius: 10,
    borderWidth: 1, marginBottom: 16 },
  errorText:     { flex: 1, fontSize: 14 },
  saveBtn:       { borderRadius: 14, paddingVertical: 16, alignItems: 'center',
    marginTop: 24 },
  saveBtnText:   { color: '#fff', fontSize: 17, fontWeight: '700' },
});
