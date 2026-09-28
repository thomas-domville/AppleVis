"""Looks for posts the rules may have MISSED: a deliberately wide net of
signals, run only over items the matching rule didn't flag. Everything it
prints is a candidate for manual review, not a verdict.
Usage: python miss_net.py month90.json"""
import json, os, re, sys, html, collections
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rules

FILE = sys.argv[1] if len(sys.argv) > 1 else 'month90.json'
items = json.load(open(os.path.join(HERE, FILE), encoding='utf-8'))

def plain(t):
    return re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ', t))).strip()

# signal name -> (patterns, rule ids that would already cover it)
NET = {
    'rude-words': ([r"\b(?:wtf|stfu|gtfo|pos|piece\s+of\s+(?:shit|crap|garbage|trash))\b", r"\bdouche\w*", r"\basshat\w*", r"\bjackass\w*",
                    r"\bpuss(?:y|ies)\b", r"\bsluts?\b", r"\bwhores?\b", r"\bretard\w*", r"\bspaz\w*", r"\bf[a@]gg?(?:ot)?s?\b", r"\bn[i1]gg\w*",
                    r"\bcocks?\b", r"\bbollocks\b", r"\barse\b", r"\bcrap\s*hole\b", r"\bdamn(?:ed)?\s+(?:idiot|fool|developers?|people)\b", r"\bsod\s+off\b",
                    r"\bbugger\s+off\b", r"\bscrew\s+(?:you|off|this)\b", r"\bsuck\s+(?:it|my)\b"],
                   {'vulgar-language', 'crude-language'}),
    'insults': ([r"\byou(?:'re|\s+are)?\s+(?:so\s+|such\s+an?\s+|being\s+(?:an?\s+)?)?(?:ignorant|pathetic|clueless|delusional|arrogant|rude|childish|entitled|a\s+troll|a\s+liar|an?\s+ass|a\s+hypocrite|a\s+joke|toxic|insufferable|condescending|a\s+keyboard\s+warrior)\b",
                 r"\b(?:grow\s+a\s+(?:brain|pair)|get\s+lost|nobody\s+cares|no\s+one\s+(?:cares|asked)|who\s+cares|did\s+you\s+even\s+read|read\s+the\s+(?:damn\s+)?thread|rtfm|lmgtfy|cry\s+(?:more|about\s+it)|snowflake|boo\s+hoo|get\s+over\s+(?:it|yourself)|mind\s+your\s+own|shut\s+your)\b",
                 r"\b(?:troll|trolling|trolls)\b", r"\b(?:insecure|mental\s+health\s+counselor|unhinged|mentally\s+ill)\b"],
                {'tone-high', 'tone-medium', 'tone-low'}),
    'survey-links': ([r"forms\.gle/", r"docs\.google\.com/forms", r"surveymonkey\.", r"qualtrics\.", r"typeform\.com", r"forms\.office\.com", r"jotform\.", r"survey\.alchemer", r"microsoft\.com/.*forms"],
                     {'announcement-approval'}),
    'promo-links': ([r"youtube\.com/(?:@|c/|channel/|user/)", r"youtu\.be/", r"patreon\.com/", r"buymeacoffee\.com/", r"ko-fi\.com/", r"gofundme\.com/", r"kickstarter\.com/", r"indiegogo\.com/", r"linktr\.ee/", r"substack\.com", r"paypal\.me/", r"cash\.app/"],
                    {'self-promotion', 'advertising'}),
    'image-hosts': ([r"imgur\.com/", r"flickr\.com/photos", r"instagram\.com/p/", r"pic\.twitter\.com/", r"ibb\.co/", r"postimg\.cc/", r"photos\.app\.goo\.gl/"], {'no-images'}),
    'hidden-email': ([r"\b[\w.+-]+\s*(?:\[at\]|\(at\)|\s+at\s+)\s*(?:gmail|icloud|yahoo|hotmail|outlook|proton\w*|aol|me|mac)\s*(?:\[dot\]|\(dot\)|\s+dot\s+|\.)\s*(?:com|net|me)\b"], {'personal-info'}),
    'phone-number': ([r"(?:call|phone|text|whats\s*app|mobile|cell|tel|contact)[^.\n]{0,30}?(?:\+\d{1,3}[\s.-]?)?\(?\d{2,4}\)?[\s.-]\d{3,4}[\s.-]\d{3,4}\b"], {'personal-info'}),
    'selling': ([r"\b(?:selling|for\s+sale|asking\s+(?:price|\$)|price\s+is\s+(?:negotiable|firm)|o\.?b\.?o\.?|shipping\s+included|dm\s+me\s+if\s+interested|pm\s+me\s+if\s+interested)\b"], {'advertising'}),
}

found = collections.defaultdict(list)
for it in items:
    flagged = {rid for rid, _ in rules.check(it['text'], it['isReply'])}
    p = plain(rules.policy_text(it['text']))
    for name, (pats, covered) in NET.items():
        if flagged & covered: continue
        for pat in pats:
            m = re.search(pat, p, re.I)
            if m:
                a, b = max(0, m.start() - 110), min(len(p), m.end() + 110)
                found[name].append((it, p[a:m.start()] + '[[' + m.group(0) + ']]' + p[m.end():b]))
                break

print(f'{len(items)} items checked for misses')
for name, rows in found.items():
    print(f'\n=== {name}: {len(rows)}')
    for it, snip in rows:
        print(f"- {it['kind']} by {it['author']} on \"{it['title'][:50]}\": …{snip}…")
