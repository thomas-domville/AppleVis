import type { AlertOptions } from '../contexts/AccessibleAlertContext';

/**
 * Centralised message library for AccessibleAlert.
 *
 * Every message is written for beginners: detailed, jargon-free, and
 * actionable. Where a message needs an onConfirm/onCancel callback (e.g.
 * navigating to sign-in), pass it at the call-site:
 *
 *   showAlert({ ...ALERTS.auth.signInRequired('follow topics'), onConfirm: () => router.push('/settings-account') })
 */
export const ALERTS = {

  // ── Authentication ─────────────────────────────────────────────────────────

  auth: {
    signInRequired: (action = 'perform this action'): AlertOptions => ({
      title: 'Sign In Required',
      message:
        `To ${action} you need to be signed in to your AppleVis account. ` +
        `Creating an account is free and only takes a few minutes.\n\n` +
        `Tap "Sign In" to go to the sign-in screen, or "Not Now" to return to what you were doing.`,
      confirmLabel: 'Sign In',
      cancelLabel: 'Not Now',
      type: 'info',
    }),

    signInFailed: (reason?: string): AlertOptions => ({
      title: 'Sign In Failed',
      message: reason
        ? `We could not sign you in. ${reason}\n\n` +
          `Please check your email address or username and password and try again. ` +
          `If you have forgotten your password, you can reset it on the AppleVis website.`
        : `We could not sign you in. Please check that your email address or username ` +
          `and password are correct, then try again.\n\n` +
          `If you have forgotten your password, you can reset it on the AppleVis website.`,
      confirmLabel: 'OK',
      type: 'error',
    }),

    sessionExpired: (): AlertOptions => ({
      title: 'Session Expired',
      message:
        `Your sign-in session has ended. This happens automatically after a period ` +
        `of inactivity to keep your account secure — it does not mean anything is wrong.\n\n` +
        `Please sign in again to continue posting, following topics, and using ` +
        `other account features.`,
      confirmLabel: 'OK',
      type: 'warning',
    }),

    signedInSuccess: (name: string): AlertOptions => ({
      title: 'Welcome Back',
      message:
        `You are now signed in as ${name}. You can now post in the forums, ` +
        `follow topics, write app reviews, and receive personalised notifications.`,
      confirmLabel: 'Continue',
      type: 'success',
    }),
  },

  // ── Network / server ───────────────────────────────────────────────────────

  network: {
    connectionError: (): AlertOptions => ({
      title: 'Connection Problem',
      message:
        `AppleVis could not connect to the server. This usually means your device ` +
        `is not connected to the internet, or the AppleVis server is temporarily ` +
        `unavailable.\n\n` +
        `Please check your internet connection and try again in a moment.`,
      confirmLabel: 'OK',
      type: 'error',
    }),

    serverError: (detail?: string): AlertOptions => ({
      title: 'Server Error',
      message: detail
        ? `The AppleVis server returned an error: ${detail}\n\n` +
          `Please try again. If the problem continues, contact the AppleVis team.`
        : `The AppleVis server returned an unexpected error. ` +
          `Please try again in a moment. If the problem continues, contact the AppleVis team.`,
      confirmLabel: 'OK',
      type: 'error',
    }),
  },

  // ── Posting / compose ──────────────────────────────────────────────────────

  compose: {
    postFailed: (reason?: string): AlertOptions => ({
      title: 'Post Not Sent',
      message: reason
        ? `Your post could not be sent: ${reason}\n\n` +
          `Your text has been kept so you can try again. If this keeps happening, ` +
          `try signing out and signing back in from Settings.`
        : `Your post could not be sent. This may be a temporary network issue. ` +
          `Your text has been kept so you can try again.`,
      confirmLabel: 'OK',
      type: 'error',
    }),

    replyFailed: (reason?: string): AlertOptions => ({
      title: 'Reply Not Sent',
      message: reason
        ? `Your reply could not be posted: ${reason}\n\n` +
          `Your reply text has been kept. Please try again in a moment.`
        : `Your reply could not be posted. This may be a temporary network issue. ` +
          `Your reply text has been kept so you can try again.`,
      confirmLabel: 'OK',
      type: 'error',
    }),

    commentFailed: (reason?: string): AlertOptions => ({
      title: 'Comment Not Sent',
      message: reason
        ? `Your comment could not be posted: ${reason}\n\n` +
          `Your comment text has been kept. Please try again.`
        : `Your comment could not be posted. Please check your internet connection ` +
          `and try again. Your comment text has been kept.`,
      confirmLabel: 'OK',
      type: 'error',
    }),
  },

  // ── Content actions ────────────────────────────────────────────────────────

  content: {
    saveFailed: (): AlertOptions => ({
      title: 'Could Not Save',
      message:
        `This item could not be saved. This may be due to a connection problem. ` +
        `Please try again in a moment.`,
      confirmLabel: 'OK',
      type: 'error',
    }),

    downloadFailed: (): AlertOptions => ({
      title: 'Download Failed',
      message:
        `This episode could not be downloaded to your device. Please check that ` +
        `you are connected to the internet and try again.\n\n` +
        `If the problem continues, the episode file may be temporarily unavailable.`,
      confirmLabel: 'OK',
      type: 'error',
    }),

    reportFailed: (): AlertOptions => ({
      title: 'Report Not Sent',
      message:
        `Your report could not be submitted. Please check your internet connection ` +
        `and try again. If the problem persists, you can contact the AppleVis team directly.`,
      confirmLabel: 'OK',
      type: 'error',
    }),
  },

  // ── Reviews ────────────────────────────────────────────────────────────────

  reviews: {
    submitFailed: (): AlertOptions => ({
      title: 'Review Not Submitted',
      message:
        `Your review could not be submitted. This may be due to a connection ` +
        `problem or an issue with your session.\n\n` +
        `Please try again. If the problem continues, try signing out and signing ` +
        `back in from Settings.`,
      confirmLabel: 'OK',
      type: 'error',
    }),

    submitSuccess: (): AlertOptions => ({
      title: 'Review Submitted',
      message:
        `Thank you! Your review has been received and will be visible to other ` +
        `AppleVis members after a short review period. The AppleVis community ` +
        `benefits greatly from member reviews.`,
      confirmLabel: 'Great, thanks',
      type: 'success',
    }),
  },

  // ── App submission ─────────────────────────────────────────────────────────

  submission: {
    submitFailed: (what = 'your submission'): AlertOptions => ({
      title: 'Submission Failed',
      message:
        `We could not send ${what}. Please check your internet connection ` +
        `and try again.\n\n` +
        `If the problem continues, try signing out and signing back in, ` +
        `then submit again.`,
      confirmLabel: 'OK',
      type: 'error',
    }),

    submitSuccess: (): AlertOptions => ({
      title: 'Submitted Successfully',
      message:
        `Your submission has been received by the AppleVis team. It will be ` +
        `reviewed and published shortly. Thank you for contributing to the community!`,
      confirmLabel: 'OK',
      type: 'success',
    }),
  },

  // ── Account ────────────────────────────────────────────────────────────────

  account: {
    deleteConfirm: (): AlertOptions => ({
      title: 'Delete Your Account?',
      message:
        `This will permanently delete your AppleVis account, including all your ` +
        `forum posts, comments, reviews, and profile information on applevis.com. ` +
        `This action cannot be undone.\n\n` +
        `Your locally saved content — downloads, settings, and cache — will remain ` +
        `on this device until you clear them manually.\n\n` +
        `Are you absolutely sure you want to delete your account?`,
      confirmLabel: 'Delete Account',
      cancelLabel: 'Cancel',
      type: 'error',
    }),

    deleteFailed: (reason?: string): AlertOptions => ({
      title: 'Account Could Not Be Deleted',
      message: reason
        ? `Your account could not be deleted: ${reason}\n\n` +
          `Please try again. If the problem continues, contact the AppleVis team for assistance.`
        : `Your account could not be deleted at this time. This may be a temporary ` +
          `server issue. Please try again, or contact the AppleVis team for assistance.`,
      confirmLabel: 'OK',
      type: 'error',
    }),
  },

  // ── Generic fallback ───────────────────────────────────────────────────────

  generic: {
    error: (detail?: string): AlertOptions => ({
      title: 'Something Went Wrong',
      message: detail
        ? `An unexpected error occurred: ${detail}\n\n` +
          `Please try again. If the problem continues, please contact the AppleVis team.`
        : `An unexpected error occurred. Please try again. ` +
          `If the problem continues, contact the AppleVis team.`,
      confirmLabel: 'OK',
      type: 'error',
    }),

    permissionDenied: (what: string): AlertOptions => ({
      title: 'Permission Required',
      message:
        `AppleVis needs permission to ${what}. ` +
        `You can grant this in your iPhone's Settings app under AppleVis.`,
      confirmLabel: 'OK',
      type: 'info',
    }),
  },
};
