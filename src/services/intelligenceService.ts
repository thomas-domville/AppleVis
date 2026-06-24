/**
 * Apple Intelligence / on-device AI integration
 *
 * JS layer (works today):
 *   translateContent   — opens Google Translate app (if installed) or web fallback
 *   detectNonEnglish   — Unicode-range heuristic, no API needed
 *   readAloud          — expo-speech text-to-speech, stops any current speech first
 *   stopReading        — stops active speech
 *
 * Native layer (stubs — require a native Expo module to activate):
 *   donateSiriActivity — tells Siri about an action the user just performed
 *                        so Siri learns to suggest it proactively
 *   summariseText      — Foundation Models on-device LLM (iOS 18.2+)
 *   indexInSpotlight   — CoreSpotlight, lets content appear in system Search
 *
 * To build the native side: create an Expo config plugin that adds the Swift
 * AppIntent types below, links the module, and registers the donation calls.
 * Each stub logs a reminder in __DEV__ so it is easy to find later.
 */

import { Linking } from 'react-native';
import * as Speech from 'expo-speech';
import { isAppleIntelligenceAvailable as nativeIsAvailable, runFoundationModel } from '../native/nativeModules';

// ─── Types ────────────────────────────────────────────────────────────────────

export type SiriIntent =
  | { type: 'openForums' }
  | { type: 'showUnread' }
  | { type: 'playLatestPodcast' }
  | { type: 'showSinceLastVisit' }
  | { type: 'continuePlaying' }
  | { type: 'searchApps'; query: string }
  | { type: 'openSaved' };

export type SpotlightItem = {
  id: string;
  title: string;
  description: string;
  contentType: 'forumTopic' | 'podcast' | 'app' | 'resource';
  url: string;
};

// ─── JS-only: translate via Google Translate ─────────────────────────────────

/**
 * Opens Google Translate with the supplied text pre-filled, auto-detecting
 * the source language and targeting English.
 *
 * Priority:
 *   1. Google Translate app (googletranslate://) if installed
 *   2. Google Translate web in the default browser
 *
 * Text is capped at 1 500 characters before encoding to keep URLs in range.
 * Used by TranslationBanner when a user types non-English in a compose field
 * — the goal is to help them produce an English post per site guidelines.
 */
export async function translateContent(text: string): Promise<void> {
  const capped  = text.trim().slice(0, 1500);
  const encoded = encodeURIComponent(capped);
  const appUrl  = `googletranslate://translate?text=${encoded}&sl=auto&tl=en`;
  const webUrl  = `https://translate.google.com/?sl=auto&tl=en&text=${encoded}`;
  try {
    const canUseApp = await Linking.canOpenURL(appUrl).catch(() => false);
    await Linking.openURL(canUseApp ? appUrl : webUrl);
  } catch {
    // Silent — if the URL cannot be opened (e.g. simulator) do nothing.
  }
}

// ─── JS-only: non-English text detection ─────────────────────────────────────

/**
 * Returns true when more than 30 % of the word characters in the string
 * fall outside the Basic Latin + Latin Extended range (U+0000–U+024F).
 * Covers CJK, Arabic, Cyrillic, Hebrew, Devanagari, Thai, and more.
 * Minimum 8 characters to avoid false positives on short strings.
 */
export function detectNonEnglish(text: string): boolean {
  const stripped = text.replace(/[\s\d\p{P}]/gu, '');
  if (stripped.length < 8) return false;
  const nonLatin = [...stripped].filter((c) => c.charCodeAt(0) > 0x024f).length;
  return nonLatin / stripped.length > 0.3;
}

// ─── JS-only: Read Aloud via expo-speech ─────────────────────────────────────

/**
 * Reads text aloud using the device's on-device TTS engine.
 * Stops any currently-playing speech first so tapping Read Aloud on a
 * second item doesn't overlap the first.
 * Useful for users who want to listen to content hands-free without
 * navigating through it element-by-element with VoiceOver.
 */
export async function readAloud(text: string): Promise<void> {
  try {
    const speaking = await Speech.isSpeakingAsync();
    if (speaking) await Speech.stop();
    Speech.speak(text, { language: 'en-US', rate: 0.92, pitch: 1.0 });
  } catch (_e) { /* non-critical */ }
}

export async function stopReading(): Promise<void> {
  try {
    const speaking = await Speech.isSpeakingAsync();
    if (speaking) await Speech.stop();
  } catch (_e) { /* non-critical */ }
}

export async function isReading(): Promise<boolean> {
  try { return await Speech.isSpeakingAsync(); } catch { return false; }
}

// ─── Apple Intelligence availability ─────────────────────────────────────────

