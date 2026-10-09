"""Fourth batch of live AppleVis questions for Ask the Mouse: the App
Directory, every kind of "is there an app for…" question. Run from the repo root:

    python tools/mouse_help_eval/live_site_questions_4.py

Like batch 1, each question carries the plan Apple Intelligence would most
likely make: app keywords, platform, category, and whether only fully
accessible apps were asked for, plus a forum or guide search where members'
experience matters. Category IDs are read from the app's own table in
AppEndpoints.swift, so this tests the same filter the app sends.
Read-only and light on the server (about one request a second); don't loop it.
"""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import live_site_questions as L
import live_site_questions_2 as Q2

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
src = open(os.path.join(ROOT, 'AppleVis', 'Sources', 'Networking', 'Endpoints', 'AppEndpoints.swift'), encoding='utf-8').read()
# The table itself, after "= [": the first "]" is in the type,
# "[String: String]", which left this empty so every category but the six
# above was silently ignored. Fixed 2026-10-09.
table = src[src.find('private static let categoryUUIDs'):]
table = table[table.find('= [') + 3:]
table = table[:table.find(']')]
for name, uuid in re.findall(r'"([^"]+)": "([0-9a-f-]{36})"', table):
    L.CATS[('ios', name)] = uuid

ALIKE = {"1": "one", "2": "two", "3": "three", "4": "four", "5": "five", "phone": "iphone",
         "brail": "braille", "centre": "center", "colour": "color", "colours": "colors"}

def norm(text):
    """AskTheMouse.normalizedForMatching, near enough for app names and descriptions."""
    text = text.lower().replace('voice over', 'voiceover').replace('voice-over', 'voiceover')
    return [ALIKE.get(w, w) for w in re.split(r'[^0-9a-z]+', text) if w]

def plain(html):
    return re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', ' ', html or '')).strip()

def mouse_apps(keyword, platform='ios', category=None, full=False, limit=60):
    """The Mouse's app search and AskTheMouse.rankedApps, as the app now
    runs them: name match first, then the description (the whole body, now
    that a blank Drupal summary falls back to it), then member comments.
    Returns the 15 Apple Intelligence is given, as (title, tier)."""
    saved = L.get
    captured = {}
    def get(path, query):
        query = dict(query, **{'page[limit]': str(limit)})
        r = saved(path, query)
        captured['data'] = r.get('data', [])
        return r
    L.get = get
    in_category = set()
    try:
        # Names only first, then name or description, merged with the
        # name matches ahead, as AppEndpoints.mouseSearch does (2026-10-09).
        L.apps(keyword, platform, None, full, limit, names_only=True)  # any category
        named = captured.get('data', [])
        _, err = L.apps(keyword, platform, category, full, limit)
        in_category = {d['id'] for d in captured.get('data', [])} if category else set()
        seen = {d['id'] for d in named}
        captured['data'] = named + [d for d in captured.get('data', []) if d['id'] not in seen]
    finally:
        L.get = saved
    stems = [w.strip().lower() for w in keyword.split(',') if w.strip()]
    stems = [w[:-1] if w.endswith('s') else w for w in stems]
    def matches(words):
        return any(w in (st, st + 's', st + 'es') for st in stems for w in words)
    rows = []
    for i, d in enumerate(captured.get('data', [])):
        a = d.get('attributes') or {}
        name = a.get('title', '?')
        nw = norm(name)
        body = a.get('body') or {}
        desc = plain(body.get('summary') or body.get('processed') or body.get('value') or '')
        tier = 2 if matches(nw) or any(len(st) >= 5 and st.replace(' ', '') in ''.join(nw) for st in stems) else (1 if matches(norm(desc)) else 0)
        comments = next((v.get('comment_count', 0) for k, v in a.items() if k.startswith('comment_') and isinstance(v, dict)), 0)
        # In the chosen category first among equals, as rankedApps does.
        rows.append((tier, d['id'] in in_category, min(comments or 0, 999), -i, name, desc))
    rows.sort(reverse=True)
    # At most 10 apps named for the keyword in the 15, then the best of the
    # rest, as AskTheMouse.rankedApps does (2026-10-09).
    named = [r for r in rows if r[0] == 2]
    others = [r for r in rows if r[0] < 2]
    lead = named[:10] + others[:15 - len(named[:10])]
    return [(r[4], r[0]) for r in lead], err, len(rows)

