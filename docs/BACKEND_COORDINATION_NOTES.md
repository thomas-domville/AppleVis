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
  another page" signal — those five have been converged onto it (see
  `ThemeColors`... no, see the pagination convergence commit/changes in
  `AppEndpoints`, `PodcastEndpoints`, `ContentEndpoints`). Forums' list is
  the one exception: `/api/v1/forums/recent` is a custom native REST
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
- **Not blocking:** the heuristic isn't wrong most of the time — it only
  misfires at the specific boundary of an exactly-full final page — so this
  is a real but low-frequency bug, not a functional break.
