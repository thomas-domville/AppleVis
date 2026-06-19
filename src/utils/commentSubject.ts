const GENERIC_SUBJECTS = new Set([
  'comment',
  'reply',
  'review',
  're',
  'add new comment',
]);

function normalise(value: string): string {
  return value.trim().replace(/\s+/g, ' ').toLowerCase().replace(/^re:\s*/i, '');
}

export function displayCommentSubject(subject?: string, parentTitle?: string): string | null {
  const clean = subject?.trim().replace(/\s+/g, ' ');
  if (!clean) return null;

  const normalised = normalise(clean);
  if (!normalised || GENERIC_SUBJECTS.has(normalised)) return null;
  if (parentTitle && normalised === normalise(parentTitle)) return null;

  return clean;
}

export function subjectLabel(subject?: string, parentTitle?: string): string {
  const display = displayCommentSubject(subject, parentTitle);
  return display ? `Subject: ${display}. ` : '';
}
