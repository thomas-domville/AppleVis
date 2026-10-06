"""Python port of GuidelinesChecker.swift and ContentSubmissionPolicy.swift,
for reviewing real posts on a machine without an Apple toolchain.

The patterns come from the same file the app uses,
AppleVis/Sources/Resources/guideline-rules.json (2026-10-06), so a rule fix is
made once. The logic here mirrors the Swift line for line. Verified against
the app's own tests in test_rules.py before use."""
import json, os, re

I = re.IGNORECASE
RULES_FILE = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'AppleVis', 'Sources', 'Resources', 'guideline-rules.json'))
DOC = json.load(open(RULES_FILE, encoding='utf-8'))


def _expand(pattern):
    for name, value in DOC['variables'].items():
        pattern = pattern.replace('{' + name + '}', value)
    return pattern


P = {key: [_expand(p) for p in pats] for key, pats in DOC['patterns'].items()}
LISTS = DOC['lists']
THING = DOC['variables']['thing']
NOT_A_TOOL = DOC['variables']['notATool']


def matches(text, pattern, ci=False):
    return re.search(pattern, text, I if ci else 0) is not None


def any_match(text, key, ci=True):
    return any(matches(text, p, ci) for p in P[key])

# ---------- ContentSubmissionPolicy ----------

def policy_text(body, subject=None):
    joined = "\n".join([x for x in (subject, body) if x is not None])
    lines = re.split("\r\n|\r|\n|\u2028|\u2029|\u0085", joined)
    kept = [l for l in lines if not l.strip(" \t").startswith(">") and " wrote:" not in l.lower()]
    return "\n".join(kept)

def contains_image_reference(text):
    return any_match(text, 'image')

def contains_strong_vulgar(text):
    return any_match(text, 'vulgarStrong')

def contains_crude(text):
    return any_match(text, 'crude')

def sentence_chunks(text):
    chunks, cur = [], ""
    for ch in text:
        cur += ch
        if ch in ".!?":
            chunks.append(cur); cur = ""
    if cur: chunks.append(cur)
    return chunks

def looks_like_self_promotion(text):
    if any_match(text, 'selfPromotion'):
        return True
    # Developers seeking feedback on something from their site (2026-10-06).
    if any_match(text, 'selfPromotionFeedback'):
        return False
    return any(any_match(s, 'selfPromotionMyThing') and any_match(s, 'link') for s in sentence_chunks(text))

def removing_shut_up_at_device(text):
    for p in P['shutUpAtDevice']:
        text = re.sub(p, " ", text, flags=I)
    return text

def removing_quoted(text):
    text = re.sub(r"(?is)<blockquote\b.*?</blockquote>", " ", text)
    text = text.replace("&quot;", '"').replace("&#039;", "'").replace("&#8220;", "“").replace("&#8221;", "”").replace("&ldquo;", "“").replace("&rdquo;", "”")
    for p in P['quotedPassage']:
        text = re.sub(p, " ", text)
    return text

def sounds_like_moderation(text):
    return any_match(text, 'moderation')

def removing_self_shut_up(text):
    for p in P['selfShutUp']:
        text = re.sub(p, " ", text, flags=I)
    return text

def removing_manner_adverbs(text):
    for p in P['mannerAdverbAfter']:
        text = re.sub(p, " ", text, flags=I)
    for p in P['mannerAdverbBefore']:
        text = re.sub(p, " ", text, flags=I)
    return text

def tone_concern(text):
    unquoted = removing_quoted(text)
    if any_match(unquoted, 'toneHigh'): return "high"
    if any_match(text, 'toneHigh'): return None if sounds_like_moderation(text) else "medium"
    if any_match(text, 'toneMedium'): return "medium"
    if any_match(unquoted, 'tonePutDown'): return "medium"
    if any(any_match(s.strip(), 'tonePutDownSentence') for s in sentence_chunks(text)): return "medium"
    if any_match(removing_self_shut_up(removing_shut_up_at_device(text)), 'shutUp'): return "medium"
    def low_hit(sentence):
        if any_match(sentence, 'toneThanks'): return False
        return any_match(removing_manner_adverbs(sentence), 'toneLowSentence')
    if any(low_hit(s) for s in sentence_chunks(text)) or any_match(text, 'toneLowAnywhere'):
        return "low"
    return None

