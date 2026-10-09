"""Rough port of MouseKnowledge.searchHelp + bestPassages, run over the real
HelpContent.swift, to see what Ask the Mouse would hand Apple Intelligence."""
import re, sys
sys.stdout.reconfigure(encoding='utf-8')
import os
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'AppleVis', 'Sources') + os.sep
help_src = open(SRC + 'Models/HelpContent.swift', encoding='utf-8').read()
# The How-To Library lives in its own files (2026-10-08); Help searches it too.
import glob as _glob
for _f in sorted(_glob.glob(SRC + 'Models/HowTo/HowTo*.swift')):
    help_src += chr(10) + open(_f, encoding='utf-8').read()
mk = open(SRC + 'Services/MouseKnowledge.swift', encoding='utf-8').read()

stop = set(re.findall(r'"([^"]+)"', mk[mk.find('stopWords: Set<String> = ['):mk.find(']', mk.find('stopWords: Set<String> = ['))]))
nick = {}
block = mk[mk.find('nicknames: [String: [String]] = ['):]
block = block[:block.find('\n    ]')]
for m in re.finditer(r'"([\w-]+)":\s*\[([^\]]*)\]', block):
    nick[m.group(1)] = re.findall(r'"([^"]+)"', m.group(2))

# Words that mean a nickname isn't about that article after all (2026-10-09).
nick_excludes = {}
_ex = mk[mk.find('nicknameExcludes: [String: [String]] = ['):]
_ex = _ex[:_ex.find('\n    ]')]
for m in re.finditer(r'"([\w-]+)":\s*\[([^\]]*)\]', _ex):
    nick_excludes[m.group(1)] = re.findall(r'"([^"]+)"', m.group(2))

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

def normalize(t):
    """MouseKnowledge.normalized: "Wi-Fi" and "wifi" are one word."""
    return re.sub(r'\bwi[- ]fi\b', 'wifi', t.lower())

def terms(t):
    ws = [w.strip("'") for w in re.split(r"[^0-9a-z']+", normalize(t))]
    out, seen = [], set()
    for w in ws:
        if len(w) >= 2 and w not in stop and w not in seen:
            seen.add(w); out.append(w)
    return out

# Words nearly every article has, which count for little when the question
# has a subject of its own ("set an alarm with VoiceOver"). Mirrors
# MouseKnowledge.weakWords (2026-10-09).
WEAK = {"voiceover", "iphone", "ipad", "applevis", "app", "apps", "use", "using"}

def stem(w):
    """MouseKnowledge.stem: "deleting", "transcripts", "funded" match
    "delete", "transcript", "funds"."""
    if len(w) <= 4:
        return w
    for suf in ("ing", "ed", "es", "s"):
        if w.endswith(suf) and len(w) - len(suf) >= 4:
            return w[:-len(suf)]
    if w.endswith("e"):
        return w[:-1]
    return w

def score(title, summary, body, ts, phrases):
    title, summary, body = normalize(title), normalize(summary), normalize(body)
    tot = 0
    strong = any(t not in WEAK for t in ts)
    for t in ts:
        weak = strong and t in WEAK
        # A stem matches at the start of a word only, so "thing" isn't
        # found inside "something".
        pat = re.compile(r'(?<![0-9a-z])' + re.escape(stem(t)))
        if pat.search(title): tot += 3 if weak else 6
        if pat.search(summary): tot += 1 if weak else 3
        tot += min(len(pat.findall(body)), 2 if weak else 3)
    for p in [p.lower() for p in phrases if ' ' in p]:
        if p in title: tot += 8
        if p in summary or p in body: tot += 4
    return tot

# Spelling: a word Help never uses becomes the one Help word a letter away,
# so "evrything", "roter", and "magnifyer" still find their articles.
# Mirrors MouseKnowledge.spellingFixed (2026-10-09).
_vocab = set()
for _a in articles:
    for _t in [_a['title'], _a['summary']] + [l[1] for l in _a['lines']]:
        _vocab.update(w for w in re.split(r"[^0-9a-z]+", normalize(_t)) if len(w) >= 3)
for _names in nick.values():
    for _n in _names:
        _vocab.update(w for w in re.split(r"[^0-9a-z]+", normalize(_n)) if len(w) >= 3)

def _one_off(a, b):
    if abs(len(a) - len(b)) > 1 or a == b:
        return False
    if len(a) == len(b):
        return sum(x != y for x, y in zip(a, b)) == 1
    if len(a) > len(b):
        a, b = b, a
    for i in range(len(b)):
        if b[:i] + b[i + 1:] == a:
            return True
    return False

def correction(word):
    if len(word) < 5 or word in _vocab or not word.isalpha():
        return word
    near = [v for v in _vocab if _one_off(word, v)]
    return near[0] if len(near) == 1 else word

def spelling_fixed(q):
    """Fixes lowercase words only: a capitalized one is likely a name
    (Sonos, Kindle) after the first word."""
    parts = re.split(r"([^0-9A-Za-z']+)", q)
    out = []
    first = True
    for part in parts:
        if re.fullmatch(r"[0-9A-Za-z']+", part or ''):
            if first or part.islower():
                fixed = correction(part.lower())
                if fixed != part.lower():
                    part = fixed
            first = False
        out.append(part)
    return ''.join(out)

def nick_text(t):
    """Nicknames match without apostrophes: "whats" finds "what's"."""
    return normalize(t).replace("'", '').replace('\u2019', '')

def search(q, with_heading=False):
    q = spelling_fixed(q)
    ts = terms(q)
    res = []
    lq = nick_text(q)
    for a in articles:
        body = '\n'.join(l[1] for l in a['lines'])
        v = score(a['title'], a['summary'], body, ts, [q])
        if any(nick_text(n) in lq for n in nick.get(a["id"], [])) and not any(nick_text(x) in lq for x in nick_excludes.get(a["id"], [])): v += 16
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
