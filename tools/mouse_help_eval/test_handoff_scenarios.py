"""Run from the repo root: python tools/mouse_help_eval/test_handoff_scenarios.py

The Ask the Mouse and Help scenarios from the October 2026 retrieval handoff
(RETRIEVAL_TESTS G01-V01, MASTER_TEST_MATRIX C01-C20), checked against the
real Swift sources without Xcode:

- the checked quick reference (MouseQuickReference) picks the right record,
  device, and follow-up subject, and never picks one it shouldn't;
- every record's lines are word for word in its Help article, which is
  then the Mouse's first Help source, with the lines in its passage;
- Help search, follow-ups, and the screen question rank as the app would;
- every Help article id from the handoff's inventory still exists.

What needs Apple Intelligence, the live site, or a device (writing the
answer, app picks, forum and podcast relevance, navigation and VoiceOver
focus) is listed at the end as not run here (2026-10-09)."""
import csv, os, re, sys
sys.stdout.reconfigure(encoding='utf-8')
sys.argv = [sys.argv[0]]
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sim_help as S
import quick_reference as Q
from test_howto_questions import refers_back

failures = []


def check(name, ok, detail=''):
    print(('PASS' if ok else 'FAIL'), '|', name, ('| ' + detail if detail and not ok else ''))
    if not ok:
        failures.append(name)


def article(aid):
    return next((a for a in S.articles if a['id'] == aid), None)


def mouse_help(question, earlier=None, on_mac=False):
    """AskTheMouse.run's Help step: follow-up context, the checked record,
    and Help's ranking with that record's article first."""
    context = earlier if earlier and refers_back(question) else ''
    search_q = question + ' ' + context if context else question
    record = Q.match(question, context, on_mac)
    ts, res = S.search(search_q)
    ids = [a['id'] for _, a in res]
    if record:
        ids = [record['article']] + [i for i in ids if i != record['article']]
    return record, ids, context


# ---------------------------------------------------------------- records
for r in Q.RECORDS:
    a = article(r['article'])
    check(f"record {r['id']}: article {r['article']} exists", a is not None)
    if a:
        text = '\n'.join(l[1] for l in a['lines'])
        for line in r['lines']:
            check(f"record {r['id']}: line is in Help word for word", line in text, line)
    check(f"record {r['id']}: has an Apple source", r['source'] and 'support.apple.com' in r['source'] or r['source'] in ('gestures', 'customize', 'brailleCommands'), r['source'])
ids = [r['id'] for r in Q.RECORDS]
check('record ids are unique', len(ids) == len(set(ids)))

