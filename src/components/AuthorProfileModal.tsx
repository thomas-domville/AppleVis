import { useEffect, useState, type ComponentProps } from 'react';
import {
  Linking,
  ActivityIndicator, KeyboardAvoidingView, Modal, Platform,
  Pressable, ScrollView, StyleSheet, Text, TextInput, View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { useTheme } from '../contexts/ThemeContext';
import { api } from '../services/api';

const APPLEVIS_BASE = 'https://www.applevis.com';

type AuthorProfile = {
  uuid: string;
  displayName: string;
  username: string;
  memberSince: string;
  numericUid: number;
  profileUrl?: string;
  location?: string;
  bio?: string;
  website?: string;
};

type Props = {
  visible: boolean;
  onClose: () => void;
  authorId: string;
  authorName: string;
  isSignedIn: boolean;
  showToast: (msg: string, type?: 'success' | 'warning' | 'error') => void;
};

export function AuthorProfileModal({
  visible, onClose, authorId, authorName, isSignedIn, showToast,
}: Props) {
  const { colors } = useTheme();

  const [profile,  setProfile]  = useState<AuthorProfile | null>(null);
  const [loading,  setLoading]  = useState(false);
  const [view,     setView]     = useState<'profile' | 'compose'>('profile');
  const [subject,  setSubject]  = useState('');
  const [message,  setMessage]  = useState('');
  const [sending,  setSending]  = useState(false);

  useEffect(() => {
    if (!visible || !authorId) return;
    setView('profile');
    setProfile(null);
    setLoading(true);
    api.users.profile(authorId).then((res) => {
      setLoading(false);
      if (res.ok) setProfile(res.data);
    });
  }, [visible, authorId]);

  function handleOpenCompose() {
    if (!isSignedIn) {
      showToast('Sign in to contact this member.', 'warning');
      return;
    }
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    setSubject('');
    setMessage('');
    setView('compose');
  }

  async function handleSend() {
    if (!profile || !profile.numericUid || !subject.trim() || !message.trim()) {
      showToast('Please enter a subject and message.', 'warning');
      return;
    }
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    setSending(true);
    const res = await api.users.sendContact(profile.numericUid, subject.trim(), message.trim());
    setSending(false);
    if (res.ok) {
      showToast(`Message sent to ${profile.displayName}.`, 'success');
      setView('profile');
    } else {
      // Expected during testing if the Drupal contact_message REST resource
      // has not yet been enabled (Admin → Config → Services → REST Resources).
      showToast(
        'Contact messaging is coming soon — pending server configuration. Visit applevis.com to reach this member in the meantime.',
        'warning',
      );
    }
  }

  const displayName = profile?.displayName || authorName;
  const firstName   = displayName.split(' ')[0];
  const initials    = displayName.charAt(0).toUpperCase();
  const profilePathName = profile?.username || displayName;
  const profileUrl = profile?.profileUrl || (profilePathName ? `${APPLEVIS_BASE}/users/${encodeURIComponent(profilePathName)}` : '');
  const contactAvailable = !!profile?.numericUid;
  const visibleDetails = [
    profile?.location ? { label: 'Location', value: profile.location, icon: 'location-outline' as const } : null,
    profile?.website ? { label: 'Website', value: profile.website, icon: 'link-outline' as const } : null,
    profile?.bio ? { label: 'Bio', value: profile.bio, icon: 'person-circle-outline' as const } : null,
  ].filter(Boolean) as Array<{ label: string; value: string; icon: ComponentProps<typeof Ionicons>['name'] }>;

  const memberSinceLabel = profile?.memberSince
    ? `Member since ${new Date(profile.memberSince).toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}`
    : '';

  function handleOpenProfile() {
    if (!profileUrl) {
      showToast('Could not open this profile.', 'error');
      return;
    }
    Linking.openURL(profileUrl).catch(() => showToast('Could not open this profile.', 'error'));
  }

  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      onRequestClose={onClose}
      accessibilityViewIsModal
    >
      {/* Scrim */}
      <Pressable
        style={[StyleSheet.absoluteFill, { backgroundColor: 'rgba(0,0,0,0.45)' }]}
        onPress={onClose}
        accessible={false}
      />

      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        style={{ flex: 1, justifyContent: 'flex-end' }}
      >
        <View
          onAccessibilityEscape={onClose}
          style={{
            backgroundColor: colors.card,
            borderTopLeftRadius: 20,
            borderTopRightRadius: 20,
            maxHeight: '85%',
            paddingBottom: Platform.OS === 'ios' ? 34 : 16,
          }}
        >
          {/* Drag handle — visual only */}
          <View
            style={{ alignItems: 'center', paddingTop: 12, paddingBottom: 6 }}
            accessibilityElementsHidden
            importantForAccessibility="no-hide-descendants"
          >
            <View style={{ width: 36, height: 4, borderRadius: 2, backgroundColor: colors.border }} />
          </View>

          <ScrollView
            keyboardShouldPersistTaps="handled"
            contentContainerStyle={{ paddingHorizontal: 20, paddingTop: 4, paddingBottom: 8 }}
          >
            {view === 'profile' ? (
              <>
                {/* ── Profile header ─────────────────────────────────── */}
                <View
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 20 }}
                  accessible
                  accessibilityLabel={[
                    displayName,
                    profile?.username && profile.username !== displayName ? `@${profile.username}` : null,
                    memberSinceLabel || null,
                  ].filter(Boolean).join('. ')}
                  accessibilityRole="header"
                >
                  <View style={{
                    width: 58, height: 58, borderRadius: 29,
                    backgroundColor: colors.accent,
                    alignItems: 'center', justifyContent: 'center', flexShrink: 0,
                  }}
                    accessibilityElementsHidden
                  >
                    <Text style={{ fontSize: 26, fontWeight: '700', color: colors.accentText }}>
                      {initials}
                    </Text>
                  </View>

                  <View style={{ flex: 1 }} accessibilityElementsHidden>
                    <Text style={{ fontSize: 18, fontWeight: '700', color: colors.text }}>
                      {displayName}
                    </Text>
                    {profile?.username && profile.username !== displayName && (
                      <Text style={{ fontSize: 14, color: colors.textSecondary, marginTop: 1 }}>
                        @{profile.username}
                      </Text>
                    )}
                    {loading && !profile
                      ? <ActivityIndicator size="small" color={colors.accent} style={{ alignSelf: 'flex-start', marginTop: 6 }} />
                      : memberSinceLabel
                        ? <Text style={{ fontSize: 13, color: colors.textSecondary, marginTop: 3 }}>{memberSinceLabel}</Text>
                        : null
                    }
                  </View>
                </View>

                {/* ── Contact button ─────────────────────────────────── */}
                {visibleDetails.length > 0 && (
                  <View style={{ marginBottom: 14 }}>
                    {visibleDetails.map((detail) => (
                      <View
                        key={detail.label}
                        style={styles.detailRow(colors)}
                        accessible
                        accessibilityLabel={`${detail.label}: ${detail.value}`}
                      >
                        <Ionicons name={detail.icon} size={17} color={colors.textSecondary} accessibilityElementsHidden />
                        <View style={{ flex: 1 }} accessibilityElementsHidden>
                          <Text style={styles.detailLabel(colors)}>{detail.label}</Text>
                          <Text style={styles.detailValue(colors)}>{detail.value}</Text>
                        </View>
                      </View>
                    ))}
                  </View>
                )}

                {visibleDetails.length === 0 && !loading && (
                  <View
                    style={styles.detailRow(colors)}
                    accessible
                    accessibilityLabel="AppleVis only exposes limited public profile details for this member in the app."
                  >
                    <Ionicons name="information-circle-outline" size={17} color={colors.textSecondary} accessibilityElementsHidden />
                    <Text style={[styles.detailValue(colors), { flex: 1 }]} accessibilityElementsHidden>
                      AppleVis only exposes limited public profile details for this member in the app.
                    </Text>
                  </View>
                )}

                <View style={{ gap: 10, marginBottom: 14 }}>
                  {contactAvailable && (
                    <Pressable
                      onPress={handleOpenCompose}
                      accessible
                      accessibilityRole="button"
                      accessibilityLabel={`Contact ${firstName}`}
                      accessibilityHint="Opens a private message form. Your email address will not be shared."
                      style={({ pressed }) => styles.primaryButton(colors, pressed)}
                    >
                      <Ionicons name="mail-outline" size={18} color={colors.accentText} accessibilityElementsHidden />
                      <Text style={{ fontSize: 15, fontWeight: '700', color: colors.accentText }}>
                        {`Contact ${firstName}`}
                      </Text>
                    </Pressable>
                  )}

                  <Pressable
                    onPress={handleOpenProfile}
                    accessible
                    accessibilityRole="button"
                    accessibilityLabel={`View ${displayName}'s full profile on AppleVis`}
                    accessibilityHint="Opens applevis.com in Safari."
                    style={({ pressed }) => styles.secondaryButton(colors, pressed)}
                  >
                    <Ionicons name="open-outline" size={18} color={colors.accent} accessibilityElementsHidden />
                    <Text style={{ fontSize: 15, fontWeight: '700', color: colors.accent }}>
                      View Full Profile
                    </Text>
                  </Pressable>
                </View>

                {/* ── Privacy note ───────────────────────────────────── */}
                {contactAvailable && (
                  <View
                    style={{
                      flexDirection: 'row', alignItems: 'flex-start', gap: 8,
                      backgroundColor: colors.pill, borderRadius: 8, padding: 12, marginBottom: 16,
                    }}
                    accessible
                    accessibilityLabel="Privacy: messages are routed through AppleVis. Neither party sees the other's email address."
                  >
                    <Ionicons
                      name="shield-checkmark-outline" size={16} color={colors.textSecondary}
                      accessibilityElementsHidden style={{ marginTop: 1 }}
                    />
                    <Text style={{ fontSize: 13, color: colors.textSecondary, flex: 1, lineHeight: 19 }}
                      accessibilityElementsHidden>
                      Messages are routed through AppleVis. Neither party's email address is revealed.
                    </Text>
                  </View>
                )}
              </>
            ) : (
              <>
                {/* ── Compose header ─────────────────────────────────── */}
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 20 }}>
                  <Pressable
                    onPress={() => setView('profile')}
                    accessible
                    accessibilityRole="button"
                    accessibilityLabel="Back to profile"
                    style={({ pressed }) => ({ opacity: pressed ? 0.55 : 1, padding: 2 })}
                  >
                    <Ionicons name="arrow-back" size={22} color={colors.accent} />
                  </Pressable>
                  <Text
                    accessible
                    accessibilityRole="header"
                    style={{ fontSize: 17, fontWeight: '700', color: colors.text }}
                  >
                    {`Contact ${firstName}`}
                  </Text>
                </View>

                {/* ── Subject ────────────────────────────────────────── */}
                <Text style={styles.fieldLabel(colors)}>Subject</Text>
                <TextInput
                  value={subject}
                  onChangeText={setSubject}
                  placeholder="What is this about?"
                  placeholderTextColor={colors.textSecondary}
                  accessible
                  accessibilityLabel="Subject"
                  returnKeyType="next"
                  style={styles.input(colors)}
                />

                {/* ── Message ────────────────────────────────────────── */}
                <Text style={styles.fieldLabel(colors)}>Message</Text>
                <TextInput
                  value={message}
                  onChangeText={setMessage}
                  placeholder="Write your message…"
                  placeholderTextColor={colors.textSecondary}
                  accessible
                  accessibilityLabel="Message"
                  multiline
                  textAlignVertical="top"
                  style={[styles.input(colors), { minHeight: 120 }]}
                />

                {/* ── Privacy note ───────────────────────────────────── */}
                <Text
                  style={{ fontSize: 12, color: colors.textSecondary, marginBottom: 16, lineHeight: 18 }}
                  accessible
                  accessibilityLabel={`Privacy: your email address will not be shared with ${firstName}.`}
                >
                  {`Your email address will not be shared with ${firstName}.`}
                </Text>

                {/* ── Send ───────────────────────────────────────────── */}
                <Pressable
                  onPress={handleSend}
                  disabled={sending || !subject.trim() || !message.trim()}
                  accessible
                  accessibilityRole="button"
                  accessibilityLabel={sending ? 'Sending, please wait' : 'Send message'}
                  style={({ pressed }) => ({
                    flexDirection: 'row', alignItems: 'center', justifyContent: 'center',
                    gap: 8, paddingVertical: 14, borderRadius: 12,
                    backgroundColor: colors.accent, marginBottom: 4,
                    opacity: (pressed || sending || !subject.trim() || !message.trim()) ? 0.55 : 1,
                  })}
                >
                  {sending
                    ? <ActivityIndicator size="small" color={colors.accentText} accessibilityElementsHidden />
                    : <Ionicons name="send-outline" size={17} color={colors.accentText} accessibilityElementsHidden />
                  }
                  <Text style={{ fontSize: 15, fontWeight: '700', color: colors.accentText }}>
                    {sending ? 'Sending…' : 'Send Message'}
                  </Text>
                </Pressable>
              </>
            )}

            {/* ── Close ──────────────────────────────────────────────── */}
            <Pressable
              onPress={onClose}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Close"
              style={({ pressed }) => ({
                alignItems: 'center', paddingVertical: 14, marginTop: 6, opacity: pressed ? 0.55 : 1,
              })}
            >
              <Text style={{ fontSize: 16, color: colors.textSecondary }}>Close</Text>
            </Pressable>
          </ScrollView>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}

