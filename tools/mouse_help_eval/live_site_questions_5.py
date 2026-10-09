"""Fifth batch of live AppleVis questions for Ask the Mouse (2026-10-09):
more App Directory questions of kinds batch 4 didn't cover, and more named
apps. Run from the repo root:

    python tools/mouse_help_eval/live_site_questions_5.py

Same plan format and ranking as batch 4 (live_site_questions_4.py), so the
15 apps printed are the ones Apple Intelligence would be given.
Read-only and light on the server (about one request a second); don't loop it.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import live_site_questions as L
import live_site_questions_2 as Q2
from live_site_questions_4 import mouse_apps

# (question, (keywords, platform, category, fully accessible) or None, [(site phrase, kind)], app name or None)
QUESTIONS = [
    # Money and shopping
    ("Accessible banking apps", ('bank, banking', 'ios', 'Finance', False), [('accessible banking app', 'forum')], None),
    ("Is there an app that identifies money?", ('money, currency, bill, banknote', 'ios', None, False), None, None),
    ("Accessible budgeting apps", ('budget, expense, spending', 'ios', 'Finance', False), None, None),
    ("Accessible grocery delivery apps", ('grocery, groceries, delivery', 'ios', 'Shopping', False), None, None),
    ("A barcode scanner that tells me what a product is", ('barcode, scanner, product', 'ios', None, False), None, None),
    # Seeing and daily living
    ("An app that tells me what color my clothes are", ('color, colour, identifier', 'ios', None, False), None, None),
    ("Is there a light detector app?", ('light, detector', 'ios', 'Utilities', False), None, None),
    ("Apps that read my mail and letters", ('ocr, scan, document, read', 'ios', 'Productivity', False), None, None),
    ("Accessible medication reminder apps", ('medication, pill, medicine, reminder', 'ios', 'Medical', False), None, None),
    ("Accessible recipe apps", ('recipe, recipes, cooking', 'ios', 'Food and Drink', False), None, None),
    ("Smart home apps that work with VoiceOver", ('smart home, home, homekit', 'ios', 'Lifestyle', False), None, None),
    # Getting around
    ("Accessible public transit apps", ('transit, bus, train, subway', 'ios', 'Navigation', False), [('transit app VoiceOver', 'forum')], None),
    ("Indoor navigation apps for blind people", ('indoor, navigation', 'ios', 'Navigation', False), None, None),
    ("Accessible ride sharing apps", ('ride, taxi, rideshare', 'ios', 'Travel', False), None, None),
    # Health and fitness
    ("Accessible workout apps", ('workout, fitness, exercise', 'ios', 'Health and Fitness', False), None, None),
    ("Accessible meditation apps", ('meditation, mindfulness, sleep', 'ios', 'Health and Fitness', False), None, None),
    ("Accessible running apps", ('running, run', 'ios', 'Health and Fitness', False), None, None),
    # Work and study
    ("Accessible note taking apps", ('notes, note', 'ios', 'Productivity', False), None, None),
    ("Accessible calendar apps", ('calendar, schedule', 'ios', 'Productivity', False), None, None),
    ("Accessible email apps other than Mail", ('email, mail', 'ios', 'Productivity', False), None, None),
    ("Accessible password managers", ('password', 'ios', 'Utilities', False), None, None),
    ("Accessible math apps for students", ('math, calculator', 'ios', 'Education', False), None, None),
    ("Accessible word processors", ('word processor, writing, document', 'ios', 'Productivity', False), None, None),
    # Music and audio
    ("Accessible apps for making music", ('music, synth, recording, piano', 'ios', 'Music', False), None, None),
    ("A guitar tuner that works with VoiceOver", ('tuner, guitar', 'ios', 'Music', False), None, None),
    ("Accessible bird song identification apps", ('bird, birds, birdsong', 'ios', None, False), None, None),
    # Games
    ("Accessible chess apps", ('chess', 'ios', 'Games', False), None, None),
    ("Accessible crossword apps", ('crossword', 'ios', 'Games', False), None, None),
    ("Accessible board games like Monopoly", ('board, monopoly', 'ios', 'Games', False), None, None),
    ("Fully accessible puzzle games", ('puzzle', 'ios', 'Games', True), None, None),
    # Other devices
    ("Accessible Apple Watch fitness apps", ('fitness, workout', 'watch', 'Health and Fitness', False), None, None),
    ("Fully accessible Apple TV apps", ('tv', 'tv', None, True), None, None),
    ("Accessible audio editors for Mac", ('audio, editor, recording', 'mac', None, False), None, None),
    ("Mac apps for reading ebooks", ('ebook, books, reader', 'mac', None, False), None, None),
    # Named apps
    ("Is Uber accessible?", None, [('Uber VoiceOver', 'forum')], 'Uber'),
    ("Is Seeing AI any good?", None, [('Seeing AI', 'forum')], 'Seeing AI'),
    ("Is the Libby app accessible?", None, [('Libby VoiceOver', 'forum')], 'Libby'),
    ("Does Microsoft Teams work with VoiceOver?", None, [('Teams VoiceOver', 'forum')], 'Microsoft Teams'),
    ("Is Kindle accessible?", None, [('Kindle VoiceOver', 'forum')], 'Kindle'),
    ("Is Instacart accessible?", None, [('Instacart VoiceOver', 'forum')], 'Instacart'),
]

if __name__ == '__main__':
    for q, app, sites, name in QUESTIONS:
        print('\nQ:', q)
        if app:
            kw, platform, cat, full = app
            top, err, found = mouse_apps(kw, platform, cat, full)
            label = {2: 'name', 1: 'desc', 0: 'none'}
            print(f'  Apps [{platform}, "{kw}", {cat or "any category"}{", fully accessible" if full else ""}] {found} found, given to the model:',
                  err or ('; '.join(f'{t} ({label[tier]})' for t, tier in top) if top else 'NONE'))
        for phrase, kind in sites or []:
            titles, err = L.site(phrase, kind, 5)
            print(f'  {kind} "{phrase}":', err or ('; '.join(titles) if titles else 'NONE'))
        if name:
            titles, err = Q2.app_by_name(name)
            print(f'  app "{name}":', err or (', '.join(titles) if titles else 'NONE'))
