import { useEffect, useRef } from 'react';
import {
  AccessibilityInfo, Animated, findNodeHandle,
  Pressable, ScrollView, Text, View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useContactWizard, ContactType } from '../../src/contexts/ContactWizardContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { sounds } from '../../src/services/sounds';

// ── Contact type definitions ──────────────────────────────────────────────────

type TypeCard = {
  type:        ContactType;
  icon:        string;
  label:       string;
  description: string;
  color:       string;
  hint:        string;
};

const TYPE_CARDS: TypeCard[] = [
  {
    type:        'bug',
    icon:        'bug-outline',
    label:       'Bug Report',
    description: 'Something in the app is broken or not working as expected.',
    color:       '#EF4444',
    hint:        'Report a technical problem with the AppleVis app.',
  },
  {
    type:        'feedback',
    icon:        'chatbubble-ellipses-outline',
    label:       'Feedback',
    description: 'Share your thoughts, reactions, or general impressions about the app.',
    color:       '#0A84FF',
    hint:        'Tell us what you think about the app.',
  },
  {
    type:        'suggestion',
    icon:        'bulb-outline',
    label:       'Suggestion',
    description: 'An idea to make the app better — a feature, improvement, or change.',
    color:       '#10B981',
    hint:        'Suggest a new feature or improvement.',
  },
  {
    type:        'recommendation',
    icon:        'star-outline',
    label:       'Recommendation',
    description: 'Suggest a resource, podcast, app entry, blog topic, or piece of content.',
    color:       '#F59E0B',
    hint:        'Recommend content or resources for the AppleVis community.',
  },
];

// ── Step 1: Contact Type ──────────────────────────────────────────────────────

export default function ContactStep1() {
  const { colors }                            = useTheme();
  const router                                = useRouter();
  const { state, pickType }                   = useContactWizard();
  const { screenReaderEnabled, reduceMotion } = useAccessibilityPreferences();

  const headingRef  = useRef<Text>(null);
  const fadeAnim    = useRef(new Animated.Value(reduceMotion || screenReaderEnabled ? 1 : 0)).current;

  useEffect(() => {
    if (!reduceMotion && !screenReaderEnabled) {
      Animated.timing(fadeAnim, { toValue: 1, duration: 300, useNativeDriver: true }).start();
    }
    if (screenReaderEnabled) {
      const id = setTimeout(() => {
        const node = findNodeHandle(headingRef.current);
        if (node) AccessibilityInfo.setAccessibilityFocus(node);
      }, 350);
      return () => clearTimeout(id);
    }
  }, []);

  function handleSelect(t: ContactType) {
    pickType(t);
    sounds.pickerTick().catch(() => {});
    router.push('/contact/compose' as any);
  }

  return (
    <ScrollView
      contentContainerStyle={{ padding: 20, paddingBottom: 60 }}
      showsVerticalScrollIndicator={false}
    >
      <Animated.View style={{ opacity: fadeAnim, transform: [{ translateY: fadeAnim.interpolate({ inputRange: [0,1], outputRange: [12,0] }) }] }}>

        {/* Header */}
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 8 }}>
          <View
            style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: colors.accent, justifyContent: 'center', alignItems: 'center' }}
            accessibilityElementsHidden
          >
            <Ionicons name="mail-outline" size={24} color="#fff" />
          </View>
          <Text
            ref={headingRef}
            accessibilityRole="header"
            style={{ fontSize: 24, fontWeight: '800', color: colors.text, flex: 1 }}
          >
            Contact AppleVis
          </Text>
        </View>

        <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 21, marginBottom: 28 }}>
          What would you like to send us? Choose the type that best fits your message.
        </Text>

        {/* Type cards */}
        {TYPE_CARDS.map((card, idx) => {
          const isSelected = state.contactType === card.type;
          const delay = reduceMotion || screenReaderEnabled ? 0 : idx * 60;

          return (
            <TypeCardView
              key={card.type}
              card={card}
              isSelected={isSelected}
              delay={delay}
              reduceMotion={reduceMotion || screenReaderEnabled}
              colors={colors}
              onPress={() => handleSelect(card.type)}
            />
          );
        })}

        {/* Note */}
        <View
          style={{ backgroundColor: `${colors.accent}12`, borderRadius: 12, padding: 14,
            borderLeftWidth: 3, borderLeftColor: colors.accent, marginTop: 8 }}
          accessible
          accessibilityLabel="Note: This form contacts the AppleVis team about the app itself. To report an accessibility bug in Apple software, use Discover, then Contribute, then Submit a Bug Report."
        >
          <Text style={{ fontSize: 13, color: colors.text, lineHeight: 19 }}>
            <Text style={{ fontWeight: '700' }}>Note: </Text>
            This form contacts the AppleVis team about the app. To report an accessibility bug in Apple software, use Discover → Contribute → Submit a Bug Report.
          </Text>
        </View>

      </Animated.View>
    </ScrollView>
  );
}

