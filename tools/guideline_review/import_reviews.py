"""Reads guideline review notes sent from the app (Profile > Admin >
Guideline Violation Check > Send Review Notes, which arrive through the
Contact form) and shows what today's rules do with each decision:

    python import_reviews.py review-notes-2026-11-01.txt

Paste the email's message into a text file in this folder first. Names
containing "review-notes" are git-ignored, since they hold members' posts.

- Per rule: how many decisions said real or not a problem, and how many the
  current rules still get wrong.
- Every case the rules still get wrong, with the line that set them off.
- Ready-to-paste Swift test strings for AppleVisTests/GuidelineLanguageTests.swift.
"""
import re, sys, os, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rules

if len(sys.argv) < 2:
    sys.exit(__doc__)
raw = open(sys.argv[1], encoding='utf-8').read().replace('\r\n', '\n')

HEAD = re.compile(r'^\[(REAL PROBLEM|NOT A PROBLEM)\] (.*?) \{(.*?)\} \((\w+)\)$')
reviews = []
for block in re.split(r'\n\s*\n', raw):
    lines = [l.strip() for l in block.strip().split('\n') if l.strip()]
    if not lines:
        continue
    m = HEAD.match(lines[0])
    if not m:
        continue
    r = {'verdict': 'realProblem' if m.group(1) == 'REAL PROBLEM' else 'notAProblem',
         'ruleIds': [x for x in m.group(3).split(',') if x], 'severity': m.group(4),
         'isReply': False, 'threadTitle': '', 'trigger': '', 'text': ''}
    for line in lines[1:]:
        key, _, value = line.partition(': ')
        if key == 'Reply': r['isReply'] = value == 'yes'
        elif key == 'In': r['threadTitle'] = value
        elif key == 'Trigger': r['trigger'] = value
        elif key == 'Text': r['text'] = value
    reviews.append(r)

tally = collections.defaultdict(lambda: {'real': 0, 'fine': 0, 'still_wrong': 0})
wrong = []
for r in reviews:
    text = r['text'] or r['trigger']
    now = {rid for rid, _ in rules.check(text, r['isReply'])} if text else set()
    for rule in r['ruleIds']:
        t = tally[rule]
        t['real' if r['verdict'] == 'realProblem' else 'fine'] += 1
        if rule == 'english-only' or not text:
            continue  # the language check runs only on device
        fires = rule in now
        if (r['verdict'] == 'notAProblem' and fires) or (r['verdict'] == 'realProblem' and not fires):
            t['still_wrong'] += 1
            wrong.append((rule, r, fires))

print(f"{len(reviews)} decisions\n")
print(f"{'rule':24} {'real':>5} {'fine':>5} {'rules still wrong':>18}")
for rule, t in sorted(tally.items(), key=lambda x: -x[1]['still_wrong']):
    print(f"{rule:24} {t['real']:5} {t['fine']:5} {t['still_wrong']:18}")

if wrong:
    print("\nStill wrong under today's rules:")
    for rule, r, fires in wrong:
        what = 'still flags' if fires else 'no longer catches'
        print(f"- {rule} {what}: \"{r['trigger'] or r['text'][:160]}\" ({r['threadTitle'][:60]})")
    print("\nSwift test strings (check and trim before adding):")
    for rule, r, fires in wrong:
        line = (r['trigger'] or r['text'][:200]).replace('\\', '\\\\').replace('"', '\\"')
        kind = 'should not flag' if r['verdict'] == 'notAProblem' else 'should flag'
        print(f'    "{line}",  // {rule}: {kind}')
else:
    print("\nToday's rules agree with every decision.")
