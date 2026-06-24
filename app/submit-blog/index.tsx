import { useEffect, useRef } from 'react';
import {
  AccessibilityInfo, Animated, findNodeHandle,
  Pressable, ScrollView, Text, TextInput, View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useBlogWizard, BLOG_CATEGORIES } from '../../src/contexts/BlogWizardContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { sounds } from '../../src/services/sounds';

// ─── Step 1: Title + Category ─────────────────────────────────────────────────

export default function BlogStep1() {
  const { colors }                            = useTheme();
  const router                                = useRouter();
  const { state, update }                     = useBlogWizard();
  const { screenReaderEnabled, reduceMotion } = useAccessibilityPreferences();

  const headingRef = useRef<Text>(null);
  const fadeAnim   = useRef(new Animated.Value(reduceMotion || screenReaderEnabled ? 1 : 0)).current;

  useEffect(() => {
    if (!reduceMotion && !screenReaderEnabled) {
      Animated.timing(fadeAnim, { toValue: 1, duration: 350, useNativeDriver: true }).start();
    }
    if (screenReaderEnabled) {
      const id = setTimeout(() => {
        const node = findNodeHandle(headingRef.current);
        if (node) AccessibilityInfo.setAccessibilityFocus(node);
      }, 350);
      return () => clearTimeout(id);
    }
  }, []);

  const canContinue = !!state.title.trim() && !!state.category;

  function handleContinue() {
    sounds.articleOpen().catch(() => {});
    router.push('/submit-blog/content' as any);
  }

  return (
    <ScrollView
      contentContainerStyle={{ padding: 20, paddingBottom: 60 }}
      keyboardShouldPersistTaps="handled"
      showsVerticalScrollIndicator={false}
    >
      <Animated.View style={{ opacity: fadeAnim, transform: [{ translateY: fadeAnim.interpolate({ inputRange: [0,1], outputRange: [16,0] }) }] }}>

        {/* Heading */}
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 8, marginTop: 8 }}>
          <View style={{ width: 52, height: 52, borderRadius: 26, backgroundColor: colors.accent, justifyContent: 'center', alignItems: 'center' }} accessibilityElementsHidden>
            <Ionicons name="newspaper-outline" size={28} color="#fff" />
          </View>
          <Text ref={headingRef} accessibilityRole="header" style={{ fontSize: 28, fontWeight: '800', color: colors.text, flex: 1, lineHeight: 34 }}>
            Submit a blog post
          </Text>
        </View>

        <Text style={{ fontSize: 15, color: colors.textSecondary, lineHeight: 23, marginBottom: 28 }}>
          Share your accessibility knowledge, tips, or experiences with the AppleVis community. All posts are reviewed by our editorial team before publishing.
        </Text>

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
            fontSize: 17, color: colors.text,
            borderWidth: 1.5, borderColor: state.title.trim() ? colors.accent : colors.border,
          }}
          accessible
          accessibilityLabel="Blog title"
          accessibilityHint="Required. A clear, descriptive title for your post."
          returnKeyType="done"
        />

        {/* Category */}
        <View style={{ marginTop: 24 }}>
          <FieldLabel text="Category" required />
          <Text style={{ fontSize: 13, color: colors.textSecondary, marginBottom: 10, lineHeight: 19 }}>
            Choose the category that best fits your post.
          </Text>
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
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
        </View>

        {/* Continue */}
        <Pressable
          onPress={handleContinue}
          disabled={!canContinue}
          accessible
          accessibilityRole="button"
          accessibilityLabel={canContinue ? 'Continue to write your post' : 'Continue — add a title and select a category to proceed'}
          accessibilityState={{ disabled: !canContinue }}
          style={({ pressed }) => ({
            marginTop: 36,
            backgroundColor: canContinue ? colors.accent : colors.border,
            borderRadius: 16, paddingVertical: 16,
            alignItems: 'center', flexDirection: 'row', justifyContent: 'center', gap: 8,
            opacity: pressed ? 0.85 : 1,
          })}
        >
          <Text style={{ fontSize: 17, fontWeight: '700', color: canContinue ? '#fff' : colors.textSecondary }}>
            Continue
          </Text>
          <Ionicons name="arrow-forward" size={18} color={canContinue ? '#fff' : colors.textSecondary} accessibilityElementsHidden />
        </Pressable>

      </Animated.View>
    </ScrollView>
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
