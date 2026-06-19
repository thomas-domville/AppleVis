# Implementation Notes

This ZIP is a buildable starter scaffold, not a finished production app.

Expo is useful for quickly developing the UI and core experience. The following require native iOS work or config plugins:

- Apple Watch app and complications
- Dynamic Island and Live Activities via ActivityKit
- Full Siri App Intents/App Shortcuts
- iCloud key-value store or CloudKit
- MPRemoteCommandCenter and Now Playing metadata beyond basic audio playback
- Smart Speed/silence trimming DSP
- Voice enhancement/EQ audio pipeline
- Home Screen/Lock Screen/StandBy widgets

Recommended production path:

1. Build and test the Expo UI.
2. Add real AppleVis Drupal API endpoints.
3. Implement local persistence for saved/read/list position.
4. Add account sync through AppleVis API.
5. Add native iOS modules for Apple ecosystem features.
6. Add watchOS target.
7. Add WidgetKit target.
8. Add ActivityKit Live Activity.
9. Complete App Store privacy/accessibility compliance checklist.

## AppleVis Tips Pattern

Use `src/components/HelpfulTip.tsx` for short contextual guidance, friendly
warnings, and recoverable error explanations throughout the app.

Guidelines:

- Add tips where they reveal a useful hidden workflow, prevent a likely mistake,
  or explain a recoverable error near the place it happened.
- Keep each message short and focused on one action or idea.
- Prefer contextual tips near the relevant control or screen, not large tutorial
  blocks.
- Give persistent tips a stable `id` so users can dismiss them once.
- Add `syncDismissal` for evergreen "seen this before" tips that should stay
  dismissed after reinstalling the app or moving to a new device.
- Leave `syncDismissal` off for device-specific, session-specific, permission,
  storage, download, or temporary error messages.
- Respect the global AppleVis Tips switch in Accessibility settings by using the
  shared component. The switch is iCloud-synced.
- Use `variant="tip"` for guidance, `variant="warning"` for cautionary reminders,
  and `variant="error"` for recoverable problems that need a clearer explanation
  than a toast.
- Do not use tips for critical blocking errors that require an alert, form field
  validation that belongs inline, or content that should live in Help.

## Welcome Summary

Home shows a short "Since your last visit" summary when loaded feed items have
activity newer than the iCloud-synced `lastVisit` timestamp. Keep this summary
brief, grouped by content type, and non-blocking.

Guidelines:

- Read the previous visit timestamp before stamping the current visit.
- Respect the iCloud-synced Welcome Summary setting in Accessibility settings.
- If the summary appears on initial Home load, VoiceOver focus should land on
  the summary before the first feed card. If there is no summary, keep the
  existing first-card focus behavior.
- Do not use the splash screen for dynamic counts; render dynamic updates on
  Home after content has loaded.

## VoiceOver Detail Page Navigation

On pushed detail pages, avoid exposing both the shared outer `Screen` title and
the in-page content heading to VoiceOver. The outer title sits outside the
scrollable detail content and can cause right-swipe navigation to stop at the
heading until the user touch-explores lower content.

Guidelines:

- If a detail page renders its own accessible in-page heading, pass
  `titleAccessible={false}` to `Screen`.
- Make the first meaningful in-page content element `accessibilityRole="header"`.
- After changing app, topic, resource, blog, podcast episode, or discussion
  detail layouts, test VoiceOver order from the Back button: swipe right should
  reach the page heading, then continue into the next content element without
  needing touch exploration.
- For collapsed detail sections, only render "Show full ..." / "Read more"
  controls when there is actually hidden content. Long single paragraphs that
  are shown in full should not get an expand button.
- When rendering comments on detail pages, include the comment `subject` in the
  visible header and VoiceOver label when it is meaningful. Suppress generic
  subjects such as "Reply" or "Comment", and suppress subjects that simply
  duplicate the parent title.
- Render user comments as two accessibility areas: an actionable header
  containing author, date, subject, new state, and comment actions; then a
  separate readable body. Do not put the full comment body into the parent
  card label. This keeps VoiceOver output shorter and makes Braille navigation
  more predictable.
- Podcast episode detail should keep community comments inline, not hidden
  behind a separate discussion card. Avoid redundant jump controls when the
  target section is already nearby in the normal reading order.
- Detail page comment section headings should clearly name the section, for
  example "Community Discussion - 32 comments - 1 new", instead of starting with
  a bare count.
- Detail-page submitter profile popups share `AuthorProfileModal`. Keep this
  modal consistent with detail page accessibility work: the member name should
  be the heading, swipe order should continue into details/actions, and rows
  should remain concise for Braille users. As of the June 2026 API probe,
  AppleVis public `user--user` records expose only `display_name`; location,
  bio, website, member-since, numeric uid, and profile path should be rendered
  only when the API returns them.

## Accessible Alerts

Use `AccessibleAlertContext` for blocking messages such as sign-in-required,
expired-session, and failed-submit errors.

Guidelines:

- Do not make the modal card itself one large accessible element. VoiceOver
  must be able to reach every action button inside the alert.
- Move VoiceOver focus to the alert title when it opens, and include the
  message in that title's accessibility label so the alert is announced
  immediately.
- Hide the separate message text from accessibility when it is already included
  in the title label, to avoid duplicate speech.
- Support `onAccessibilityEscape` so VoiceOver users can dismiss the alert with
  the standard escape gesture.
- Confirm sign-in-required alerts from comments and detail-page actions expose
  both the cancel/dismiss action and the sign-in action.

## New Comment Tracking

Home feed "new comment" counts use local item visit records. Opening a detail
page stamps that item's current comment count and visit time. Refreshing Home
or closing and reopening the app should not clear a per-item new-comment count
unless the user has opened that item. Items with no prior visit record have no
baseline, so they should not show all existing comments as new.