# (question, (keywords, platform, category, fully accessible) or None, [(site phrase, kind)], app name or None)
QUESTIONS = [
    # Kids and family
    ("What games are good for keeping kids busy on iOS?", ('kids, children, toddler, family', 'ios', 'Games', False), [('games for kids', 'forum')], None),
    ("Are there accessible games my blind child can play?", ('kids, children', 'ios', 'Games', False), [('blind children games', 'forum')], None),
    ("What educational apps work for blind kids?", ('kids, children, learning', 'ios', 'Education', False), [('blind child education app', 'forum')], None),
    ("Is there an app to teach braille to children?", ('braille', 'ios', 'Education', False), [('teach braille children', 'forum')], None),
    ("Bedtime story apps that work with VoiceOver", ('story, stories, bedtime', 'ios', 'Books', False), None, None),
    # Games
    ("Fully accessible card games like solitaire", ('solitaire, card', 'ios', 'Games', True), None, None),
    ("Are there audio games for iPhone?", ('audio game, audio', 'ios', 'Games', False), [('audio games', 'forum')], None),
    ("Accessible word games like Wordle", ('word, wordle', 'ios', 'Games', False), None, None),
    ("Is there an accessible sudoku?", ('sudoku', 'ios', 'Games', False), None, None),
    ("What trivia games work with VoiceOver?", ('trivia, quiz', 'ios', 'Games', False), None, None),
    ("Accessible poker or blackjack games", ('poker, blackjack, casino', 'ios', 'Games', False), None, None),
    ("Are there accessible dice games?", ('dice, yahtzee', 'ios', 'Games', False), None, None),
    ("Accessible racing or sports games", ('racing, football, soccer, baseball', 'ios', 'Games', False), None, None),
    ("Accessible multiplayer games to play with friends", ('multiplayer, online', 'ios', 'Games', False), [('multiplayer accessible game', 'forum')], None),
    ("Games for Apple TV with VoiceOver", ('game', 'tv', None, False), None, None),
    ("Accessible games for Mac", ('game', 'mac', None, False), None, None),
    # Seeing and identifying
    ("What apps identify money for blind people?", ('money, currency, cash', 'ios', None, False), None, None),
    ("Apps that describe photos for me", ('describe, description, image', 'ios', None, False), [('describe photos app', 'forum')], None),
    ("Is there a color identifier app?", ('color, colour', 'ios', None, False), None, None),
    ("Barcode scanner to identify products", ('barcode, scanner, product', 'ios', None, False), None, None),
    ("Light detector app", ('light detector, light', 'ios', None, False), None, None),
    ("Apps to read printed text", ('ocr, read text, text recognition, document', 'ios', None, False), None, None),
    # Daily living
    ("Which grocery shopping apps are accessible?", ('grocery, groceries, supermarket', 'ios', 'Shopping', False), [('grocery app accessible', 'forum')], None),
    ("Accessible food delivery apps", ('delivery, food', 'ios', 'Food and Drink', False), None, None),
    ("Accessible pill reminder or medication app", ('medication, pill, medicine', 'ios', 'Medical', False), None, None),
    ("Recipe apps for blind cooks", ('recipe, cooking', 'ios', 'Food and Drink', False), None, None),
    ("Accessible smart home apps", ('smart home, home', 'ios', None, False), None, None),
    ("Accessible dating apps", ('dating', 'ios', 'Lifestyle', False), [('dating app accessible', 'forum')], None),
    ("Accessible religious apps like a Bible app", ('bible, prayer, quran', 'ios', None, False), None, None),
    # Money
    ("Fully accessible banking app", ('bank, banking', 'ios', 'Finance', True), None, None),
    ("Accessible budget apps", ('budget, budgeting, money', 'ios', 'Finance', False), None, None),
    ("Accessible apps for investing or stocks", ('stocks, investing, invest', 'ios', 'Finance', False), None, None),
    # Productivity
    ("Is there an accessible calendar app better than Apple's?", ('calendar', 'ios', 'Productivity', False), None, None),
    ("Accessible to-do list apps", ('task, to-do, todo, reminders', 'ios', 'Productivity', False), None, None),
    ("Accessible password manager", ('password', 'ios', None, False), None, None),
    ("Accessible VPN app", ('vpn', 'ios', None, False), None, None),
    ("Accessible document scanner", ('scanner, scan, document', 'ios', 'Business', False), None, None),
    # Travel and getting around
    ("Accessible bus and train apps", ('transit, bus, train', 'ios', 'Navigation', False), None, None),
    ("Accessible taxi or ride-share apps", ('ride, taxi, rideshare', 'ios', 'Travel', False), None, None),
    ("Apps to help me cross the street", ('crossing, intersection, street', 'ios', 'Navigation', False), [('crossing street app', 'forum')], None),
    ("Indoor navigation apps for blind people", ('indoor, navigation', 'ios', 'Navigation', False), None, None),
    # Health and fitness
    ("Fitness apps for blind runners", ('running, run, workout', 'ios', 'Health and Fitness', False), None, None),
    ("Meditation apps that work with VoiceOver", ('meditation, mindfulness, sleep', 'ios', 'Health and Fitness', False), None, None),
    ("Accessible Apple Watch weather apps", ('weather', 'watch', None, False), None, None),
    ("Accessible Apple Watch timer or alarm apps", ('timer, alarm', 'watch', None, False), None, None),
    # Reading, news, and media
    ("Accessible audiobook apps", ('audiobook, audiobooks, audio book', 'ios', 'Books', False), None, None),
    ("Accessible news apps", ('news', 'ios', 'News', False), None, None),
    ("A podcast player that's accessible, other than Apple Podcasts", ('podcast, podcasts', 'ios', None, False), None, None),
    ("Accessible music streaming apps", ('music, streaming', 'ios', 'Music', False), None, None),
    ("Accessible Mastodon apps", ('mastodon', 'ios', 'Social Networking', False), None, None),
    ("Accessible apps for learning a language", ('language, learn', 'ios', 'Education', False), None, None),
    ("Accessible dictionary or translation app", ('dictionary, translate, translation', 'ios', 'Reference', False), None, None),
    ("Accessible radio apps", ('radio', 'ios', 'Music', False), None, None),
    # Mac
    ("Accessible podcast recording software for Mac", ('podcast, recording, audio', 'mac', None, False), None, None),
    ("Fully accessible Mac utilities", ('utility, utilities', 'mac', None, True), None, None),
    # Named apps
    ("Is Duolingo accessible?", None, [('Duolingo VoiceOver', 'forum')], 'Duolingo'),
    ("Is Audible accessible with VoiceOver?", None, [('Audible VoiceOver', 'forum')], 'Audible'),
    ("Does Zoom work with VoiceOver?", None, [('Zoom VoiceOver', 'forum')], 'Zoom'),
    ("Is DoorDash accessible?", None, [('DoorDash VoiceOver', 'forum')], 'DoorDash'),
    ("Is PayPal accessible?", None, [('PayPal VoiceOver', 'forum')], 'PayPal'),
    ("How accessible is Google Maps?", None, [('Google Maps VoiceOver', 'forum')], 'Google Maps'),
    ("Is Aira worth it?", None, [('Aira', 'forum')], 'Aira'),
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
