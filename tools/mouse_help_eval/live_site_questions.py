"""Live check of Ask the Mouse's website searches for everyday AppleVis
questions. Run from the repo root:

    python tools/mouse_help_eval/live_site_questions.py

Apple Intelligence can't run here, so each question carries the plan it
would most likely produce (search phrases, app keywords, category,
platform). This runs the same requests the app makes against the live
site and prints what comes back, so a person can judge whether the right
guides, topics, and apps are found. It's light on the server: one or two
small requests per question, spaced a second apart. Don't run it in a loop.
"""
import json, os, re, sys, time, urllib.parse, urllib.request

sys.stdout.reconfigure(encoding='utf-8')
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
BASE = 'https://www.applevis.com/jsonapi/'

# The app's own request headers. The auth value is read from the source,
# never printed or stored.
bypass = open(os.path.join(ROOT, 'AppleVis', 'Sources', 'Networking', 'CloudflareBypass.swift'), encoding='utf-8').read() \
    if os.path.exists(os.path.join(ROOT, 'AppleVis', 'Sources', 'Networking', 'CloudflareBypass.swift')) else ''
if not bypass:
    for dirpath, _, files in os.walk(os.path.join(ROOT, 'AppleVis', 'Sources')):
        if 'CloudflareBypass.swift' in files:
            bypass = open(os.path.join(dirpath, 'CloudflareBypass.swift'), encoding='utf-8').read()
AUTH = re.search(r'"([0-9a-f]{20})"', bypass).group(1)
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 AppleVis/2026',
    'Accept-Language': 'en-US,en;q=0.9', 'Origin': 'https://www.applevis.com', 'Referer': 'https://www.applevis.com/',
    'X-App-Auth': AUTH, 'Accept': 'application/vnd.api+json',
}

def get(path, query):
    url = BASE + path + '?' + urllib.parse.urlencode(query)
    req = urllib.request.Request(url, headers=HEADERS)
    time.sleep(1)
    try:
        return json.loads(urllib.request.urlopen(req, timeout=30).read().decode('utf-8'))
    except Exception as e:
        return {'error': str(e), 'data': []}

def site(phrase, kind, limit=6):
    r = get('index/solr_site_index', {'filter[fulltext]': phrase, 'filter[type]': kind, 'page[limit]': str(limit)})
    return [(d.get('attributes') or {}).get('title', '?') for d in r.get('data', [])], r.get('error')

CATS = {
    ('ios', 'Games'): 'a63cc23a-836a-4068-8f23-b3afbf5b994e', ('ios', 'Weather'): '5df92429-93bc-4d33-a882-a303b899959e',
    ('ios', 'Navigation'): '551ed39e-0816-40b5-8c5b-fb9c700eaf9e', ('ios', 'Productivity'): 'cc18cc76-e08e-4037-a3bf-064f5f5b696f',
    ('ios', 'Travel'): '17c20229-4532-4e40-8853-88da8d9a8c46', ('ios', 'Food and Drink'): 'b1a99efd-7626-4fb5-bfe4-1c14ad0947f2',
    ('mac', 'Music'): '6ad779ec-afa4-4893-928b-f9257d885142', ('watch', 'Health and Fitness'): 'b00897e2-a715-494a-903b-1f072ce919af',
}
BUNDLE = {'ios': 'ios_app_directory', 'mac': 'mac_app_directory', 'watch': 'watch_directory', 'tv': 'tv_directory'}
FULL = {'ios': ('field_voiceover', '=', 'VoiceOver reads all page elements.'), 'mac': ('field_usability', 'STARTS_WITH', 'The app is fully accessible'),
        'watch': ('field_usability_watch', '=', 'Fully Accessible'), 'tv': ('field_usability_tv', '=', 'Fully Accessible')}

