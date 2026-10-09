"""Port of MouseQuickReference (AppleVis/Sources/Models/MouseQuickReference.swift),
reading its records straight from the Swift file, so the handoff scenarios
can be checked without Xcode. Keep `normalized`, `named_platform`, and
`match` in step with the Swift (2026-10-09)."""
import os, re

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'AppleVis', 'Sources') + os.sep
swift = open(SRC + 'Models/MouseQuickReference.swift', encoding='utf-8').read()

_braille = re.search(r'brailleWords = (\[[^\]]*\])', swift).group(1)


def _strings(text):
    return re.findall(r'"((?:[^"\\]|\\.)*)"', text)


def _array_after(block, label):
    """The [...] literal (nested allowed) after `label:`, with brailleWords expanded."""
    i = block.find(label + ':')
    if i < 0:
        return None
    j = i + len(label) + 1
    text = block[j:].lstrip()
    text = text.replace('brailleWords + [', _braille[:-1] + ', ').replace('brailleWords', _braille)
    depth, end = 0, 0
    for k, ch in enumerate(text):
        if ch == '[':
            depth += 1
        elif ch == ']':
            depth -= 1
            if depth == 0:
                end = k + 1
                break
    return text[:end]


RECORDS = []
_list = swift[swift.find('static let all: [MouseQuickReference] = ['):]
for block in re.split(r'\n\s*\.init\(', _list)[1:]:
    rid = re.search(r'id: "([^"]+)"', block).group(1)
    platform = re.search(r'platform: \.(\w+)', block).group(1)
    article = re.search(r'articleId: "([^"]+)"', block).group(1)
    lines = _strings(_array_after(block, 'lines'))
    needs_src = _array_after(block, 'needs')
    needs = [_strings(g) for g in re.findall(r'\[([^\[\]]*)\]', needs_src[1:-1])]
    changing = 'isAboutChanging: true' in block
    excl_src = _array_after(block, 'excludes')
    excludes = _strings(excl_src) if excl_src else []
    source = re.search(r'source: (?:"([^"]+)"|(\w+))', block)
    RECORDS.append(dict(id=rid, platform=platform, article=article, lines=lines,
                        needs=needs, excludes=excludes, changing=changing,
                        source=source.group(1) or source.group(2)))


_ALIKE = {"1": "one", "2": "two", "3": "three", "4": "four", "5": "five",
          "fingers": "finger", "taps": "tap", "swipes": "swipe", "doubletap": "double tap",
          "screenshot": "screen shot", "screenshots": "screen shot", "phone": "iphone",
          "brail": "braille", "brial": "braille", "centre": "center", "colour": "color", "colours": "colors",
          "braill": "braille", "braile": "braille", "commands": "command"}


def normalized_for_matching(text):
    """AskTheMouse.normalizedForMatching."""
    t = text.lower().replace('voice over', 'voiceover').replace('voice-over', 'voiceover')
    return ' '.join(_ALIKE.get(w, w) for w in re.split(r'[^0-9a-zÀ-￿]+', t) if w)


def normalized(text):
    s = ' ' + normalized_for_matching(text).replace('’', "'").replace('-', ' ').replace(',', ' ').replace('?', ' ').replace('.', ' ') + ' '
    for digit, word in {'1': 'one', '2': 'two', '3': 'three', '4': 'four'}.items():
        s = s.replace(f' {digit} finger', f' {word} finger')
    s = (s.replace(' fingers ', ' finger ').replace(' single finger', ' one finger')
          .replace(' triple finger', ' three finger').replace(' double finger', ' two finger')
          .replace(' doubletap', ' double tap').replace(' centre', ' center'))
    for count in ['one', 'two', 'three', 'four']:
        for kind in ['double tap', 'triple tap', 'quadruple tap', 'tap', 'swipe up', 'swipe down', 'swipe left', 'swipe right']:
            s = s.replace(f' {kind} with {count} finger ', f' {count} finger {kind} ')
    for count in ['one', 'two', 'three', 'four']:
        for times, kind in [('twice', 'double tap'), ('two times', 'double tap'), ('2 times', 'double tap'),
                            ('three times', 'triple tap'), ('3 times', 'triple tap'), ('thrice', 'triple tap')]:
            for verb in [' tap', ' tapped', ' tapping', ' taps']:
                s = s.replace(f'{verb} {count} finger {times} ', f' {count} finger {kind} ')
                s = s.replace(f'{verb} with {count} finger {times} ', f' {count} finger {kind} ')
            s = s.replace(f' {count} finger tap {times} ', f' {count} finger {kind} ')
    s = s.replace(' and ', ' & ')
    words = s.split()
    out, i = [], 0
    while i < len(words):
        w = words[i]
        if w in ('dot', 'dots'):
            digits, n = [], i + 1
            while n < len(words):
                c = words[n]
                if len(c) == 1 and c.isdigit() and 1 <= int(c) <= 8:
                    digits.append(c)
                elif c != '&':
                    break
                n += 1
            if digits:
                out.append(f'dot {digits[0]}' if len(digits) == 1 else 'dots ' + ' '.join(digits))
                i = n
                continue
        out.append('and' if w == '&' else w)
        i += 1
    return ' ' + ' '.join(out) + ' '


def named_platform(text):
    s = normalized(text)
    if any(x in s for x in [' mac ', ' macs ', ' macbook', ' imac', " mac's ", ' macos ', ' mac mini', ' mac studio', ' mac pro ']):
        return 'mac'
    if any(x in s for x in [' iphone', ' ipad', ' ios ', ' ipados ']):
        return 'iPhoneAndIPad'
    if any(x in s for x in [' apple watch', ' my watch', ' the watch ', ' watchos ', ' apple tv', ' tvos ', ' vision pro', ' visionos ']):
        return 'other'
    return None


def platform(question, earlier='', on_mac=False):
    return named_platform(question) or named_platform(earlier) or ('mac' if on_mac else 'iPhoneAndIPad')


CHANGE_WORDS = [' change', ' reassign', ' customize', ' customise', ' remap', ' assign']
COMMAND_WORDS = [' command', ' gesture', ' shortcut', ' key ', ' keys ']


def asks_to_change(text):
    return any(w in text for w in CHANGE_WORDS) and any(w in text for w in COMMAND_WORDS)


def _best(text, plat):
    changing = asks_to_change(text)
    found = [(i, r) for i, r in enumerate(RECORDS)
             if r['platform'] == plat
             and (not changing or r['changing'])
             and not any(x in text for x in r['excludes'])
             and all(any(p in text for p in g) for g in r['needs'])]
    if not found:
        return None
    return max(found, key=lambda f: (len(f[1]['needs']), -f[0]))[1]


def match(question, earlier='', on_mac=False):
    import sim_help
    question = sim_help.spelling_fixed(question)
    plat = platform(question, earlier, on_mac)
    own = _best(normalized(question), plat)
    if own or not earlier:
        return own
    return _best(normalized(question + ' ' + earlier), plat)
