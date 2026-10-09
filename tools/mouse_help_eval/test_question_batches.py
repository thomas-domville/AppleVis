"""Run from the repo root: python tools/mouse_help_eval/test_question_batches.py

Batches of everyday questions, written 2026-10-09 to find gaps, that Help
must answer: devices (A), the AppleVis app (B), the AppleVis site and
community (C), and odd wordings with typos, follow-ups, and traps (E). Each must put one of the acceptable articles in the Mouse's
top two Help sources, with a checked quick-reference article pinned first
the way AskTheMouse does. Off-topic questions aren't here: Apple
Intelligence's plan turns those away before Help is searched."""
import io, contextlib, os, sys
sys.argv = [sys.argv[0]]
sys.stdout.reconfigure(encoding='utf-8')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
with contextlib.redirect_stdout(io.TextIOWrapper(io.BytesIO(), encoding='utf-8')):
    import sim_help as S
    import quick_reference as Q
    from test_howto_questions import refers_back

# (question, acceptable article ids)
A = [  # devices
    ("How do I turn on VoiceOver on my iPad?", ["ref-accessibility-shortcut", "ref-setup-voiceover", "guide-ipad"]),
    ("How do I take a screenshot with VoiceOver?", ["howto-screenshot"]),
    ("How do I record my screen?", ["howto-screen-recording"]),
    ("My AirPods won't connect", ["howto-bluetooth-trouble", "ref-restart-watch-airpods-tv", "howto-know-airpods"]),
    ("How do I pair a Bluetooth keyboard?", ["howto-bluetooth-pair", "howto-hardware-keyboard"]),
    ("How do I forget a Wi-Fi network?", ["howto-wifi-forget"]),
    ("How do I share my Wi-Fi password with a friend?", ["howto-wifi-share"]),
    ("How do I see my Wi-Fi password?", ["howto-wifi-see-password"]),
    ("How do I turn on Low Power Mode?", ["howto-low-power"]),
    ("What's using my battery?", ["howto-battery-usage"]),
    ("How do I free up storage on my iPhone?", ["howto-storage"]),
    ("How do I update iOS?", ["howto-update-ios", "ref-updating"]),
    ("How do I back up my iPhone to iCloud?", ["howto-backup", "ref-updating"]),
    ("How do I set up a new iPhone from my old one?", ["howto-new-iphone", "ref-setup-voiceover"]),
    ("How do I change my passcode?", ["howto-passcode"]),
    ("What is Stolen Device Protection?", ["howto-stolen-device"]),
    ("How do I stop an app from using my location?", ["howto-app-permissions"]),
    ("How do I find my lost AirPods?", ["howto-find-my"]),
    ("How do I set an alarm with VoiceOver?", ["howto-alarm"]),
    ("How do I block a phone number?", ["howto-block-number"]),
    ("How do I silence unknown callers?", ["howto-unknown-callers"]),
    ("How do I listen to my voicemail?", ["howto-voicemail"]),
    ("How do I call emergency services?", ["howto-sos", "howto-emergency"]),
    ("How do I send an audio message?", ["howto-audio-message"]),
    ("How do I schedule a text message?", ["howto-message-later"]),
    ("How do I turn on Do Not Disturb?", ["howto-focus"]),
    ("How do I stop notifications from one app?", ["howto-notifications-app"]),
    ("How do I have Siri read my notifications?", ["howto-announce-notifications"]),
    ("How do I change my ringtone?", ["howto-ringtone"]),
    ("How do I put my iPhone on vibrate?", ["howto-silent-mode"]),
    ("How do I use Apple Pay with VoiceOver?", ["howto-apple-pay"]),
    ("How do I make a shortcut?", ["howto-shortcut"]),
    ("How do I use SharePlay?", ["howto-shareplay"]),
    ("How do I set screen time limits?", ["howto-screen-time"]),
    ("How do I add a widget?", ["howto-home-widget"]),
    ("How do I delete an app?", ["howto-home-delete", "howto-home-remove"]),
    ("How do I move apps to the Dock?", ["howto-home-dock"]),
    ("How do I set up the Action button?", ["howto-home-action-button", "howto-know-action-button"]),
    ("How do I add controls to Control Center?", ["howto-home-control-center"]),
    ("How do I customize my Lock Screen?", ["howto-home-lock-screen"]),
    ("How do I use eSIM?", ["howto-esim"]),
    ("How do I connect to a VPN?", ["howto-vpn"]),
    ("How do I use my iPhone as a hotspot?", ["howto-hotspot"]),
    ("How do I turn on airplane mode?", ["howto-airplane-mode"]),
    ("How do I stream to my Apple TV?", ["howto-airplay"]),
    ("How do I use the Apple TV remote with VoiceOver?", ["ref-voiceover-tv", "howto-know-tv-remote", "howto-tv-voiceover"]),
    ("How do I turn on VoiceOver on my Apple Watch?", ["howto-watch-voiceover", "ref-voiceover-watch"]),
    ("What is the Digital Crown?", ["howto-know-watch"]),
    ("How do I use the AirPods controls?", ["howto-airpods-controls", "howto-know-airpods"]),
    ("How do I use the iPad's menu bar?", ["howto-ipad-menu"]),
    ("How do I use Magnifier on my Mac?", ["howto-mac-magnifier"]),
    ("How do I turn on two-factor authentication?", ["howto-two-factor"]),
    ("How do I sign out of my Apple Account?", ["howto-apple-account-sign-out"]),
    ("How do I use Writing Tools to proofread?", ["howto-writing-tools"]),
    ("How do I turn on Apple Intelligence?", ["howto-apple-intelligence-on", "smart-apple-intelligence"]),
    ("How do I change how Siri responds?", ["howto-siri-settings"]),
    ("How do I add text replacement shortcuts?", ["howto-text-replacement"]),
    ("Autocorrect keeps changing my words", ["howto-autocorrect"]),
    ("How do I use a hardware keyboard with my iPhone?", ["howto-hardware-keyboard", "ref-voiceover-keyboard-ios"]),
    ("How do I make VoiceOver say less?", ["howto-vo-verbosity", "howto-vo-hints"]),
    ("How do I add items to the rotor?", ["howto-vo-rotor-items"]),
    ("How do I label a button VoiceOver doesn't read?", ["howto-vo-label"]),
    ("How do I copy the last thing VoiceOver said?", ["howto-vo-copy-speech"]),
    ("How do I use VoiceOver activities?", ["howto-vo-activities"]),
    ("How do I turn off audio ducking?", ["howto-vo-audio-ducking"]),
    ("How do I teach VoiceOver to pronounce a word?", ["howto-vo-pronunciations"]),
    ("How do I use the item chooser?", ["howto-vo-item-chooser", "ref-voiceover-gestures"]),
    ("How do I change the braille table?", ["howto-braille-tables"]),
    ("How do I turn off the braille cursor?", ["howto-braille-cursor"]),
    ("How do I use Nemeth code?", ["howto-braille-nemeth"]),
    ("My braille display keeps disconnecting", ["howto-braille-trouble"]),
    ("What are the holes on the bottom of my iPhone?", ["howto-know-bottom-edge"]),
    ("Which iPhone do I have?", ["howto-know-which-iphone"]),
    ("Where is the SIM tray?", ["howto-know-sim"]),
    ("How do I use Voice Control?", ["howto-voice-control"]),
    ("How do I use Switch Control?", ["howto-switch-control"]),
    ("How do I use Live Listen?", ["howto-live-listen"]),
    ("How do I pair hearing aids?", ["howto-hearing-devices"]),
    ("How do I get a hearing test with AirPods?", ["howto-airpods-hearing"]),
]
B = [  # the AppleVis app
    ("How do I see what's new on AppleVis?", ["howto-app-see-new", "home-whats-new"]),
    ("What is Fetch?", ["home-fetch", "howto-app-fetch"]),
    ("How do I have Goldie read everything to me?", ["howto-app-listen-fetch", "home-fetch"]),
    ("What are Nibbles?", ["howto-app-nibbles", "home-whats-new"]),
    ("How do I mark everything as read?", ["howto-app-mark-read", "tutorial-save-follow"]),
    ("How do I pick up where I left off?", ["howto-app-left-off"]),
    ("How do I jump to the first new comment?", ["howto-app-first-new-comment"]),
    ("How do I post a new forum topic?", ["howto-app-new-topic", "tutorial-post"]),
    ("How do I reply to a comment?", ["howto-app-reply", "tutorial-post"]),
    ("Can AppleVis summarize a long thread?", ["howto-app-summarize", "smart-reading-writing"]),
    ("How do I follow a topic?", ["howto-app-follow", "tutorial-save-follow"]),
    ("How do I get notified when someone replies?", ["howto-app-replies-notify", "settings-notifications"]),
    ("How do I send a private message to a member?", ["howto-app-message"]),
    ("How do I save a post for later?", ["howto-app-save", "tutorial-save-follow"]),
    ("Where are my saved items?", ["howto-app-find-saved", "foryou-overview"]),
    ("How do I recommend an app?", ["howto-app-recommend", "tutorial-save-follow"]),
    ("What are Community Picks?", ["discover-community-picks", "howto-app-community-picks"]),
    ("How do I play a podcast episode?", ["howto-app-play-episode", "tutorial-podcast"]),
    ("How do I download an episode to listen offline?", ["howto-app-download-episode", "tutorial-podcast"]),
    ("How do I add an episode to my queue?", ["howto-app-queue", "tutorial-podcast"]),
    ("How do I set a sleep timer?", ["howto-app-sleep-timer", "content-podcasts"]),
    ("Does the podcast have transcripts?", ["howto-app-transcript", "content-podcasts"]),
    ("How do I skip to a chapter?", ["howto-app-chapters", "content-podcasts"]),
    ("How do I search AppleVis?", ["howto-app-search", "search-overview"]),
    ("How do I report a bug in the AppleVis app?", ["howto-app-contact", "trouble-contact", "settings-support"]),
    ("How do I change my AppleVis password?", ["howto-app-change-password"]),
    ("How do I change my email address on AppleVis?", ["howto-app-change-email"]),
    ("How do I delete my AppleVis account?", ["howto-app-delete-account"]),
    ("How do I read AppleVis in Spanish?", ["howto-app-own-language", "community-writing-tools"]),
    ("Do my saved items sync to my iPad?", ["howto-app-sync", "settings-privacy-sync"]),
    ("How much space is AppleVis using?", ["howto-app-free-space", "settings-storage-cache"]),
    ("How do I turn off Apple Intelligence features in AppleVis?", ["howto-app-ai-off", "smart-apple-intelligence"]),
    ("How do I turn off the tips?", ["howto-app-tips", "settings-general"]),
    ("What can I ask Siri to do in AppleVis?", ["howto-app-siri", "smart-siri-widgets"]),
    ("What are the AppleVis keyboard shortcuts?", ["howto-app-keyboard", "ref-applevis-keyboard"]),
    ("How do I change the theme?", ["howto-av-theme", "settings-appearance"]),
    ("How do I turn off the sounds in AppleVis?", ["howto-av-sounds", "settings-sounds-haptics"]),
    ("How do I stop the welcome message?", ["howto-av-welcome", "settings-general"]),
    ("How do I make links open in Safari?", ["howto-av-web-links", "settings-general"]),
    ("How do I sign out of AppleVis?", ["howto-av-sign-out", "start-sign-in"]),
    ("How do I edit a comment I posted?", ["community-edit-post"]),
    ("How do I delete my post?", ["community-delete-post"]),
    ("How do I report a comment?", ["community-report-comment"]),
    ("How do I edit my profile?", ["community-edit-profile"]),
    ("Why are some words masked with stars?", ["community-language-filter"]),
    ("How do I replay the Welcome Tour?", ["tutorial-replay-welcome-tour"]),
    ("What's new in this version of AppleVis?", ["start-whats-new", "howto-app-version"]),
    ("How do I use AppleVis on my iPad side by side?", ["start-ipad-duo"]),
    ("How do I share a topic?", ["howto-app-share", "smart-share"]),
    ("How do I add an app from the App Store share sheet?", ["smart-share", "community-submit-app"]),
]
C = [  # the AppleVis site and community
    ("Who runs AppleVis?", ["start-what-is-applevis"]),
    ("Is AppleVis owned by Be My Eyes?", ["start-what-is-applevis"]),
    ("How is AppleVis funded?", ["start-what-is-applevis"]),
    ("How do I donate to AppleVis?", ["start-what-is-applevis", "start-tabs"]),
    ("How do I submit an app to the App Directory?", ["community-submit-app", "howto-app-contribute"]),
    ("How do I submit a blog post?", ["community-submit-blog"]),
    ("How do I submit a podcast?", ["community-submit-podcast"]),
    ("How do I report an accessibility bug?", ["community-submit-bug", "tutorial-bug-tracker"]),
    ("Are app submissions reviewed before they go live?", ["community-submit-app"]),
    ("What are the community guidelines?", ["community-guidelines"]),
    ("What does the Bug Tracker show?", ["content-bugs", "discover-bug-tracker", "tutorial-bug-tracker"]),
    ("What do the accessibility ratings in the App Directory mean?", ["content-apps"]),
    ("What are the Golden Apples?", ["ref-glossary", "content-apps", "smart-ask-the-mouse"]),
    ("How do I follow AppleVis with RSS?", ["discover-rss-feeds"]),
    ("Where are the AppleVis guides?", ["content-blog-guides", "discover-overview"]),
    ("How do I contact the AppleVis team?", ["trouble-contact", "settings-support", "howto-app-contact"]),
    ("What is Be My Eyes?", ["discover-be-my-eyes", "howto-app-be-my-eyes"]),
    ("Do I need an account to read AppleVis?", ["start-sign-in", "start-what-is-applevis", "start-faq"]),
    ("I can't sign in to AppleVis", ["trouble-sign-in"]),
    ("My post didn't go through", ["trouble-posting"]),
]


