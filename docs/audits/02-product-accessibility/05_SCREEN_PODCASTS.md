# Screen Audit — Podcasts

Mission: flagship feature (per `APPLEVIS_2026_1_MASTER_SPEC.md`) — background
playback, Lock Screen/Control Center, AirPlay, speed 0.5x–3.0x, Smart Speed,
voice enhancement, EQ, chapters, sleep timer, queue, downloads, saved episodes,
continue listening, transcript, iCloud sync.

Evidence files: `Sources/Views/Podcasts/PodcastBrowseView.swift`,
`PlayerView.swift`, `EpisodeDetailView.swift`, `QueueView.swift`,
`TranscriptView.swift`, `RoutePickerView.swift`, `Sources/Stores/PlayerStore.swift`,
`DownloadManager.swift`, `Sources/Services/AudioEffectsProcessor.swift`,
`Sources/Models/Podcast.swift`, `Sources/Views/Shared/RowViews.swift`
(`PodcastEpisodeRow`). Card/action-system duplication findings (CARD-01–03) apply
here too and are not repeated; this doc covers Podcasts-specific findings.

---

## PODCAST-01 — Confirmation-sound playback silently downgrades the shared audio session from `.playback` to `.ambient`, defeating background/Lock Screen audio

- **Screen/component:** `PlayerStore` play/pause path, `SoundPlayer`
- **Severity:** P0
- **Category:** BUG / ARCHITECTURE ISSUE
- **Evidence:** `Sources/Stores/PlayerStore.swift` lines 142–162 (`play()`/`pause()` call `SoundPlayer.shared.play(.podcastPlay/.podcastPause)`); `Sources/Services/SoundPlayer.swift` lines 109–114 (`configureSession()`).
- **Current behavior:** `setupAudioSession()` sets the shared `AVAudioSession` to category `.playback`/mode `.spokenAudio` when an episode loads. But every `play()`/`pause()` call — including ones triggered remotely from Lock Screen/Control Center via `setupRemoteCommands()` — also fires `SoundPlayer.shared.play(.podcastPlay/.podcastPause)`. `SoundPlayer.configureSession()` unconditionally resets the *shared* session to category `.ambient` + `.mixWithOthers` whenever it isn't already `.ambient` — which it never is while a podcast is loaded. So the very first pause (or any Lock Screen play/pause) after starting an episode silently downgrades the session from `.playback` to `.ambient`.
- **Recommended behavior:** `SoundPlayer` must never reconfigure the shared session's category while podcast playback is active/loaded — either check `PlayerStore`'s state before reconfiguring, or move short UI confirmation sounds onto a session configuration that doesn't clobber playback category (e.g., use `.mixWithOthers` without changing category, or a separate `AVAudioPlayer` instance that doesn't touch the shared session category at all).
- **Exact reason:** `.ambient` sessions are silenced by the mute switch and are not eligible to continue playing in the background — this defeats both "Background audio playback" and "Lock Screen controls," the two most safety-critical player features listed in the master spec for a blind user who locks the phone or pockets it while listening. This is a release blocker: a core, flagship feature silently breaks itself on the very first pause/resume.
- **Suggested implementation approach:** Gate `SoundPlayer.configureSession()`'s category reset behind a check of whether `PlayerStore` currently has a loaded/active episode (or expose a small shared "is podcast session active" flag that `SoundPlayer` consults before touching the category), so UI confirmation sounds play through the existing `.playback` session instead of reconfiguring it.
- **Manual verification required:** Yes — lock the phone immediately after tapping Pause or Play once (including via Lock Screen/Control Center remote commands) and confirm playback continues/resumes correctly in the background and with the mute switch engaged.
- **Regression tests required:** Yes — assert `AVAudioSession.sharedInstance().category == .playback` after any play()/pause() cycle while an episode is loaded, in addition to a manual background-audio smoke test each release.

---

## PODCAST-02 — Downloads use a foreground `URLSession`, not a background session — downloads can die if the app is backgrounded