# ---------------------------------------------------------------- conversations
# (test id, question, earlier question, runtime on Mac, expected record or None,
#  record that must not be chosen, Help article that must be in the top 2, text in record lines)
CASES = [
    ('G01/C01', 'What does a three finger double tap do?', None, False, 'vo.mute', 'vo.curtain', 'ref-voiceover-gestures', 'three-finger double-tap'),
    ('C01b', 'What does a three-finger double-tap do?', None, False, 'vo.mute', 'vo.curtain', None, 'three-finger double-tap'),
    ('C01c', 'what does double tap with 3 fingers do', None, False, 'vo.mute', None, None, None),
    ('C01d', 'triple finger double tap', None, False, 'vo.mute', None, None, None),
    ('G02', 'How do I change that gesture?', 'What does a three finger double tap do?', False, 'vo.customize', 'vo.mute', 'howto-vo-gestures', 'Touch Gestures'),
    ('C02', 'How do I change that?', 'What does a three-finger double-tap do?', False, 'vo.customize', 'vo.mute', 'howto-vo-gestures', 'Touch Gestures'),
    ('G03/C03', 'What does a three finger triple tap do?', None, False, 'vo.curtain', 'vo.mute', 'ref-voiceover-gestures', 'three-finger triple-tap'),
    ('B01', "What's the braille command to open Notification Center?", None, False, 'braille.notification', None, 'ref-braille-display', 'dots 4-6'),
    ('C04', 'How do I open Notification Center with braille?', None, False, 'braille.notification', None, 'ref-braille-display', 'dots 4-6'),
    ('C04b', 'How do I open Notification Centre with my braille display?', None, False, 'braille.notification', None, None, 'dots 4-6'),
    ('C04c', 'dots 4 and 6 with space what does that do', None, False, None, None, None, None),
    ('C07', 'How do I use the rotor?', None, False, 'vo.rotor', 'mac.rotor', 'ref-voiceover-gestures', 'turn two fingers'),
    ('C08/D01', 'What about on a Mac?', 'How do I use the rotor?', False, 'mac.rotor', 'vo.rotor', 'ref-voiceover-keyboard-mac', 'VO-U'),
    ('C09', 'How do I change text size?', 'What about on a Mac?', False, 'vision.text', None, 'howto-text-size', 'Larger Text'),
    ('D02', 'How do I change my speech rate?', 'How do I do that on my Mac?', False, None, None, 'howto-vo-speaking-rate', None),
    ('C11/V01', 'How can I make everything bigger?', None, False, 'vision.zoom', None, 'howto-zoom', 'Zoom'),
    ('settings', 'How do I make everything larger?', None, False, 'vision.zoom', None, None, None),
    ('C16', 'What is the exact shortcut on my obscure display?', None, True, None, None, None, None),
    ('C17', 'How do I turn that off?', None, False, None, None, None, None),
    ('C17b', 'How do I turn that off?', 'What does a three finger triple tap do?', False, 'vo.curtain', None, None, None),
    ('C20', 'magic tap', None, False, 'vo.magic-tap', None, None, 'two-finger double-tap'),
    ('mac-device', 'What does VO mean?', None, True, 'mac.voiceover.modifier', None, None, 'Control and Option'),
    ('mac-not-iphone', 'What does a three finger double tap do on my Mac?', None, False, None, 'vo.mute', None, None),
    ('watch', 'What does a three finger double tap do on my Apple Watch?', None, False, None, 'vo.mute', None, None),
    ('zoom-app', 'Is the Zoom app accessible?', None, False, None, 'vision.zoom', None, None),
    ('braille-next', 'braille command for next item', None, False, 'braille.next', 'vo.next', None, 'dot 4'),
    ('vo-next', 'How do I move to the next item?', None, False, 'vo.next', 'braille.next', None, 'swipe right'),
    ('speak', 'Can my iPhone read the screen without VoiceOver?', None, False, 'vision.speak-screen', 'vo.readall', None, 'Speak Screen'),
    ('voice', 'How do I change the voice?', None, False, None, 'vo.customize', None, None),
    ('braille-change', 'Is there a way to change this command?', 'What is the braille command to open the Notification Center on my iPhone?', False, None, 'braille.notification', 'howto-braille-commands', None),
    ('text-size-change', 'How do I change text size?', None, False, 'vision.text', None, None, None),
]
for tid, q, earlier, on_mac, want, never, top, text in CASES:
    record, ids, context = mouse_help(q, earlier, on_mac)
    got = record['id'] if record else None
    check(f'{tid} "{q}" -> {want}', got == want, f'got {got}')
    if never:
        check(f'{tid} never {never}', got != never, f'got {got}')
    if top:
        check(f'{tid} Help top 2 has {top}', top in ids[:2], str(ids))
    if text and record:
        check(f'{tid} answer keeps "{text}"', any(text in l for l in record['lines']), str(record['lines']))

# Follow-up context: a new topic doesn't keep the earlier device.
check('C09 "How do I change text size?" is a new topic', not refers_back('How do I change text size?'))
check('D02 "How do I change my speech rate?" is a new topic', not refers_back('How do I change my speech rate?'))
check('C08 "What about on a Mac?" is a follow-up', refers_back('What about on a Mac?'))
check('G02 "How do I change that gesture?" is a follow-up', refers_back('How do I change that gesture?'))
check('A02 "Which one is easiest with VoiceOver?" is a follow-up', refers_back('Which one is easiest with VoiceOver?'))
check('Q.platform keeps the Mac only through the follow-up', Q.platform('What about on a Mac?') == 'mac' and Q.platform('How do I change text size?') == 'iPhoneAndIPad')

