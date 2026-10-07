"""Run from the repo root: python tools/mouse_help_eval/test_help_questions.py

Batch test: does Ask the Mouse's Help search find the right article (top 2)
and does the answer line survive into the ~900-character passage it reads?"""
import sys, re
sys.stdout.reconfigure(encoding='utf-8')
sys.argv = [sys.argv[0]]
sys.path.insert(0, __import__('os').path.dirname(__import__('os').path.abspath(__file__)))
import sim_help as S

def passage(a, ts, maxc=900):
    # Mirrors MouseKnowledge.helpPassageText + bestPassages.
    lines = []
    for kind, text, heading in a['lines']:
        if kind in ('h', 'source'):
            continue
        lines.append(f"{heading}: {text}" if heading else text)
    ranked = [(i, S.score('', '', p, ts, [])) for i, p in enumerate(lines)]
    chosen = [i for i, s in sorted([r for r in ranked if r[1] > 0], key=lambda r: -r[1])]
    order = chosen + [i for i in range(len(lines)) if i not in chosen]
    picked, n = [], 0
    for i in order:
        if n + len(lines[i]) > maxc: continue
        picked.append(i); n += len(lines[i]) + 1
    return '\n'.join(lines[i] for i in sorted(picked))

# (question, expected article id, text that must reach the Mouse)
TESTS = [
    ("What's the braille command for Control Center?", "ref-braille-display", "dots 2-5"),
    ("braille display command to go home", "ref-braille-display", "dots 1-2-5"),
    ("how do i pan my braille display", "ref-braille-display", "Pan left"),
    ("What braille command opens notification center on iphone", "ref-braille-display", "dots 4-6"),
    ("braille command for the menu bar on my mac", "ref-braille-display-mac", "dots 2-3-4"),
    ("How do I force restart my iPhone?", "ref-restart-iphone-ipad", "volume up"),
    ("my iphone is frozen what do i do", "ref-restart-iphone-ipad", "Force restart"),
    ("How do I restart my iPad without a home button", "ref-restart-iphone-ipad", "nearest the top button"),
    ("how do i turn off my ipad", "ref-restart-iphone-ipad", "iPad"),
    ("How do I shut down my Mac when it's frozen?", "ref-restart-mac", "power button"),
    ("How do I get into macOS Recovery on an Apple silicon Mac?", "ref-restart-mac", "Loading startup options"),
    ("How do I reset my AirPods Pro?", "ref-restart-watch-airpods-tv", "setup button"),
    ("How do I restart my Apple TV?", "ref-restart-watch-airpods-tv", "TV button"),
    ("force restart apple watch", "ref-restart-watch-airpods-tv", "Digital Crown"),
    ("What's the Magic Tap?", "ref-voiceover-gestures", "two-finger double-tap"),
    ("How do I scroll down with VoiceOver?", "ref-voiceover-gestures", "three-finger swipe up"),
    ("how do i go back with voiceover", "ref-voiceover-gestures", "scrub"),
    ("What gesture opens the item chooser?", "ref-voiceover-gestures", "two-finger triple-tap"),
    ("How do I use the rotor on iPhone?", "ref-voiceover-gestures", "turn two fingers"),
    ("Keyboard shortcut to go to the home screen with VoiceOver", "ref-voiceover-keyboard-ios", "VO-H"),
    ("How do I open Control Center with a Magic Keyboard and VoiceOver?", "ref-voiceover-keyboard-ios", "Option-Down Arrow"),
    ("What is quick nav?", "ref-glossary", "Quick Nav"),
    # Adaptive Experience upgrade (2026-10-06).
    ("How do I read forum topics side by side on my iPad?", "start-ipad-duo", "Forums: topics beside the list of topics"),
    ("With VoiceOver how do I move to the topic beside the list?", "start-ipad-duo", "choose it again"),
    ("Does AppleVis work on iPhone Duo?", "start-ipad-duo", "iPhone Duo"),
    ("What's the keyboard shortcut for Ask the Mouse?", "smart-ask-the-mouse", "Command-M"),
    ("How do I contact AppleVis with my keyboard?", "ref-applevis-keyboard", "Command-Shift-C"),
    ("How do I see AppleVis keyboard shortcuts on my iPad?", "ref-applevis-keyboard", "Globe-M"),
    ("How do I turn on VoiceOver on a Mac?", "ref-accessibility-shortcut", "Command-F5"),
    ("how do i open voiceover utility", "ref-voiceover-keyboard-mac", "VO-Fn-F8"),
    ("Mac VoiceOver command to go to the dock", "ref-voiceover-keyboard-mac", "VO-D"),
    ("trackpad gesture to go to the menu bar with voiceover", "ref-voiceover-trackpad-mac", "near the top of the trackpad"),
    ("How do I check notifications on my Apple Watch with VoiceOver?", "ref-voiceover-watch", "two fingers"),
    ("How do I change VoiceOver volume on my watch?", "ref-voiceover-watch", "double-tap and hold"),
    ("What's exploration mode on Apple TV?", "ref-voiceover-tv", "Exploration mode"),
    ("How do I turn on VoiceOver when setting up a new iPhone?", "ref-setup-voiceover", "three times"),
    ("triple click doesn't turn on voiceover", "ref-accessibility-shortcut", "Accessibility Shortcut"),
    ("VoiceOver isn't talking anymore", "ref-voiceover-silent", "three-finger double-tap"),
    ("My screen is black but VoiceOver is still talking", "ref-voiceover-silent", "Screen Curtain"),
    ("How do I make the text bigger?", "ref-low-vision", "Display & Text Size"),
    ("How do I have my iPhone read the screen to me without VoiceOver?", "ref-low-vision", "Speak Screen"),
    ("How do I select text with VoiceOver?", "ref-typing-voiceover", "Text Selection"),
    ("How do I insert a new line with Braille Screen Input?", "ref-typing-voiceover", "two fingers"),
    ("What's touch typing?", "ref-typing-voiceover", "Touch Typing"),
    ("Can VoiceOver describe the doors around me?", "ref-recognition", "door"),
    ("How do I use screen recognition?", "ref-recognition", "Screen Recognition"),
    ("How do I jump between headings in Safari?", "ref-web-voiceover", "rotor"),
    ("How do I answer a phone call with VoiceOver?", "ref-iphone-everyday-voiceover", "two-finger double-tap"),
    ("How do I get to the App Switcher with VoiceOver on iPhone 15?", "ref-iphone-everyday-voiceover", "App Switcher"),
    ("How do I switch apps on a Mac?", "ref-mac-essentials", "Command"),
    ("Mac shortcut for force quit", "ref-mac-essentials", "Option-Command-Escape"),
    ("What's Apple's accessibility phone number in the UK?", "ref-getting-help", "0800 048 0754"),
    ("How do I back up my iPhone before updating?", "ref-updating", "iCloud Backup"),
    ("What is contracted braille?", "ref-glossary", "short forms"),
    ("whats the brail command for control centre", "ref-braille-display", "dots 2-5"),
    # Found by the live-site batch 3 (2026-10-05).
    ("My phone keeps reading everything twice", "ref-voiceover-silent", "off and on again"),
    ("voiceover is speaking double after a phone call", "ref-voiceover-silent", "phone call"),
]

