# Drupal reply validation — October 5, 2026

This covers only the developer's pin, flagging, and read-history response.

## Live checks completed

- Public `GET /api/v1/forums/recent?page=0`: HTTP 200, 20 rows. All rows include `sticky` as a string. All values on this page were `"0"`.
- Public JSON:API query for sticky forum nodes: HTTP 200 with no visible records. This does not prove there are no pinned topics on the website; the developer should provide a known pinned example for comparison.
- Public recommendation records: HTTP 200 with no visible records and authorization omissions. Own-record filtering cannot provide a public count of everyone's recommendations.

## Authenticated live results

The user authorized testing items 2 and 3 with Snorlax. Checks completed against the production site:

- Signed-in form-encoded history batch: HTTP 200 with a valid per-node integer mapping.
- Anonymous history batch: HTTP 403.
- One topic marked read: HTTP 200 with a positive timestamp. A subsequent batch lookup returned the exact same timestamp. The later diagnostic session also retrieved that persisted read status. This changed Snorlax's read timestamp for that one topic.
- Temporary subscriptions and recommendations: creation HTTP 201; owner relationship matched Snorlax; unfiltered queries returned the created records.
- Both flag types: `filter[uid.id]`, `filter[entity_id]`, and their combination returned HTTP 200 but did not return the created records. Repeated with fresh records to verify ownership and unfiltered visibility. The filter fix is not functioning on production; deployment/configuration needs checking.
- Snorlax's deletion of all temporary records: HTTP 204. Existing records were not deleted. Anonymous delete requests were denied with HTTP 403. This does not test another signed-in user's deletion access.
- Final test session logout: HTTP 204. The first session's logout attempt was HTTP 403 because the script originally omitted Drupal's separate logout token; the script was corrected for the follow-up session.

These are API checks, not an executed iOS app/device test. The app's filtered Following/Recommended/removal flows still depend on the server filter fix. No claim that the deletion ownership security patch is verified.

## App changes

- Accept sticky string values, display an accessible Pinned label, and sort pins first among loaded forum topics.
- Refresh recent and category browsing from the server, with the existing cache available as an offline fallback.
- Use supported own-user flag filters for removal; read the target relationship rather than filter the computed field.
- Fetch all pages of Following and Recommended lists.
- Use form-encoded batch history requests and merge newer website reads into Home and Forums. Later comments remain new on Home.
- Explicit Mark as Read and Mark All as Read now also send website history writes while signed in. Fetch offers Mark This Group as Read on the heading and every comment; all use the same complete-item path. Mark Read Up to Here has been removed at the user's request to match the website's whole-topic behavior.
- Website writes run at most four at a time, resolve missing numeric IDs, and check the current account before each write. Failure leaves local read history intact and displays a translated message. Offline writes are not replayed later, which would risk clearing replies posted after the original action.

## Build and device validation still required

This workspace is on Windows. No Xcode, connected iOS device, configured Mac build workflow, or iOS simulator is available here. Swift syntax checks can run, but they do not substitute for an iOS build or device test.

On a Mac, open `AppleVis.xcodeproj`, select the shared AppleVis scheme and an available iOS simulator, then run Product > Test. Run the app on the test device for these checks:

1. Refresh Forums with a known pinned topic included in the loaded results. Confirm Pinned appears visually and in VoiceOver/Braille. Check large Dynamic Type and Switch Control navigation. Unpin the topic on the website and refresh; confirm the label disappears and its position follows normal activity order.
2. Use a test account with a website subscription and recommendation. Confirm Following and Recommended show them; remove each from the app and confirm removal on the website. Check an account with more than 50 records to verify later pages.
3. Read a topic on the website, refresh Home and Forums in the signed-in app, and confirm it is recognized as read. Add a later reply using an approved test setup, refresh, and confirm Home still shows that new reply. An offline history request must preserve local badges. Signed-out browsing must not call authenticated history.
4. Sign out during a pending refresh and sign in as a different account. Confirm the previous account's pending response does not update the new account's lists or history.
5. Use Mark as Read from a Home item and a browse item's actions, then check its website history. Use Mark All as Read and confirm each selected item is updated. Verify missing-ID forum rows and Mac/Watch/TV app entries. In Fetch, Mark This Group as Read on any comment must clear the complete group and move VoiceOver to the next heading. Check the Actions rotor, swipe action, and context menu; none should offer Mark Read Up to Here. Offline marking still clears local badges and reports that the website update failed.

The developer's deletion owner check cannot be certified without the patch or a controlled two-user test. Anonymous deletion rejection alone does not prove ownership enforcement.

## Fetch action navigation — October 7, 2026

Fetch comment actions are now declared in one ordered list: Mark This Group as Read, Reply when signed in, Open Comment in Topic, Copy, Share, Report, authorized moderation actions, then Expand Visible Text/Collapse Visible Text. The full comment remains one spoken/Braille item; visual expansion still has a visible Show Full Comment/Show Less button. The accessible reading element ignores the child NavigationLink's default long action label and opens through the explicitly named action. Sighted navigation continues using the original link.

A Reading List heading immediately follows the separate Mark All as Read button. It is included in Fetch's custom Headings rotor, so users can return from distant comments and swipe left once to the button. No Mark All as Read action is added to individual comments.

Device checks: verify the action order with signed-out, member, author, and admin accounts; verify full-text reading remains intact; open via the named action and check focus returns to the same comment; expand/collapse with VoiceOver and with the visible button; navigate to Reading List using Headings while far down Fetch and swipe left to Mark All as Read. Check Braille, Switch Control, Voice Control, and large Dynamic Type. After marking all read, existing immediate focus/cue behavior must reach All Caught Up.