# ---------- GuidelinesChecker ----------

def email_addresses(text):
    text = re.sub(r"</?[a-zA-Z][a-zA-Z0-9]*(?:\s[^<>]*)?/?>", " ", text).replace("&nbsp;", " ").replace("&#039;", "'").replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
    out = []
    for m in re.finditer(P['emailAddress'][0], text, I):
        before = text[max(0, m.start() - 80):m.start()]
        after = text[m.end():m.end() + 40]
        header = any_match(before, 'emailHeaderBefore') or any_match(after, 'emailHeaderAfter')
        out.append({'local': m.group(1).lower(), 'domain': m.group(2).lower(), 'header': header,
                    'shared': any_match(before, 'emailInvitation'), 'project': any_match(m.group(1).lower(), 'emailProject')})
    offered = {a['local'] + '@' + a['domain'] for a in out if a['shared']}
    for a in out:
        if a['local'] + '@' + a['domain'] in offered: a['shared'] = True
    return out

PERSONAL = set(LISTS['personalEmailProviders'])

def email_domains(text):
    return [a['domain'] for a in email_addresses(text)]

def is_personal(domain):
    if domain in PERSONAL: return True
    return domain.split(".")[0] in set(LISTS['personalEmailRegionalBases'])

def announcement_needs_approval(text):
    for s in re.split(r"[.!?]", text):
        if any_match(s, 'announcementTopic') and "thank" not in s.lower() and any_match(s, 'announcementInvitation'):
            return True
    return False

def check(text, is_reply=False):
    trimmed = policy_text(text).strip()
    if len(trimmed) < 10: return []
    lower = trimmed.lower()
    w = []
    if contains_image_reference(trimmed): w.append(("no-images", "high"))
    if contains_strong_vulgar(trimmed): w.append(("vulgar-language", "high"))
    elif contains_crude(trimmed): w.append(("crude-language", "medium"))
    t = tone_concern(trimmed)
    if t: w.append(("tone-" + t, t))
    addrs = email_addresses(text)
    doms = [a['domain'] for a in addrs]
    if any(is_personal(a['domain']) and a['header'] and not a['shared'] and not a['project'] for a in addrs): w.append(("personal-info", "medium"))
    elif any(is_personal(d) for d in doms): w.append(("personal-info", "low"))
    if any_match(text, 'referral'): w.append(("referral-link", "medium"))
    if looks_like_self_promotion(text): w.append(("self-promotion", "medium"))
    if any_match(text, 'advertising'): w.append(("advertising", "medium"))
    if announcement_needs_approval(text): w.append(("announcement-approval", "high"))
    if any_match(text, 'pressRelease'): w.append(("press-release", "medium"))
    if any_match(lower, 'aiDisclosure', ci=False): w.append(("ai-disclosure", "medium"))
    toks = [t for t in trimmed.split(" ") if len(t) > 3 and any(c.isalpha() for c in t)]
    if len(toks) >= 5:
        caps = [t for t in toks if t == t.upper() and any(c.isupper() for c in t)]
        if len(caps) / len(toks) > 0.55: w.append(("all-caps", "low"))
    if any(any_match(s, 'shoutingMarks', ci=False) and any_match(s, 'shoutingCaps', ci=False) and not any_match(s, 'shoutingExcitement')
           for s in re.findall(r"[^.!?]*[.!?]+|[^.!?]+$", trimmed)):
        w.append(("excessive-punctuation", "low"))
    if len(trimmed) < 60:
        if any(p in lower for p in LISTS['lowValuePhrases']): w.append(("low-value", "low"))
    if not is_reply and any_match(text, 'topicSwitch'): w.append(("multi-topic", "low"))
    sents = [s.strip().lower() for s in re.split(r"[.!?]", trimmed)]
    sents = [s for s in sents if len(s) > 15]
    if len(sents) >= 4 and len(set(sents)) / len(sents) < 0.55: w.append(("repetition", "medium"))
    order = {"high": 0, "medium": 1, "low": 2}
    return sorted(w, key=lambda x: order[x[1]])