- **Screen/component:** `DownloadManager`
- **Severity:** P1
- **Category:** ARCHITECTURE ISSUE
- **Evidence:** `Sources/Stores/DownloadManager.swift` line 37: `session = URLSession(configuration: .default, ...)`.
- **Current behavior:** Not a background `URLSessionConfiguration`; in-flight downloads stall or die if the app is backgrounded or suspended before completion.
- **Recommended behavior:** Use `URLSessionConfiguration.background(withIdentifier:)`, wire the app-delegate background-completion handler, and reconcile download state on relaunch (resuming or re-surfacing failed downloads).
- **Exact reason:** A blind/low-vision user starting a large episode download and then locking the phone or switching apps (a completely normal usage pattern) can lose the download silently, with no clear signal of why it stopped.
- **Suggested implementation approach:** Migrate `DownloadManager`'s `URLSession` to a background configuration with a stable identifier, implement `application(_:handleEventsForBackgroundURLSession:completionHandler:)` in the app delegate/scene delegate, and add relaunch-time reconciliation of any downloads that completed while suspended.
- **Manual verification required:** Yes — start a download, background the app, and confirm it completes and the completion sound/notification still fires.
- **Regression tests required:** Yes — a code-level assertion the session uses a background configuration, plus a manual QA checklist item each release.

---

## PODCAST-03 — In-progress download has no cancel affordance for anyone; `DownloadManager.cancelDownload` exists but is never called

- **Screen/component:** `EpisodeDetailView.downloadButton`
- **Severity:** P2
- **Category:** ACCESSIBILITY DEFECT / BUG
- **Evidence:** `Sources/Views/Podcasts/EpisodeDetailView.swift` lines 190–193: active-download state renders a bare `ProgressView(value:).progressViewStyle(.circular)` with only an `.accessibilityLabel` — no `Button`, no gesture, no accessibility action attached. `DownloadManager.cancelDownload(_:)` (`DownloadManager.swift` line 100) exists but a repo-wide grep confirms it is never invoked anywhere in the app.
- **Current behavior:** No user — sighted or VoiceOver — can cancel an in-progress download from the UI at all.
- **Recommended behavior:** Wrap the progress indicator in a `Button` calling `downloads.cancelDownload(episode.id)`, with an accessible label such as "Downloading, 45 percent. Double-tap to cancel."
- **Exact reason:** A dead-end progress indicator with no way to stop an unwanted or mistaken download is a basic control gap that affects every user, not just an accessibility-specific one — but it compounds for VoiceOver users who have no alternate way (e.g. visually tapping a small X elsewhere) to work around it.
- **Suggested implementation approach:** Wire the existing `cancelDownload` method to a tappable/`accessibilityAction`-bearing control at this exact call site.
- **Manual verification required:** Yes.
- **Regression tests required:** Yes — a UI test confirming activating the in-progress control cancels the download.

---

## PODCAST-04 — Transcript is a single unsegmented `Text` block — poor VoiceOver navigation and Braille line-review

- **Screen/component:** `TranscriptView`
- **Severity:** P1
- **Category:** ACCESSIBILITY DEFECT / BRAILLE ISSUE
- **Evidence:** `Sources/Views/Podcasts/TranscriptView.swift` lines 25–31: the entire transcript is rendered as one `Text(transcript)` — a single accessibility element containing the whole multi-thousand-word string. No paragraph/heading segmentation, no timestamps, no tap-to-seek/sync with playback, no per-line Braille granularity.
- **Current behavior:** A VoiceOver or Braille-display user encounters the transcript as one enormous element; there is no way to jump to a specific point, review one line at a time on a Braille display, or navigate by heading/paragraph via the rotor.
- **Recommended behavior:** Segment the transcript into individually-accessible paragraph/sentence elements — the app already has a working pattern for exactly this (`SegmentedHTMLView`, used for episode descriptions at `EpisodeDetailView.swift` line 73). Add tap-to-seek and current-line highlighting if/when the API returns cue timestamps, per the master spec's transcript requirement.
- **Exact reason:** Transcript support is called out explicitly in the master spec as a flagship accessibility feature for exactly this app's audience; an unsegmented blob is materially worse for VoiceOver navigation and Braille line-review than the rest of the app's own content (which already solves this problem elsewhere).
- **Suggested implementation approach:** Reuse `SegmentedHTMLView`'s segmentation approach (or the underlying `HTMLSegmenter.swift` utility) to break the transcript into per-paragraph accessibility elements; layer in timestamp-based sync only if/when the transcript API provides cue data.
- **Manual verification required:** Yes — VoiceOver and Braille-display pass on a long transcript.
- **Regression tests required:** Yes — a test asserting a multi-paragraph transcript input produces more than one accessibility element.

