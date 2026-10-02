# App Store Review Notes

This file is the source of truth for text to paste into App Store Connect's
App Review Information section. Keep credentials and other secrets out of this
repository.

## Account deletion

Account deletion is available in Profile > Account > Delete Account. The app
requires an explicit acknowledgement followed by a final destructive-action
confirmation. When confirmed, the app deletes the member's account through the
same production Drupal backend used by AppleVis.com. This permanently removes
the account and its associated server-side profile information, authored posts
and comments, saved and followed content, and push-notification registration.
After the server confirms deletion, the app signs the member out and clears the
authenticated session from the device.

## Legal entity check before submission

Confirm the legal entity that owns the Apple Developer Program membership and
will appear as the App Store seller. Do not describe the Be My Eyes Foundation
as AppleVis's legal owner or App Store publisher unless that relationship has
been formally confirmed. As of October 2, 2026, the public AppleVis Terms of
Service and Privacy Policy describe AppleVis as a division of Accessibly Inc.
dba Be My Eyes, while the AppleVis About page says AppleVis is supported in part
by contributions to the Be My Eyes Foundation.

