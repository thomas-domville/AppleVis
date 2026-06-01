/**
 * Thin event bus for cross-module auth signals.
 *
 * When any API call returns HTTP 401 (session expired), the caller emits
 * `sessionExpiry`. The root layout registers a handler that clears the
 * local session and shows a toast, without creating a circular import
 * between the API layer and the React context layer.
 */

type Handler = () => void;
let _handler: Handler | null = null;

export const authEvents = {
  onSessionExpiry(handler: Handler): void {
    _handler = handler;
  },

  emitSessionExpiry(): void {
    _handler?.();
  },
};
