/**
 * Apple Intelligence / on-device AI integration
 *
 * JS layer (works today):
 *   translateContent   — opens iOS Share sheet; user picks Translate app
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

import { Share } from 'react-native';
import * as Speech from 'expo-speech';

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

// ─── JS-only: translate via system Share sheet ────────────────────────────────

/**
 * Opens the iOS Share sheet with the supplied text. The system Translate
 * option appears automatically — no native code needed.
 */
export async function translateContent(text: string, title?: string): Promise<void> {
  try {
    await Share.share({ message: text, ...(title ? { title } : {}) });
  } catch {
    // User cancelled or share not available — silent.
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
  } catch {}
}

export async function stopReading(): Promise<void> {
  try {
    const speaking = await Speech.isSpeakingAsync();
    if (speaking) await Speech.stop();
  } catch {}
}

export async function isReading(): Promise<boolean> {
  try { return await Speech.isSpeakingAsync(); } catch { return false; }
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
 * Summarises text using Apple's on-device Foundation Models (iOS 18.2+).
 * Falls back to null when the native module is absent.
 *
 * Native side to implement (Swift, requires iOS 18.2+):
 *   import FoundationModels
 *   let session = LanguageModelSession()
 *   let summary = try await session.respond(
 *     to: "Summarise the following in 2–3 sentences:\n\n\(text)"
 *   )
 */
export async function summariseText(_text: string): Promise<string | null> {
  if (__DEV__) console.log('[AppleIntelligence] summariseText — native module not yet built.');
  return null;
}

/**
 * Rewrites text at a simpler reading level using Foundation Models.
 * Useful for users who need plain-language versions of technical content.
 *
 * Native prompt (Swift):
 *   "Rewrite the following in plain, simple English that anyone can understand.
 *    Keep it under 100 words. Do not add new information:\n\n\(text)"
 */
export async function simplifyText(_text: string): Promise<string | null> {
  if (__DEV__) console.log('[AppleIntelligence] simplifyText — native module not yet built.');
  return null;
}

/**
 * Generates a personalised "What's new" digest summarising recent activity.
 * Called on app open after a long absence; result shown on the Home screen.
 *
 * Native prompt (Swift):
 *   "Here is a list of new AppleVis activity since the user's last visit.
 *    Write a friendly 2–3 sentence digest for a blind VoiceOver user:\n\n\(activity)"
 */
export async function generateDigest(_activitySummary: string): Promise<string | null> {
  if (__DEV__) console.log('[AppleIntelligence] generateDigest — native module not yet built.');
  return null;
}

/**
 * Aggregates multiple app reviews into an accessibility consensus statement.
 * E.g. "Most reviewers say this app works well with VoiceOver. Some note issues
 *       with the in-app purchase screen."
 *
 * Native prompt (Swift):
 *   "Summarise the following AppleVis accessibility reviews in 1–2 sentences,
 *    focusing on VoiceOver and accessibility:\n\n\(reviews)"
 */
export async function accessibilityConsensus(_reviews: string[]): Promise<string | null> {
  if (__DEV__) console.log('[AppleIntelligence] accessibilityConsensus — native module not yet built.');
  return null;
}

/**
 * Cleans up a raw auto-generated podcast transcript:
 * fixes punctuation, removes filler words, corrects common mis-transcriptions.
 *
 * Native prompt (Swift):
 *   "Clean up this auto-generated podcast transcript. Fix punctuation, remove
 *    filler words (um, uh, like), and correct obvious mis-transcriptions.
 *    Do not change the meaning:\n\n\(transcript)"
 */
export async function cleanTranscript(_rawTranscript: string): Promise<string | null> {
  if (__DEV__) console.log('[AppleIntelligence] cleanTranscript — native module not yet built.');
  return null;
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
  _text: string,
): Promise<import('./guidelinesChecker').GuidelineWarning[]> {
  if (__DEV__) console.log('[AppleIntelligence] checkAgainstGuidelinesAI — native module not yet built.');
  return [];
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
