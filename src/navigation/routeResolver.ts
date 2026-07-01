/**
 * Central map from a content-area intent to its current navigation destination.
 *
 * The app still registers hidden legacy tabs (`/(tabs)/forums`, `/(tabs)/podcasts`,
 * `/(tabs)/apps`, `/(tabs)/resources`) for backward compatibility, but no new code
 * should route to them directly. Use this resolver instead so there is one place
 * to update when navigation destinations change.
 */

export type ContentDestination =
  | 'forums'
  | 'podcasts'
  | 'apps'
  | 'resources'
  | 'saved'
  | 'discover'
  | 'home'
  | 'search';

export function routeForContentDestination(destination: ContentDestination): string {
  switch (destination) {
    case 'forums':
      return '/forums-browse';
    case 'podcasts':
      return '/podcast-browse';
    case 'apps':
      return '/app-browse';
    case 'resources':
      return '/guide-browse';
    case 'saved':
      return '/(tabs)/foryou';
    case 'discover':
      return '/(tabs)/discover';
    case 'home':
      return '/(tabs)';
    case 'search':
      return '/search';
  }
}
