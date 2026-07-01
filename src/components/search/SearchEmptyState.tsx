import { useRouter } from 'expo-router';
import { EmptyState } from '../EmptyState';

type Props = {
  query: string;
  onClearSearch: () => void;
  onBrowseDiscover?: () => void;
};

export function SearchEmptyState({ query, onClearSearch, onBrowseDiscover }: Props) {
  const router = useRouter();
  return (
    <EmptyState
      icon="search-outline"
      title="No results found"
      subtitle={`We couldn't find anything matching "${query}".`}
      suggestions={[
        'Check the spelling.',
        'Use fewer words.',
        'Search for a broader topic.',
      ]}
      primaryAction={{ label: 'Clear Search', onPress: onClearSearch }}
      secondaryAction={onBrowseDiscover ? { label: 'Browse Discover', onPress: onBrowseDiscover } : undefined}
      learnMore={{
        label: 'Learn how AppleVis Search works',
        onPress: () => router.push({ pathname: '/help-article', params: { articleId: 'search-overview' } }),
      }}
    />
  );
}