def apps(keyword, platform='ios', category=None, full=False, limit=40):
    q = {'sort': '-changed', 'page[limit]': str(limit)}
    words = [w.strip() for w in keyword.split(',') if w.strip()]
    keep = {'rpg', 'gps', 'ocr', 'pdf', 'vpn', 'mmo', 'rss', 'sms', 'tts'}  # AppEndpoints.shortKeywordsKept
    if any(len(w) >= 4 for w in words):
        words = [w for w in words if len(w) >= 4 or w.lower() in keep]
    if words:
        q['filter[words][group][conjunction]'] = 'OR'
        for i, w in enumerate(words[:4]):
            for field, path in (('title', 'title'), ('body', 'body.value')):
                q[f'filter[{field}{i}][condition][path]'] = path
                q[f'filter[{field}{i}][condition][operator]'] = 'CONTAINS'
                q[f'filter[{field}{i}][condition][value]'] = w
                q[f'filter[{field}{i}][condition][memberOf]'] = 'words'
    if full:
        path, op, val = FULL[platform]
        q['filter[va][condition][path]'] = path
        if op != '=':
            q['filter[va][condition][operator]'] = op
        q['filter[va][condition][value]'] = val
    if category and (platform, category) in CATS:
        field = {'ios': 'taxonomy_vocabulary_1', 'mac': 'taxonomy_vocabulary_16', 'watch': 'field_category_watch', 'tv': 'field_category_tv'}[platform]
        q['filter[cat][condition][path]'] = field + '.id'
        q['filter[cat][condition][value]'] = CATS[(platform, category)]
    r = get('node/' + BUNDLE[platform], q)
    titles = [(d.get('attributes') or {}).get('title', '?') for d in r.get('data', [])]
    # Same ordering idea as AskTheMouse.rankedApps: keyword in the name first.
    stems = [w.lower()[:-1] if w.lower().endswith('s') else w.lower() for w in words]
    def whole(t):
        ws = re.split(r'[^0-9a-z]+', t.lower())
        return any(x in (st, st + 's', st + 'es') for st in stems for x in ws) or any(len(st) >= 5 and st in ''.join(ws) for st in stems)
    named = [t for t in titles if whole(t)]
    return named + [t for t in titles if t not in named], r.get('error')

# (question, plan the Mouse would likely make)
QUESTIONS = [
    ("What are the most popular RPG games for iOS?", dict(apps=('rpg, role playing, adventure', 'ios', 'Games', False))),
    ("Is the SiriusXM app accessible?", dict(apps=('sirius', 'ios', None, False), site=[('siriusxm', 'forum')])),
    ("Recommend a fully accessible weather app", dict(apps=('weather', 'ios', 'Weather', True))),
    ("What's the best GPS app for blind people?", dict(apps=('navigation, gps', 'ios', 'Navigation', False), site=[('GPS navigation app', 'forum')])),
    ("Is there an accessible chess game?", dict(apps=('chess', 'ios', 'Games', False))),
    ("What app can read my mail with OCR?", dict(apps=('ocr, read text, text recognition', 'ios', None, False), site=[('OCR read print mail', 'forum')])),
    ("Fully accessible audio editors for Mac", dict(apps=('audio editor, audio editing, recording', 'mac', None, True))),
    ("Apple Watch fitness apps that work with VoiceOver", dict(apps=('fitness, workout', 'watch', 'Health and Fitness', False))),
    ("How do I use Microsoft Word with VoiceOver on Mac?", dict(site=[('Microsoft Word VoiceOver Mac', 'guides'), ('Microsoft Word VoiceOver Mac', 'forum')])),
    ("What do people think of Be My Eyes?", dict(site=[('Be My Eyes', 'forum'), ('Be My Eyes', 'blog2')])),
    ("How do I use Instagram with VoiceOver?", dict(site=[('Instagram VoiceOver', 'guides'), ('Instagram VoiceOver', 'forum')])),
    ("What accessibility bugs are in iOS 26?", dict(site=[('iOS 26 accessibility bugs', 'blog2'), ('iOS 26', 'ios_bug_report')])),
    ("Who won the Golden Apples?", dict(site=[('Golden Apples', 'blog2')])),
    ("How do I read Kindle books with VoiceOver?", dict(site=[('Kindle VoiceOver', 'guides'), ('Kindle books VoiceOver', 'forum')])),
    ("Is there a podcast about the iPhone camera for blind people?", dict(site=[('camera', 'podcast')])),
    ("How do I set up a braille display with my iPhone?", dict(site=[('braille display iPhone', 'guides')])),
    ("Any tips for using Uber with VoiceOver?", dict(site=[('Uber VoiceOver', 'forum'), ('Uber', 'guides')])),
    ("What's the best accessible email app for iPhone?", dict(apps=('email, mail', 'ios', 'Productivity', False), site=[('email app', 'forum')])),
]

if __name__ == '__main__':
    for question, plan in QUESTIONS:
        print('\nQ:', question)
        if 'apps' in plan:
            kw, platform, cat, full = plan['apps']
            titles, err = apps(kw, platform, cat, full)
            print(f'  Apps [{platform}, "{kw}", {cat or "any category"}{", fully accessible" if full else ""}]:',
                  err or (', '.join(titles[:8]) if titles else 'NONE'))
        for phrase, kind in plan.get('site', []):
            titles, err = site(phrase, kind)
            print(f'  {kind} "{phrase}":', err or ('; '.join(titles[:5]) if titles else 'NONE'))
