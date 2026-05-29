import { StyleSheet } from 'react-native';

export const colors = {
  appleVisBlue: '#0A84FF',
  background: '#F5F7FA',
  card: '#FFFFFF',
  text: '#101828',
  secondary: '#475467',
  border: '#D0D5DD'
};

export const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.background },
  content: { flex: 1, paddingHorizontal: 18, paddingTop: 18 },
  title: { fontSize: 34, fontWeight: '800', color: colors.text, marginBottom: 6 },
  lede: { fontSize: 17, lineHeight: 24, color: colors.secondary, marginBottom: 16 },
  card: { backgroundColor: colors.card, borderRadius: 20, padding: 18, marginBottom: 12, borderColor: colors.border, borderWidth: StyleSheet.hairlineWidth },
  cardSmall: { backgroundColor: colors.card, borderRadius: 14, padding: 16, marginBottom: 10, borderColor: colors.border, borderWidth: StyleSheet.hairlineWidth },
  cardTitle: { fontSize: 20, fontWeight: '700', color: colors.text, marginBottom: 4 },
  cardMeta: { fontSize: 15, lineHeight: 21, color: colors.secondary },
  body: { fontSize: 17, lineHeight: 24, color: colors.text },
  pillRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: 16 },
  pill: { paddingHorizontal: 14, paddingVertical: 10, borderRadius: 999, backgroundColor: '#E8F1FF' },
  pillText: { color: colors.appleVisBlue, fontWeight: '700' }
});
