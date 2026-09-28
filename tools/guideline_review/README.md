# Guideline rule review

Checks the posting-guideline rules against real AppleVis posts, so false alarms can be found and fixed with evidence.

1. `python test_rules.py`: confirms `rules.py` (a line-for-line Python copy of `GuidelinesChecker.swift` and `ContentSubmissionPolicy.swift`) still agrees with every case in `AppleVisTests/GuidelineLanguageTests.swift`. Run this first. If it fails, `rules.py` is out of date with the Swift rules.
2. `python fetch_month.py 30`: read-only download of the last 30 days of posts and comments (about 65 requests, one at a time). Saved to `month.json`, which is git-ignored because it holds members' posts.
3. `python run_month.py`: counts flags per rule and severity.
4. `python evidence.py medium` (or a rule id such as `tone-low`): shows the exact words that set each flag off.

When a rule changes in Swift, mirror it in `rules.py` and add the real example as a test case.
