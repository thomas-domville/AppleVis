import json, re, html, sys, os, collections
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rules

items = json.load(open(os.path.join(HERE, 'month.json'), encoding='utf-8'))
hits = []
for it in items:
    for rid, sev in rules.check(it['text'], it['isReply']):
        hits.append({'id': it['id'], 'rule': rid, 'severity': sev})
json.dump(hits, open(os.path.join(HERE, 'hits.json'), 'w', encoding='utf-8'))

by = collections.Counter((h['severity'], h['rule']) for h in hits)
flagged_items = len({h['id'] for h in hits})
print(f'{len(items)} items, {flagged_items} flagged ({flagged_items / len(items):.1%}), {len(hits)} warnings')
for sev in ('high', 'medium', 'low'):
    for (s, r), n in sorted(by.items(), key=lambda x: -x[1]):
        if s == sev: print(f'  {sev:6} {r:24} {n}')