---

## PODCAST-05 — `docs/IMPLEMENTATION_NOTES.md`'s "still needs native work" list is stale; all four listed items are already implemented

- **Screen/component:** Documentation vs. actual code
- **Severity:** P2
- **Category:** BUG (stale documentation)
- **Evidence:** `docs/IMPLEMENTATION_NOTES.md` lines 5–12 list iCloud key-value store/CloudKit, MPRemoteCommandCenter/Now Playing metadata, Smart Speed/silence-trimming DSP, and Voice enhancement/EQ pipeline as still requiring native work. All four are fully implemented in current source: `Sources/Services/ICloudSyncManager.swift` (NSUbiquitousKeyValueStore sync of queue/positions/settings/saved items), `Sources/Stores/PlayerStore.swift` lines 299–373 (`updateNowPlayingInfo`, `setupRemoteCommands`), `Sources/Services/AudioEffectsProcessor.swift` (Voice Boost, EQ presets, Trim Silence via `MTAudioProcessingTap`). The same document's own "Migration path" section (line 22) already says this work is done — the document is self-contradictory.
- **Current behavior:** Documentation understates actual feature completeness and could cause a future contributor or App Store submission checklist review to mis-scope remaining work, or to overlook re-verifying already-shipped functionality that the doc implies doesn't exist yet.
- **Recommended behavior:** Update/delete the stale "still require native iOS work" bullet list in `IMPLEMENTATION_NOTES.md` to reflect actual current state.
- **Exact reason:** Accurate internal documentation matters for planning and for App Store review readiness assessments that may reference this file.
- **Suggested implementation approach:** Edit `docs/IMPLEMENTATION_NOTES.md` lines 5–12 to remove or update the four now-shipped items (documentation-only change, outside this audit's read-only source-code scope, but worth flagging directly to the maintainer).
- **Manual verification required:** No.
- **Regression tests required:** No.

---

## PODCAST-06 — Playback-speed control bakes its value into the label instead of exposing `accessibilityValue`, risking silent post-adjust announcements

- **Screen/component:** `PlayerView.speedButton`
- **Severity:** P2
- **Category:** ACCESSIBILITY DEFECT
- **Evidence:** `Sources/Views/Podcasts/PlayerView.swift` lines 237–267: sets only `.accessibilityLabel("Playback speed: 1.0×")`, no `.accessibilityValue`, unlike the correctly-implemented `ScrubberView` a few lines below in the same file.
- **Current behavior:** VoiceOver's automatic post-adjustment announcement speaks the element's `accessibilityValue`, not its label; because the current speed lives only in the label here, changing speed may not reliably re-announce the new value the way the spec requires ("announce playback progress clearly" / speed changes should be confirmed audibly).
- **Recommended behavior:** Split into `.accessibilityLabel("Playback speed")` (static) + `.accessibilityValue("\(speedLabel(current))×")` (dynamic), matching `ScrubberView`'s pattern.
- **Exact reason:** Reliable spoken confirmation of a changed setting is core VoiceOver hygiene, and this screen already demonstrates the correct pattern one control away — this is an easy, low-risk consistency fix.
- **Suggested implementation approach:** Refactor `speedButton`'s accessibility modifiers to separate label from value, mirroring `ScrubberView`.
- **Manual verification required:** Yes — swipe up/down (or activate) and confirm the spoken value updates every time, not just on first focus.
- **Regression tests required:** Yes — an accessibility snapshot test asserting an `accessibilityValue` is exposed on this control.

---

## PODCAST-07 — Browse-list episode row never states "currently playing" in its VoiceOver label

- **Screen/component:** `RowViews.swift` `PodcastEpisodeRow.episodeLabel`
- **Severity:** P2
- **Category:** ACCESSIBILITY DEFECT
- **Evidence:** `Sources/Views/Shared/RowViews.swift`, `PodcastEpisodeRow.episodeLabel` (lines 330–342). The visible `NowPlayingWaveform` (line 27 of the waveform's own definition) and the play/pause icon (line 260) are both `.accessibilityHidden(true)`; nothing else in `episodeLabel` mentions playing state. Contrast with `QueueView`'s `NowPlayingQueueCard` (line 156), which explicitly prepends "Now playing: …" to its label.
- **Current behavior:** A VoiceOver user browsing a podcast list has no way to identify which row is currently playing without opening the Actions rotor and reading the Play/Pause action's current wording.
- **Recommended behavior:** Prepend "Now playing." to `episodeLabel` when `isCurrentlyPlaying` is true, matching the pattern `QueueView` already uses correctly.
- **Exact reason:** "Playing" is exactly the kind of high-priority state the Unified Card Standard calls out as needing to be spoken, not just shown via a decorative (and here fully hidden) visual indicator — currently it is not spoken anywhere on this row at all.
- **Suggested implementation approach:** Add an `isCurrentlyPlaying ? "Now playing. " : ""` prefix (or equivalent slot in `detailLevelLabel`'s parameters) to `episodeLabel`, consistent with how `savedQueuedLabel`/`newLabel` are already appended.
- **Manual verification required:** Yes.
- **Regression tests required:** Yes — unit test on `episodeLabel` for the playing-state case.

---

## PODCAST-08 — "Add to queue" wording capitalization mismatch between VoiceOver action and visible context-menu label

- **Screen/component:** `RowViews.swift` `PodcastEpisodeRow`
- **Severity:** P3
- **Category:** UX INCONSISTENCY
- **Evidence:** `Sources/Views/Shared/RowViews.swift` line 269 (`.accessibilityAction(named: Text(isQueued ? "Remove from Queue" : "Add to queue"))` — lowercase "queue") vs. line 291 (context-menu visible `Label` — "Add to Queue", Title Case) for the identical action on the identical row.
- **Current behavior:** Same action, two different capitalizations depending on which surface (VoiceOver rotor vs. visible menu) is being read.
- **Recommended behavior:** Standardize on Title Case ("Add to Queue") for both, matching the visible label convention used everywhere else in the app.
- **Exact reason:** Small, easy-to-fix wording inconsistency; worth bundling with the CARD-01 fix pass since both touch the same code region.
- **Suggested implementation approach:** Fix the string literal at line 269.
- **Manual verification required:** No.
- **Regression tests required:** No.

---

## PODCAST-09 — Action order deviates from the proposed universal ordering: Mark as Read lands after Save/Queue instead of before

- **Screen/component:** `RowViews.swift` (`PodcastEpisodeRow`'s injected Play/Queue actions) + `ContentActions.swift` (`ContentActionsModifier.body`)
- **Severity:** P3
- **Category:** UX INCONSISTENCY
- **Evidence:** Proposed order (per `02_CROSS_APP_PATTERNS_AND_UNIFIED_CARD.md` CARD-03): Play/Pause → Mark as Read → Save/Unsave → Follow → Add Comment → Queue/Download → Share → Browser → Edit/Delete. Actual order: Play/Pause, Add to Queue (`RowViews.swift` lines 266–271), then Save/Unsave (`ContentActions.swift` line 183), then Mark as Read (line 191, conditional), then Add Comment, Open in Browser, Share, Follow.
- **Current behavior:** "Mark as Read" (arguably one of the most common, lowest-risk actions on a row with new activity) lands after Save/Queue rather than before them.
- **Recommended behavior:** Reorder to Play → Mark as Read → Save/Queue/Share, applied consistently — this is the same shared `ContentActionsModifier` that also drives Forum/App/Guide/Blog rows, so this is really an instance of CARD-03, not a Podcasts-only issue.
- **Exact reason:** Consistency with the app-wide proposed ordering; see CARD-03 for the full cross-app rationale.
- **Suggested implementation approach:** Fold into the CARD-01/CARD-03 reordering pass rather than fixing PodcastEpisodeRow in isolation.
- **Manual verification required:** Yes (VoiceOver rotor order), as part of the CARD-03 fix verification.
- **Regression tests required:** Covered by the CARD-03 ordering test once written.

---

## PODCAST-10 — Duration is formatted five different ways across five files, producing visibly inconsistent output for the same value

- **Screen/component:** `PlayerView`, `EpisodeDetailView`, `QueueView`, `RowViews.swift`
- **Severity:** P2
- **Category:** UX INCONSISTENCY / ARCHITECTURE ISSUE
- **Evidence:**
  - `PlayerView.swift` lines 310–318 (`FullPlayerView.formatTime`) and lines 331–339 (top-level `formatScrubberTime`) — two near-identical private colon (H:MM:SS) implementations in the *same file*.
  - `EpisodeDetailView.swift` lines 366–374 (`ChapterRow.formatTime`) — a third copy of the colon format.
  - `QueueView.swift` lines 243–251 (`formatTime`, colon) and lines 253–258 (`formatDuration`, "Xh Ym" abbreviated, no colon) — a fourth and fifth style, in the same file.
  - `EpisodeDetailView.swift` line 159 and `RowViews.swift` lines 234/332 use `Duration.seconds(x).formatted(.units(allowed: [.hours, .minutes]))` → "X hr Y min" — a sixth convention.
- **Current behavior:** The same underlying duration value reads as "2:15:00" in the player, "2h 15m" in the queue, and "2 hr 15 min" in the browse list, depending purely on which screen you're on.
- **Recommended behavior:** Extract one shared, localization-aware duration formatter (covering both a visible-text form and, where different, a spoken accessibility-string form) and delete the five duplicate implementations in favor of it.
- **Exact reason:** Inconsistent formatting for identical data is confusing on its own, and is exactly the kind of drift the Unified Card Standard's "Braille model" section warns against ("dates not overly verbose," "content types predictable") extended to duration formatting — a Braille or VoiceOver user comparing episode lengths across screens gets differently-shaped output for no functional reason.
- **Suggested implementation approach:** Add a single `PodcastDuration.format(_:style:)`-style helper (in `Models/Podcast.swift` or a shared utility file) with at minimum a "colon" and an "abbreviated words" style, and migrate all five call sites to it, retiring the private duplicates.
- **Manual verification required:** No.
- **Regression tests required:** Yes — unit tests for the shared formatter covering hour/minute/second boundary cases.

---

## PODCAST-11 — Playback-progress announcement wording (elapsed/percent) is inconsistent and unnecessarily verbose for repeated Braille reads

- **Screen/component:** `QueueView` (`NowPlayingQueueCard`), `PlayerView` (`ScrubberView`)
- **Severity:** P3
- **Category:** BRAILLE ISSUE / UX INCONSISTENCY
- **Evidence:** `PlayerView.swift` lines 373–376: scrubber says "12:34 of 45:00, 27%". `QueueView.swift` line 151: `NowPlayingQueueCard` says only "Playback progress: 27 percent" (no time at all). The scrubber's combined time+percent string also repeats verbatim on every focus/adjust, which is verbose for a Braille user re-reading the same cell repeatedly during a seek gesture.
- **Current behavior:** Two different progress phrasings for logically the same concept, and one of them omits absolute time entirely while the other duplicates both time and percent every time.
- **Recommended behavior:** Standardize on elapsed-of-total phrasing (e.g. "12:34 of 45:00") across all progress surfaces; percent is largely redundant alongside time and can be dropped or made optional.
- **Exact reason:** Matches the audit package's explicit Braille guidance to avoid unnecessary punctuation/verbosity and keep state wording predictable across surfaces.
- **Suggested implementation approach:** Once PODCAST-10's shared duration formatter exists, build the progress string on top of it consistently in both `NowPlayingQueueCard` and `ScrubberView`.
- **Manual verification required:** Yes — Braille-display pass, per the audit package's explicit requirement to test Braille separately from VoiceOver speech.
- **Regression tests required:** No formal test required beyond the shared formatter's own tests.

---

## PODCAST-12 — Scrubber only supports tap-to-seek, no drag gesture or visible thumb

- **Screen/component:** `PlayerView.ScrubberView`
- **Severity:** P2
- **Category:** VISUAL-LOW-VISION ISSUE
- **Evidence:** `Sources/Views/Podcasts/PlayerView.swift` lines 343–390: the only interaction is `.onTapGesture` jumping to an absolute position (lines 364–368) — no `DragGesture`, no visible drag handle/thumb.
- **Current behavior:** Sighted/low-vision users must tap a precise x-coordinate on a roughly 28pt-tall bar to seek, rather than dragging a visible thumb to the desired position.
- **Recommended behavior:** Add a `DragGesture` with a visible thumb, alongside the existing tap-to-seek and the already-correct `accessibilityAdjustableAction` (see PODCAST-P3 in the PASS list).
- **Exact reason:** Precise tap-targeting on a thin bar is materially harder for low-vision users (tremor, reduced fine motor precision, difficulty judging exact position visually) than dragging a larger, visible handle — this is squarely a low-vision usability gap distinct from the VoiceOver-focused adjustable action, which is already implemented correctly.
- **Suggested implementation approach:** Add a `DragGesture` updating position continuously as the user drags, with a visibly rendered thumb view at the current progress position, layered alongside the existing tap and VoiceOver adjustable-action handling.
- **Manual verification required:** Yes.
- **Regression tests required:** Yes — a UI test confirming dragging updates position continuously.

---

## PODCAST-13 — No way to reach the Queue from the Now Playing full player screen

- **Screen/component:** `PlayerView.FullPlayerView`
- **Severity:** P2
- **Category:** UX INCONSISTENCY / IMPROVEMENT
- **Evidence:** No button/link to `QueueView` anywhere in `PlayerView.swift` (confirmed via grep — no "Queue" reference in the file).
- **Current behavior:** Users must dismiss the full player and navigate elsewhere in the app to see or reorder "Up Next," unlike the equivalent screen in Apple Podcasts/Apple Music.
- **Recommended behavior:** Add a Queue/"Up Next" toolbar button on `FullPlayerView` that presents `QueueView`.
- **Exact reason:** The Now Playing screen is the natural, expected place to check or adjust what's coming up next; requiring a full navigation detour breaks the flow the master spec's "flagship feature" framing implies.
- **Suggested implementation approach:** Add a toolbar item to `FullPlayerView` presenting `QueueView` as a sheet or push destination.
- **Manual verification required:** No.
- **Regression tests required:** None yet (feature addition); add once implemented.

---

## PODCAST-14 — Episode detail's bottom action bar has no Queue toggle, unlike every other podcast surface

- **Screen/component:** `ContentDetailActions` as used by `EpisodeDetailView`
- **Severity:** P2
- **Category:** UX INCONSISTENCY
- **Evidence:** `Sources/Views/Shared/ContentActions.swift` `ContentDetailActions` (lines 528–619), used by `EpisodeDetailView.swift` line 122, offers only Follow (n/a for episodes)/Save/Share/Open in Browser — no "Add to Queue," even though every other podcast surface (browse row, queue screen) supports queueing.
- **Current behavior:** A user reading the full episode detail page has to leave the screen (back to a list) to queue the episode.
- **Recommended behavior:** Add a kind-specific Queue toggle for `.podcastEpisode` to the detail bottom bar, mirroring the `extraMenuItems` pattern already used on the row.
- **Exact reason:** Queueing is a primary, frequent action for this content kind per the master spec; omitting it from the single most detailed view of an episode is a real functional gap, not just a wording inconsistency.
- **Suggested implementation approach:** Extend `ContentDetailActions` (or `EpisodeDetailView`'s own bar) with a Queue button wired to `PlayerStore.enqueue`/`removeFromQueue`, matching `PodcastEpisodeRow`'s existing logic.
- **Manual verification required:** No.
- **Regression tests required:** Yes, once implemented.

---

## PODCAST-15 — Two accessibility-announcement strings bypass localization

- **Screen/component:** `PlayerStore`, `QueueView`
- **Severity:** P4
- **Category:** IMPROVEMENT (localization)
- **Evidence:** `Sources/Stores/PlayerStore.swift` line 417 and `Sources/Views/Podcasts/QueueView.swift` line 67: bare string interpolations passed directly to `UIAccessibility.post` ("Chapter…" and "Queue cleared.") are not wrapped in `String(localized:)`, unlike nearly every other user-facing string in these files.
- **Current behavior:** These two announcements won't be picked up for translation extraction.
- **Recommended behavior:** Wrap both in `String(localized:)`.
- **Exact reason:** Consistency with the rest of the codebase's localization discipline; low severity but a one-line fix.
- **Suggested implementation approach:** Wrap the two literals.
- **Manual verification required:** No.
- **Regression tests required:** No.

---

## PODCAST-16 — No hardware-keyboard shortcut to dismiss the full player sheet

- **Screen/component:** `PlayerView.FullPlayerView` "Done" button
- **Severity:** P3
- **Category:** IMPROVEMENT (hardware keyboard)
- **Evidence:** `Sources/Views/Podcasts/PlayerView.swift` line 177 — hidden shortcuts exist for space/left/right (transport controls) but not for dismissing the sheet.
- **Current behavior:** No keyboard-only path to close the Now Playing sheet.
- **Recommended behavior:** Add `.keyboardShortcut(.cancelAction)` to the Done button.
- **Exact reason:** Hardware-keyboard support is an explicit audit dimension and an iPad/external-keyboard usability gap.
- **Suggested implementation approach:** One-line modifier addition.
- **Manual verification required:** Yes — external keyboard/iPad pass.
- **Regression tests required:** No.

---

## PODCAST-17 — Mini player has no Skip Backward control, asymmetric with the full player and Lock Screen

- **Screen/component:** `PlayerView.MiniPlayerView`
- **Severity:** P4
- **Category:** UX INCONSISTENCY
- **Evidence:** `Sources/Views/Podcasts/PlayerView.swift` lines 33–59: only Play/Pause, Skip Forward, and Stop are present — no Skip Backward.
- **Current behavior:** A user relying on the mini player can skip forward but not backward, while the full player and Lock Screen controls offer both.
- **Recommended behavior:** Add a Skip Backward control to the mini player for parity, space permitting.
- **Exact reason:** Asymmetric controls across surfaces for the same underlying capability is confusing, particularly for a control users will reach for quickly/from muscle memory.
- **Suggested implementation approach:** Add the control if the mini player's layout can accommodate it; otherwise document the omission as deliberate.
- **Manual verification required:** No.
- **Regression tests required:** No.

---

## PODCAST-18 — Mini player uses `.accessibilityElement(children: .contain)` alongside a tap gesture and focusable children — needs an on-device pass

- **Screen/component:** `PlayerView.MiniPlayerView`
- **Severity:** MANUAL VERIFY
- **Category:** MANUAL VERIFY
- **Evidence:** `Sources/Views/Podcasts/PlayerView.swift` line 67 — `.accessibilityElement(children: .contain)` combined with a sibling `.onTapGesture` and individually-focusable interactive children.
- **Current behavior:** Defensible pattern in source but a common source of on-device VoiceOver surprises (double announcements, ambiguous double-tap target) that isn't verifiable from static code alone.
- **Recommended behavior:** No defect identified in code; flag for an on-device VoiceOver pass specifically probing double-tap behavior on the mini player.
- **Exact reason:** `.contain` grouping behavior with mixed gesture/focusable-children setups is genuinely OS/SDK-version-sensitive.
- **Suggested implementation approach:** N/A pending manual test.
- **Manual verification required:** Yes.
- **Regression tests required:** No.

---

## PODCAST-19 — No explicit VoiceOver focus restoration after dismissing the full player

- **Screen/component:** `PlayerView.FullPlayerView`
- **Severity:** MANUAL VERIFY
- **Category:** MANUAL VERIFY
- **Evidence:** `Sources/Views/Podcasts/PlayerView.swift` line 177 — no `@AccessibilityFocusState` restoration on dismiss, unlike other screens in this codebase that manage post-dismiss focus explicitly (e.g. `EpisodeDetailView`'s `isTitleFocused`).
- **Current behavior:** Unconfirmed from static code whether focus lands sensibly (e.g. back on the mini player or the row that opened it) after closing the full player sheet, or is left wherever the system default puts it.
- **Recommended behavior:** Confirm on-device; if focus lands somewhere unhelpful, add explicit `@AccessibilityFocusState` restoration matching the pattern already used elsewhere in the app (see `docs/IMPLEMENTATION_NOTES.md`'s general focus-return conventions).
- **Exact reason:** Focus-on-dismiss is one of the audit package's explicitly required VoiceOver test scenarios ("sheet dismiss").
- **Suggested implementation approach:** Add `@AccessibilityFocusState` restoration if the manual pass finds it's needed.
- **Manual verification required:** Yes.
- **Regression tests required:** No.

---

## PASS findings

- **PODCAST-P1 — PASS.** `RowViews.swift` `NowPlayingWaveform.animate()` (lines 31–41): correctly checks `UIAccessibility.isReduceMotionEnabled` and skips animation entirely when set.
- **PODCAST-P2 — PASS.** `QueueView.QueueRow`: full non-drag reorder via explicit Move Up/Move Down accessibility actions (lines 235–236) alongside `List.onMove`, with correct `move(fromOffsets:toOffset:)` math (lines 93, 98). Satisfies the master spec's "never require drag-only interactions" requirement — a genuinely good reference implementation.
- **PODCAST-P3 — PASS.** `PlayerView.ScrubberView.accessibilityAdjustableAction` (lines 377–388): correct swipe up/down seek behavior that reads the user's configured skip intervals rather than hardcoding a value.
- **PODCAST-P4 — PASS.** `PlayerStore.updateCurrentChapter()` (lines 406–420): live chapter title/number announcement during playback, matching the master spec's explicit requirement.
- **PODCAST-P5 — PASS.** `RoutePickerView.swift`: wraps the real system `AVRoutePickerView`, correctly sized to a 44×44 minimum touch target.
- **PODCAST-P6 — PASS.** `PlayerStore` interruption/route-change handling (lines 529–593): correct `shouldResume`-gated resume logic and old-device-unavailable pause behavior.
- **PODCAST-P7 — PASS.** `PlayerStore.observeDidFinish()`/`observeFailure()` (lines 429–473): correctly per-item-scoped Combine subscriptions with single-cancellable auto-replacement, avoiding subscription leaks across episode changes.
- **PODCAST-P8 — PASS.** `SoundPlayer.swift`: podcast play/pause/download-complete sounds correctly default ON and are user-togglable, matching the master spec's sound defaults exactly.
- **PODCAST-P9 — PASS.** `PreferencesStore.PodcastSpeedOptions.all` (line 246): 0.5x–3.0x range matches the master spec exactly, with a single source of truth shared between Settings and the player.
- **PODCAST-P10 — PASS.** `AppleVisApp.swift` (lines 10, 51): single `PlayerStore` instance injected once at the app root — correct one-player-instance architecture, avoiding competing audio sessions.

---

## Podcasts summary

Podcasts is functionally the most complete flagship area of the app (queue
reordering, chapters, remote commands, interruption handling, and route
picking are all done correctly — PODCAST-P2 through P7 are genuinely strong
reference implementations). The one release blocker is PODCAST-01: the shared
confirmation-sound player silently downgrades the audio session away from
background-eligible playback on the very first pause/resume, which undermines
the two most safety-critical features (background audio, Lock Screen control)
for this app's core audience. The remaining P1/P2 findings cluster around two
themes: (a) surfaces that were clearly built once and not revisited since
(unsegmented transcript, foreground-only downloads, no download cancel), and
(b) formatting/wording drift across Player/Queue/Row (duration format,
progress wording, action ordering) that mirrors the same "several people
touched this independently" pattern found in the shared card system audit.
