/**
 * Drupal HTML form submission helpers.
 *
 * All three community submission forms (blog, bug report, podcast) live as
 * Drupal webforms / contact forms that the REST module cannot reach without
 * admin permission. Instead we replicate exactly what a browser does:
 *
 *   1. GET the form page (with session cookie) → extract one-time tokens
 *   2. POST the form-encoded body (same session cookie → auth is automatic)
 *   3. Detect success by checking whether the response URL changed (redirect)
 *
 * Session cookies from the JSON:API login are stored automatically by
 * React Native's URLSession cookie store and included in all fetch calls.
 */

const BASE = 'https://www.applevis.com';

const FORM_HEADERS = {
  'User-Agent':      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 AppleVis/2026',
  'Accept-Language': 'en-US,en;q=0.9',
  'Origin':          BASE,
  'Referer':         `${BASE}/`,
  'X-App-Auth':      '2ff01dc7bf35469d93c6',
};

export type DrupalFormResult =
  | { ok: true }
  | { ok: false; error: string };

type FormTokens = {
  formBuildId:  string;
  formToken:    string;
  honeypotTime: string;
};

async function fetchTokens(path: string): Promise<FormTokens | null> {
  try {
    const res = await fetch(`${BASE}${path}`, {
      headers: { ...FORM_HEADERS, Accept: 'text/html,application/xhtml+xml' },
    });
    if (!res.ok) return null;
    const html = await res.text();
    const formBuildId  = html.match(/name="form_build_id"\s+value="([^"]+)"/)?.[1]  ?? '';
    const formToken    = html.match(/name="form_token"\s+value="([^"]+)"/)?.[1]    ?? '';
    const honeypotTime = html.match(/name="honeypot_time"\s+value="([^"]+)"/)?.[1] ?? '';
    if (!formBuildId || !formToken) return null;
    return { formBuildId, formToken, honeypotTime };
  } catch {
    return null;
  }
}

function encodeFields(fields: Record<string, string>): string {
  return Object.entries(fields)
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
    .join('&');
}

function wasRedirected(res: Response, formPath: string): boolean {
  // Drupal redirects on success; a form error re-renders the same URL.
  return !res.url.startsWith(`${BASE}${formPath}`);
}

// ── Blog submission ───────────────────────────────────────────────────────────
// Form at /form/blog-submission
// Fields: name, email, message (cover note), blog_draft (content)

export type BlogPayload = {
  name:       string;   // auto-filled from user account
  email:      string;   // auto-filled from user account
  message:    string;   // cover note to editors (title + pitch + category info)
  blogDraft:  string;   // the actual blog post body
};

export async function submitBlogForm(payload: BlogPayload): Promise<DrupalFormResult> {
  const path = '/form/blog-submission';
  const tokens = await fetchTokens(path);
  if (!tokens) return { ok: false, error: 'Could not load the submission form. Check your connection and try again.' };

  const body = encodeFields({
    name:          payload.name,
    email:         payload.email,
    message:       payload.message,
    blog_draft:    payload.blogDraft,
    form_build_id: tokens.formBuildId,
    form_token:    tokens.formToken,
    form_id:       'webform_submission_blog_submission_add_form',
    op:            'Submit',
  });

  try {
    const res = await fetch(`${BASE}${path}`, {
      method:  'POST',
      headers: { ...FORM_HEADERS, 'Content-Type': 'application/x-www-form-urlencoded' },
      body,
    });
    return wasRedirected(res, path)
      ? { ok: true }
      : { ok: false, error: 'The submission was not accepted. Please check your content and try again.' };
  } catch (e) {
    return { ok: false, error: e instanceof Error ? e.message : 'Network error. Please try again.' };
  }
}

// ── Community bug report ──────────────────────────────────────────────────────
// Form at /form/community-bug-report-form
// Fields: your_name, email, title, apple_feedback, platform, software_version,
//         can_you_reproduce_the_issue, description,
//         may_we_thank_and_publicly_recognize_you_for_your_efforts_in_our

