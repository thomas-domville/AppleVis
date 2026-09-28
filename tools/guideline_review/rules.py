"""Line-for-line Python port of GuidelinesChecker.swift and
ContentSubmissionPolicy.swift (as of 2026-09-27), for reviewing real posts
on a machine without an Apple toolchain. Kept deliberately literal so a rule
change can be mirrored one-to-one. Verified against the app's own tests in
test_rules.py before use."""
import re

I = re.IGNORECASE

def matches(text, pattern, ci=False):
    return re.search(pattern, text, I if ci else 0) is not None

# ---------- ContentSubmissionPolicy ----------

def policy_text(body, subject=None):
    joined = "\n".join([x for x in (subject, body) if x is not None])
    lines = re.split(r"\r\n|\r|\n| | |\u0085", joined)
    kept = [l for l in lines if not l.strip(" \t").startswith(">") and " wrote:" not in l.lower()]
    return "\n".join(kept)

def contains_image_reference(text):
    pats = [
        r"<\s*img\b", r"<\s*picture\b", r"""<\s*source\b[^>]+type\s*=\s*["']image/""",
        r"\!\[[^\]]*\]\([^)]+\)", r"data:image/",
        r"\bhttps?://\S+\.(png|jpe?g|gif|webp|heic|heif|tiff?|bmp|svg)(\?\S*)?\b",
        r"\b\S+\.(png|jpe?g|gif|webp|heic|heif|tiff?|bmp|svg)\b",
    ]
    return any(matches(text, p, True) for p in pats)

def contains_strong_vulgar(text):
    pats = [
        r"\b(?:mother|cluster|mind|brain)?f+[\W_]*u+[\W_]*c+[\W_]*k",
        r"\bf[*#@$%]{1,3}c?k(?:er|ers|ing|in|ed|s)?\b",
        r"\bf[*#@$%]{2,3}ing\b",
        r"\bf(?:ck|uk|kn)(?:ing|in|er|ers|ed|s)?\b",
        r"\bc+[\W_]*u+[\W_]*n+[\W_]*t+s?\b",
        r"\bc[*#@$%]nts?\b",
        r"\btwats?\b",
        r"\bc+[\W_]*o+[\W_]*c+[\W_]*k+[\W_]*s+[\W_]*u+[\W_]*c+[\W_]*k+(?:er|ers|ing)?\b",
        r"\bc+[\W_]*u+[\W_]*m+[\W_]*s+[\W_]*h+[\W_]*o+[\W_]*t+s?\b",
    ]
    return any(matches(text, p, True) for p in pats)

def contains_crude(text):
    pats = [
        r"\b(?:bull|horse|dip|chicken)?sh+[*!1i]+t+(?:s|ty|tier|tiest|head|heads|show|load|storm|post|ting)?\b",
        r"\b(?:ass|arse)holes?\b",
        r"\b(?:dumb|jack|smart|bad)\s*ass(?:es)?\b",
        r"\bbitch(?:es|y|ing)?\b",
        r"\bdickheads?\b",
        r"\bwankers?\b",
        r"\bpiss\s+off\b",
        r"\b(?:you|you're|you are|such|what|he's|she's|they're)\s+(?:an?\s+)?(?:\w+\s+)?(?:prick|dick|bastard)s?\b",
    ]
    return any(matches(text, p, True) for p in pats)

THING = r"(?:podcast|youtube\s+channel|channel|website|site|blog|newsletter|mailing\s+list|substack|patreon|videos?|episodes?)"
NOT_A_TOOL = r"(?!\s+(?:player|app|reader|client))"

def sentence_chunks(text):
    chunks, cur = [], ""
    for ch in text:
        cur += ch
        if ch in ".!?":
            chunks.append(cur); cur = ""
    if cur: chunks.append(cur)
    return chunks

def looks_like_self_promotion(text):
    pats = [
        r"\b(?:check\s+out|visit|subscribe\s+to|follow|listen\s+to|watch|join|head\s+(?:over\s+)?to|go\s+to|stop\s+by|support|sign\s+up\s+(?:for|to)|tune\s+in\s+to|give)\s+my\s+(?:new\s+|latest\s+)?" + THING + r"\b",
        r"\bmy\s+(?:new|latest|brand[-\s]new)\s+" + THING + r"\b" + NOT_A_TOOL,
        r"\bi(?:'ve|\s+have)?\s+(?:just\s+)?(?:started|launched|created)\s+(?:a|my)\s+(?:new\s+)?" + THING + r"\b",
        r"\blike\s+and\s+subscribe\b",
    ]
    if any(matches(text, p, True) for p in pats):
        return True
    my_thing = r"\bmy\s+" + THING + r"\b" + NOT_A_TOOL
    link = r"(?:https?://|www\.)\S+"
    return any(matches(s, my_thing, True) and matches(s, link, True) for s in sentence_chunks(text))

