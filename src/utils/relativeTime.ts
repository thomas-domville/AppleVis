/**
 * Returns a human-friendly relative time string for any ISO date string or Date.
 *
 * Tiers:
 *   < 1 min          → "just now"
 *   1–59 min         → "14 minutes ago" / "1 minute ago"
 *   1–47 hours       → "2 hours ago"   / "1 hour ago"
 *   2–13 days        → "3 days ago"    / "2 days ago"
 *   2–3 weeks        → "2 weeks ago"   / "1 week ago"
 *   1–11 months      → "3 months ago"  / "1 month ago"
 *   12+ months       → "2 years ago"   / "1 year ago"
 */
export function relativeTime(input: string | Date | null | undefined): string {
  if (!input) return '';
  const date   = input instanceof Date ? input : new Date(input as string);
  if (isNaN(date.getTime())) return '';

  const diffMs  = Date.now() - date.getTime();
  const diffMin = Math.floor(diffMs  / 60_000);
  const diffH   = Math.floor(diffMin / 60);
  const diffD   = Math.floor(diffH   / 24);
  const diffW   = Math.floor(diffD   / 7);
  const diffMo  = Math.floor(diffD   / 30.44);
  const diffY   = Math.floor(diffD   / 365.25);

  if (diffMin  <  1)  return 'just now';
  if (diffMin  < 60)  return diffMin  === 1  ? '1 minute ago'  : `${diffMin} minutes ago`;
  if (diffH    < 48)  return diffH    === 1  ? '1 hour ago'    : `${diffH} hours ago`;
  if (diffD    < 14)  return diffD    === 1  ? 'yesterday'     : `${diffD} days ago`;
  if (diffW    <  4)  return diffW    === 1  ? '1 week ago'    : `${diffW} weeks ago`;
  if (diffMo   < 12)  return diffMo   === 1  ? '1 month ago'   : `${diffMo} months ago`;
  return diffY === 1 ? '1 year ago' : `${diffY} years ago`;
}
