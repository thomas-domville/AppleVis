import json, re, html, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rules


def plain(t):
    return re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ', t))).strip()

def trigger(rule, text):
    """The words that set the rule off, with a little context."""
    t = rules.policy_text(text)
    pats = {
        'crude-language': [r"\b(?:bull|horse|dip|chicken)?sh+[*!1i]+t+\w*", r"\b(?:ass|arse)holes?\b", r"\b(?:dumb|jack|smart|bad)\s*ass(?:es)?\b",
                           r"\bbitch\w*", r"\bdickheads?\b", r"\bwankers?\b", r"\bpiss\s+off\b",
                           r"\b(?:you|you're|you are|such|what|he's|she's|they're)\s+(?:an?\s+)?(?:\w+\s+)?(?:prick|dick|bastard)s?\b"],
        'vulgar-language': [r"\b(?:mother|cluster|mind|brain)?f+[\W_]*u+[\W_]*c+[\W_]*k\w*", r"\bf[*#@$%]{1,3}c?k\w*", r"\bf(?:ck|uk|kn)\w*",
                            r"\bc+[\W_]*u+[\W_]*n+[\W_]*t+s?\b", r"\btwats?\b", r"\bc+[\W_]*o+[\W_]*c+[\W_]*k+[\W_]*s+[\W_]*u+[\W_]*c+[\W_]*k+\w*",
                            r"\bc+[\W_]*u+[\W_]*m+[\W_]*s+[\W_]*h+[\W_]*o+[\W_]*t+s?\b"],
        'personal-info': [rules.EMAIL],
        'announcement-approval': [r"\b(survey|research study|research project|focus group|participants? needed|looking for participants?|study participants?)\b"],
        'advertising': [r"(\bfor sale\b|\bwanted to buy\b|\bbuy now\b|\bpromo code\b|\bcoupon code\b|\bget \d+% off\b)"],
        'tone-medium': [r"\b(you're|you are)\s+(is\s+)?(stupid|dumb|ridiculous|nonsense|garbage|trash)\b",
                        r"\b(learn\s+to\s+read|use\s+your\s+brain|you\s+clearly\s+don't\s+know|you\s+obviously\s+don't\s+understand)\b",
                        r"\b(stop\s+(whining|complaining|crying)|quit\s+(whining|complaining|crying))\b",
                        r"\b(what\s+is\s+wrong\s+with\s+you|are\s+you\s+serious\s+right\s+now)\b", r"\bshut\s+up\b",
                        r"\bwhatever\s+helps\s+you\s+sleep\b", r"like\s+you\b", r"\bcope\b", r"\bstay\s+mad\b", r"\bgrass\b",
                        r"\bboomer\b", r"\bget\s+a\s+life\b", r"\bskill\s+issue\b", r"\bwho\s+asked\b", r"\bgrow\s+up\b"],
        'tone-low': [r"\b(obviously|clearly)\b[^.!?]*[!?]", r"\bwhatever\b[^.!?]*[!?]", r"\b(i\s+can't\s+believe|that's\s+absurd|that's\s+annoying)\b"],
        'excessive-punctuation': [r"[!?]{3,}"],
        'low-value': [r".+"],
        'multi-topic': [r"\?"],
    }.get(rule, [])
    p = plain(t)
    for pat in pats:
        m = re.search(pat, p, re.I)
        if m:
            a, b = max(0, m.start() - 110), min(len(p), m.end() + 110)
            return ('…' if a else '') + p[a:m.start()] + '[[' + m.group(0) + ']]' + p[m.end():b] + ('…' if b < len(p) else '')
    return p[:220]

if __name__ == '__main__':
    items = {i['id']: i for i in json.load(open(os.path.join(HERE, 'month.json'), encoding='utf-8'))}
    hits = json.load(open(os.path.join(HERE, 'hits.json'), encoding='utf-8'))
    want = set(sys.argv[1].split(',')) if len(sys.argv) > 1 else {'high', 'medium'}
    n = 0
    for h in sorted(hits, key=lambda h: ({'high': 0, 'medium': 1, 'low': 2}[h['severity']], h['rule'])):
        if h['severity'] not in want and h['rule'] not in want: continue
        it = items[h['id']]
        n += 1
        print(f"#{n} {h['severity'].upper()} {h['rule']} | {it['kind']} by {it['author']} on \"{it['title'][:60]}\"")
        print('   ', trigger(h['rule'], it['text']))
