"""Publishes the guideline rules so members get them without an app update.

    python publish_rules.py           check, then copy to published/
    python publish_rules.py --check   check only

The app ships AppleVis/Sources/Resources/guideline-rules.json and downloads
published/guideline-rules.json from the public GitHub repo once it's pushed.
Run this only after the user approves a rule change:

1. Every pattern the app needs is there and compiles, every list is filled.
2. The version is higher than the published one (the app ignores a copy
   that isn't newer).
3. The rule tests still pass against it (test_rules.py).
Then it copies the file. Committing and pushing is what makes it live.
"""
import json, os, re, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
BUILT_IN = os.path.join(ROOT, 'AppleVis', 'Sources', 'Resources', 'guideline-rules.json')
PUBLISHED = os.path.join(ROOT, 'published', 'guideline-rules.json')

# Must match GuidelineRules.requiredPatterns and requiredLists in the app.
REQUIRED_PATTERNS = [
    "image", "vulgarStrong", "crude", "toneHigh", "toneMedium", "tonePutDown", "tonePutDownSentence",
    "toneLowSentence", "toneLowAnywhere", "toneThanks", "shutUp", "shutUpAtDevice", "selfShutUp",
    "mannerAdverbAfter", "mannerAdverbBefore", "quotedPassage", "moderation", "selfPromotion",
    "selfPromotionFeedback", "selfPromotionMyThing", "link", "referral", "advertising", "pressRelease",
    "aiDisclosure", "shoutingMarks", "shoutingCaps", "shoutingExcitement", "topicSwitch", "emailAddress",
    "emailInvitation", "emailProject", "emailHeaderBefore", "emailHeaderAfter", "announcementTopic",
    "announcementInvitation",
]
REQUIRED_LISTS = ["lowValuePhrases", "personalEmailProviders", "personalEmailRegionalBases"]


def problems(doc):
    found = []
    for key in REQUIRED_PATTERNS:
        pats = doc.get('patterns', {}).get(key) or []
        if not pats:
            found.append(f'missing pattern {key}')
        for p in pats:
            for name, value in doc.get('variables', {}).items():
                p = p.replace('{' + name + '}', value)
            try:
                re.compile(p)
            except re.error as e:
                found.append(f'{key}: {e}')
    for key in REQUIRED_LISTS:
        if not doc.get('lists', {}).get(key):
            found.append(f'missing list {key}')
    return found


def main():
    doc = json.load(open(BUILT_IN, encoding='utf-8'))
    issues = problems(doc)
    published_version = json.load(open(PUBLISHED, encoding='utf-8'))['version'] if os.path.exists(PUBLISHED) else 0
    if doc['version'] <= published_version and os.path.exists(PUBLISHED):
        same = open(BUILT_IN, encoding='utf-8').read() == open(PUBLISHED, encoding='utf-8').read()
        if not same:
            issues.append(f'version {doc["version"]} must be higher than the published {published_version}')
    tests = subprocess.run([sys.executable, os.path.join(HERE, 'test_rules.py')], capture_output=True, text=True, encoding='utf-8')
    last = (tests.stdout.strip().splitlines() or ['?'])[-1]
    if tests.returncode != 0 or 'agree' not in last or last.split('/')[0] != last.split('/')[1].split()[0]:
        issues.append(f'rule tests: {last}')
    print(f'Built-in rules version {doc["version"]}, published {published_version}. Tests: {last}')
    if issues:
        print('Not published:')
        for i in issues: print('  -', i)
        sys.exit(1)
    if '--check' in sys.argv:
        print('Ready to publish.')
        return
    os.makedirs(os.path.dirname(PUBLISHED), exist_ok=True)
    shutil.copyfile(BUILT_IN, PUBLISHED)
    print('Copied to published/guideline-rules.json. Commit and push to make it live.')


if __name__ == '__main__':
    main()
