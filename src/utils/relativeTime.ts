/**
 * Returns a human-friendly relative time string matching the AppleVis website format.
 *
 * Compound two-unit form — second unit only appears when the remainder is non-zero:
 *   < 1 min      → "just now"
 *   minutes      → "14 minutes ago" / "1 minute ago"
 *   hours        → "2 hours ago" / "8 hours and 5 minutes ago"
 *   days         → "3 days ago" / "2 days and 3 hours ago"
 *   weeks        → "2 weeks ago" / "2 weeks and 3 days ago"
 *   months       → "3 months ago" / "3 months and 2 weeks ago"
 *   years        → "1 year ago" / "1 year and 2 months ago"
 */
export function relativeTime(input: string | Date | null | undefined): string {
  if (!input) return '';
  const date = input instanceof Date ? input : new Date(input as string);
  if (isNaN(date.getTime())) return '';

  const diffMs  = Date.now() - date.getTime();
  const diffMin = Math.floor(diffMs  / 60_000);
  const diffH   = Math.floor(diffMin / 60);
  const diffD   = Math.floor(diffH   / 24);
  const diffW   = Math.floor(diffD   / 7);
  const diffMo  = Math.floor(diffD   / 30.44);
  const diffY   = Math.floor(diffD   / 365.25);

  // e.g. n(8, 'hour') → "8 hours",  n(1, 'minute') → "1 minute"
  const n = (val: number, unit: string) =>
    `${val} ${unit}${val === 1 ? '' : 's'}`;

  // Appends "and X units" only when the remainder is non-zero
  const compound = (major: string, remainder: number, unit: string) =>
    remainder === 0 ? `${major} ago` : `${major} and ${n(remainder, unit)} ago`;

  if (diffMin < 1)  return 'just now';
  if (diffH   < 1)  return `${n(diffMin, 'minute')} ago`;
  if (diffD   < 1)  return compound(n(diffH,  'hour'),  diffMin % 60,                               'minute');
  if (diffW   < 1)  return compound(n(diffD,  'day'),   diffH   % 24,                               'hour');
  if (diffMo  < 1)  return compound(n(diffW,  'week'),  diffD   %  7,                               'day');
  if (diffY   < 1)  return compound(n(diffMo, 'month'), Math.floor((diffD - Math.floor(diffMo * 30.44)) / 7), 'week');
  return                    compound(n(diffY,  'year'),  diffMo  - diffY * 12,                       'month');
}
