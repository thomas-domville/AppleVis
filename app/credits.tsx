import { useEffect, useRef } from 'react';
import { AccessibilityInfo, findNodeHandle, ScrollView, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';

type CreditSection = {
  title: string;
  icon: string;
  body: string;
  people?: { label: string; name: string }[];
  featured?: boolean;
};

const CREDIT_SECTIONS: CreditSection[] = [
  {
    title: 'App Creation',
    icon: 'construct-outline',
    body: 'The AppleVis app was shaped by people who cared deeply about making the community easier, faster, and more enjoyable to use.',
    people: [
      { label: 'Design and Coding', name: 'Thomas Domville' },
      { label: 'Wording and Quality', name: 'Michael Hansen' },
    ],
  },
  {
    title: 'Beta Testers',
    icon: 'flask-outline',
    body: 'Thank you to every beta tester who shared feedback, suggested improvements, and found bugs before release. Your careful testing made this app better for everyone.',
  },
  {
    title: 'The AppleVis Community',
    icon: 'people-outline',
    body: 'Thank you to the AppleVis community for making the site what it is. Without the people who ask questions, share knowledge, review apps, post comments, and support one another, AppleVis would not be the same. This app is for you.',
  },
  {
    title: 'AppleVis Editorial Team',
    icon: 'newspaper-outline',
    body: 'Thank you to the AppleVis Editorial Team, past and present, for the care, judgment, hard work, and steady commitment required to keep AppleVis maintained, updated, and moving forward.',
  },
  {
    title: 'David Goodwin',
    icon: 'star-outline',
    body: 'Most of all, thank you to AppleVis founder David Goodwin. This app would not have come to life without the community he created for all of us to enjoy. His dedication, hard work, and commitment to AppleVis made everything that followed possible.',
    featured: true,
  },
  {
    title: 'Be My Eyes',
    icon: 'heart-outline',
    body: 'Thank you to Be My Eyes for supporting AppleVis and helping keep the lights on, so people can continue to learn, participate, and contribute.',
  },
];

function CreditCard({ section, colors, styles }: {
  section: CreditSection;
  colors: ReturnType<typeof useTheme>['colors'];
  styles: ReturnType<typeof useTheme>['styles'];
}) {
  return (
    <View
      style={[
        styles.card,
        {
          borderLeftWidth: section.featured ? 5 : 3,
          borderLeftColor: section.featured ? colors.accent : colors.border,
        },
      ]}
    >
      <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 12 }}>
        <View
          style={{
            width: 40,
            height: 40,
            borderRadius: 10,
            backgroundColor: colors.pill,
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
            marginTop: 2,
          }}
          accessibilityElementsHidden
        >
          <Ionicons name={section.icon as any} size={20} color={colors.accent} />
        </View>

        <View style={{ flex: 1 }}>
          <Text
            style={[
              styles.cardTitle,
              {
                marginBottom: 8,
                color: section.featured ? colors.accent : colors.text,
              },
            ]}
            accessibilityRole="header"
          >
            {section.title}
          </Text>

          {section.people?.map(({ label, name }) => (
            <View
              key={label}
              style={{
                paddingVertical: 8,
                borderBottomWidth: 0.5,
                borderBottomColor: colors.border,
              }}
              accessible
              accessibilityLabel={`${label}: ${name}`}
            >
              <Text style={{ fontSize: 15, color: colors.textSecondary, marginBottom: 2 }}>
                {label}
              </Text>
              <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text }}>
                {name}
              </Text>
            </View>
          ))}

          <Text style={[styles.cardMeta, { marginTop: section.people ? 10 : 0 }]}>
            {section.body}
          </Text>
        </View>
      </View>
    </View>
  );
}

export default function Credits() {
  const { colors, styles } = useTheme();
  const firstHeadingRef = useRef<Text | null>(null);
  const didFocusFirstHeadingRef = useRef(false);

  useEffect(() => {
    const timers = [350, 700, 1100].map((delay) =>
      setTimeout(() => {
        if (didFocusFirstHeadingRef.current) return;
        const handle = findNodeHandle(firstHeadingRef.current);
        if (handle) {
          didFocusFirstHeadingRef.current = true;
          AccessibilityInfo.setAccessibilityFocus(handle);
        }
      }, delay),
    );

    return () => timers.forEach(clearTimeout);
  }, []);

  return (
    <Screen title="Credits" showSettings={false}>
      <ScrollView showsVerticalScrollIndicator={false}>
        <View
          style={[styles.card, { alignItems: 'center', paddingVertical: 22 }]}
        >
          <View
            style={{
              width: 52,
              height: 52,
              borderRadius: 14,
              backgroundColor: colors.accent,
              alignItems: 'center',
              justifyContent: 'center',
              marginBottom: 12,
            }}
            accessibilityElementsHidden
          >
            <Ionicons name="sparkles-outline" size={26} color={colors.accentText} />
          </View>
          <Text
            ref={firstHeadingRef}
            accessibilityRole="header"
            style={{ fontSize: 22, fontWeight: '700', color: colors.text, textAlign: 'center', marginBottom: 8 }}
          >
            AppleVis Credits
          </Text>
          <Text
            style={{ fontSize: 17, color: colors.textSecondary, textAlign: 'center', lineHeight: 24 }}
          >
            AppleVis exists because of the people who build, write, test, maintain, support, and participate in this community.
          </Text>
        </View>

        {CREDIT_SECTIONS.map((section) => (
          <CreditCard key={section.title} section={section} colors={colors} styles={styles} />
        ))}

        <View
          style={[styles.card, { backgroundColor: colors.pill, borderColor: colors.border, borderWidth: 1 }]}
          accessible
          accessibilityLabel="To everyone who has helped AppleVis become what it is: thank you."
        >
          <Text style={{ fontSize: 16, lineHeight: 23, color: colors.text, textAlign: 'center', fontWeight: '700' }}>
            To everyone who has helped AppleVis become what it is: thank you.
          </Text>
        </View>
      </ScrollView>
    </Screen>
  );
}
