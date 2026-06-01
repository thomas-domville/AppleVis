/**
 * AppleVis Posting Guidelines checker
 *
 * Rule-based checks derived from https://www.applevis.com/help/guidelines
 * (last updated January 13, 2026).
 *
 * These checks catch clear, structural violations. Nuanced judgement
 * (is this on-topic? is this actually harassment?) is handled by the
 * Foundation Models stub in intelligenceService.ts.
 *
 * Returns warnings sorted by severity: high → medium → low.
 * The caller decides how many to show at once (typically just the top one).
 */

export type GuidelineWarning = {
  /** Stable ID used to track which warnings the user has dismissed. */
  id: string;
  /** Short guideline name shown as the banner heading. */
  rule: string;
  /** Friendly, specific 1–2 sentence message shown to the user. */
  message: string;
  /** Controls banner colour and how strongly the warning is worded. */
  severity: 'high' | 'medium' | 'low';
};

export function checkGuidelines(text: string): GuidelineWarning[] {
  const warnings: GuidelineWarning[] = [];
  const trimmed = text.trim();
  const lower   = trimmed.toLowerCase();

  if (trimmed.length < 10) return [];

  // ── Personal information (email address) ─────────────────────────────────
  // Guideline: "it is recommended that you not include email addresses"
  if (/[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}/.test(text)) {
    warnings.push({
      id: 'personal-info',
      rule: 'Personal Information',
      message:
        'Your post appears to contain an email address. For your privacy and security, ' +
        'the AppleVis guidelines recommend not sharing personal contact information publicly.',
      severity: 'medium',
    });
  }

  // ── Referral / affiliate links ────────────────────────────────────────────
  // Guideline: "Referral links are not permitted."
  if (/[?&](ref|referral|affiliate|aff|partner|subid)=/i.test(text)) {
    warnings.push({
      id: 'referral-link',
      rule: 'No Referral Links',
      message:
        'Your post may contain a referral or affiliate link. ' +
        'These are not permitted on AppleVis as they can create conflicts of interest.',
      severity: 'medium',
    });
  }

  // ── Self-promotion ────────────────────────────────────────────────────────
  // Guideline: "Please do not use AppleVis to promote your own website, podcast,
  //             YouTube channel, mailing list or other online resource."
  if (/\bmy (podcast|youtube channel|channel|website|blog|newsletter|mailing list|substack|patreon)\b/i.test(text)) {
    warnings.push({
      id: 'self-promotion',
      rule: 'No Self-Promotion',
      message:
        'AppleVis asks that you not use the forums to promote your own podcast, ' +
        'YouTube channel, website, newsletter, or other online resource.',
      severity: 'medium',
    });
  }

  // ── Advertising / selling ─────────────────────────────────────────────────
  // Guideline: "The AppleVis Forums are not to be used for trading/swapping
  //             or selling/advertising products or services."
  if (/(\bfor sale\b|\bwanted to buy\b|\bbuy now\b|\bpromo code\b|\bcoupon code\b|\bget \d+% off\b)/i.test(text)) {
    warnings.push({
      id: 'advertising',
      rule: 'No Advertising or Selling',
      message:
        'AppleVis forums are not for selling, trading, or advertising products or services. ' +
        'If you believe this is genuinely useful to the community, please contact AppleVis first.',
      severity: 'medium',
    });
  }

  // ── Announcements requiring prior approval ────────────────────────────────
  // Guideline: "Announcements, such as those regarding surveys; research projects;
  //             or trainings/meetings, may only be posted with prior approval."
  if (/\b(survey|research study|research project|focus group|participants? needed|looking for participants?|study participants?)\b/i.test(text)) {
    warnings.push({
      id: 'announcement-approval',
      rule: 'Approval Required for Announcements',
      message:
        'Posts about surveys, research projects, or studies require prior approval from the ' +
        'AppleVis Editorial Team. Please contact them via the Contact Form before posting.',
      severity: 'high',
    });
  }

  // ── Press releases for pure promotion ────────────────────────────────────
  // Guideline: "Please do not post press releases unless the intention is to
  //             inform or contextualize a new or existing discussion."
  if (/\bpress release\b/i.test(text) || (/\bfor immediate release\b/i.test(text))) {
    warnings.push({
      id: 'press-release',
      rule: 'Press Releases',
      message:
        'Press releases may only be posted as part of a broader discussion, not purely to ' +
        'promote a product or service. Make sure your post adds context beyond the release itself.',
      severity: 'medium',
    });
  }

  // ── AI-generated content without disclosure ───────────────────────────────
  // Guideline: "If AI tools have been used for content generation, that this
  //             clearly be stated in the body of the post."
  const aiArtifacts = [
    'as an ai',
    'as a language model',
    "i don't have personal experience",
    "i cannot browse the internet",
    "as of my knowledge cutoff",
    "i'm unable to access real-time",
    "certainly! here's",
    "absolutely! here's",
    "sure! here's a",
    "great question! here",
  ];
  if (aiArtifacts.some((a) => lower.includes(a))) {
    warnings.push({
      id: 'ai-disclosure',
      rule: 'Disclose AI-Generated Content',
      message:
        'Your post may contain AI-generated text. AppleVis requires you to clearly state ' +
        'in the body of your post when AI tools have been used to help generate the content.',
      severity: 'medium',
    });
  }

  // ── All-caps (perceived shouting) ────────────────────────────────────────
  // Guideline: "Please be polite … express your views in a respectful manner."
  const wordTokens = trimmed.split(/\s+/).filter((w) => w.length > 3 && /[A-Za-z]/.test(w));
  if (wordTokens.length >= 5) {
    const capsCount = wordTokens.filter(
      (w) => w === w.toUpperCase() && /[A-Z]/.test(w),
    ).length;
    if (capsCount / wordTokens.length > 0.55) {
      warnings.push({
        id: 'all-caps',
        rule: 'Be Polite',
        message:
          'Your post uses a lot of capital letters, which can read as shouting. ' +
          'Normal capitalization will make it easier and friendlier to read.',
        severity: 'low',
      });
    }
  }

  // ── Excessive punctuation ─────────────────────────────────────────────────
  if (/[!?]{3,}/.test(text)) {
    warnings.push({
      id: 'excessive-punctuation',
      rule: 'Be Polite',
      message:
        'Your post contains multiple consecutive exclamation marks or question marks. ' +
        'Toning these down will help your message come across more calmly.',
      severity: 'low',
    });
  }

  // ── Low-value / no-value reply ────────────────────────────────────────────
  // Guideline: "Please do not post replies which add no value to the existing discussion."
  if (trimmed.length < 60) {
    const noValuePhrases = [
      'me too', 'same here', 'same issue', 'same problem', 'same for me',
      'same thing', 'ditto', 'i agree', 'agreed', 'just google it',
      'try googling', 'just search for it', "i haven't used", "i don't use that",
      "never used it", "haven't tried it", "can't help",
    ];
    if (noValuePhrases.some((p) => lower.includes(p))) {
      warnings.push({
        id: 'low-value',
        rule: 'Add Value to the Discussion',
        message:
          'Short replies like "me too" or "I haven\'t used that" don\'t add much to the ' +
          'discussion. Consider sharing specific details, experience, or a follow-up question instead.',
        severity: 'low',
      });
    }
  }

  // ── Multiple questions / topics ───────────────────────────────────────────
  // Guideline: "Please only post questions about a single topic in any new post."
  const questionCount = (text.match(/\?/g) ?? []).length;
  if (questionCount >= 3 && trimmed.length > 120) {
    warnings.push({
      id: 'multi-topic',
      rule: 'One Topic Per Post',
      message:
        'Your post appears to ask several different questions. AppleVis guidelines ask that ' +
        'you cover one topic per post — splitting into separate posts will get you better answers.',
      severity: 'low',
    });
  }

  // ── Spam / repetition ────────────────────────────────────────────────────
  // Guideline: "Repeated posting of a message (or very similar messages)
  //             multiple times is considered spamming."
  const sentences = trimmed
    .split(/[.!?]+/)
    .map((s) => s.trim().toLowerCase())
    .filter((s) => s.length > 15);
  if (sentences.length >= 4) {
    const unique = new Set(sentences);
    if (unique.size / sentences.length < 0.55) {
      warnings.push({
        id: 'repetition',
        rule: 'No Spam or Repetition',
        message:
          'Your post contains repeated phrases or sentences. ' +
          'Please avoid repeating the same content multiple times in a single post.',
        severity: 'medium',
      });
    }
  }

  // Sort: high first, then medium, then low.
  const order: Record<GuidelineWarning['severity'], number> = { high: 0, medium: 1, low: 2 };
  return warnings.sort((a, b) => order[a.severity] - order[b.severity]);
}
