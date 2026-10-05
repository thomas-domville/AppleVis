"""Second batch of live AppleVis questions for Ask the Mouse. Run from the repo root:

    python tools/mouse_help_eval/live_site_questions_2.py

Each question is searched twice:
  plan     - the search phrase Apple Intelligence would most likely choose.
  fallback - what the Mouse sends with no Apple Intelligence: the question's
             first six meaningful words (AskTheMouse.searchWords).
Light on the server: two or three small requests per question, a second apart.
"""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import live_site_questions as L

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
mk = open(os.path.join(ROOT, 'AppleVis', 'Sources', 'Services', 'MouseKnowledge.swift'), encoding='utf-8').read()
start = mk.find('stopWords: Set<String> = [')
STOP = set(re.findall(r'"([^"]+)"', mk[start:mk.find(']', start)]))

def search_words(q):
    out, seen = [], set()
    for w in re.split(r"[^0-9a-z']+", q.lower()):
        w = w.strip("'")
        if len(w) >= 2 and w not in STOP and w not in seen:
            seen.add(w); out.append(w)
    return ' '.join(out[:6]) or q[:60]

# (question, plan phrase, content types to search, optional app name to look up)
QUESTIONS = [
    ("Is Netflix accessible with VoiceOver?", "Netflix VoiceOver", ['forum'], 'Netflix'),
    ("How accessible is WhatsApp on iPhone?", "WhatsApp accessibility", ['forum'], 'WhatsApp'),
    ("Does Spotify work well with VoiceOver?", "Spotify VoiceOver", ['forum'], 'Spotify'),
    ("Which banking apps are accessible?", "accessible banking app", ['forum'], None),
    ("How do I use CarPlay with VoiceOver?", "CarPlay VoiceOver", ['forum', 'guides'], None),
    ("What's the best braille display to buy?", "best braille display", ['forum'], None),
    ("Are the Meta Ray-Ban glasses good for blind people?", "Meta Ray-Ban glasses", ['forum', 'podcast'], None),
    ("Should I switch from Android to iPhone?", "switch from Android to iPhone", ['forum'], None),
    ("What's the latest AppleVis podcast?", "AppleVis podcast", ['podcast'], None),
    ("Where's the AppleVis report on iOS 27?", "iOS 27 VoiceOver braille issues", ['blog2'], None),
    ("Are there VoiceOver bugs in macOS 27?", "macOS 27 VoiceOver bug", ['os_x_bug_report', 'blog2'], None),
    ("How do I learn VoiceOver on my Mac as a beginner?", "beginner guide macOS VoiceOver", ['guides'], None),
    ("How do I use Apple Pay with VoiceOver?", "Apple Pay VoiceOver", ['forum', 'guides'], None),
    ("How can I play audio games on iPhone?", "audio games iPhone", ['forum', 'guides'], None),
    ("How do I edit podcasts in GarageBand with VoiceOver?", "GarageBand VoiceOver editing", ['forum', 'guides'], None),
    ("Any recommendations for an accessible note taking app?", "accessible note taking app", ['forum'], None),
    ("How do I use Seeing AI?", "Seeing AI", ['forum', 'podcast'], 'Seeing AI'),
    ("What's the best way to read PDFs with VoiceOver?", "PDF VoiceOver", ['forum', 'guides'], None),
    ("How do I get my iPhone to read my emails out loud?", "read email aloud", ['forum'], None),
    ("Is Microsoft Teams accessible on iPhone?", "Microsoft Teams accessibility", ['forum'], 'Microsoft Teams'),
]

def app_by_name(name):
    r = L.get('node/ios_app_directory', {'sort': '-changed', 'page[limit]': '5',
              'filter[title][condition][path]': 'title', 'filter[title][condition][operator]': 'CONTAINS',
              'filter[title][condition][value]': name})
    return [(d.get('attributes') or {}).get('title', '?') for d in r.get('data', [])], r.get('error')

if __name__ == '__main__':
    for q, plan, kinds, app in QUESTIONS:
        fb = search_words(q)
        print('\nQ:', q)
        for kind in kinds:
            titles, err = L.site(plan, kind, 5)
            print(f'  plan {kind} "{plan}":', err or ('; '.join(titles) if titles else 'NONE'))
        titles, err = L.site(fb, kinds[0], 5)
        print(f'  fallback {kinds[0]} "{fb}":', err or ('; '.join(titles) if titles else 'NONE'))
        if app:
            titles, err = app_by_name(app)
            print(f'  app "{app}":', err or (', '.join(titles) if titles else 'NONE'))