# U01/C10: the screen isn't the iPhone's bottom edge.
_, res = S.search('What are the three things at the bottom of my screen?')
ids10 = [a['id'] for _, a in res]
check('C10 "bottom of my screen" puts AppleVis tabs in the top 2', 'start-tabs' in ids10[:2], str(ids10))
check('C10 "bottom of my screen" is not the bottom-edge hardware', ids10[0] != 'howto-know-bottom-edge', str(ids10))
_, res = S.search('What are those three things at the bottom?')
idsU = [a['id'] for _, a in res]
check('U01 "those three things at the bottom" offers both readings', {'start-tabs', 'howto-know-bottom-edge'} <= set(idsU[:3]), str(idsU))
check('U01 no record claims to know the screen', Q.match('What are those three things at the bottom?') is None)
prompt = open(S.SRC + 'Services/IntelligenceService.swift', encoding='utf-8').read()
check("U01 answer instructions say the Mouse can't see the screen", "You can't see the person's screen" in prompt)

# C14: AppleVis's own workflow from Help.
_, res = S.search('How do I submit an app to AppleVis?')
check('C14 submit an app -> community-submit-app', res and res[0][1]['id'] == 'community-submit-app', str([a['id'] for _, a in res]))

# C20: Help's own search shows the quick answer without Apple Intelligence.
help_view = open(S.SRC + 'Views/Info/HelpView.swift', encoding='utf-8').read()
check('C20 Help search shows the checked quick answer', 'MouseQuickReference.match' in help_view and 'Quick Answer' in help_view)
mouse = open(S.SRC + 'Services/AskTheMouse.swift', encoding='utf-8').read()
check('C20 Mouse falls back to the checked lines when no answer is written', 'if answer == nil, plan.kind != .findApps, let reference' in mouse)

# A01/C05: the dice gate.
check('A01 game questions drop apps Apple files outside Games', 'AppGenres.shared.gamesId(platform: plan.appPlatform)' in mouse)

# Fresh wordings nobody wrote the records for (2026-10-09): odd phrasings,
# typos, follow-ups, and traps where a gesture answer would be wrong.
FRESH_QS = [
    # gesture phrasing variety
    ("what happens if i tap three fingers twice", None, "vo.mute"),
    ("my phone went silent after I tapped 3 fingers 2 times", None, "vo.mute"),
    ("whats a 2 finger double tap for", None, "vo.magic-tap"),
    ("how do i pause my podcast with a voiceover gesture", None, "help:ref-voiceover-gestures"),
    ("three-finger quadruple tap", None, "vo.curtain"),
    ("how do I make the screen black but keep voiceover", None, "vo.curtain"),
    ("how do i scroll a page in voiceover", None, "vo.scroll"),
    ("how do i get voiceover to read everything from the top", None, "vo.readall"),
    ("voice over rotor how do i use it", None, "vo.rotor"),
    # braille
    ("brail dots for control centre", None, "braille.control"),
    ("on my focus 40 how do I get to notifications", None, "none"),
    ("braille display: how to jump to the last item", None, "braille.first-last"),
    ("how do i open braile access on my iphone", None, "braille.access"),
    ("what are dots 7 and 8 for", None, "none"),
    # follow-ups
    ("and on my mac?", "How do I use the rotor?", "mac.rotor"),
    ("can I change it to something else?", "What does a two finger double tap do?", "vo.customize"),
    ("how do i reassign that gesture", "What does a three finger triple tap do?", "vo.customize"),
    ("what about with braille?", "How do I open Control Center with VoiceOver?", "braille.control"),
    # new topics after Mac
    ("How do I make text larger?", "And on my Mac?", "vision.text"),
    ("How do I turn on Zoom?", "What does VO mean on Mac?", "vision.zoom"),
    # low vision
    ("everything on my screen is too small", None, "help:howto-zoom"),
    ("can my iphone read a webpage out loud without voiceover", None, "vision.speak-screen"),
    ("bigger letters please", None, "vision.text"),
    # traps: must NOT pin a gesture/command answer
    ("Is the Zoom app accessible with VoiceOver?", None, "none"),
    ("What are some good dice games?", None, "none"),
    ("How do I change my VoiceOver voice?", None, "none"),
    ("How do I change the braille table?", None, "none"),
    ("How do I change my keyboard shortcut for Ask the Mouse?", None, "none"),
    ("What does the rotor do on Apple Watch?", None, "none"),
    ("What's the three finger double tap on my Apple TV?", None, "none"),
    ("how do i mute my phone ringer", None, "none"),
    ("next item on my mac trackpad", None, "none"),
    ("How do I read the AppleVis blog?", None, "none"),
    ("What does Magic Tap do in the AppleVis podcast player?", None, "vo.magic-tap"),
    ("how do I scroll in Zoom", None, "none"),
    ("is there a notification center shortcut on my keyboard", None, "none"),
]

