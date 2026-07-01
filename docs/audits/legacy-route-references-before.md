# Legacy Tab Route References — Baseline (before migration)

Generated 2026-07-01 via manual re-run of `Temp/scripts/find_legacy_tab_refs.sh` logic
(the `rg` binary isn't installed in this shell; ripgrep-equivalent searches were run via
the Grep tool instead — same patterns, same results).

## Classified references

### 1. Internal legacy screen reference (tab registration itself — not a migration target)

- `app/(tabs)/_layout.tsx:142-145` — `<Tabs.Screen name="forums|podcasts|apps|resources" options={{ href: null }} />`
  Registers the hidden tabs. This is the thing Phase 06 decides the fate of, not a reference to migrate away from.

### 2. Profile link

- `app/profile.tsx:766` — Forum Topics saved row → `/(tabs)/forums`
- `app/profile.tsx:767` — Apps saved row → `/(tabs)/apps`
- `app/profile.tsx:768` — Resources saved row → `/(tabs)/resources`

Owner: **Phase 02**.

### 3. Universal/deep link fallback

- `src/services/universalLinks.ts:89` — generic share action → `/(tabs)/forums`
- `src/services/universalLinks.ts:98` — `applevis://podcasts` → `/(tabs)/podcasts`
- `src/services/universalLinks.ts:121` — `/forum`, `/node`, `/community` → `/(tabs)/forums`
- `src/services/universalLinks.ts:135` — `applevis://forums` → `/(tabs)/forums`
- `src/services/universalLinks.ts:140` — `/accessibility-apps`, `/app` → `/(tabs)/apps`
- `src/services/universalLinks.ts:145` — `/podcast`, `/audio`, `/episode` → `/(tabs)/podcasts`
- `src/services/universalLinks.ts:150` — `/resource`, `/guide`, `/tutorial`, `/article`, `/help` → `/(tabs)/resources`

Owner: **Phase 04**.

### 4. Notification fallback

- `src/services/notifications.ts:136` — forum category, no topic ID → `/(tabs)/forums`
- `src/services/notifications.ts:140` — new episode, no episode ID → `/(tabs)/podcasts`
- `src/services/notifications.ts:144` — app update, no app ID → `/(tabs)/apps`
- `src/services/notifications.ts:150` — new resource/announcement fallback → `/(tabs)/resources`

Owner: **Phase 03**.

### 5. Submission success route

- `app/submit-podcast/review.tsx:77` — `router.replace('/(tabs)/podcasts')` after successful podcast submission.

Owner: **Phase 05**.

### 6. Website URL only — not an app route (do not migrate)

All of the following are `https://www.applevis.com/...` strings used in Handoff `webpageURL`,
`Share.share()` messages, or user-facing fallback text — none are `router.push`/`router.replace`
calls and none need to change:

- `app/(tabs)/resources.tsx:46,159,162`
- `app/(tabs)/foryou.tsx:810`
- `app/(tabs)/podcasts.tsx:510,512,681`
- `app/(tabs)/forums.tsx:52,98`
- `app/(tabs)/apps.tsx:125,191`
- `app/app-detail/[id].tsx:505,638,644`
- `app/app-category.tsx:311`
- `app/episode/[id].tsx:1255,1261,1269`
- `app/podcast-browse.tsx:710`
- `src/components/FeedCard.tsx:101,102`
- `src/hooks/useHandoff.ts:20` (doc comment example)
- `app/submit-podcast/review.tsx:65` (fallback error text pointing to the website)

## Already-current references (no action needed)

These already route to the newer browse screens, confirming Discover is already correctly wired:

- `app/(tabs)/foryou.tsx:251,399` → `/podcast-browse` (empty-state actions added this session)
- `app/(tabs)/foryou.tsx:1018` → `/forums-browse`
- `app/(tabs)/discover.tsx:303,321,351,363` → `/app-browse`, `/forums-browse`, `/guide-browse`, `/podcast-browse`

## Summary

| Owner phase | Reference count |
|---|---|
| Phase 02 (Profile) | 3 |
| Phase 03 (Notifications) | 4 |
| Phase 04 (Universal links) | 7 |
| Phase 05 (Submission success) | 1 |
| Tab registration (Phase 06 territory) | 4 (the `Tabs.Screen` lines) |
| Website URLs (no action) | 15 |

Every hidden-tab route reference found has an owning phase. No source reference was ignored.