# E (2026-10-09): odd wordings: typos, dictation slips, vague and rambling
# questions, two questions in one, follow-ups, and traps that must not get
# a checked gesture or command answer.
# (question, earlier question or None, acceptable: article ids, "rec:<record id>", or "none" for no record)
E = [
    # typos and dictation slips
    ("how do i turn of voice over", None, ["ref-accessibility-shortcut", "ref-setup-voiceover"]),
    ("voiceover keeps reading evrything twice", None, ["ref-voiceover-silent"]),
    ("how do i chang the speaking rate", None, ["howto-vo-speaking-rate"]),
    ("whats the brail command for home", None, ["ref-braille-display"]),
    ("how do i reset my air pods", None, ["ref-restart-watch-airpods-tv"]),
    ("how do i turn on the flash light", None, ["howto-flashlight", "howto-home-control-center", "howto-home-lock-screen"]),
    ("i cant here voiceover", None, ["ref-voiceover-silent"]),
    ("how to forse restart iphone 16", None, ["ref-restart-iphone-ipad"]),
    ("how do i use the roter", None, ["rec:vo.rotor", "ref-voiceover-gestures"]),
    ("magnifyer on my phone", None, ["howto-magnifier"]),
    # vague or rambling
    ("my phone is talking too fast", None, ["howto-vo-speaking-rate"]),
    ("everything went dark on my phone help", None, ["ref-voiceover-silent", "rec:vo.curtain"]),
    ("the phone wont stop talking", None, ["ref-voiceover-silent", "ref-accessibility-shortcut"]),
    ("i accidentally turned something on and now i have to double tap everything", None, ["ref-accessibility-shortcut", "ref-setup-voiceover", "accessibility-voiceover"]),
    ("my screen is zoomed in and i cant get out", None, ["howto-zoom", "rec:vision.zoom", "ref-low-vision"]),
    ("the colors on my screen are all weird", None, ["howto-color-filters", "howto-invert-dark"]),
    ("my phone keeps vibrating for no reason", None, ["howto-notifications-app", "howto-silent-mode", "trouble-sync-notifications", "settings-notifications"]),
    ("i want my phone to read my texts to me", None, ["howto-announce-notifications", "howto-speak-screen", "ref-low-vision"]),
    ("im new and dont know where to start", None, ["guide-iphone", "tutorial-first-visit", "howto-app-where"]),
    ("i got a new mac what now", None, ["guide-mac"]),
    # two questions in one
    ("how do i turn on voiceover and how do i turn it off again", None, ["ref-accessibility-shortcut"]),
    ("how do i save a topic and find it later", None, ["howto-app-save", "howto-app-find-saved", "tutorial-save-follow"]),
    ("can i download podcast episodes and listen offline on a plane", None, ["howto-app-download-episode", "tutorial-podcast"]),
    # follow-ups
    ("and on my watch?", "How do I turn on VoiceOver?", ["ref-voiceover-watch", "howto-watch-voiceover"]),
    ("what about with a keyboard?", "How do I go to the Home Screen with VoiceOver?", ["ref-voiceover-keyboard-ios"]),
    ("how do i turn it back on", "How do I mute VoiceOver?", ["rec:vo.mute", "ref-voiceover-gestures", "ref-voiceover-silent"]),
    ("is there a gesture for that", "How do I scroll down a page?", ["rec:vo.scroll", "ref-voiceover-gestures"]),
    ("and with braille?", "How do I go to the next item?", ["rec:braille.next", "ref-braille-display"]),
    ("what about the mac", "How do I force quit an app?", ["ref-mac-essentials"]),
    # AppleVis app, everyday wording
    ("where did my saved stuff go", None, ["howto-app-find-saved", "foryou-overview"]),
    ("how do i get the podcast to play faster", None, ["howto-av-podcast", "content-podcasts", "howto-app-play-episode"]),
    ("can goldie read the new posts out loud", None, ["howto-app-listen-fetch", "home-fetch"]),
    ("why does the app make noises", None, ["howto-av-sounds", "settings-sounds-haptics"]),
    ("how do i stop the app vibrating", None, ["howto-av-haptics", "settings-sounds-haptics"]),
    ("how do i make the app dark", None, ["howto-av-theme", "settings-appearance"]),
    ("the text in applevis is too small", None, ["rec:vision.text", "howto-text-size", "accessibility-low-vision", "settings-appearance"]),
    ("how do i see only new posts", None, ["howto-app-see-new", "home-whats-new"]),
    ("how do i message another member privately", None, ["howto-app-message"]),
    ("can i turn off the mouse", None, ["howto-app-ai-off", "smart-ask-the-mouse", "smart-apple-intelligence"]),
    ("how do i get notified about replies to my topic", None, ["howto-app-replies-notify", "settings-notifications"]),
    ("how do i undo marking something as read", None, ["howto-app-mark-read", "tutorial-save-follow"]),
    ("i want to hear the newest podcast", None, ["howto-app-play-episode", "tutorial-podcast", "content-podcasts"]),
    ("how do i quote someone in my reply", None, ["howto-app-reply", "tutorial-post"]),
    ("can i write my post in another language", None, ["community-writing-tools", "howto-app-own-language"]),
    ("what does recommend do", None, ["howto-app-recommend", "tutorial-save-follow", "foryou-save-follow-download-faq"]),
    # AppleVis site
    ("is applevis free", None, ["start-what-is-applevis", "start-faq"]),
    ("who started applevis", None, ["start-what-is-applevis"]),
    ("can anyone add an app", None, ["community-submit-app", "howto-app-contribute"]),
    ("does someone check my bug report", None, ["community-submit-bug", "tutorial-bug-tracker"]),
    ("what are the rules for posting", None, ["community-guidelines"]),
    ("how do i become a guide writer", None, ["community-submit-blog", "howto-app-contribute", "content-blog-guides"]),
    ("whats the difference between saving and following", None, ["foryou-save-follow-download-faq", "tutorial-save-follow"]),
    # devices, plain words
    ("how do i take a picture of a document", None, ["howto-scan-text", "howto-camera-voiceover"]),
    ("can my phone tell me whats in front of me", None, ["ref-recognition", "howto-vo-live-recognition", "howto-magnifier"]),
    ("how do i find out who is calling without picking up", None, ["howto-answer-call", "ref-iphone-everyday-voiceover", "howto-unknown-callers"]),
    ("how do i check my battery percentage", None, ["howto-battery-usage", "ref-iphone-everyday-voiceover", "howto-low-power"]),
    ("how do i know if my phone is charging", None, ["howto-know-charging"]),
    ("how do i connect to wifi at a hotel", None, ["howto-wifi-join"]),
    ("how do i send a photo to my mac", None, ["howto-airdrop"]),
    ("how do i set a timer", None, ["howto-alarm"]),
    ("how do i turn on dark mode", None, ["howto-invert-dark"]),
    ("how do i hide an app", None, ["howto-home-hide-app"]),
    ("how do i get a person on the phone at apple", None, ["ref-getting-help"]),
    ("how do i type with braille on the screen", None, ["howto-braille-screen-input", "ref-typing-voiceover"]),
    ("how do i connect my focus 40", None, ["howto-braille-connect", "ref-braille-display"]),
    ("how do i turn on captions for a video", None, ["howto-auto-captions", "howto-live-captions"]),
    ("i cant hear phone calls well", None, ["howto-audio-adjust", "howto-hearing-devices"]),
    ("how do i stop my phone reading notifications on the lock screen", None, ["howto-vo-notifications", "howto-announce-notifications", "howto-notifications-app"]),
    # traps (no checked gesture/command answer)
    ("what does triple click do", None, ["ref-accessibility-shortcut", "none"]),
    ("how do i double tap", None, ["ref-voiceover-gestures", "none"]),
    ("whats the best braille display to buy", None, ["none"]),
    ("can i change the voiceover sound effects", None, ["none"]),
    ("does voiceover work with zoom meetings", None, ["none"]),
    ("how do i scroll in safari on my mac", None, ["none"]),
    ("what is the rotor on apple watch", None, ["none"]),
]