/**
 * Returns true when the device supports Apple Intelligence and the user has
 * enabled it in Settings → Apple Intelligence & Siri. Delegates to the native
 * AppleVisIntelligence module — false in Expo Go / simulator / unsupported devices.
 */
export function isAppleIntelligenceAvailable(): boolean {
  return nativeIsAvailable();
}

// ─── Native stubs ─────────────────────────────────────────────────────────────
// These are no-ops until a native Expo module implements the bridge.
// The Swift AppIntent types to implement are documented below each stub.

/**
 * Donates a Siri user activity so Siri learns to suggest this action.
 *
 * Native side to implement (Swift):
 *   struct OpenForumsIntent: AppIntent {
 *     static var title: LocalizedStringResource = "Open Forums"
 *     static var description = IntentDescription("Open the AppleVis forums.")
 *     func perform() async throws -> some IntentResult {
 *       return .result()
 *     }
 *   }
 *   // Repeat for each SiriIntent type.
 *   // Register via: INInteraction(intent:, response:).donate()
 */
export function donateSiriActivity(intent: SiriIntent): void {
  if (__DEV__) {
    console.log('[AppleIntelligence] donateSiriActivity — native module not yet built:', intent);
  }
}

/**
 * Summarises text using Apple's on-device Foundation Models (iOS 18.1+).
 * Returns null when Apple Intelligence is not available on the device.
 */
export async function summariseText(text: string): Promise<string | null> {
  if (!isAppleIntelligenceAvailable()) return null;
  return runFoundationModel(
    `Summarise the following in 2–3 sentences:\n\n${text}`,
  );
}

/**
 * Rewrites text at a simpler reading level using Foundation Models.
 * Returns null when Apple Intelligence is not available on the device.
 */
export async function simplifyText(text: string): Promise<string | null> {
  if (!isAppleIntelligenceAvailable()) return null;
  return runFoundationModel(
    `Rewrite the following in plain, simple English that anyone can understand. ` +
    `Keep it under 100 words. Do not add new information:\n\n${text}`,
  );
}

export type DraftRewriteResult = {
  subject?: string;
  body: string;
};

async function cleanModelText(text: string | null): Promise<string | null> {
  if (!text) return null;
  const cleaned = text
    .replace(/^```(?:text|json)?/i, '')
    .replace(/```$/i, '')
    .trim();
  return cleaned || null;
}

export async function rewriteDraftFriendly({
  subject,
  body,
  isTopic,
}: {
  subject?: string;
  body: string;
  isTopic: boolean;
}): Promise<DraftRewriteResult | null> {
  if (!isAppleIntelligenceAvailable()) return null;

  const rewrittenBody = await cleanModelText(await runFoundationModel(
    `Rewrite this AppleVis ${isTopic ? 'forum topic body' : 'comment'} so it is personable, friendly, clear, and respectful. ` +
    `Preserve the author's meaning, facts, questions, and tone. Do not add new information. ` +
    `Do not include labels, explanations, markdown fences, or quotation marks around the result.\n\n${body}`,
  ));
  if (!rewrittenBody) return null;

  if (!isTopic || !subject?.trim()) return { body: rewrittenBody };

  const rewrittenSubject = await cleanModelText(await runFoundationModel(
    `Rewrite this AppleVis forum topic subject to be clear, friendly, and concise. ` +
    `Keep it under 90 characters. Do not add new information. Return only the subject text.\n\n${subject}`,
  ));

  return {
    subject: rewrittenSubject ?? subject,
    body: rewrittenBody,
  };
}

export async function translateDraftToEnglish({
  subject,
  body,
  isTopic,
}: {
  subject?: string;
  body: string;
  isTopic: boolean;
}): Promise<DraftRewriteResult | null> {
  if (!isAppleIntelligenceAvailable()) return null;

  const translatedBody = await cleanModelText(await runFoundationModel(
    `Translate this AppleVis ${isTopic ? 'forum topic body' : 'comment'} into natural English. ` +
    `Preserve the author's meaning, facts, questions, and intent. Do not add new information. ` +
    `Return only the translated text.\n\n${body}`,
  ));
  if (!translatedBody) return null;

  if (!isTopic || !subject?.trim()) return { body: translatedBody };

  const translatedSubject = await cleanModelText(await runFoundationModel(
    `Translate this AppleVis forum topic subject into natural English. ` +
    `Keep it concise. Return only the translated subject text.\n\n${subject}`,
  ));

  return {
    subject: translatedSubject ?? subject,
    body: translatedBody,
  };
}

export async function translateSearchQueryToEnglish(query: string): Promise<string | null> {
  if (!isAppleIntelligenceAvailable()) return null;
  return cleanModelText(await runFoundationModel(
    `Translate this AppleVis search query into natural English. ` +
    `Keep it short and search-friendly. Return only the translated query.\n\n${query.trim()}`,
  ));
}

