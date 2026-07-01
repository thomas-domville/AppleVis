import { Pressable, Text, View } from 'react-native';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { WizardLayout } from '../../src/components/WizardLayout';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useContactWizard, ContactType } from '../../src/contexts/ContactWizardContext';
import { useAuth } from '../../src/contexts/AuthContext';
import { useAlert } from '../../src/contexts/AccessibleAlertContext';
import { sounds } from '../../src/services/sounds';

// ── Shared type metadata (re-exported for other wizard steps) ─────────────────

export const TYPE_COLOR: Record<ContactType, string> = {
  bug:            '#EF4444',
  feedback:       '#0A84FF',
  suggestion:     '#10B981',
  recommendation: '#F59E0B',
};

export const TYPE_LABEL: Record<ContactType, string> = {
  bug:            'Bug Report',
  feedback:       'Feedback',
  suggestion:     'Suggestion',
  recommendation: 'Recommendation',
};

export const TYPE_ICON: Record<ContactType, string> = {
  bug:            'bug-outline',
  feedback:       'chatbubble-ellipses-outline',
  suggestion:     'bulb-outline',
  recommendation: 'star-outline',
};

export const MESSAGE_PLACEHOLDER: Record<ContactType, string> = {
  bug:            'Describe what happened, what you expected, and the steps to reproduce it…',
  feedback:       'Share your thoughts about the AppleVis app…',
  suggestion:     'Describe your idea and why it would improve the app…',
  recommendation: 'Tell us what you would like to see in AppleVis…',
};

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
    color:       TYPE_COLOR.bug,
    hint:        'Report a technical problem with the AppleVis app.',
  },
  {
    type:        'feedback',
    icon:        'chatbubble-ellipses-outline',
    label:       'Feedback',
    description: 'Share your thoughts, reactions, or general impressions about the app.',
    color:       TYPE_COLOR.feedback,
    hint:        'Tell us what you think about the app.',
  },
  {
    type:        'suggestion',
    icon:        'bulb-outline',
    label:       'Suggestion',
    description: 'An idea to make the app better — a feature, improvement, or change.',
    color:       TYPE_COLOR.suggestion,
    hint:        'Suggest a new feature or improvement.',
  },
  {
    type:        'recommendation',
    icon:        'star-outline',
    label:       'Recommendation',
    description: 'Suggest a resource, podcast, app entry, blog topic, or piece of content.',
    color:       TYPE_COLOR.recommendation,
    hint:        'Recommend content or resources for the AppleVis community.',
  },
];

// ── Step 1: Type Selection ────────────────────────────────────────────────────

export default function ContactStep1() {
  const { colors }           = useTheme();
  const auth                 = useAuth();
  const { state, pickType, reset } = useContactWizard();
  const { showAlert }        = useAlert();

  const isSignedIn  = auth.isSignedIn;
  const totalSteps  = isSignedIn ? 3 : 4;
  const typeColor   = state.contactType ? TYPE_COLOR[state.contactType] : colors.accent;

  function handleSelect(t: ContactType) {
    pickType(t);
    sounds.pickerTick().catch(() => {});
  }

  function handleNext() {
    if (!state.contactType) return;
    sounds.articleOpen().catch(() => {});
    router.push(isSignedIn ? ('/contact/compose' as any) : ('/contact/details' as any));
  }

  function handleCancel() {
    showAlert({
      title: 'Cancel contact?',
      message: 'Your selections will be discarded.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep Going',
      type: 'warning',
      onConfirm: () => {
        reset();
        router.replace({ pathname: '/profile' as any, params: { focus: 'contactSupport' } });
      },
    });
  }

  return (
    <WizardLayout
      step={1}
      totalSteps={totalSteps}
      title="Contact AppleVis"
      description="Choose the type of message you'd like to send. This helps us get it to the right team."
      onNext={handleNext}
      nextLabel="Next"
      nextDisabled={!state.contactType}
      hideSkip
      accentColor={typeColor}
      onCancel={handleCancel}
    >
      {/* Info note */}
      <View
        style={{
          backgroundColor: `${colors.accent}12`, borderRadius: 12, padding: 14,
          borderLeftWidth: 3, borderLeftColor: colors.accent, marginBottom: 20,
        }}
        accessible
        accessibilityLabel="Note: This form contacts the AppleVis team about the app itself. To report an accessibility bug in Apple software, use Discover, then Contribute, then Submit a Bug Report."
      >
        <Text style={{ fontSize: 13, color: colors.text, lineHeight: 19 }}>
          <Text style={{ fontWeight: '700' }}>Note: </Text>
          To report an Apple accessibility bug, use Discover → Contribute → Submit a Bug Report.
        </Text>
      </View>

      {/* Radio group */}
      <View accessibilityRole="radiogroup" accessibilityLabel="Contact type options">
        {TYPE_CARDS.map(card => (
          <TypeCardView
            key={card.type}
            card={card}
            isSelected={state.contactType === card.type}
            onPress={() => handleSelect(card.type)}
          />
        ))}
      </View>
    </WizardLayout>
  );
}

// ── Type card ─────────────────────────────────────────────────────────────────

function TypeCardView({
  card, isSelected, onPress,
}: {
  card: TypeCard;
  isSelected: boolean;
  onPress: () => void;
}) {
  const { colors } = useTheme();

  return (
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
        marginBottom: 12,
        opacity: pressed ? 0.85 : 1,
      })}
    >
      {/* Icon */}
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

      {/* Radio dot */}
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
  );
}