for q, earlier, want in FRESH_QS:
    record, ids, _ = mouse_help(q, earlier)
    got = record['id'] if record else 'none'
    if want.startswith('help:'):
        check(f'fresh "{q}" -> {want[5:]} in Help top 2', want[5:] in ids[:2], str(ids[:2]))
    else:
        check(f'fresh "{q}" -> {want}', got == want, f'got {got}')

# The Help and How-To question tests, with the checked article pinned first
# and its lines leading the passage, the way the app now does it.
import test_help_questions as H
import test_howto_questions as W2


def app_passage(a, ts, record=None):
    tw = set(S.terms(a['title']))
    focused = [t for t in ts if t not in tw] or ts
    text = H.passage(a, focused)
    if record and record['article'] == a['id']:
        text = chr(10).join(record['lines']) + chr(10) + text
    return text


for label, tests in (('Help', [(q, w, n, None) for q, w, n in H.TESTS]), ('How-To', W2.TESTS)):
    for q, want, needle, earlier in tests:
        record, ids, context = mouse_help(q, earlier)
        ts = S.terms(q + ' ' + context if context else q)
        arts = {a['id']: a for a in S.articles}
        ok = want in ids[:2] and needle.lower() in app_passage(arts[want], ts, record).lower()
        check(f'{label} with pinning: "{q}"', ok, f'top {ids[:2]}, record {record and record["id"]}')
    # A pinned answer for a question about something else would mislead,
    # even when the right article is second.

# A Swift dictionary literal with the same key twice crashes the app when
# it's first used. Four nickname keys were doubled once (2026-10-09).
_mk = open(S.SRC + 'Services/MouseKnowledge.swift', encoding='utf-8').read()
for _table in ('nicknames: [String: [String]] = [', 'nicknameExcludes: [String: [String]] = ['):
    _b = _mk[_mk.find(_table):]
    _b = _b[:_b.find(chr(10) + '    ]')]
    _keys = re.findall(r'^\s*"([\w-]+)":\s*\[', _b, re.M)
    _dups = sorted({k for k in _keys if _keys.count(k) > 1})
    check(f'no duplicate keys in MouseKnowledge {_table.split(":")[0]}', not _dups, str(_dups))

# Help ids from the handoff inventory still exist.
inventory = os.path.join(HERE, 'handoff_help_ids.txt')
if os.path.exists(inventory):
    wanted = [l.strip() for l in open(inventory, encoding='utf-8') if l.strip()]
    have = {a['id'] for a in S.articles}
    missing = [i for i in wanted if i not in have]
    check(f'all {len(wanted)} handoff Help ids still exist', not missing, str(missing[:10]))
    check('Help article ids are unique', len(S.articles) == len(have), f'{len(S.articles)} vs {len(have)}')

print()
print(f'{len(failures)} failed' if failures else 'all passed')
print('''
Not run here (needs Apple Intelligence, the live site, or a device):
  A01/C05 dice games picks, A02/C06 which-of-those follow-ups, C12/F01 forum relevance,
  C13/M01 podcast relevance, C15 app accessibility evidence, the written answers themselves,
  and the navigation and VoiceOver focus scenarios N01-N12 and C18-C19.''')
sys.exit(1 if failures else 0)