def run_e():
    failures = []
    for q, earlier, want in E:
        ctx = earlier if earlier and refers_back(q) else ''
        rec = Q.match(q, ctx)
        _, res = S.search(q + ' ' + ctx if ctx else q)
        ids = [a['id'] for _, a in res]
        if rec:
            ids = [rec['article']] + [i for i in ids if i != rec['article']]
        recs = [w[4:] for w in want if w.startswith('rec:')]
        arts = [w for w in want if not w.startswith('rec:') and w != 'none']
        if want == ['none']:
            good = rec is None
        else:
            good = bool((rec and rec['id'] in recs) or any(a in ids[:2] for a in arts))
            if 'none' in want and rec is not None and rec['id'] not in recs:
                good = False
        if not good:
            failures.append(f'E odd wordings: {q} | want {want} | record {rec and rec["id"]} | got {ids[:3]}')
    return failures


def run():
    total, failures = 0, []
    for name, qs in (('A devices', A), ('B AppleVis app', B), ('C AppleVis site', C)):
        for q, want in qs:
            total += 1
            rec = Q.match(q)
            _, res = S.search(q)
            ids = [a['id'] for _, a in res]
            if rec:
                ids = [rec['article']] + [i for i in ids if i != rec['article']]
            if not any(w in ids[:2] for w in want):
                failures.append(f'{name}: {q} | want {want} | got {ids[:3]}')
    failures += run_e()
    total += len(E)
    print(f'{total - len(failures)}/{total} passed')
    for f in failures:
        print(' - ' + f)
    return not failures


if __name__ == '__main__':
    sys.exit(0 if run() else 1)
