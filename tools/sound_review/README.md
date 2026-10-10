# Sound review

Trial versions of AppleVis sounds, to compare by ear. Nothing in this
folder ships in the app: the app only uses AppleVis/Sources/Resources/Sounds.
Once a version is chosen, it's copied there under the app's file name.

Every new version fades in and fades out (no abrupt start or hard stop).
Version 1 is always what the app plays (or played) before the change.

## Volume

Every app sound is set to its loudness group by level_installed.py (run it after installing any new sound): quiet −21 dB, tip −18, Mark as Read −16, confirmations −13, rare moments and errors −11, measured by each sound's loudest moment.

## Chosen

- Refresh: option 6, bubbles (three tiny rising bloops, 0.5 s). In the app.
- Sync complete: version 2 (gentle start, silent padding removed, 1.75 s). In the app.
- Search complete: kept as it is (the user preferred the full original to the shorter version).
- Podcast Play, Pause and Added to Queue: set A, soft mallet (up for Play, down for Pause, the same note twice for Queue). In the app.
- Tip popup: version 1, the original sound, turned down about 10 dB (it was as loud as success). In the app.
- Tab change: the pop (option 6), pitched per tab: low for Home, middle for Discover, high for For You. In the app.
- Screen close: option 5, fold (two tiny soft paper crinkles, 0.26 s, quiet tier). In the app.
- Reply: option 4, letter drop (a soft paper "fwump" with a gentle low tap, 0.4 s). In the app, for every reply, comment, review and new topic.
- Success: version 2 (gentle start, fade-out finishing at 0.85 s). In the app.
- Welcome: option 6, quick sunrise (a soft chord blooming quickly with a bell on top, 1.1 s). In the app.
- Recommend, Unsave, Unfollow, No Longer Recommend, and the screen-open "unfold": made to Claude's judgment at the user's request (make_family_finish.py), and the user approved the unfold by ear. In the app.
- Follow: option 1, tap and bell (the clip's wooden tap, then a tiny high bell, 0.5 s). In the app.
- Bookmark saved: option 8, clip (two quick, soft wooden taps). In the app.
- Download complete: version 2 (gentle start, silent padding removed, 0.6 s). In the app.
- Error: option 4, uh-oh (two round, low notes stepping down, 0.5 s). In the app.
- Loading start: version 2 (about 8 dB quieter, gentle start). In the app.
- Picker tick: version 2 (about 8 dB quieter, gentle start). In the app.

## Chosen 2026-10-10: End of Group in Fetch, option 5 (page end). In the app as end_of_group.wav.

### The options that were offered

Plays when VoiceOver lands on the last row of a group in Fetch, so you know
it's the last one before the next group. Quiet group (-18), made by
make_end_of_group.py.

- end_of_group_0_guideline_ding: the guideline ding as it is, for comparison.
- end_of_group_1_ding_sibling: the ding, a little lower and longer.
- end_of_group_2_two_bells_down: two soft bells stepping down.
- end_of_group_3_felt_settle: one low felt-piano note, settling.
- end_of_group_4_mallet_tock: a short wooden "tock".
- end_of_group_5_page_end: a tiny paper fold, then a small low bell.
- end_of_group_6_soft_blip_pair: two very small round blips on one note.

## Status

Sound review complete (2026-10-07). Every app sound has been chosen by the
user, or made to Claude's judgment at the user's request, and levelled.
The scripts here (make_*.py) recreate any of them; level_installed.py sets
volumes after installing a new sound. To try new options, generate them
into this folder (never into the app's Sounds folder) and list them here.
