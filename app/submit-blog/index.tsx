import { Pressable, Text, TextInput, View } from 'react-native';
import { router } from 'expo-router';
import { WizardLayout } from '../../src/components/WizardLayout';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useBlogWizard, BLOG_CATEGORIES } from '../../src/contexts/BlogWizardContext';
import { useAlert } from '../../src/contexts/AccessibleAlertContext';
import { sounds } from '../../src/services/sounds';

// ─── Step 1: Title + Category ─────────────────────────────────────────────────

export default function BlogStep1() {
  const { colors }      = useTheme();
  const { state, update, reset } = useBlogWizard();
  const { showAlert }   = useAlert();

  const canContinue = !!state.title.trim() && !!state.category;

  function handleNext() {
    sounds.articleOpen().catch(() => {});
    router.push('/submit-blog/content' as any);
  }

  function handleCancel() {
    showAlert({
      title: 'Discard this submission?',
      message: 'Your blog post details will be discarded.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep Editing',
      type: 'warning',
      onConfirm: () => {
        reset();
        router.replace('/(tabs)/discover' as any);
      },
    });
  }

  return (
    <WizardLayout
      step={1}
      totalSteps={3}
      title="Submit a blog post"
      description="Share your accessibility knowledge with the AppleVis community. All posts are reviewed by our editorial team before publishing."
      onNext={handleNext}
      nextLabel="Next: Write your post"
      nextDisabled={!canContinue}
      hideSkip
      onCancel={handleCancel}
    >
      {/* Title */}
      <FieldLabel text="Blog title" required />
      <TextInput
        value={state.title}
        onChangeText={v => update({ title: v })}
        placeholder="e.g. How I use VoiceOver to navigate the App Store"
        placeholderTextColor={colors.textSecondary}
        style={{
          backgroundColor: colors.card, borderRadius: 12,
          paddingHorizontal: 14, paddingVertical: 12,
          fontSize: 17, color: colors.text, marginBottom: 24,
          borderWidth: 1.5, borderColor: state.title.trim() ? colors.accent : colors.border,
        }}
        accessible
        accessibilityLabel="Blog title"
        accessibilityHint="Required. A clear, descriptive title for your post."
        returnKeyType="done"
      />

      {/* Category */}
      <FieldLabel text="Category" required />
      <Text style={{ fontSize: 13, color: colors.textSecondary, marginBottom: 10, lineHeight: 19 }}>
        Choose the category that best fits your post.
      </Text>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}
        accessibilityRole="radiogroup" accessibilityLabel="Blog category options">
        {BLOG_CATEGORIES.map(cat => {
          const selected = state.category === cat;
          return (
            <Pressable
              key={cat}
              onPress={() => { sounds.pickerTick().catch(() => {}); update({ category: cat }); }}
              accessible
              accessibilityRole="radio"
              accessibilityLabel={cat}
              accessibilityState={{ selected }}
              style={({ pressed }) => ({
                paddingHorizontal: 14, paddingVertical: 8, borderRadius: 20,
                borderWidth: 1.5,
                borderColor: selected ? colors.accent : colors.border,
                backgroundColor: selected ? `${colors.accent}18` : colors.card,
                opacity: pressed ? 0.75 : 1,
              })}
            >
              <Text style={{ fontSize: 14, fontWeight: selected ? '700' : '400', color: selected ? colors.accent : colors.text }}>
                {cat}
              </Text>
            </Pressable>
          );
        })}
      </View>
      {state.category ? (
        <Text style={{ fontSize: 13, color: colors.accent, marginTop: 8, fontWeight: '600' }} accessibilityLiveRegion="polite">
          Selected: {state.category}
        </Text>
      ) : null}
    </WizardLayout>
  );
}

function FieldLabel({ text, required }: { text: string; required?: boolean }) {
  const { colors } = useTheme();
  return (
    <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8 }}>
      {text}{required && <Text style={{ color: colors.accent }}> *</Text>}
    </Text>
  );
}