HELD_OUT = [
 ("how do i unlock my iphone with voiceover on", "ref-iphone-everyday-voiceover", "drag one finger up"),
 ("what does the three finger triple tap do", "ref-voiceover-gestures", "Screen Curtain"),
 ("braille command to activate an item", "ref-braille-display", "dots 3-6"),
 ("how to copy text using braille display", "ref-braille-display", "dots 1-4"),
 ("turn speech off from my braille display", "ref-braille-display", "dots 1-3-4"),
 ("how do i change the voiceover speaking rate", "ref-voiceover-silent", "Speaking Rate"),
 ("how do i reset voiceover settings", "ref-voiceover-silent", "Reset VoiceOver Settings"),
 ("airpods max restart", "ref-restart-watch-airpods-tv", "listening mode"),
 ("how do i mute voiceover on my mac", "ref-voiceover-keyboard-mac", "Control"),
 ("how do I open spotlight on mac", "ref-mac-essentials", "Command-Space"),
 ("how do i put my ipad into recovery mode", "ref-restart-iphone-ipad", "recovery"),
 ("dictation command for a new paragraph", "ref-typing-voiceover", "new paragraph"),
 ("how do I take a photo with voiceover", "ref-iphone-everyday-voiceover", "two-finger double-tap"),
 ("can i skip images on web pages", "ref-web-voiceover", "Navigate Images"),
 ("how do i turn off screen curtain", "ref-voiceover-gestures", "three-finger triple-tap"),
 ("how do I use magnifier to find people", "ref-recognition", "people"),
 ("set up apple watch with voiceover", "ref-setup-voiceover", "Digital Crown"),
 ("email apple about accessibility", "ref-getting-help", "accessibility@apple.com"),
 ("what is a perkins keyboard", "ref-glossary", "six or eight keys"),
 ("apple tv voiceover rotor", "ref-voiceover-tv", "two fingers"),
]

# The held-out set was written after tuning, to check the fixes generalize.
TESTS = TESTS + HELD_OUT

fails = []
for q, want, needle in TESTS:
    ts, res = S.search(q)
    top = [a['id'] for v, a in res[:2]]
    got_article = want in top
    got_text = False
    if got_article:
        a = next(a for v, a in res if a['id'] == want)
        tw = set(S.terms(a['title']))
        focused = [t for t in ts if t not in tw] or ts
        got_text = needle.lower() in passage(a, focused).lower()
    ok = got_article and got_text
    print(('PASS' if ok else 'FAIL'), '|', q, '|', 'top2=' + ','.join(top) if not ok else '')
    if not ok:
        fails.append((q, want, needle, top, got_article))
print(f'\n{len(TESTS) - len(fails)}/{len(TESTS)} passed')
for q, want, needle, top, art in fails:
    print(' -', q, '| want', want, '| article found' if art else '| article MISSING', '| needle:', needle)
