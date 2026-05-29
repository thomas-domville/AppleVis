import { useState } from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';
import { Screen } from '../../src/components/Screen';
import { AccessibleCard } from '../../src/components/AccessibleCard';
import { forumFilters, forumTopics } from '../../src/data/sampleData';
import { styles, colors } from '../../src/theme/styles';

export default function Forums() {
  const [activeFilter, setActiveFilter] = useState('Recent');

  return (
    <Screen title="Forums">
      <ScrollView showsVerticalScrollIndicator={false}>
        {/* Filter bar */}
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          accessibilityLabel="Forum filters"
          accessibilityRole="tablist"
          style={{ marginBottom: 16 }}
          contentContainerStyle={{ gap: 8, paddingRight: 4 }}
        >
          {forumFilters.map((filter) => {
            const isActive = filter === activeFilter;
            return (
              <Pressable
                key={filter}
                onPress={() => setActiveFilter(filter)}
                accessible
                accessibilityRole="tab"
                accessibilityLabel={filter}
                accessibilityState={{ selected: isActive }}
                style={[
                  styles.pill,
                  isActive && { backgroundColor: colors.appleVisBlue },
                ]}
              >
                <Text style={[styles.pillText, isActive && { color: '#FFFFFF' }]}>
                  {filter}
                </Text>
              </Pressable>
            );
          })}
        </ScrollView>

        {/* Topic list */}
        {forumTopics.map((topic) => (
          <AccessibleCard
            key={topic.title}
            title={topic.title}
            meta={topic.meta}
            actions={['Open', 'Save Topic', 'Follow Topic', 'Mark as Read', 'Share']}
          />
        ))}

        <View style={{ height: 160 }} />
      </ScrollView>
    </Screen>
  );
}
