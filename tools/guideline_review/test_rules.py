"""Runs the app's own GuidelineLanguageTests cases against the Python port,
so the port is known to agree with the Swift rules before it's trusted."""
import re, sys, ast
sys.path.insert(0, __import__('os').path.dirname(__file__))
import rules

ROOT = __import__('os').path.abspath(__import__('os').path.join(__import__('os').path.dirname(__file__), '..', '..'))
src = open(__import__('os').path.join(ROOT, 'AppleVisTests', 'GuidelineLanguageTests.swift'), encoding='utf-8').read()
blocks = re.findall(r'@Test\("[^"]*", arguments: \[(.*?)\]\)\s*func (\w+)', src, re.S)

def swift_strings(body):
    body = re.sub(r'(?m)^\s*//.*$', '', body)
    return [ast.literal_eval('"' + m + '"') for m in re.findall(r'"((?:[^"\\]|\\.)*)"', body)]

def email_sev(t):
    return next((s for i, s in rules.check(t) if i == 'personal-info'), None)

expect = {
    'strong': lambda t: rules.contains_strong_vulgar(t),
    'crude': lambda t: rules.contains_crude(t) and not rules.contains_strong_vulgar(t),
    'putDowns': lambda t: rules.tone_concern(t) == 'medium',
    'selfPromotion': lambda t: rules.looks_like_self_promotion(t),
    'notSelfPromotion': lambda t: not rules.looks_like_self_promotion(t),
    'clean': lambda t: not rules.contains_strong_vulgar(t) and not rules.contains_crude(t) and rules.tone_concern(t) is None,
    'personalEmailIsMedium': lambda t: email_sev(t) == 'medium',
    'workEmailIsLow': lambda t: email_sev(t) == 'low',
    'roleEmailIsIgnored': lambda t: email_sev(t) is None,
    'descriptiveClearlyIsFine': lambda t: rules.tone_concern(t) is None,
    'dismissiveClearlyIsLow': lambda t: rules.tone_concern(t) == 'low',
    'surveyMentionIsFine': lambda t: not any(i == 'announcement-approval' for i, _ in rules.check(t)),
    'surveyInvitationNeedsApproval': lambda t: any(i == 'announcement-approval' for i, _ in rules.check(t)),
    'buyingMentionIsFine': lambda t: not any(i == 'advertising' for i, _ in rules.check(t)),
    'listingIsAdvertising': lambda t: any(i == 'advertising' for i, _ in rules.check(t)),
    'selfShutUpIsFine': lambda t: rules.tone_concern(t) is None,
    'shutUpAtSomeoneIsMedium': lambda t: rules.tone_concern(t) == 'medium',
    'undirectedLowToneIsFine': lambda t: rules.tone_concern(t) is None,
    'dismissiveWhateverIsLow': lambda t: rules.tone_concern(t) == 'low',
    'excitementIsFine': lambda t: not any(i == 'excessive-punctuation' for i, _ in rules.check(t)),
    'shoutingIsFlagged': lambda t: any(i == 'excessive-punctuation' for i, _ in rules.check(t)),
    'relatedQuestionsAreOneTopic': lambda t: not any(i == 'multi-topic' for i, _ in rules.check(t)),
    'topicSwitchIsFlagged': lambda t: any(i == 'multi-topic' for i, _ in rules.check(t)),
    'appStorePromoCodeIsFine': lambda t: not any(i == 'advertising' for i, _ in rules.check(t)),
    'discountCodeIsAdvertising': lambda t: any(i == 'advertising' for i, _ in rules.check(t)),
    'pressReleaseMentionIsFine': lambda t: not any(i == 'press-release' for i, _ in rules.check(t)),
    'pressReleaseIsFlagged': lambda t: any(i == 'press-release' for i, _ in rules.check(t)),
    'aiMentionIsFine': lambda t: not any(i == 'ai-disclosure' for i, _ in rules.check(t)),
    'chatbotPhrasingIsFlagged': lambda t: any(i == 'ai-disclosure' for i, _ in rules.check(t)),
    'groupStatementIsFine': lambda t: rules.tone_concern(t) != 'high',
    'missedPutDownsAreMedium': lambda t: rules.tone_concern(t) == 'medium',
    'caringCounsellingIsFine': lambda t: rules.tone_concern(t) is None,
    'quotedPutDownIsFine': lambda t: rules.tone_concern(t) != 'medium',
}
total = fails = 0
for body, name in blocks:
    f = expect.get(name)
    if not f:
        print('no mapping for', name); continue
    for t in swift_strings(body):
        total += 1
        if not f(t):
            fails += 1; print('FAIL', name, repr(t))
# The two single-case tests.
crash = re.search(r'let post = """\n(.*?)\n\s*"""', src, re.S).group(1)
crash = "\n".join(l.strip() for l in crash.splitlines())
serious = [x for x in rules.check(crash) if x[1] != 'low']
total += 1
if serious: fails += 1; print('FAIL voiceOverCrashPost', serious)
total += 1
if email_sev("Email me at gokhan@birkinapps.com.\nFrom: Jane Doe <jane.doe@gmail.com>") != 'medium': fails += 1; print('FAIL mixed')
total += 2
if rules.tone_concern('There is a difference between calling out a behavior ("Michael, you\'re being a keyboard warrior") and a personal attack ("Michael, you\'re an idiot").') != 'medium': fails += 1; print('FAIL quoted insult')
if rules.tone_concern("Michael, you're an idiot.") != 'high': fails += 1; print('FAIL unquoted insult')
total += 1
if rules.tone_concern('All blind people are useless.') != 'high': fails += 1; print('FAIL hateful generalisation')
total += 1
if rules.tone_concern("If you don't like it in landscape, I'm sorry but suck it up.") != 'low': fails += 1; print('FAIL suck it up')
for q in ['Saying things like "Mind your own business" in response to someone\'s opinion is counterproductive.',
          'You told that person that "... you have some insecurities that you should probably address with a mental health counselor," which was hurtful.']:
    total += 1
    if rules.tone_concern(q) == 'medium': fails += 1; print('FAIL quoted put-down', q[:50])
for q in ['Please be respectful. Saying things like &quot;Mind your own business&quot; is counterproductive.',
          "<blockquote><p>Mind your own business.</p></blockquote><p>That wasn't kind. Please be respectful.</p>",
          'There is a difference between calling out a behavior and a personal attack ("Michael, you\'re an idiot"). Personal attacks are not welcome on AppleVis.']:
    total += 1
    if rules.tone_concern(q) is not None: fails += 1; print('FAIL moderator case', q[:50])
total += 1
if rules.tone_concern('Legato 0.3.85 is out. Most of this release is the browser learning to shut up.') is not None: fails += 1; print('FAIL browser shut up')
print(f'{total - fails}/{total} cases agree with the app tests')