SPEECH_TARGETS = r"voiceover|voice\s+over|siri|daniel|alex|samantha|karen|moira|tessa|fred|serena|arthur|martha|rishi|veena|fiona|eloquence|espeak|vocalizer|the\s+voice|voice|speech|phone|iphone|ipad|mac|watch|browser|app|notifications?|alerts?|narrator|screen\s+reader|it"
SHUT_UP_LINKING = r"to|would|will|just|finally|please|should|won't|wouldn't|doesn't|didn't|never|can't|couldn't|learning|learned|learns|trying|going|made|make|got|get"

def removing_shut_up_at_device(text):
    p = (r"\b(?:" + SPEECH_TARGETS + r")(?:[\s,.:!-]+(?:" + SHUT_UP_LINKING + r"))*[\s,.:!-]*shut\s+up\b"
         r"|\bshut\s+up[\s,.:!-]*(?:" + SPEECH_TARGETS + r")\b")
    return re.sub(p, " ", text, flags=I)

def removing_quoted(text):
    text = re.sub(r"(?is)<blockquote\b.*?</blockquote>", " ", text)
    text = text.replace("&quot;", '"').replace("&#039;", "'").replace("&#8220;", "“").replace("&#8221;", "”").replace("&ldquo;", "“").replace("&rdquo;", "”")
    for p in [r'"[^"\n]{1,200}"', r"“[^”\n]{1,200}”", r"‘[^’\n]{1,200}’", r"(?<![\w])'[^'\n]{1,200}'(?![\w])"]:
        text = re.sub(p, " ", text)
    return text

def sounds_like_moderation(text):
    return matches(text, r"\b(?:please\s+be\s+(?:respectful|kind|civil)|(?:our|the|community|posting|appleVis)\s+guidelines|goes\s+against|posting\s+privileges|personal\s+attacks\s+(?:are|aren't|are\s+not)|(?:our|the)\s+(?:trolling|moderation)\s+policy|as\s+a\s+(?:friendly\s+)?reminder|moderator\s+note|keep\s+(?:the|this)\s+discussion|this\s+thread\s+(?:has|will)\s+been?\s+(?:locked|closed))\b", True)

def removing_self_shut_up(text):
    p = r"\b(?:i|we|i'll|we'll|i'd|we'd|i'm|we're|me|us|myself|ourselves)\b[^.!?\n]{0,40}?\bshut\s+up\b"
    return re.sub(p, " ", text, flags=I)

VERBS = r"explain\w*|speak\w*|spoke|talk\w*|hear\w*|heard|see|seeing|seen|saw|read\w*|writ\w*|wrote|describ\w*|stat(?:e|es|ed|ing)|label\w*|mark\w*|show\w*|shown|sound\w*|pronounc\w*|announc\w*|display\w*|laid|lay|set|put|visible|audible|understand\w*|understood|communicat\w*"

def removing_manner_adverbs(text):
    after = r"\b(?:" + VERBS + r")\s+(?:(?:it|this|that|them|things|everything|out|up|so|very|more|really)\s+){0,2}(?:clearly|obviously)\b"
    before = r"\b(?:clearly|obviously)\s+(?:labell?ed|marked|written|visible|audible|stated|explained|shown|displayed|announced)\b"
    return re.sub(before, " ", re.sub(after, " ", text, flags=I), flags=I)