/**
 * Generates a personalised "What's new" digest summarising recent activity.
 * Returns null when Apple Intelligence is not available on the device.
 */
export async function generateDigest(activitySummary: string): Promise<string | null> {
  if (!isAppleIntelligenceAvailable()) return null;
  return runFoundationModel(
    `Here is a list of new AppleVis activity since the user's last visit. ` +
    `Write a friendly 2–3 sentence digest for a blind VoiceOver user:\n\n${activitySummary}`,
  );
}

/**
 * Aggregates multiple app reviews into an accessibility consensus statement.
 * Returns null when Apple Intelligence is not available on the device.
 */
export async function accessibilityConsensus(reviews: string[]): Promise<string | null> {
  if (!isAppleIntelligenceAvailable()) return null;
  return runFoundationModel(
    `Summarise the following AppleVis accessibility reviews in 1–2 sentences, ` +
    `focusing on VoiceOver and accessibility:\n\n${reviews.join('\n\n')}`,
  );
}

/**
 * Cleans up a raw auto-generated podcast transcript.
 * Returns null when Apple Intelligence is not available on the device.
 */
export async function cleanTranscript(rawTranscript: string): Promise<string | null> {
  if (!isAppleIntelligenceAvailable()) return null;
  return runFoundationModel(
    `Clean up this auto-generated podcast transcript. Fix punctuation, remove ` +
    `filler words (um, uh, like), and correct obvious mis-transcriptions. ` +
    `Do not change the meaning:\n\n${rawTranscript}`,
  );
}

/**
 * Uses Foundation Models to check a draft post against the full AppleVis
 * posting guidelines. Returns an array of warnings — empty means no issues.
 * Falls back to [] when the native module is not built (rule-based checks
 * in guidelinesChecker.ts handle the obvious cases in the meantime).
 *
 * Native side prompt (Swift, FoundationModels):
 *   let guidelines = """
 *   [Full text of https://www.applevis.com/help/guidelines]
 *   """
 *   let prompt = """
 *   You are a content moderation assistant for AppleVis, an accessibility
 *   community for blind and low vision Apple users.
 *
 *   Review the following draft post and identify any CLEAR violations of
 *   the AppleVis posting guidelines below. Be conservative — only flag
 *   obvious violations, not borderline cases. If unsure, do not flag.
 *
 *   Respond ONLY with a JSON array. Each item must have:
 *     - id: a short camelCase identifier (e.g. "offTopic", "harassment")
 *     - rule: short guideline name (e.g. "Stay On Topic")
 *     - message: friendly 1–2 sentence reminder for the author
 *     - severity: "high" | "medium" | "low"
 *
 *   If no violations found, return: []
 *
 *   Guidelines:
 *   \(guidelines)
 *
 *   Draft post:
 *   \(text)
 *   """
 *   let session = LanguageModelSession()
 *   let result  = try await session.respond(to: prompt)
 *   // Parse result.content as JSON → [GuidelineWarning]
 */
export async function checkAgainstGuidelinesAI(
  text: string,
): Promise<import('./guidelinesChecker').GuidelineWarning[]> {
  if (!isAppleIntelligenceAvailable()) return [];
  const result = await runFoundationModel(
    `You are a content moderation assistant for AppleVis, an accessibility community ` +
    `for blind and low vision Apple users. Review the following draft post and identify ` +
    `any CLEAR violations of the AppleVis posting guidelines. Be conservative — only flag ` +
    `obvious violations. Respond ONLY with a JSON array where each item has: id, rule, message, severity. ` +
    `If no violations, return []\n\nDraft post:\n${text}`,
  );
  if (!result) return [];
  try {
    return JSON.parse(result) as import('./guidelinesChecker').GuidelineWarning[];
  } catch {
    return [];
  }
}

/**
 * Indexes a content item in Spotlight so it appears in system search.
 *
 * Native side to implement (Swift):
 *   import CoreSpotlight
 *   let attr = CSSearchableItemAttributeSet(contentType: .text)
 *   attr.title       = item.title
 *   attr.contentDescription = item.description
 *   let searchItem   = CSSearchableItem(uniqueIdentifier: item.id,
 *                                       domainIdentifier: "com.applevis.app",
 *                                       attributeSet: attr)
 *   CSSearchableIndex.default().indexSearchableItems([searchItem])
 */
export function indexInSpotlight(_item: SpotlightItem): void {
  if (__DEV__) {
    console.log('[AppleIntelligence] indexInSpotlight — native module not yet built:', _item.id);
  }
}