// Style helpers — functions so they pick up theme colors at call time
const styles = {
  detailRow: (colors: any) => ({
    flexDirection: 'row' as const,
    alignItems: 'flex-start' as const,
    gap: 10,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: 8,
    backgroundColor: colors.background,
    padding: 12,
    marginBottom: 10,
  }),
  detailLabel: (colors: any) => ({
    fontSize: 12,
    fontWeight: '700' as const,
    color: colors.textSecondary,
    textTransform: 'uppercase' as const,
    letterSpacing: 0,
    marginBottom: 3,
  }),
  detailValue: (colors: any) => ({
    fontSize: 14,
    lineHeight: 20,
    color: colors.text,
  }),
  primaryButton: (colors: any, pressed: boolean) => ({
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
    gap: 8,
    paddingVertical: 13,
    borderRadius: 8,
    backgroundColor: colors.accent,
    opacity: pressed ? 0.75 : 1,
  }),
  secondaryButton: (colors: any, pressed: boolean) => ({
    flexDirection: 'row' as const,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
    gap: 8,
    paddingVertical: 13,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.background,
    opacity: pressed ? 0.75 : 1,
  }),
  fieldLabel: (colors: any) => ({
    fontSize: 12, fontWeight: '700' as const, color: colors.textSecondary,
    textTransform: 'uppercase' as const, letterSpacing: 0, marginBottom: 6,
  }),
  input: (colors: any) => ({
    borderWidth: 1, borderColor: colors.border, borderRadius: 8,
    padding: 12, fontSize: 15, color: colors.text,
    backgroundColor: colors.background, marginBottom: 16,
  }),
};