def tone_concern(text):
    high = [
        r"\b(you|you're|you are|u r)\s+(an?\s+)?(idiot|moron|loser|stupid|dumb|clown|fool|jerk)\b",
        r"\b(nobody\s+wants\s+you|you\s+should\s+leave)\b",
        r"\byou\s+(should\s+)?go\s+away\b",
        r"\byou\s+shut\s+up\b",
        r"\b(kill\s+yourself|kys|i\s+hope\s+you\s+(die|suffer))\b",
        r"\b(?<!not\s)(all|those)\s+(blind|disabled|deaf|autistic|lgbt|gay|trans|black|white|asian|jewish|muslim|christian)\s+(people\s+)?(are|should)\s+(?:all\s+|just\s+|so\s+)?(?:stupid|dumb|lazy|idiots?|useless|worthless|inferior|disgusting|freaks?|animals|scum|a\s+burden|a\s+waste|parasites|sick|die|leave|go\s+away|be\s+(?:banned|removed|locked\s+up|ashamed))\b",
        r"\b(troll|trolling)\b.*\b(shut\s+up|go\s+away|idiot|moron|stupid)\b",
    ]
    unquoted = removing_quoted(text)
    if any(matches(unquoted, p, True) for p in high): return "high"
    if any(matches(text, p, True) for p in high): return None if sounds_like_moderation(text) else "medium"
    medium = [
        r"\b(you're|you are)\s+(is\s+)?(stupid|dumb|ridiculous|nonsense|garbage|trash)\b",
        r"\b(learn\s+to\s+read|use\s+your\s+brain|you\s+clearly\s+don't\s+know|you\s+obviously\s+don't\s+understand)\b",
        r"\b(stop\s+(whining|complaining|crying)|quit\s+(whining|complaining|crying))\b",
        r"\b(what\s+is\s+wrong\s+with\s+you|are\s+you\s+serious\s+right\s+now)\b",
    ]
    if any(matches(text, p, True) for p in medium): return "medium"
    putdowns = [
        r"\bwhatever\s+helps\s+you\s+sleep\b",
        r"\b(?:always|there's\s+always|of\s+course)\s+(?:(?:find|get|have)\s+)?(?:someone|somebody|people)\s+like\s+you\b",
        r"\bpeople\s+like\s+you\s+(?:always|never|keep|ruin|are\s+(?:the\s+problem|why))\b",
        r"\bcope\s+(?:and\s+seethe|harder)\b", r"\bstay\s+mad\b", r"\btouch(?:ing)?\s+grass\b",
        r"\bok(?:ay)?\s+boomer\b", r"\bget\s+a\s+life\b", r"\bskill\s+issue\b",
        r"\bmind\s+your\s+own\s+(?:damn\s+)?business\b",
        r"\byou(?:'ve|\s+have|\s+got|\s+obviously\s+have|\s+clearly\s+have)\s+(?:some\s+|serious\s+|a\s+lot\s+of\s+|real\s+|deep\s+)?(?:insecurit(?:y|ies)|issues)\b[^.!?]{0,80}\b(?:counsell?or|therapist|therapy|psychiatrist|professional\s+help)\b",
        r"\byou\s+(?:really\s+)?need\s+(?:some\s+)?(?:therapy|a\s+therapist|professional\s+help|to\s+see\s+a\s+(?:therapist|shrink))\b",
    ]
    if any(matches(unquoted, p, True) for p in putdowns): return "medium"
    pd_sent = [r"^\W*(?:ok(?:ay)?\W+|but\W+|lol\W+|lmf?ao+\W+)?who\s+asked\W*$",
               r"^\W*(?:just\s+|you\s+need\s+to\s+|please\s+)?grow\s+up\W*$"]
    if any(any(matches(s.strip(), p, True) for p in pd_sent) for s in sentence_chunks(text)): return "medium"
    if matches(removing_self_shut_up(removing_shut_up_at_device(text)), r"\bshut\s+up\b", True): return "medium"
    low_sent = [r"\b(obviously|clearly)\b(?=.*\byou(?:r|'re|'ve|'d|'ll)?\b).*[!?]|\byou(?:r|'re|'ve|'d|'ll)?\b.*\b(obviously|clearly)\b.*[!?]",
                r"^\W*whatever\b.*[!?]|^\W*whatever\W*$|\bwhatever\s+you\s+say\b"]
    def low_hit(sentence):
        if matches(sentence, r"\b(thank|thanks|thx|appreciate[ds]?)\b", True): return False
        checked = removing_manner_adverbs(sentence)
        return any(matches(checked, p, True) for p in low_sent)
    if any(low_hit(s) for s in sentence_chunks(text)) or matches(text, r"\b(i\s+can't\s+believe|that's\s+absurd|that's\s+annoying|suck\s+it\s+up)\b", True):
        return "low"
    return None

