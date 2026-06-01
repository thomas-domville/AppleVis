import { useCallback, useEffect, useRef, useState } from 'react';
import { AccessibilityInfo } from 'react-native';
import { checkGuidelines, type GuidelineWarning } from '../services/guidelinesChecker';
import { checkAgainstGuidelinesAI } from '../services/intelligenceService';

/**
 * Watches a draft post/reply for potential guideline violations.
 *
 * - Rule-based checks fire after 1.5 s of inactivity (fast, always available).
 * - Foundation Models AI check fires after 3 s (richer, when native module is built).
 * - Once the user dismisses a warning by ID it won't reappear for this session.
 * - VoiceOver is notified via announceForAccessibility when a new warning appears.
 * - The post button is never disabled — this is advisory only.
 *
 * Usage in a compose screen:
 *   const { topWarning, dismiss } = useGuidelinesCheck(draftText);
 *   {topWarning && <GuidelinesReminder warning={topWarning} onDismiss={dismiss} />}
 */
export function useGuidelinesCheck(text: string) {
  const [warnings, setWarnings]     = useState<GuidelineWarning[]>([]);
  const dismissedIds                = useRef<Set<string>>(new Set());
  const lastAnnouncedId             = useRef<string | null>(null);

  // ── Rule-based check (1.5 s debounce) ────────────────────────────────────
  useEffect(() => {
    if (text.trim().length < 10) { setWarnings([]); return; }

    const timer = setTimeout(() => {
      const all     = checkGuidelines(text);
      const visible = all.filter((w) => !dismissedIds.current.has(w.id));
      setWarnings(visible);
    }, 1500);

    return () => clearTimeout(timer);
  }, [text]);

  // ── Foundation Models check (3 s debounce, no-op until native module) ────
  useEffect(() => {
    if (text.trim().length < 30) return;

    const timer = setTimeout(async () => {
      const aiWarnings = await checkAgainstGuidelinesAI(text);
      if (aiWarnings.length === 0) return;
      setWarnings((prev) => {
        const existingIds = new Set(prev.map((w) => w.id));
        const newOnes = aiWarnings.filter(
          (w) => !existingIds.has(w.id) && !dismissedIds.current.has(w.id),
        );
        if (newOnes.length === 0) return prev;
        const merged = [...prev, ...newOnes];
        const order: Record<GuidelineWarning['severity'], number> = { high: 0, medium: 1, low: 2 };
        return merged.sort((a, b) => order[a.severity] - order[b.severity]);
      });
    }, 3000);

    return () => clearTimeout(timer);
  }, [text]);

  // ── Announce the top warning to VoiceOver when it first appears ───────────
  useEffect(() => {
    const top = warnings[0];
    if (!top || top.id === lastAnnouncedId.current) return;
    lastAnnouncedId.current = top.id;
    AccessibilityInfo.announceForAccessibility(
      `Guideline reminder: ${top.rule}. ${top.message}`,
    );
  }, [warnings]);

  const dismiss = useCallback((id: string) => {
    dismissedIds.current.add(id);
    setWarnings((prev) => prev.filter((w) => w.id !== id));
  }, []);

  const dismissAll = useCallback(() => {
    warnings.forEach((w) => dismissedIds.current.add(w.id));
    setWarnings([]);
  }, [warnings]);

  return {
    /** The single highest-priority warning to show, or null if none. */
    topWarning:  warnings[0] ?? null,
    /** All active warnings, sorted high → medium → low. */
    allWarnings: warnings,
    dismiss,
    dismissAll,
  };
}
