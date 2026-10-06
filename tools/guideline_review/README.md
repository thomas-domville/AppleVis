# Guideline rule review

Checks the posting-guideline rules against real AppleVis posts, so false alarms can be found and fixed with evidence.

1. `python test_rules.py`: confirms `rules.py` (a line-for-line Python copy of `GuidelinesChecker.swift` and `ContentSubmissionPolicy.swift`) still agrees with every case in `AppleVisTests/GuidelineLanguageTests.swift`. Run this first. If it fails, `rules.py` is out of date with the Swift rules.
2. `python fetch_month.py 30`: read-only download of the last 30 days of posts and comments (about 65 requests, one at a time). Saved to `month.json`, which is git-ignored because it holds members' posts.
3. `python run_month.py`: counts flags per rule and severity.
4. `python evidence.py medium` (or a rule id such as `tone-low`): shows the exact words that set each flag off.

When a rule changes in Swift, mirror it in `rules.py` and add the real example as a test case.

## Learning from your decisions (2026-10-06)

5. In the app, Profile > Admin > Guideline Violation Check: mark flags **Not a Problem** or **Real Problem**, from a swipe or the VoiceOver Actions rotor. Each rule's score builds up under **Your Reviews**. Decisions sync between your own devices through iCloud.
6. Every so often, choose **Send Review Notes**. They arrive through the Contact form. Paste the message into a file here named `review-notes-<date>.txt`; names with `review-notes` are git-ignored because they hold members' posts.
7. `python import_reviews.py review-notes-<date>.txt`: shows which decisions today's rules still get wrong, and drafts Swift test strings for them.
8. Fix the rules in Swift and `rules.py`, add the cases to `AppleVisTests/GuidelineLanguageTests.swift`, run `python test_rules.py`, then `python compare_today.py month90.json` to check nothing else moved.

## One rules file, updated without an app release (2026-10-06)

The patterns, word lists, and Apple Intelligence's rule descriptions live in
`AppleVis/Sources/Resources/guideline-rules.json`. The app and `rules.py` both
read it, so a rule is changed in one place. Messages members see stay in the
app's code, so they keep their translations.

To change a rule:

1. Edit `guideline-rules.json` and raise its `version`.
2. Add a case to `test_rules.py` and run it.
3. `python publish_rules.py --check`, then `python publish_rules.py` once the
   change is approved. This copies the file to `published/`.
4. Commit and push. Members' apps pick it up within about 12 hours.

The app always has the built-in copy from its last build, and keeps the last
copy it downloaded, so the checks keep working with no internet or if GitHub
can't be reached. A downloaded copy that's broken or not newer is ignored.

## Team decisions

Decisions marked in the Guideline Violation Check are also shared in iCloud
(CloudKit) with other Site Editors and Admins, without the post text, and
scored together under Team Reviews.
