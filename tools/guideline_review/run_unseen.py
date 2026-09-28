"""Runs the current rules over posts from an age range, default days 30-60
(usage: run_unseen.py month90.json 60 90), which the rules were never adjusted against, and
prints every flag with the words that set it off, for review."""
import json, os, sys, datetime, collections
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rules
from evidence import trigger

FILE = sys.argv[1] if len(sys.argv) > 1 else 'month60.json'
FROM, TO = (int(sys.argv[2]), int(sys.argv[3])) if len(sys.argv) > 3 else (30, 60)
items = json.load(open(os.path.join(HERE, FILE), encoding='utf-8'))
now = datetime.datetime.now(datetime.timezone.utc)
def age(i): return (now - datetime.datetime.fromisoformat(i['created'].replace('Z', '+00:00'))).days
older = [i for i in items if FROM <= age(i) < TO]
hits = [(i, rid, sev) for i in older for rid, sev in rules.check(i['text'], i['isReply'])]
print(f'{len(older)} unseen items, {len({i["id"] for i, _, _ in hits})} flagged, {len(hits)} warnings')
for (sev, rid), n in sorted(collections.Counter((s, r) for _, r, s in hits).items(), key=lambda x: ({'high': 0, 'medium': 1, 'low': 2}[x[0][0]], -x[1])):
    print(f'  {sev:6} {rid:24} {n}')
print()
for n, (it, rid, sev) in enumerate(sorted(hits, key=lambda h: ({'high': 0, 'medium': 1, 'low': 2}[h[2]], h[1])), 1):
    print(f"#{n} {sev.upper()} {rid} | {it['kind']} by {it['author']} on \"{it['title'][:60]}\"")
    print('   ', trigger(rid, it['text'])[:330])
