import { Linking } from 'react-native';
import { useRouter } from 'expo-router';
import { AccessibleCard } from '../AccessibleCard';
import { SearchResultSection } from './SearchResultSection';
import { donateSiriActivity, readAloud } from '../../services/intelligenceService';
import { relativeTime } from '../../utils/relativeTime';
import type { SearchResults } from '../../hooks/useSearch';

type Props = {
  results: SearchResults;
  screenReaderEnabled: boolean;
  onOpenExternalError?: () => void;
};

/**
 * Renders all four search-result groups with the official AppleVis section names
 * (Site Results, Forum Topics, Apps, Guides and Resources) and consistent actions.
 * Shared by the Search tab and Discover's embedded search so the two stop drifting apart.
 */
export function SearchResultsGrouped({ results, screenReaderEnabled, onOpenExternalError }: Props) {
  const router = useRouter();
  const readAloudAction = !screenReaderEnabled ? ['Read Aloud'] : [];

  return (
    <>
      <SearchResultSection title="Site Results" count={results.site.length}>
        {results.site.map((item) => (
          <AccessibleCard
            key={item.id}
            title={item.title}
            meta={[
              item.contentType !== 'unknown' ? item.contentType : null,
              item.source === 'public' ? 'AppleVis public search' : 'AppleVis search API',
            ].filter(Boolean).join(' · ')}
            actions={['Open Result', ...readAloudAction]}
            openSound="external"
            onAction={(action) => {
              if (action === 'Open Result') Linking.openURL(item.url).catch(() => onOpenExternalError?.());
              if (action === 'Read Aloud') readAloud(`${item.title}. ${item.summary ?? ''}`);
            }}
          />
        ))}
      </SearchResultSection>

      <SearchResultSection title="Forum Topics" count={results.forums.length}>
        {results.forums.map((topic) => (
          <AccessibleCard
            key={topic.id}
            title={topic.title}
            meta={topic.meta}
            actions={['Open Topic', ...readAloudAction]}
            onAction={(action) => {
              if (action === 'Open Topic') {
                router.push({ pathname: '/topic/[id]' as any, params: { id: topic.id, title: topic.title } });
              }
              if (action === 'Read Aloud') readAloud(`${topic.title}. ${topic.meta}`);
            }}
          />
        ))}
      </SearchResultSection>

      <SearchResultSection title="Apps" count={results.apps.length}>
        {results.apps.map((app) => (
          <AccessibleCard
            key={app.id}
            title={app.name}
            meta={[
              app.developer || null,
              app.reviewCount > 0 ? `${app.reviewCount} reviews` : null,
            ].filter(Boolean).join(' · ')}
            iconUrl={app.iconUrl}
            actions={['View AppleVis Details', ...readAloudAction]}
            onAction={(action) => {
              if (action === 'View AppleVis Details') {
                donateSiriActivity({ type: 'searchApps', query: app.name });
                router.push({ pathname: '/app-detail/[id]' as any, params: { id: app.id, name: app.name } });
              }
              if (action === 'Read Aloud') readAloud(`${app.name}. ${app.summary}`);
            }}
          />
        ))}
      </SearchResultSection>

      <SearchResultSection title="Guides and Resources" count={results.resources.length}>
        {results.resources.map((item) => (
          <AccessibleCard
            key={item.id}
            title={item.title}
            meta={`${item.kind} · Updated ${relativeTime(item.updatedAt)}`}
            actions={['Open Guide', ...readAloudAction]}
            onAction={(action) => {
              if (action === 'Open Guide') {
                router.push({ pathname: '/resource-detail/[id]' as any, params: { id: item.id, title: item.title, url: item.url } });
              }
              if (action === 'Read Aloud') readAloud(`${item.title}. ${item.summary}`);
            }}
          />
        ))}
      </SearchResultSection>
    </>
  );
}
