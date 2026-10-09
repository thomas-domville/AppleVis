"""Run from the repo root: python tools/mouse_help_eval/test_howto_questions.py

How-To Library batch (2026-10-08): real questions, worded the way people
ask them, across all eight How To sections. Each must find the expected
article in the top 2, and the line that answers it must survive into the
passage the Mouse reads. Follow-ups carry the question before them, as
AskTheMouse.refersBack does."""
import os, re, sys
sys.stdout.reconfigure(encoding='utf-8')
sys.argv = [sys.argv[0]]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sim_help as S
from test_help_questions import passage

POINTERS = {"this", "that", "it", "it's", "its", "these", "those", "there", "them", "they", "one"}

def refers_back(q):
    words = re.findall(r"[a-z']+", q.lower())
    if any(w in POINTERS for w in words):
        return True
    own = [t for t in S.terms(q) if t not in FOLLOW_UP_WORDS]
    return len(words) <= 6 and len(own) <= 1


FOLLOW_UP_WORDS = {
    "mac", "macs", "macbook", "imac", "ipad", "iphone", "apple", "watch", "tv", "vision", "pro",
    "braille", "display", "keyboard", "trackpad", "instead", "else", "also", "too", "again", "and", "now",
}

# (question, expected article, text that must reach the Mouse, earlier question or None)
TESTS = [
    # Forum questions, reworded (2026-10-09): the gaps 496 recent topic
    # titles showed.
    ("How do I sign a PDF on my iPhone?", "howto-sign-pdf", "Signature", None),
    ("Can I fill out a form on my iPhone with VoiceOver?", "howto-sign-pdf", "Text", None),
    ("I have duplicate contacts, how do I merge them?", "howto-duplicate-contacts", "Merge All", None),
    ("How do I switch to 24 hour time?", "howto-time-format", "24-Hour Time", None),
    ("How do I name a group chat?", "howto-group-chat-name", "Edit Name & Photo", None),
    ("My name isn't showing up on my friend's phone", "howto-share-name-photo", "Share Name and Photo", None),
    ("How do I get files from Dropbox onto my iPhone?", "howto-files-cloud", "Dropbox", None),
    ("How do I keep a folder synced between my Mac and iPhone?", "howto-files-cloud", "Desktop & Documents", None),
    ("Does iPhone Mirroring work with VoiceOver?", "howto-iphone-mirroring", "VoiceOver", None),
    ("How do I use verification codes from text messages?", "howto-passwords", "suggestions", None),
    ("How do I add a passkey?", "howto-passwords", "passkey", None),
    ("How do I delete a downloaded VoiceOver voice?", "howto-vo-voice", "delete", None),
    ("How do I copy text after selecting it?", "ref-typing-voiceover", "copy", None),
    ("I can't get to the Home Screen while I'm on a call", "ref-iphone-everyday-voiceover", "call keeps going", None),
    ("How do I lock my Mac?", "ref-mac-essentials", "Control-Command-Q", None),
    ("I'm buying my first Mac, where do I start?", "guide-mac", "VoiceOver", None),
    ("How do I type an emoji?", "howto-keyboard-language", "emoji", None),
    ("Can I make changes to my AppleVis account?", "community-edit-profile", "profile", None),
    # Using AppleVis (the app itself)
    ("Who owns AppleVis?", "start-what-is-applevis", "Be My Eyes Foundation", None),
    ("Is AppleVis a nonprofit?", "start-what-is-applevis", "nonprofit", None),
    ("How can I donate to AppleVis?", "start-what-is-applevis", "donate", None),
    ("How do I see only card games in the App Directory?", "content-apps", "Type picker", None),
    ("How do I get a Mac app that isn't in the App Store?", "content-apps", "Get It from the Developer", None),
    ("Can I add a subject to my comment?", "tutorial-post", "subject", None),
    ("How do I submit a Mac app that's not in the Mac App Store?", "community-submit-app", "Homebrew", None),
    ("Where is everything in the AppleVis app?", "howto-app-where", "For You", None),
    ("What version of AppleVis do I have?", "howto-app-version", "Version", None),
    ("How do I see only the new posts?", "howto-app-see-new", "New", None),
    ("How do I mark a topic as read?", "howto-app-mark-read", "Mark as Read", None),
    ("How do I read all the new comments in one place?", "howto-app-fetch", "Fetch", None),
    ("Can AppleVis read the new posts out loud to me?", "howto-app-listen-fetch", "Listen to Fetch", None),
    ("Is there a weekly summary of what happened on AppleVis?", "howto-app-nibbles", "Past Week", None),
    ("How do I get back to where I left off?", "howto-app-left-off", "Pick Up Where You Left Off", None),
    ("How do I jump to the first new comment?", "howto-app-first-new-comment", "Jump to First New Comment", None),
    ("How do I get to the last comment in a long thread?", "howto-app-last-comment", "Jump to Last Comment", None),
    ("How do I filter the forums to unread topics?", "howto-app-browse-forums", "Unread", None),
    ("How do I start a new forum topic?", "howto-app-new-topic", "New Topic", None),
    ("How do I reply to someone's comment?", "howto-app-reply", "Reply to this Comment", None),
    ("Can I get a summary of a long forum thread?", "howto-app-summarize", "Summarize Discussion", None),
    ("How do I follow a forum topic?", "howto-app-follow", "Following", None),
    ("How do I get notified when someone replies to my post?", "howto-app-replies-notify", "Replies to My Posts", None),
    ("How do I send a private message to another member?", "howto-app-message", "Send Message", None),
    ("How do I share a forum topic with a friend?", "howto-app-share", "Share", None),
    ("How do I save a topic to read later?", "howto-app-save", "For You > Saved", None),
    ("Where do I find my downloads?", "foryou-overview", "Downloads", None),
    ("Where are my saved items?", "howto-app-find-saved", "Saved", None),
    ("How do I find out if an app is accessible with VoiceOver?", "howto-app-check-app", "App Directory", None),
    ("How do I leave a comment on an app in the App Directory?", "howto-app-comment-app", "Add Comment", None),
    ("How do I recommend an app?", "howto-app-recommend", "Recommend", None),
    ("Which apps do members recommend most?", "howto-app-community-picks", "Most Recommended", None),
    ("How do I play the AppleVis podcast?", "howto-app-play-episode", "Play", None),
    ("How do I download a podcast episode for offline listening?", "howto-app-download-episode", "Download", None),
    ("How do I reorder my podcast queue?", "howto-app-queue", "Move Up", None),
    ("How do I set a sleep timer for the podcast?", "howto-app-sleep-timer", "End of Episode", None),
    ("Where is the episode transcript?", "howto-app-transcript", "Transcript", None),
    ("How do I skip to a chapter in a podcast episode?", "howto-app-chapters", "Chapters", None),
    ("How do I start a podcast episode over from the beginning?", "howto-app-start-over", "Start Over", None),
    ("How do I search AppleVis?", "howto-app-search", "Discover", None),
    ("Can I print a help article?", "howto-app-help", "Share or Print", None),
    ("How do I ask the Mouse a question?", "howto-app-ask-mouse", "Ask the Mouse", None),
    ("How do I check if a VoiceOver bug is already known?", "howto-app-known-bug", "Bug Tracker", None),
    ("How do I call a Be My Eyes volunteer?", "howto-app-be-my-eyes", "Call a Volunteer", None),
    ("How can I contribute to AppleVis?", "howto-app-contribute", "Contribute", None),
    ("How do I change my AppleVis password?", "howto-app-change-password", "Change Password", None),
    ("How do I change my email address on AppleVis?", "howto-app-change-email", "Change Email Address", None),
    ("How do I delete my AppleVis account?", "howto-app-delete-account", "Delete Account", None),
    ("How do I contact the AppleVis team?", "howto-app-contact", "Contact AppleVis", None),
    ("How do I report a problem with the AppleVis app?", "howto-app-contact", "Bug Report", None),
    ("Can I read AppleVis in Spanish?", "howto-app-own-language", "Auto-Translate Content", None),
    ("How do I sync my saved items between my iPhone and iPad?", "howto-app-sync", "Enable iCloud Sync", None),
    ("AppleVis is using too much storage", "howto-app-free-space", "Clear Cached Content", None),
    ("How do I make VoiceOver say less in AppleVis lists?", "howto-app-detail-level", "VoiceOver Detail Level", None),
    ("How do I turn off the AI features in AppleVis?", "howto-app-ai-off", "Intelligence", None),
    ("How do I turn off the tips?", "howto-app-tips", "AppleVis Tips", None),
    ("What can I ask Siri to do in AppleVis?", "howto-app-siri", "Hey Siri", None),
    ("Are there keyboard shortcuts in AppleVis?", "ref-applevis-keyboard", "Command", None),
    ("Can I use AppleVis with a keyboard?", "howto-app-keyboard", "Command-F", None),
    # AppleVis settings
    ("How do I turn off the sounds in AppleVis?", "howto-av-sounds", "Confirmation Sounds", None),
    ("How do I change the theme in AppleVis?", "howto-av-theme", "Appearance", None),
    ("How do I turn on catch-up reminders?", "howto-av-reminders", "Catch-Up Reminders", None),
    ("How do I change the podcast skip time?", "howto-av-podcast", "Skip Forward", None),
    ("How do I hide non-Apple topics in AppleVis?", "howto-av-apple-only", "Apple Topics Only", None),
    ("How do I turn off the welcome message when AppleVis opens?", "howto-av-welcome", "Home Startup Behavior", None),
    ("How do I use the Goldie theme?", "howto-av-theme", "Goldie", None),
    ("How do I turn off haptics in AppleVis?", "howto-av-haptics", "Haptic Feedback", None),
    ("How do I change the notification sound for AppleVis?", "howto-av-notification-sound", "Notification Sound", None),
    ("How do I sign out of AppleVis?", "howto-av-sign-out", "Sign Out", None),
    ("How do I sign out of my Apple Account?", "howto-apple-account-sign-out", "Find My", None),
    ("How do I open links in Safari instead?", "howto-av-web-links", "Default Browser", None),
    # Device guides
    ("I just got my first iPhone, where do I start with VoiceOver?", "guide-iphone", "triple-click the side button", None),
    ("I'm new to iPad, what's different from iPhone?", "guide-ipad", "Globe-M", None),
    ("I just got a Mac, how do I get started with VoiceOver?", "guide-mac", "Command-F5", None),
    ("Getting started with Apple Watch and VoiceOver", "guide-watch", "Digital Crown", None),
    ("I'm new to Apple TV", "guide-tv", "Back button", None),
    # Know your device
    ("What are the buttons on the side of my iPhone?", "howto-know-side-buttons", "Side button", None),
    ("What is this button above the volume buttons?", "howto-know-action-button", "Action button", None),
    ("What is the flat button on the right side near the bottom?", "howto-know-camera-control", "Camera Control", None),
    ("What are the round bumps on the back of my phone?", "howto-know-camera-bumps", "camera lenses", None),
    ("What are the smaller bumps and the little hole on the back?", "howto-know-small-holes", "Microphone", None),
    ("What are the three things along the bottom edge of my iPhone?", "howto-know-bottom-edge", "charging port", None),
    ("What is the dynamic island?", "howto-know-front", "Dynamic Island", None),
    ("What is MagSafe?", "howto-know-magsafe", "magnets", None),
    ("How do I charge my iPhone wirelessly?", "howto-know-charging", "MagSafe", None),
    ("Where is the SIM card on my iPhone?", "howto-know-sim", "pinhole", None),
    ("What are the lines on the edge of my phone?", "howto-know-edge-lines", "antenna", None),
    ("Which iPhone do I have?", "howto-know-which-iphone", "Model Name", None),
    ("What's the button on the back of my AirPods case?", "howto-know-airpods", "Case button", None),
    ("What is the digital crown?", "howto-know-watch", "Digital Crown", None),
    ("What are the buttons on my Apple TV remote?", "howto-know-tv-remote", "Clickpad", None),
    # Home Screen and apps
    ("How do I move apps around on my home screen with VoiceOver?", "howto-home-move-app", "Drop Before", None),
    ("how do i rearrange my apps", "howto-home-move-app", "Drag", None),
    ("How do I make a folder on my iPhone?", "howto-home-make-folder", "Create New Folder", None),
    ("how to rename a folder on iphone", "howto-home-rename-folder", "Edit Mode", None),
    ("How do I get an app out of a folder?", "howto-home-out-of-folder", "Drop Before", None),
    ("Can I rename an app on my iPhone?", "howto-home-rename-app", "Shortcuts", None),
    ("How do I lock an app with Face ID?", "howto-home-lock-app", "Require Face ID", None),
    ("how do i hide an app", "howto-home-hide-app", "Hide and Require Face ID", None),
    ("where do hidden apps go", "howto-home-hide-app", "Hidden folder", None),
    ("How do I remove an app from my home screen but keep it?", "howto-home-remove", "Remove from Home Screen", None),
    ("how do i delete an app", "howto-home-delete", "Delete App", None),
    ("What does offload app mean?", "howto-home-offload", "Offload App", None),
    ("I can't find an app on my phone", "howto-home-find-app", "App Library", None),
    ("How do I add a widget?", "howto-home-widget", "Add Widget", None),
    ("How do I make my app icons dark?", "howto-home-icons", "Customize", None),
    ("how do i stop new apps appearing on my home screen", "howto-home-new-apps", "App Library Only", None),
    ("How do I add something to Control Center?", "howto-home-control-center", "Add a Control", None),
    ("How do I change what the Action button does?", "howto-home-action-button", "Action Button", None),
    ("how do I change the flashlight button on my lock screen", "howto-home-lock-screen", "Customize", None),
    # Connections
    ("How do I connect to Wi-Fi?", "howto-wifi-join", "Choose the network", None),
    ("how do i forget a wifi network", "howto-wifi-forget", "Forget This Network", None),
    ("How do I share my Wi-Fi password with a friend?", "howto-wifi-share", "Share Password", None),
    ("Where can I see my wifi password?", "howto-wifi-see-password", "Password", None),
    ("How do I pair Bluetooth headphones?", "howto-bluetooth-pair", "Other Devices", None),
    ("how do I unpair a bluetooth speaker", "howto-bluetooth-forget", "Forget This Device", None),
    ("My bluetooth keyboard won't connect", "howto-bluetooth-trouble", "pairing mode", None),
    ("How do I turn on hotspot?", "howto-hotspot", "Allow Others to Join", None),
    ("Can I use airplane mode and still use bluetooth?", "howto-airplane-mode", "turn them back on", None),
    ("How do I stop an app using cellular data?", "howto-mobile-data-apps", "Cellular", None),
    ("How do I AirDrop a photo?", "howto-airdrop", "AirDrop", None),
    ("How do I play music on my HomePod from my iPhone?", "howto-airplay", "AirPlay", None),
    ("How do I add an eSIM?", "howto-esim", "Add eSIM", None),
    # Calls, messages, notifications
    ("How do I change my ringtone?", "howto-ringtone", "Sounds & Haptics", None),
    ("how do i put my phone on silent", "howto-silent-mode", "Silent Mode", None),
    ("How do I make my ringer louder without changing music volume?", "howto-ringer-volume", "Change with Buttons", None),
    ("How do I turn off notifications for Facebook?", "howto-notifications-app", "Allow Notifications", None),
    ("What is scheduled summary?", "howto-notification-summary", "Scheduled Summary", None),
    ("How do I get my AirPods to read my notifications?", "howto-announce-notifications", "Announce Notifications", None),
    ("How do I set up Do Not Disturb?", "howto-focus", "Do Not Disturb", None),
    ("How do I stop spam calls?", "howto-unknown-callers", "Screen Unknown Callers", None),
    ("What is hold assist?", "howto-hold-assist", "Hold Assist", None),
    ("How do I answer a call with VoiceOver?", "howto-answer-call", "Magic Tap", None),
    ("How do I block a number?", "howto-block-number", "Block This Caller", None),
    ("How do I set up my voicemail?", "howto-voicemail", "Set Up Now", None),
    ("How do I set up medical ID?", "howto-emergency", "Medical ID", None),
    ("How do I call emergency services with my iPhone?", "howto-sos", "Emergency SOS", None),
    ("How do I send a voice message in Messages?", "howto-audio-message", "Audio", None),
    ("Can I unsend a text message?", "howto-message-later", "Undo Send", None),
    # VoiceOver
    ("How do I make VoiceOver talk faster?", "howto-vo-speaking-rate", "Speaking Rate", None),
    ("How do I change the VoiceOver voice?", "howto-vo-voice", "Voice", None),
    ("Can VoiceOver use the old Siri voice in iOS 27?", "howto-vo-voice", "older Siri voices", None),
    ("How do I switch VoiceOver to Spanish?", "howto-vo-languages", "Rotor Languages", None),
    ("How do I add things to the rotor?", "howto-vo-rotor-items", "Rotor Items", None),
    ("How do I change a VoiceOver gesture?", "howto-vo-gestures", "Touch Gestures", None),
    ("How do I turn off VoiceOver hints?", "howto-vo-hints", "Hints", None),
    ("VoiceOver keeps saying double tap to open, how do I stop that", "howto-vo-hints", "Hints", None),
    ("How do I make VoiceOver read one sentence at a time when I swipe?", "howto-vo-text-navigation", "Text Navigation", None),
    ("How do I make VoiceOver read only the line under my finger?", "howto-vo-text-exploration", "Text Exploration", None),
    ("How do I share my pronunciation dictionary?", "howto-vo-pronunciations", "Pronunciations", None),
    ("How do I hide the black box around items?", "howto-vo-cursor-visibility", "Cursor Visibility", None),
    ("How do I get VoiceOver to describe a picture?", "howto-vo-image-explorer", "Image Recognition", None),
    ("How do I ask a question about a photo with VoiceOver?", "howto-vo-image-explorer", "Ask About Image", None),
    ("How do I ask what my camera is looking at?", "howto-vo-live-recognition", "Live Recognition", None),
    ("How do I turn on screen curtain?", "howto-vo-screen-curtain", "three fingers", None),
    ("What is VoiceOver quick settings?", "howto-vo-quick-settings", "four times with two fingers", None),
    ("My music gets quiet when VoiceOver talks", "howto-vo-audio-ducking", "Audio Ducking", None),
    ("How do I change typing mode in VoiceOver?", "howto-vo-typing-style", "Typing Style", None),
    ("How do I label a button?", "howto-vo-label", "two fingers and hold", None),
    ("How do I copy the last thing VoiceOver said?", "howto-vo-copy-speech", "four times with three fingers", None),
    # Braille
    ("How do I connect my braille display?", "howto-braille-connect", "Choose a Braille Display", None),
    ("Is there a way to change this command?", "howto-braille-commands", "Braille Commands", "What is the braille command to open the Notification Center on my iPhone?"),
    ("How do I change to contracted braille?", "howto-braille-tables", "Contracted Braille", None),
    ("How do I use braille screen input?", "howto-braille-screen-input", "Braille Screen Input", None),
    ("Does braille screen input have word suggestions now?", "howto-braille-screen-input", "swipe up or down", None),
    ("How do I open braille access?", "howto-braille-access", "dots 7 and 8", None),
    ("Can braille access open PDF files?", "howto-braille-access", "PDF", None),
    ("What is snap to print text cursor?", "howto-braille-cursor", "Snap to Print Text Cursor", None),
    ("My braille display keeps disconnecting", "howto-braille-trouble", "Forget This Device", None),
    # Vision, hearing, physical access
    ("How do I make the text bigger on my iPhone?", "howto-text-size", "Larger Text", None),
    ("How do I make text bold?", "howto-bold-text", "Bold Text", None),
    ("The glass effect in iOS 27 is hard to see", "howto-liquid-glass", "Glass Intensity", None),
    ("Where is the Liquid Glass slider?", "howto-liquid-glass", "Glass Intensity", None),
    ("How do I zoom in on the screen?", "howto-zoom", "three fingers", None),
    ("How do I use accessibility reader?", "howto-accessibility-reader", "Read & Speak", None),
    ("How do I turn on dark mode?", "howto-invert-dark", "Dark", None),
    ("How do I make my iPhone screen grayscale?", "howto-color-filters", "Color Filters", None),
    ("How do I stop the screen moving so much?", "howto-reduce-motion", "Reduce Motion", None),
    ("How do I have my iPhone read the screen to me without VoiceOver?", "howto-speak-screen", "Speak Screen", None),
    ("How do I turn on live captions?", "howto-live-captions", "Live Captions", None),
    ("How do I get subtitles on my home videos?", "howto-auto-captions", "Automatic Captions", None),
    ("Can my iPhone tell me when the doorbell rings?", "howto-sound-recognition", "Sound Recognition", None),
    ("How do I connect my hearing aids?", "howto-hearing-devices", "Hearing Devices", None),
    ("How do I use AirPods as a hearing aid?", "howto-airpods-hearing", "Hearing Assistance", None),
    ("How do I use live listen?", "howto-live-listen", "Live Listen", None),
    ("How do I make the camera flash when I get a call?", "howto-led-flash", "LED Flash for Alerts", None),
    ("What is back tap?", "howto-back-tap", "Back Tap", None),
    ("How do I change what triple clicking the side button does?", "howto-accessibility-shortcut", "Accessibility Shortcut", None),
    ("How do I control my iPhone with my voice?", "howto-voice-control", "Voice Control", None),
    ("How do I set up switch control?", "howto-switch-control", "Add New Switch", None),
    # Everyday
    ("How do I add another language keyboard?", "howto-keyboard-language", "Add New Keyboard", None),
    ("How do I turn off autocorrect?", "howto-autocorrect", "Auto-Correction", None),
    ("How do I make a text replacement?", "howto-text-replacement", "Text Replacement", None),
    ("How do I dictate a message with punctuation?", "howto-dictation", "comma", None),
    ("How do I type to Siri instead of talking?", "howto-siri-settings", "Type to Siri", None),
    ("How do I turn on Apple Intelligence?", "howto-apple-intelligence-on", "Apple Intelligence & Siri", None),
    ("How do I proofread my email?", "howto-writing-tools", "Writing Tools", None),
    ("How do I take a screenshot?", "howto-screenshot", "volume up", None),
    ("How do I record my screen with VoiceOver sound?", "howto-screen-recording", "Screen Recording", None),
    ("How do I set an alarm?", "howto-alarm", "Clock", None),
    ("How do I scan a document with my iPhone?", "howto-scan-text", "Scan Documents", None),
    ("How do I take a picture with VoiceOver?", "howto-camera-voiceover", "faces", None),
    ("How do I use Apple Pay?", "howto-apple-pay", "double-press the side button", None),
    ("How do I share my screen on FaceTime?", "howto-shareplay", "Share My Screen", None),
    # Battery, privacy, devices
    ("What's draining my battery?", "howto-battery-usage", "Battery", None),
    ("How do I turn on low power mode?", "howto-low-power", "Low Power Mode", None),
    ("My iPhone storage is full", "howto-storage", "iPhone Storage", None),
    ("How do I update to iOS 27?", "howto-update-ios", "Software Update", None),
    ("How do I back up my iPhone?", "howto-backup", "iCloud Backup", None),
    ("How do I transfer everything to my new iPhone?", "howto-new-iphone", "Quick Start", None),
    ("How do I change my passcode?", "howto-passcode", "Change Passcode", None),
    ("What is stolen device protection?", "howto-stolen-device", "Stolen Device Protection", None),
    ("Which apps can see my location?", "howto-app-permissions", "Location Services", None),
    ("Where are my saved passwords?", "howto-passwords", "Passwords app", None),
    ("I lost my AirPods, how do I find them?", "howto-find-my", "Play Sound", None),
    ("How do I change what my AirPods do when I squeeze them?", "howto-airpods-controls", "Press and Hold AirPods", None),
    ("How do I turn on VoiceOver on my Apple Watch?", "howto-watch-voiceover", "Digital Crown", None),
    ("How do I turn on VoiceOver on Apple TV?", "howto-tv-voiceover", "Back button", None),
]

def run():
    passed, failures = 0, []
    for q, want, needle, earlier in TESTS:
        query = q + " " + earlier if earlier and refers_back(q) else q
        ts, res = S.search(query)
        ids = [a['id'] for _, a in res]
        top = ids[:2]
        if want not in top:
            failures.append((q, want, f"got {ids}"))
            continue
        art = next(a for _, a in res if a['id'] == want)
        text = passage(art, ts)
        if needle.lower() not in text.lower():
            failures.append((q, want, f"needle missing: {needle}"))
            continue
        passed += 1
    print(f"{passed}/{len(TESTS)} passed")
    for q, want, why in failures:
        print(f" - {q} | want {want} | {why}")
    return not failures

if __name__ == '__main__':
    sys.exit(0 if run() else 1)