// ── Type card sub-component ───────────────────────────────────────────────────

function TypeCardView({
  card, isSelected, delay, reduceMotion, colors, onPress,
}: {
  card: TypeCard;
  isSelected: boolean;
  delay: number;
  reduceMotion: boolean;
  colors: ReturnType<typeof useTheme>['colors'];
  onPress: () => void;
}) {
  const slideAnim = useRef(new Animated.Value(reduceMotion ? 0 : 20)).current;
  const opacAnim  = useRef(new Animated.Value(reduceMotion ? 1 :  0)).current;

  useEffect(() => {
    if (!reduceMotion) {
      const t = setTimeout(() => {
        Animated.parallel([
          Animated.timing(slideAnim, { toValue: 0, duration: 280, useNativeDriver: true }),
          Animated.timing(opacAnim,  { toValue: 1, duration: 280, useNativeDriver: true }),
        ]).start();
      }, delay);
      return () => clearTimeout(t);
    }
  }, []);

  return (
    <Animated.View style={{ opacity: opacAnim, transform: [{ translateY: slideAnim }], marginBottom: 12 }}>
      <Pressable
        onPress={onPress}
        accessible
        accessibilityRole="radio"
        accessibilityState={{ checked: isSelected }}
        accessibilityLabel={`${card.label}. ${card.description}`}
        accessibilityHint={card.hint}
        style={({ pressed }) => ({
          backgroundColor: isSelected ? `${card.color}10` : colors.card,
          borderRadius: 16,
          borderWidth: isSelected ? 2 : 1,
          borderColor: isSelected ? card.color : colors.border,
          padding: 16,
          flexDirection: 'row',
          alignItems: 'center',
          gap: 14,
          opacity: pressed ? 0.85 : 1,
        })}
      >
        {/* Icon square */}
        <View
          style={{
            width: 48, height: 48, borderRadius: 14,
            backgroundColor: isSelected ? card.color : `${card.color}20`,
            justifyContent: 'center', alignItems: 'center', flexShrink: 0,
          }}
          accessibilityElementsHidden
        >
          <Ionicons name={card.icon as any} size={24} color={isSelected ? '#fff' : card.color} />
        </View>

        {/* Text */}
        <View style={{ flex: 1 }}>
          <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text, marginBottom: 3 }}>
            {card.label}
          </Text>
          <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 18 }}>
            {card.description}
          </Text>
        </View>

        {/* Radio indicator */}
        <View
          style={{
            width: 22, height: 22, borderRadius: 11, flexShrink: 0,
            borderWidth: isSelected ? 0 : 2,
            borderColor: colors.textSecondary,
            backgroundColor: isSelected ? card.color : 'transparent',
            justifyContent: 'center', alignItems: 'center',
          }}
          accessibilityElementsHidden
        >
          {isSelected && <Ionicons name="checkmark" size={13} color="#fff" />}
        </View>
      </Pressable>
    </Animated.View>
  );
}