export type BugPayload = {
  name:          string;
  email:         string;
  title:         string;
  appleFeedback: string;
  platform:      'iOS' | 'iPadOS' | 'macOS';
  softwareVersion: string;
  canReproduce:  'Yes, always' | 'Yes, sometimes' | 'No';
  description:   string;
  recognition:   'Yes - please use my name.' | 'Yes - please use my AppleVis username' | 'No - please thank/recognize me anonymously';
};

export async function submitBugForm(payload: BugPayload): Promise<DrupalFormResult> {
  const path = '/form/community-bug-report-form';
  const tokens = await fetchTokens(path);
  if (!tokens) return { ok: false, error: 'Could not load the submission form. Check your connection and try again.' };

  const body = encodeFields({
    your_name:       payload.name,
    email:           payload.email,
    title:           payload.title,
    apple_feedback:  payload.appleFeedback,
    platform:        payload.platform,
    software_version: payload.softwareVersion,
    can_you_reproduce_the_issue: payload.canReproduce,
    description:     payload.description,
    may_we_thank_and_publicly_recognize_you_for_your_efforts_in_our: payload.recognition,
    form_build_id:   tokens.formBuildId,
    form_token:      tokens.formToken,
    form_id:         'webform_submission_community_bug_report_form_add_form',
    op:              'Submit',
  });

  try {
    const res = await fetch(`${BASE}${path}`, {
      method:  'POST',
      headers: { ...FORM_HEADERS, 'Content-Type': 'application/x-www-form-urlencoded' },
      body,
    });
    return wasRedirected(res, path)
      ? { ok: true }
      : { ok: false, error: 'The submission was not accepted. Please check your content and try again.' };
  } catch (e) {
    return { ok: false, error: e instanceof Error ? e.message : 'Network error. Please try again.' };
  }
}

// ── Podcast submission ────────────────────────────────────────────────────────
// Form at /podcasts/upload (Drupal Contact Form)
// Fields: name, mail, field_description[0][value], files[field_podcast_file_0]

export type PodcastPayload = {
  name:        string;
  email:       string;
  description: string;
  audioFile: {
    uri:  string;
    name: string;
    type: string;  // e.g. 'audio/mpeg', 'audio/mp4', 'audio/x-wav'
  } | null;
};

export async function submitPodcastForm(payload: PodcastPayload): Promise<DrupalFormResult> {
  const path = '/podcasts/upload';
  const tokens = await fetchTokens(path);
  if (!tokens) return { ok: false, error: 'Could not load the submission form. Check your connection and try again.' };

  const formData = new FormData();
  formData.append('name', payload.name);
  formData.append('mail', payload.email);
  formData.append('field_description[0][value]', payload.description);
  formData.append('field_podcast_file[0][display]', '1');
  formData.append('field_podcast_file[0][fids]', '');

  if (payload.audioFile) {
    // React Native FormData accepts { uri, name, type } for file fields
    formData.append('files[field_podcast_file_0]', {
      uri:  payload.audioFile.uri,
      name: payload.audioFile.name,
      type: payload.audioFile.type,
    } as unknown as Blob);
  }

  formData.append('honeypot_time', tokens.honeypotTime);
  formData.append('form_build_id', tokens.formBuildId);
  formData.append('form_token',    tokens.formToken);
  formData.append('form_id',       'contact_message_submit_podcast_form');
  formData.append('url',           '');   // honeypot — must be blank
  formData.append('op',            'Send message');

  try {
    const res = await fetch(`${BASE}${path}`, {
      method:  'POST',
      headers: { ...FORM_HEADERS },  // fetch sets multipart boundary automatically
      body:    formData,
    });
    return wasRedirected(res, path)
      ? { ok: true }
      : { ok: false, error: 'The submission was not accepted. Please check your content and try again.' };
  } catch (e) {
    return { ok: false, error: e instanceof Error ? e.message : 'Network error. Please try again.' };
  }
}
