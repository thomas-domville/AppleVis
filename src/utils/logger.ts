/**
 * Minimal structured dev-only logger. Use for native-module fallbacks and
 * other non-critical diagnostic logging that must never run in production.
 */
export function logDev(scope: string, message: string, data?: unknown): void {
  if (!__DEV__) return;
  if (data !== undefined) console.log(`[${scope}]`, message, data);
  else console.log(`[${scope}]`, message);
}
