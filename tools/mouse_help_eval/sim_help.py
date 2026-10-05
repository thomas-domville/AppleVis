"""Rough port of MouseKnowledge.searchHelp + bestPassages, run over the real
HelpContent.swift, to see what Ask the Mouse would hand Apple Intelligence."""
import re, sys
sys.stdout.reconfigure(encoding='utf-8')
import os
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'AppleVis', 'Sources') + os.sep
help_src = open(SRC + 'Models/HelpContent.swift', encoding='utf-8').read()
mk = open(SRC + 'Services/MouseKnowledge.swift', encoding='utf-8').read()

stop = set(re.findall(r'"([^"]+)"', mk[mk.find('stopWords: Set<String> = ['):mk.find(']', mk.find('stopWords: Set<String> = ['))]))
nick = {}
block = mk[mk.find('nicknames: [String: [String]] = ['):]
block = block[:block.find('\n    ]')]
for m in re.finditer(r'"([\w-]+)":\s*\[([^\]]*)\]', block):
    nick[m.group(1)] = re.findall(r'"([^"]+)"', m.group(2))

def unesc(s): return s.replace('\\"', '"')
articles = []
for m in re.finditer(r'HelpArticle\(\s*id: "([^"]+)",\s*title: "((?:[^"\\]|\\.)*)",\s*summary: "((?:[^"\\]|\\.)*)",\s*content: \[', help_src):
    start = m.end()
    nxt = help_src.find('HelpArticle(', start)
    body_src = help_src[start: nxt if nxt > 0 else len(help_src)]
    lines = []
    heading = ''
    for b in re.finditer(r'\.(heading|body|tip|note|warning|source)\((?:label: )?"((?:[^"\\]|\\.)*)"|^\s*"((?:[^"\\]|\\.)*)",\s*$', body_src, re.M):
        kind, text, item = b.group(1), b.group(2), b.group(3)
        if kind == 'heading':
            heading = unesc(text); lines.append(('h', heading, heading))
        elif kind:
            lines.append((kind, unesc(text), heading))
        elif item:
            lines.append(('item', unesc(item), heading))
    articles.append(dict(id=m.group(1), title=unesc(m.group(2)), summary=unesc(m.group(3)), lines=lines))

def terms(t):
    ws = [w.strip("'") for w in re.split(r"[^0-9a-z']+", t.lower())]
    out, seen = [], set()
    for w in ws:
        if len(w) >= 2 and w not in stop and w not in seen:
            seen.add(w); out.append(w)
    return out

def score(title, summary, body, ts, phrases):
    title, summary, body = title.lower(), summary.lower(), body.lower()
    tot = 0
    for t in ts:
        if t in title: tot += 6
        if t in summary: tot += 3
        tot += min(body.count(t), 3)
    for p in [p.lower() for p in phrases if ' ' in p]:
        if p in title: tot += 8
        if p in summary or p in body: tot += 4
    return tot

def search(q, with_heading=False):
    ts = terms(q)
    res = []
    for a in articles:
        body = '\n'.join(l[1] for l in a['lines'])
        v = score(a['title'], a['summary'], body, ts, [q])
        if any(n in q.lower() for n in nick.get(a['id'], [])): v += 12
        res.append((v, a))
    res = [r for r in res if r[0] >= 4]
    res.sort(key=lambda r: -r[0])
    return ts, res[:3]

def passages(a, ts, maxc=900, with_heading=False):
    paras = [(f"{l[2]}: {l[1]}" if with_heading and l[0] == 'item' and l[2] else l[1]) for l in a['lines']]
    ranked = [(i, score('', '', p, ts, [])) for i, p in enumerate(paras)]
    chosen = [i for i, s in sorted([r for r in ranked if r[1] > 0], key=lambda r: -r[1])]
    order = chosen or list(range(len(paras)))
    picked, n = [], 0
    for i in order:
        if n + len(paras[i]) > maxc: continue
        picked.append(i); n += len(paras[i]) + 1
    return '\n'.join(paras[i] for i in sorted(picked))

if __name__ == '__main__':
    with_heading = '--headings' in sys.argv
    qs = [a for a in sys.argv[1:] if a != '--headings']
    for q in qs:
        ts, res = search(q)
        print('\nQ:', q, '| terms:', ts)
        for v, a in res:
            print(f'  {v:3} {a["id"]}')
        for v, a in res[:2]:
            print('  --- passage from', a['id'])
            print('   ', passages(a, ts, with_heading=with_heading).replace('\n', '\n    ')[:700])
