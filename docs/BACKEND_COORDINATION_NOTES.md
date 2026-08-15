# Backend Coordination Notes

Running list of release-audit findings that need a change or confirmation
on the Drupal side, not just the iOS client. See also
`PUSH_NOTIFICATION_BACKEND_COORDINATION.md` for the push-notification-
specific brief (kept separate since it's substantial on its own).

## Forums list pagination has no real "more" signal (ARCH-10)

- **Where:** `ForumEndpoints.recent(page:appleOnly:)`, which calls the
  native REST endpoint `/api/v1/forums/recent?page=N`.
- **The issue:** Every other primary browse-list endpoint (Apps, Podcasts,
  Guides, Blogs, Bug Reports) uses Drupal JSON:API, which returns a
  standard `links.next` entry the client can trust as a true "is there
  another page" signal — those five have been converged onto it (see the
  `PagedListResult` changes in `AppEndpoints`, `PodcastEndpoints`, and
  `ContentEndpoints`). Forums' list is the one exception: `/api/v1/forums/recent` is a custom native REST
  endpoint that returns a bare JSON array with no pagination metadata at
  all, so the client has no choice but to keep guessing "more" from
  whether the last page came back full — which is wrong whenever a page
  happens to land exactly full but no more topics actually exist.
- **What would fix it:** Either add a `hasMore` boolean (or a total count)
  to `/api/v1/forums/recent`'s JSON response, matching the shape the
  Apps-directory native REST endpoint (`/apps/{platform}/categories/{id}`)
  already returns, or move Forums' list onto a JSON:API-backed endpoint
  the way the other content types are — whichever is less work on the
  Drupal side.
- **Already checked, so this doesn't need re-confirming:** verified live
  against production (2026-08-15) that `GET /api/v1/forums/recent?page=0`
  truly has no pagination signal anywhere — not in the JSON body, not in
  any response header (no `Link`, no `X-Total-Count`), returns exactly 20
  items per page. Also tried routing Forums' list through the same Solr
  JSON:API index (`jsonapi/index/solr_site_index`) the app's search
  feature now uses, since that index does return a standard `links.next`
  — it works for listing `type=forum` nodes without a search term, but its
  default sort (`sort=-changed`) doesn't match the site's actual "sorted
  by last comment activity" ordering (a topic with a brand-new comment but
  an old node-edit timestamp ranks low, when it should rank near the top —
  same mismatch the original code comment already flagged). Tried
  `sort=-comment_forum.last_comment_timestamp` on that index directly —
  server returns `400 Bad Request`, so that field isn't exposed as a sort
  key on the index today. So this can't be worked around purely
  client-side; either the native endpoint needs the pagination field
  added, or the Solr index needs that sort key exposed.
- **Not blocking:** the heuristic isn't wrong most of the time — it only
  misfires at the specific boundary of an exactly-full final page — so this
  is a real but low-frequency bug, not a functional break.

## "Report Comment" has no real backend flag to submit to (App Store Guideline 1.2)

- **Where:** `ResourceDetailView.swift`'s `ConditionalAccessibilityAction`/
  Menu "Report Comment" action (and the same shared comment-row component
  used by Blog/Bug Report comments) — currently just shows a toast:
  "Reporting is coming once the Drupal Flags API is confirmed."
- **The issue:** Apple's Guideline 1.2 (User-Generated Content) expects a
  real mechanism for users to flag objectionable content, not just a UI
  affordance that does nothing server-side. The app already has a working
  generic Drupal "flagging" JSON:API pattern for follows (see
  `FlagEndpoints.follow`/`unfollow` in `ContentEndpoints.swift`, machine
  name `subscribe_node`) — the same pattern would work for abuse reporting
  IF there's a configured flag for it, but guessing a machine name and
  wiring it up blind risks silently hitting a 404 or, worse, flagging the
  wrong thing.
- **What's needed:** Confirm whether a content-abuse-report flag already
  exists in Drupal's Flag module config on this site (a plausible machine
  name would be something like `report_content` or `abuse`, but this needs
  confirming, not guessing) and, if so, its exact machine name. If none
  exists yet, it needs to be created before this can go from a "coming
  soon" stub to a real, submittable moderation mechanism.
- **Not fully blocking on its own:** the app also has a general Contact
  App Support wizard as a fallback reporting path, and existing post-hoc
  moderation (admin-gated edit/delete/unpublish) is real and functional —
  but Apple review notes should mention both explicitly if this ships
  before the dedicated Report flag is wired up.