# ---------- GuidelinesChecker ----------

EMAIL = r"\b(?!(?:accessibility|support|contact|info|help|press|sales|admin|team|hello|feedback|abuse|legal|privacy|webmaster|postmaster|user|example|someone|yourname)@)([a-zA-Z0-9._%+-]+)@([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})"
INVITATION = r"\b(?:e-?mail|mail|contact|reach|write\s+to|message|drop(?:ping)?\s+(?:me|us)\s+a\s+(?:line|note|message)|send\b[^.!?\n]{0,60}?\bto|email\s+address(?:\s+is)?|feedback\s+to)\s*:?[^.!?\n]{0,25}$"
PROJECT = r"(?:^|[._-])(?:info|support|help|contact|feedback|dev|devs|app|apps|team|studio|games?|official|hello|mail)(?:[._-]|$)|(?:dev|app|apps|studio|games|official)$"

def email_addresses(text):
    text = re.sub(r"</?[a-zA-Z][a-zA-Z0-9]*(?:\s[^<>]*)?/?>", " ", text).replace("&nbsp;", " ").replace("&#039;", "'").replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
    out = []
    for m in re.finditer(EMAIL, text, I):
        before = text[max(0, m.start() - 80):m.start()]
        after = text[m.end():m.end() + 40]
        header = matches(before, r"(?:\b(?:from|to|cc|bcc|reply-to|sender)\s*:[^\n]{0,60}|<\s*|\[mailto:)$", True) or matches(after, r"^\s*>?\s*(?:\S+\s+){0,3}wrote\s*:", True)
        out.append({'local': m.group(1).lower(), 'domain': m.group(2).lower(), 'header': header,
                    'shared': matches(before, INVITATION, True), 'project': matches(m.group(1).lower(), PROJECT, True)})
    offered = {a['local'] + '@' + a['domain'] for a in out if a['shared']}
    for a in out:
        if a['local'] + '@' + a['domain'] in offered: a['shared'] = True
    return out
PERSONAL = {"gmail.com", "googlemail.com", "icloud.com", "me.com", "mac.com", "outlook.com", "hotmail.com", "live.com", "msn.com",
            "yahoo.com", "ymail.com", "rocketmail.com", "aol.com", "aim.com", "proton.me", "protonmail.com", "pm.me", "gmx.com", "gmx.net", "gmx.de",
            "mail.com", "zoho.com", "yandex.com", "yandex.ru", "fastmail.com", "hey.com", "tutanota.com", "tuta.io", "comcast.net", "att.net", "verizon.net", "sbcglobal.net",
            "btinternet.com", "sky.com", "virginmedia.com", "web.de", "orange.fr", "free.fr", "laposte.net", "libero.it", "qq.com", "163.com", "126.com", "naver.com"}

def email_domains(text):
    return [a['domain'] for a in email_addresses(text)]

def is_personal(domain):
    if domain in PERSONAL: return True
    return domain.split(".")[0] in {"yahoo", "hotmail", "outlook", "live", "gmx", "yandex", "aol"}

