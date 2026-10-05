"""Third batch of live AppleVis questions for Ask the Mouse: areas the first
two didn't cover. Run from the repo root:

    python tools/mouse_help_eval/live_site_questions_3.py

Same approach as batch 2: the likely Apple Intelligence search, the no-AI
fallback, and, for app questions, the App Directory search. Light on the
server; don't loop it.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import live_site_questions as L
import live_site_questions_2 as Q2

# (question, plan phrase, content types, optional app search (keyword, platform, category, fully accessible))
QUESTIONS = [
    ("What apps help DeafBlind users with braille?", "DeafBlind braille", ['forum', 'guides'], None),
    ("How do I use Live Listen with my AirPods?", "Live Listen AirPods", ['forum'], None),
    ("Are there accessible watch faces for Apple Watch?", "accessible watch face", ['forum'], None),
    ("What Apple TV apps work well with VoiceOver?", "Apple TV app VoiceOver", ['forum'], ('streaming, video', 'tv', None, True)),
    ("Is Logic Pro accessible for music production?", "Logic Pro VoiceOver", ['forum', 'guides'], None),
    ("How do I find my AirTag with VoiceOver?", "AirTag VoiceOver", ['forum'], None),
    ("Can I set up HomePod as a blind person?", "HomePod setup VoiceOver", ['forum', 'guides'], None),
    ("Which airline apps are accessible?", "airline app accessibility", ['forum'], ('airline, flight', 'ios', 'Travel', False)),
    ("Is the Amazon shopping app accessible?", "Amazon app VoiceOver", ['forum'], None),
    ("Can I learn to code Swift as a blind programmer?", "blind programmer Xcode Swift", ['forum', 'guides'], None),
    ("What are good accessible games for Apple Watch?", "Apple Watch games", ['forum'], ('game, puzzle, trivia', 'watch', None, False)),
    ("Are there recipe or cooking apps that work with VoiceOver?", "cooking recipe app", ['forum'], ('recipe, cooking', 'ios', 'Food and Drink', False)),
    ("How do I submit an app to the AppleVis App Directory?", "submit app AppleVis app directory", ['forum', 'guides'], None),
    ("How do I join the iOS beta safely?", "iOS public beta", ['forum', 'blog2'], None),
    ("My phone keeps reading everything twice", "VoiceOver speaks twice", ['forum'], None),
    ("VoiceOver keeps jumping around in apps", "VoiceOver focus jumping", ['forum', 'ios_bug_report'], None),
    ("Is the Reddit app accessible?", "Reddit app VoiceOver", ['forum'], None),
    ("Which smart home devices work best for blind people?", "smart home accessible", ['forum'], None),
    ("How do I scan documents on my Mac?", "scan documents Mac VoiceOver", ['forum', 'guides'], None),
    ("What podcasts has AppleVis done about the Apple Watch?", "Apple Watch", ['podcast'], None),
]

if __name__ == '__main__':
    for q, plan, kinds, app in QUESTIONS:
        fb = Q2.search_words(q)
        print('\nQ:', q)
        for kind in kinds:
            titles, err = L.site(plan, kind, 5)
            print(f'  plan {kind} "{plan}":', err or ('; '.join(titles) if titles else 'NONE'))
        titles, err = L.site(fb, kinds[0], 5)
        print(f'  fallback {kinds[0]} "{fb}":', err or ('; '.join(titles) if titles else 'NONE'))
        if app:
            kw, platform, cat, full = app
            titles, err = L.apps(kw, platform, cat, full)
            print(f'  apps [{platform}, "{kw}", {cat or "any"}{", fully accessible" if full else ""}]:', err or (', '.join(titles[:8]) if titles else 'NONE'))
