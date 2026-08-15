# Push Notifications — Backend Coordination Brief

Written for whoever owns the Drupal push-send logic. This is the one open
item from the native-app release audit's Phase J that cannot be resolved
from the iOS client alone — it needs confirmation (and possibly a change)
on the server side.

## The concern, in one sentence

The legacy Expo app registered **Expo push tokens** (`ExponentPushToken[...]`,
delivered via Expo's push relay service); the new native Swift app registers
a **raw APNs device token** (a 64-character hex string, delivered directly by
Apple's push servers) — if the Drupal send logic still assumes the former,
notifications will silently fail to reach native-app users even though
registration itself appears to succeed.

## What the native app actually does today

- Calls `UIApplication.shared.registerForRemoteNotifications()`, receives a
  raw `Data` token from `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
- Hex-encodes it (`token.map { String(format: "%02.2hhx", $0) }.joined()`) —
  the standard, correct format for a raw APNs token.
- PATCHes it to the user's own JSON:API resource via
  `PATCH /jsonapi/user/user/{uuid}`:
  ```json
  { "data": { "type": "user--user", "id": "{uuid}", "attributes": {
      "field_push_token": "<64-char hex string>",
      "field_push_sound": "<sound file name, e.g. mouse_squeak.caf>"
  }}}
  ```
- On sign-out, the same field is cleared with an empty string.
- Source: `Sources/Networking/Endpoints/NotificationEndpoints.swift`,
  `Sources/Services/PushNotificationManager.swift`.

There is **no field distinguishing token type** (APNs vs. Expo) in the
payload — `field_push_token` is sent as a bare string either way, so the
backend can't tell which kind it received just by inspecting the request.

## What needs confirming on the Drupal side

1. **Does the current send logic call Expo's push API** (`https://exp.host/--/api/v2/push/send`
   or the `expo-server-sdk` equivalent), **or does it call APNs directly**
   (HTTP/2 to `api.push.apple.com`, with a `.p8` auth key or `.p12`
   certificate)?
   - If it's still Expo-based: it needs a native APNs send path added
     (most Drupal push modules — e.g. `push_framework`, or a custom HTTP/2
     APNs client — support this; the exact approach depends on what's
     already in place). A bare hex string handed to Expo's API will not be
     interpreted as a valid Expo token and will fail silently.
   - If it's already been migrated to direct APNs: this concern is
     resolved — worth closing out explicitly rather than leaving it as an
     open question the next person re-discovers.
2. **If both old (Expo) and new (native) clients need to be supported
   simultaneously** during a transition period, the backend will need to
   distinguish token formats at send time (Expo tokens have a
   distinctive `ExponentPushToken[...]` shape; a raw APNs token is a bare
   64-character hex string) and route each to the correct delivery
   mechanism — a single "does it look like a hex string" check might be a
   pragmatic-enough discriminator without necessarily adding a schema field.
3. **Payload shape the native app expects on the receiving end** — for a
   tapped/received notification to route to the right screen and appear in
   the in-app notification history, the payload's top-level keys must
   include:
   ```json
   { "kind": "forumTopic", "id": "<node/comment uuid>" }
   ```
   (`kind` is matched against the app's `ContentKind` raw values:
   `forumTopic`, `podcastEpisode`, `appListing`, `resource`, `blogPost`,
   `bugReport`.) Confirm the send logic actually populates these two keys
   for every notification category (forum reply, mention, new topic,
   followed-topic activity, new episode, app update, new resource,
   announcement) — a category missing them will still show a banner but
   won't deep-link anywhere when tapped.
4. **`aps-environment`** — the app's entitlements are `development` in the
   checked-in source (correct for local Xcode debug builds). Xcode
   substitutes this to `production` automatically in a properly
   provisioned release archive/IPA — **this needs a one-time manual
   confirmation on the actual signed build submitted to the App Store**,
   since a `development`-signed push certificate mismatch would cause every
   push to silently fail in production regardless of anything above. This
   isn't a code change; it's a "check the signed archive" step already
   tracked as pending in the release audit.

## What was checked and does *not* need action right now

- **Silent/background push** (`content-available: 1`, no alert): the native
  app has no `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`
  handler and doesn't declare the `remote-notification` `UIBackgroundModes`
  entry — confirmed via source grep, not just absence of evidence. This is
  consistent, not a gap: nothing in the app currently expects a silent push
  to wake it in the background (a separate `BGTaskScheduler`-based
  `com.applevis.autodownload` task already covers periodic background
  refresh through a different, non-push mechanism). If the backend ever
  wants to push silent background-refresh triggers, that's a genuine new
  feature requiring both the entitlement and a handler to be added
  together — not something to add speculatively without a concrete use case.

## Suggested next step

Whoever has access to the Drupal codebase's notification-send module should
grep for the actual outbound push call (search for `exp.host`, `expo`, or
the push module's send function) and report back which of the two scenarios
in item 1 above is currently true. That single answer determines whether
this is "already fine" or "needs a real backend change."