def announcement_needs_approval(text):
    p = r"\b(survey|questionnaire|research study|research project|focus group|participants? needed|looking for participants?|study participants?)\b"
    inv = r"\b(please|fill\s+(?:in|out)|take\s+(?:our|this|the|a|my|their|part)|complete\s+(?:our|this|the|a|my)|participate|sign\s+up|join\s+(?:our|the|a|my)|click|link\b|below|would\s+(?:you|like)|could\s+you|we'd\s+(?:love|like|appreciate)|we\s+would\s+(?:love|like|appreciate)|help\s+us|if\s+you're\s+interested|if\s+you\s+are\s+interested|few\s+minutes|looking\s+for|participants?\s+needed|recruiting|volunteers?)\b"
    for s in re.split(r"[.!?]", text):
        if matches(s, p, True) and "thank" not in s.lower() and matches(s, inv, True):
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
    elif doms: w.append(("personal-info", "low"))
    if matches(text, r"[?&](ref|referral|affiliate|aff|partner|subid)=", True): w.append(("referral-link", "medium"))
    if looks_like_self_promotion(text): w.append(("self-promotion", "medium"))
    listing = [r"(?:^|[.!?\n]\s*)(?:for\s+sale|wanted\s+to\s+buy|wtb|wts)\b", r"\b(?:for\s+sale|wanted\s+to\s+buy)\s*[:\-–]",
               r"\b(?:i'm|i\s+am|we're|we\s+are)\s+selling\b",
               r"\b(?:have|has|got)\s+(?:an?\s+|my\s+|some\s+|two\s+|a\s+few\s+)?[\w\s-]{0,30}?\bfor\s+sale\b",
               r"\bbuy\s+now\b", r"\bget\s+\d+%\s+off\b",
               r"\b(?:promo|coupon|discount)\s+code\b[^.!?\n]{0,80}\b(?:off|discount|save|savings|checkout|%)",
               r"\b(?:off|discount|save|savings|%)[^.!?\n]{0,80}\b(?:promo|coupon|discount)\s+code\b",
               r"\b(?:takes?|saves?|get)\s+(?:up\s+to\s+)?[$£€]\d+\s+off\b"]
    if any(matches(text, p, True) for p in listing): w.append(("advertising", "medium"))
    if announcement_needs_approval(text): w.append(("announcement-approval", "high"))
    pr = [r"\bfor\s+immediate\s+release\b", r"(?:^|\n)\s*press\s+release\b", r"\bpress\s+release\s*[:\-–]",
          r"\b(?:pr\s*newswire|business\s*wire|globe\s*newswire|accesswire)\b", r"\bmedia\s+contact\s*:"]
    if any(matches(text, x, True) for x in pr): w.append(("press-release", "medium"))
    ai = [r"\bas\s+an\s+ai(?:\s+language\s+model|\s+model|\s+assistant)?\s*,\s*i\b", r"\bas\s+an\s+ai\s+language\s+model\b", r"\bas\s+a\s+language\s+model\b",
          r"\bi\s+don't\s+have\s+personal\s+experience\b", r"\bi\s+cannot\s+browse\s+the\s+internet\b", r"\bas\s+of\s+my\s+knowledge\s+cutoff\b",
          r"\bi'm\s+unable\s+to\s+access\s+real-time\b", r"\b(?:certainly|absolutely)!\s+here's\b", r"\bsure!\s+here's\s+a\b", r"\bgreat\s+question!\s+here\b"]
    if any(matches(lower, a) for a in ai): w.append(("ai-disclosure", "medium"))
    toks = [t for t in trimmed.split(" ") if len(t) > 3 and any(c.isalpha() for c in t)]
    if len(toks) >= 5:
        caps = [t for t in toks if t == t.upper() and any(c.isupper() for c in t)]
        if len(caps) / len(toks) > 0.55: w.append(("all-caps", "low"))
    pos = r"\b(?:love|loving|awesome|amazing|great|excited|exciting|yay|wow|congrat\w*|thank\w*|brilliant|fantastic|wonderful|cool|fun|happy|finally)\b"
    if any(matches(s, r"[!?]{3,}") and matches(s, r"\b[A-Z]{4,}\b") and not matches(s, pos, True) for s in re.findall(r"[^.!?]*[.!?]+|[^.!?]+$", trimmed)):
        w.append(("excessive-punctuation", "low"))
    if len(trimmed) < 60:
        nv = ["me too", "same here", "same issue", "same problem", "same for me", "same thing", "ditto", "i agree", "agreed",
              "just google it", "try googling", "just search for it", "i haven't used", "i don't use that", "never used it", "haven't tried it", "can't help"]
        if any(p in lower for p in nv): w.append(("low-value", "low"))
    topic_switch = r"\b(?:unrelated\s+(?:question|note|topic|issue)|on\s+(?:a|an)\s+(?:different|unrelated|separate|other)\s+(?:note|topic|subject)|off[\s-]topic|(?:another|second|separate|different|other)\s+(?:question|thing|issue|topic)\s*,?\s*(?:not|un)\s*related|changing\s+(?:the\s+)?(?:topic|subject)|(?:totally|completely)\s+different\s+(?:question|topic|subject))\b"
    if not is_reply and matches(text, topic_switch, True): w.append(("multi-topic", "low"))
    sents = [s.strip().lower() for s in re.split(r"[.!?]", trimmed)]
    sents = [s for s in sents if len(s) > 15]
    if len(sents) >= 4 and len(set(sents)) / len(sents) < 0.55: w.append(("repetition", "medium"))
    order = {"high": 0, "medium": 1, "low": 2}
    return sorted(w, key=lambda x: order[x[1]])
