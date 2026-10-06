"""Compares the rule flags before and after the 2026-10-06 self-promotion
changes, over the stored months plus a fresh recent download:

    python compare_today.py month90.json recent12.json

Before: "my website" plus a link always counted. After: not when the post
asks for feedback or testers, and not for a reply by the thread's starter
(set aside by the admin scan). Apple Intelligence's verdicts can't be run
here; they only run on device.
"""
import json, os, sys, collections
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rules

files = sys.argv[1:] or ['month90.json']
items, seen = [], set()
for name in files:
    for it in json.load(open(os.path.join(HERE, name), encoding='utf-8')):
        if it['id'] not in seen:
            seen.add(it['id'])
            items.append(it)

MY = r"\bmy\s+" + rules.THING + r"\b" + rules.NOT_A_TOOL
LINK = r"(?:https?://|www\.)\S+"

def old_self_promotion(text):
    if rules.looks_like_self_promotion(text):
        return True
    return any(rules.matches(s, MY, True) and rules.matches(s, LINK, True) for s in rules.sentence_chunks(text))

# Who started each thread, where the opening post is in the data.
starter = {(it['kind'], it['title']): it['author'] for it in items if not it['isReply']}

before, after = collections.Counter(), collections.Counter()
changed = []
for it in items:
    new = dict(rules.check(it['text'], it['isReply']))
    old = dict(new)
    if old_self_promotion(it['text']):
        old['self-promotion'] = 'medium'
    started = it['isReply'] and starter.get((it['kind'], it['title'])) == it['author']
    if started:
        new.pop('self-promotion', None)
    for rid, sev in old.items(): before[(sev, rid)] += 1
    for rid, sev in new.items(): after[(sev, rid)] += 1
    if ('self-promotion' in old) != ('self-promotion' in new):
        why = 'started the thread' if started and 'self-promotion' in old else 'asks for feedback or testers'
        changed.append((it, why))

flagged_before = sum(1 for it in items if rules.check(it['text'], it['isReply']) or old_self_promotion(it['text']))
print(f"{len(items)} posts and comments checked ({min(i['created'] for i in items)[:10]} to {max(i['created'] for i in items)[:10]})")
print(f"\n{'rule':26} {'before':>7} {'after':>7}")
for key in sorted(set(before) | set(after), key=lambda k: ('high', 'medium', 'low').index(k[0])):
    if before[key] != after[key] or key[1] == 'self-promotion':
        print(f"{key[0] + ' ' + key[1]:26} {before[key]:7} {after[key]:7}")
print(f"{'all other rules':26} {'same':>7} {'same':>7}")
print(f"\nNo longer flagged ({len(changed)}):")
for it, why in changed:
    print(f"- {it['created'][:10]} {it['author']} in \"{it['title'][:60]}\" ({why})")
still = [it for it in items if 'self-promotion' in dict(rules.check(it['text'], it['isReply']))
         and not (it['isReply'] and starter.get((it['kind'], it['title'])) == it['author'])]
print(f"\nStill flagged for self-promotion ({len(still)}):")
for it in still:
    line = next((s for s in rules.sentence_chunks(it['text']) if 'my ' in s.lower()), it['text'])[:160]
    print(f"- {it['created'][:10]} {it['author']} in \"{it['title'][:60]}\": {line.strip()}")
