import type { AlertOptions } from '../contexts/AccessibleAlertContext';

type ShowAlert = (options: AlertOptions) => void;

type ConfirmDestructiveActionOptions = {
  title: string;
  message: string;
  confirmLabel: string;
  cancelLabel?: string;
  onConfirm: () => void;
};

/**
 * Shows a two-button alert where the confirming action is destructive.
 * Use for irreversible actions (delete, clear queue, remove downloads, etc.)
 * instead of building the buttons array inline at each call site.
 */
export function confirmDestructiveAction(
  showAlert: ShowAlert,
  { title, message, confirmLabel, cancelLabel = 'Cancel', onConfirm }: ConfirmDestructiveActionOptions,
): void {
  showAlert({
    title,
    message,
    buttons: [
      { label: confirmLabel, style: 'destructive', onPress: onConfirm },
      { label: cancelLabel, style: 'cancel' },
    ],
  });
}
