#!/usr/bin/env python3
"""Whole-app localization audit for AppleVis.

Finds every piece of English text in the Swift sources, works out *how* it
reaches the screen, and checks it against Localizable.xcstrings. Unlike a
catalog-only check, it catches text that is in the catalog but displayed in a
way that skips it (a plain String passed to Text/Label/custom views).

Usage:  python tools/l10n_audit.py [--json out.json] [--all]
Exit status is 1 when any GAP is found, so it can gate a commit.

Categories
  GAP            English text that will show untranslated. Fix these.
  VERIFY         A plain String whose key is in the catalog. It is translated
                 only if the display site converts it (String(localized:
                 String.LocalizationValue(x)) or LocalizedStringKey(x)).
                 Listed with --all.
  PLURAL         English-only plural tricks like `n == 1 ? "" : "s"`.
  CATALOG        Catalog keys missing languages, empty, or placeholder mismatch.
  SURFACE        Share extension strings and Siri phrases missing from their own
                 catalogs (AppleVisShareExtension/Localizable.xcstrings, AppShortcuts.xcstrings).
"""
import json, os, re, sys, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCES = [os.path.join(ROOT, 'AppleVis', 'Sources'), os.path.join(ROOT, 'AppleVisShareExtension')]
CATALOG = os.path.join(ROOT, 'AppleVis', 'Sources', 'Resources', 'Localizable.xcstrings')
SIRI_CATALOG = os.path.join(ROOT, 'AppleVis', 'Sources', 'Resources', 'AppShortcuts.xcstrings')
SHARE_CATALOG = os.path.join(ROOT, 'AppleVisShareExtension', 'Localizable.xcstrings')
LANGS = ['ar', 'de', 'el', 'es', 'fa', 'fr', 'he', 'hi', 'id', 'it', 'ja', 'ko', 'nl', 'pl', 'pt', 'ru', 'sv', 'th', 'tr', 'uk', 'vi', 'zh-Hans']

# Help articles are translated at runtime by Auto-Translate, by design.
DESIGN_EXEMPT_FILES = {'HelpContent.swift'}
# Support report e-mailed to the AppleVis team; stays English on purpose.
TEAM_FACING_FILES = {'DiagnosticInfo.swift'}
# Phrase lists used to *detect* English in drafts; only the shown messages count.
DETECTION_FILES = {'GuidelinesChecker.swift', 'ContentSubmissionPolicy.swift'}
DETECTION_UI_LABELS = {'message', 'rule', 'label', 'title', 'hint'}
# Admin-only screens stay English (Profile > Admin), by decision.
ADMIN_FILES = {'GuidelineViolationCheckView.swift', 'GuidelineViolationScanner.swift', 'ModeratorToolsView.swift',
               'AppDirectoryHealthCheckView.swift', 'AppEntryHealthScanner.swift', 'FalsePositiveReportView.swift'}
# Messages e-mailed to the editorial team or posted to the English-only site.
TEAM_FACING = [
    ('ReportCommentWizard.swift', r"^(Reported |Reporter's additional|\(none provided\)|— Sent via)"),
    ('ContactView.swift', r'^\s*You can also contact'),
    ('ReportCommentWizard.swift', r'^\s*You can also report'),
    ('SubmitBlogView.swift', r'Suggested category'),
    ('SubmitPodcastView.swift', r'^Shared from'),
    ('CommunityDiscussionHeading.swift', r'wrote:|^add new comment$'),
    ('DrupalFormClient.swift', r'^(Content-Disposition|Send message|Turnstile)'),
    ('GuidelineFalsePositiveReporter.swift', r'.'),
    ('APIClient.swift', r'^Cannot parse date'),
    ('CloudflareBypass.swift', r'.'),
    ('EpisodeDetailView.swift', r'^(episode|podcast|audio) transcript'),
    ('ContactView.swift', r'^App (Bug Report|Feedback|Suggestion|Enquiry)$'),
    # item kinds handed to the on-device model for Mouse Recap blurbs
    ('Mappers.swift', r'^macOS '),
    ('ReportCommentWizard.swift', r' Report: '),
    # category names matched against server data
    ('ForumsBrowseView.swift', r'^(smart home tech and gadgets|assistive technology)$'),
    ('HomeView.swift', r'^(spotlight feature|app entry|podcast episode|blog post|guide or tutorial|forum discussion)$'),
]
# Arguments that only travel to the team (e.g. the guideline false-positive report).
TEAM_FACING_ARGS = {'GuidelinesReminderView(context: String)', 'GuidelinesReminderView(context)'}
# Product and people names, licence text.
NAMES = re.compile(r'^(iPad( Air| Pro| mini)?|Mac( Pro| Studio| mini)|MacBook( Air| Pro)|HomePod mini|AirPods( Max| Pro)|'
                   r'iPod touch|AppleVis Podcast|Ana Domville|Thomas Domville|Michael Hansen|David Goodwin|Be My Eyes|'
                   r'Be My AI|Swift|Apache License 2\.0|Copyright ©.*|Spotlight)$')
# Text sent to the on-device model, never shown.
PROMPT_FILES = {'IntelligenceService.swift'}

BS = chr(92)

# ---------------------------------------------------------------- lexer

class Lit:
    __slots__ = ('start', 'end', 'key', 'raw', 'nested_in', 'line', 'multiline')

    def __init__(self, start, end, key, raw, nested_in, line, multiline):
        self.start, self.end, self.key, self.raw = start, end, key, raw
        self.nested_in, self.line, self.multiline = nested_in, line, multiline


def lex(src):
    """Return (literals, masked). masked has comments/literals blanked, same length."""
    lits, masked, n = [], list(src), len(src)

    def blank(a, b):
        for k in range(a, b):
            if masked[k] != '\n':
                masked[k] = ' '

    def parse_string(i, parent):
        # i at opening quote(s). Returns end index (exclusive).
        multiline = src.startswith('"""', i)
        j = i + (3 if multiline else 1)
        parts, idx_self = [], len(lits)
        lits.append(None)
        nested = []
        while j < n:
            if multiline and src.startswith('"""', j):
                end = j + 3
                break
            c = src[j]
            if not multiline and c == '"':
                end = j + 1
                break
            if not multiline and c == '\n':
                end = j
                break
            if c == BS and j + 1 < n:
                d = src[j + 1]
                if d == '(':
                    k, depth = j + 2, 1
                    while k < n and depth:
                        if src[k] == '"':
                            k = parse_string(k, idx_self)
                            continue
                        if src[k] == '(':
                            depth += 1
                        elif src[k] == ')':
                            depth -= 1
                        k += 1
                    parts.append('\x00')
                    j = k
                    continue
                if d == '\n' and multiline:
                    j += 2
                    while j < n and src[j] in ' \t':
                        j += 1
                    continue
                if d == 'u' and j + 2 < n and src[j + 2] == '{':
                    k = src.index('}', j)
                    parts.append(chr(int(src[j + 3:k], 16)))
                    j = k + 1
                    continue
                parts.append({'n': '\n', 't': '\t', '0': '\0', 'r': '\r'}.get(d, d))
                j += 2
                continue
            parts.append(c)
            j += 1
        else:
            end = n
        text = ''.join(parts)
        if multiline:
            body = src[i:end]
            m = re.search(r'\n([ \t]*)"""$', body)
            indent = m.group(1) if m else ''
            lines = text.split('\n')
            if lines and lines[0].strip() == '':
                lines = lines[1:]
            if lines and lines[-1].strip() == '':
                lines = lines[:-1]
            text = '\n'.join(l[len(indent):] if l.startswith(indent) else l.lstrip() for l in lines)
        lits[idx_self] = Lit(i, end, text, src[i:end], parent, src.count('\n', 0, i) + 1, multiline)
        return end

    i = 0
    while i < n:
        if src.startswith('//', i):
            j = src.find('\n', i)
            j = n if j < 0 else j
            blank(i, j)
            i = j
            continue
        if src.startswith('/*', i):
            depth, j = 1, i + 2
            while j < n and depth:
                if src.startswith('/*', j):
                    depth += 1; j += 2
                elif src.startswith('*/', j):
                    depth -= 1; j += 2
                else:
                    j += 1
            blank(i, j)
            i = j
            continue
        m = re.match(r'(#+)("""|")', src[i:i + 20])
        if m:  # raw string: regex or similar, never UI copy here
            close = m.group(2) + m.group(1)
            j = src.find(close, i + len(m.group(0)))
            j = n if j < 0 else j + len(close)
            blank(i, j)
            i = j
            continue
        if src[i] == '"':
            first = len(lits)
            j = parse_string(i, None)
            blank(i + 1, j - 1)
            # keep a one-char atom so the literal is visible in masked text
            masked[i] = '"'
            if j - 1 > i:
                masked[j - 1] = '"'
            i = j
            continue
        i += 1
    return lits, ''.join(masked)


# ---------------------------------------------------------------- declarations

TYPE_LOC = re.compile(r'\b(LocalizedStringKey|LocalizedStringResource|Text|LocalizationValue)\b')
TYPE_STR = re.compile(r'^\s*(String|StringProtocol|Substring)\??\s*$')


def collect_signatures(files):
    """Parameter types for custom views/functions.

    Returns {name: {label: kind}} where kind is 'loc', 'other', 'mixed',
    'str+conv' (a String the component looks up in the catalog itself, via
    LocalizedStringKey(x) or String.LocalizationValue(x)) or 'str' (a String
    the component shows as-is).
    """
    sigs = collections.defaultdict(dict)

    def kind(t):
        t = t.strip().rstrip(',)')
        if TYPE_LOC.search(t):
            return 'loc'
        if TYPE_STR.match(t) or t.startswith('String?') or t == 'String':
            return 'str'
        return 'other'

    def converts(body, internal):
        return bool(re.search(r'(LocalizedStringKey|LocalizationValue)' + BS + '(' + BS + 's*(?:self' + BS + '.)?' + re.escape(internal) + r'\b', body))

    def block_after(masked, pos):
        j = masked.find('{', pos)
        if j < 0:
            return ''
        depth, k = 1, j + 1
        while k < len(masked) and depth:
            if masked[k] == '{':
                depth += 1
            elif masked[k] == '}':
                depth -= 1
            k += 1
        return masked[j:k]

    everything = '\n'.join(m for _, _, m in files)

    def string_use(body, internal, model):
        """'str+conv' looked up, 'strv' shown as-is, 'str' passed along/unknown."""
        if converts(body, internal):
            return 'str+conv'
        if model and re.search(r'(LocalizedStringKey|LocalizationValue)\(\s*[\w.]+\.' + re.escape(internal) + r'\b', everything):
            return 'str+conv'
        name = r'(?:self\.)?' + re.escape(internal)
        if re.search(r'\b(Text|Label|Button|Toggle|Section|Link|Menu|NavigationLink|LabeledContent|ProgressView|Picker)\(\s*' + name + r'\s*[,)]', body) or \
           re.search(r'\.(accessibilityLabel|accessibilityHint|accessibilityValue|navigationTitle)\(\s*' + name + r'\s*\)', body):
            return 'strv'
        return 'str'

    for path, src, masked in files:
        for m in re.finditer(r'\b(?:struct|class)\s+(\w+)[^{]*\{', masked):
            name = m.group(1)
            body = block_after(masked, m.end() - 1)
            model = not re.search(r'\bvar\s+body\s*:\s*some\s+View', body)
            d, flat = 0, []
            for ch in body[1:-1]:
                if ch == '{':
                    d += 1
                if d == 0:
                    flat.append(ch)
                if ch == '}':
                    d -= 1
            flat = ''.join(flat)
            for pm in re.finditer(r'(?:let|var)\s+(\w+)\s*:\s*([\w.?<>\[\] ]+?)\s*(?:=|\n|$)', flat):
                k = kind(pm.group(2))
                if k == 'str':
                    k = string_use(body, pm.group(1), model)
                merge(sigs[name], pm.group(1), k)
            for im in re.finditer(r'\binit\s*\(([^)]*)\)', flat):
                add_params(sigs[name], im.group(1), kind, lambda internal, b=body, md=model: string_use(b, internal, md))
        for fm in re.finditer(r'\bfunc\s+(\w+)\s*(?:<[^>]*>)?\s*\(([^)]*)\)', masked):
            body = block_after(masked, fm.end())
            add_params(sigs[fm.group(1)], fm.group(2), kind, lambda internal, b=body: string_use(b, internal, False))
    return sigs


def merge(table, label, k):
    prev = table.get(label)
    table[label] = k if prev in (None, k) else 'mixed'


def add_params(table, params, kind, use):
    for p in params.split(','):
        m = re.match(r'\s*(\w+)(?:\s+(\w+))?\s*:\s*(.+)', p)
        if not m:
            continue
        label, internal = m.group(1), m.group(2) or m.group(1)
        k = kind(re.sub(r'=.*', '', m.group(3)))
        if k == 'str':
            k = use(internal)
        merge(table, label, k)


# ---------------------------------------------------------------- context

SWIFTUI_LOC_CALLS = {
    'Text', 'Button', 'Label', 'Toggle', 'TextField', 'SecureField', 'Picker', 'Section', 'Link', 'Menu',
    'NavigationLink', 'Stepper', 'DatePicker', 'LabeledContent', 'GroupBox', 'DisclosureGroup',
    'ContentUnavailableView', 'ProgressView', 'ControlGroup', 'ShareLink', 'PasteButton', 'ColorPicker',
    'navigationTitle', 'accessibilityLabel', 'accessibilityHint', 'accessibilityValue', 'help', 'alert',
    'confirmationDialog', 'badge', 'accessibilityAction', 'accessibilityRotor', 'accessibilityCustomContent',
    'accessibilityInputLabels', 'searchable', 'LocalizedStringKey', 'LocalizedStringResource', 'IntentDescription',
    'AppShortcut', 'TypeDisplayRepresentation', 'DisplayRepresentation', 'CaseDisplayRepresentation',
    'navigationSubtitle', 'toolbar', 'keyboardShortcut', 'Tab', 'AccessibilityCustomAction',
}
LOC_LABELS = {None, 'titleKey', 'prompt', 'named', 'label', 'title', 'subtitle', 'message', 'description',
              'shortTitle', 'placeholder', 'hint'}
NON_PROSE_LABELS = {'systemImage', 'systemName', 'image', 'destination', 'value', 'id', 'forKey', 'key',
                    'named_image', 'tableName', 'bundle', 'comment', 'identifier', 'format', 'sound',
                    'forHTTPHeaderField', 'httpHeaderField', 'of', 'with', 'options', 'separator',
                    'accessibilityIdentifier', 'category', 'subsystem', 'mimeType', 'fileExtension'}
SKIP_CALLS = {
    'print', 'debugPrint', 'NSLog', 'os_log', 'assert', 'assertionFailure', 'precondition', 'preconditionFailure',
    'fatalError', 'debug', 'info', 'notice', 'error', 'warning', 'fault', 'trace', 'critical', 'log',
    'URL', 'URLComponents', 'URLQueryItem', 'Image', 'Color', 'UIImage', 'UIColor', 'NSRegularExpression',
    'Regex', 'range', 'replacingOccurrences', 'components', 'hasPrefix', 'hasSuffix', 'contains', 'split',
    'Notification.Name', 'Name', 'NSNotification.Name', 'set', 'string', 'bool', 'integer', 'object', 'data',
    'double', 'removeObject', 'value', 'setValue', 'decode', 'encode', 'CodingKeys', 'Logger', 'Font',
    'custom', 'firstIndex', 'lastIndex', 'trimmingCharacters', 'addValue', 'setValue', 'post', 'appendingPathComponent',
    'appending', 'dateFormat', 'DateFormatter', 'Bundle', 'UTType', 'NSPredicate', 'predicate', 'sorted',
    'AVAudioPlayer', 'NSSound', 'SystemSoundID', 'UNNotificationSound', 'NSUserActivity', 'Keychain',
    'SecItem', 'CKRecord', 'NSUbiquitousKeyValueStore', 'matches', 'firstMatch', 'wholeMatch', 'OSLog',
    'Selector', 'NSAttributedString', 'AttributedString', 'filter', 'jsonapi', 'include', 'field', 'query',
    'queryItem', 'header', 'setHeader', 'addHeader', 'endpoint', 'path', 'get', 'patch', 'delete', 'put', 'request',
}
PROMPT_HINTS = re.compile(r'^(You are|Rewrite|Summari[sz]e|Translate|Write a|Return only|Respond|Classify|Given)', re.I)


def enclosing_openers(masked):
    """For each index, the stack of open bracket positions. Returned as a function."""
    stack, snapshots = [], {}
    events = []
    for i, ch in enumerate(masked):
        if ch in '([{':
            stack.append(i)
        elif ch in ')]}':
            if stack:
                stack.pop()
        events.append(len(stack))
    return None  # not used; computed per literal below


def build_stacks(masked, positions):
    want = sorted(set(positions))
    out, stack, w = {}, [], 0
    for i, ch in enumerate(masked):
        while w < len(want) and want[w] == i:
            out[i] = list(stack)
            w += 1
        if ch in '([{':
            stack.append(i)
        elif ch in ')]}':
            if stack:
                stack.pop()
    return out


def callee_before(masked, pos):
    """Identifier chain immediately before an opening bracket at pos."""
    k = pos - 1
    while k >= 0 and masked[k] in ' \t':
        k -= 1
    if k >= 0 and masked[k] == '>':  # generic args
        depth = 0
        while k >= 0:
            if masked[k] == '>':
                depth += 1
            elif masked[k] == '<':
                depth -= 1
                if depth == 0:
                    k -= 1
                    break
            k -= 1
    end = k + 1
    while k >= 0 and (masked[k].isalnum() or masked[k] in '_.?!'):
        k -= 1
    return masked[k + 1:end].strip('.?!')


def segment_bounds(masked, lit, opener):
    """Start/end of the argument (or element) containing the literal."""
    depth, k = 0, lit.start - 1
    start = opener + 1
    while k > opener:
        ch = masked[k]
        if ch in ')]}':
            depth += 1
        elif ch in '([{':
            depth -= 1
        elif ch == ',' and depth == 0:
            start = k + 1
            break
        k -= 1
    depth, k, end = 0, lit.end, len(masked)
    while k < len(masked):
        ch = masked[k]
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            if depth == 0:
                end = k
                break
            depth -= 1
        elif ch == ',' and depth == 0:
            end = k
            break
        k += 1
    return start, end


def decl_type_for_block(masked, brace):
    """Return 'loc'/'str'/None for the declaration owning the { at brace."""
    line_start = masked.rfind('\n', 0, brace) + 1
    header = masked[line_start:brace]
    # multi-line headers: look back one more line when the header is a bare `{`
    if not header.strip():
        prev = masked.rfind('\n', 0, line_start - 1) + 1
        header = masked[prev:brace]
    m = re.search(r'->\s*([\w.?<>\[\]]+)\s*(?:where[^{]*)?$', header.strip())
    if not m:
        m = re.search(r'\bvar\s+\w+\s*:\s*([\w.?<>\[\]]+)\s*$', header.strip())
    if m:
        t = m.group(1)
        if TYPE_LOC.search(t):
            return 'loc'
        if t.startswith('String') or t.startswith('[String'):
            return 'str'
        return 'other'
    if re.search(r'\b(switch|if|else|guard|case|do|for|while|catch)\b', header) or re.search(r'\bdefault\s*:', header):
        return None  # keep walking up
    if re.search(r'\bin\s*$', header.strip()) or re.search(r'[\(,]\s*$', header.strip()) or header.strip().endswith('{'):
        return 'closure'
    return None


def classify(path, src, masked, lit, stack, sigs, lit_by_start):
    """Return (kind, detail). kind in LOC, STR, SKIP, SIRI, EXPR, VERBATIM."""
    if lit.nested_in is not None:
        if re.search(r'(String\(localized:|LocalizedStringResource\(|LocalizedStringKey\()\s*$', src[max(0, lit.start - 40):lit.start]):
            return 'LOC', 'nested String(localized:)'
        return 'NESTED', 'inside another string'
    if not stack:
        return 'STR', 'top-level'
    opener = stack[-1]
    oc = masked[opener]
    if oc in '([':
        s, e = segment_bounds(masked, lit, opener)
        seg = masked[s:e]
        rel = lit.start - s
        before, after = seg[:rel], seg[rel + (lit.end - lit.start):]
        lm = re.match(r'\s*(\w+)\s*:\s*$', before)
        label = lm.group(1) if lm else None
        rest = (re.sub(r'^\s*\w+\s*:', '', before) + after).strip()
        is_expr = bool(rest)
        if oc == '[':
            # dictionary value?  key: "x"
            dm = re.search(r'(\w+)\s*:\s*$', before)
            if dm and dm.group(1) in ('NSLocalizedDescriptionKey', 'NSLocalizedFailureReasonErrorKey'):
                return 'STR', 'error description'
            if re.search(r'[\]\w"]\s*:\s*$', before):  # dictionary key or value by key
                if before.strip().endswith(':'):
                    return 'SKIP', 'dict value'
                return 'SKIP', 'dict key'
            # array element: classify the whole array like a literal
            callee = callee_before(masked, opener)
            parent_stack = stack[:-1]
            if not parent_stack:
                return 'STR', 'array'
            po = parent_stack[-1]
            pc = callee_before(masked, po) if masked[po] == '(' else ''
            s2, _ = segment_bounds(masked, type('L', (), {'start': opener, 'end': opener + 1})(), po) if masked[po] in '([' else (opener, 0)
            lab2 = re.match(r'\s*(\w+)\s*:', masked[s2:opener])
            lab2 = lab2.group(1) if lab2 else None
            if lab2 == 'phrases':
                return 'SIRI', 'App Shortcut phrase'
            if pc and pc.split('.')[-1] in SWIFTUI_LOC_CALLS:
                return 'LOC', pc
            head = masked[masked.rfind('\n', 0, opener) + 1:opener]
            if re.search(r':\s*\[\s*(LocalizedStringKey|LocalizedStringResource)', head):
                return 'LOC', 'typed array'
            return 'STR', 'array element'
        if re.search(r'(==|!=)\s*$', before) or re.match(r'\s*(==|!=)', after):
            return 'SKIP', 'comparison'
        callee = callee_before(masked, opener)
        base = callee.split('.')[-1]
        if base in SKIP_CALLS or callee in SKIP_CALLS or (label in NON_PROSE_LABELS):
            return 'SKIP', callee
        if base == 'String' and (label == 'localized' or re.match(r'\s*localized\s*:', seg)):
            return ('EXPR' if is_expr and not ternary_only(rest) else 'LOC'), 'String(localized:)'
        if base in ('LocalizationValue', 'LocalizedStringKey', 'LocalizedStringResource'):
            return 'LOC', base
        if base == 'Text' and label == 'verbatim':
            return 'VERBATIM', 'Text(verbatim:)'
        if base in ('Announcement',) or (callee.endswith('post') and label == 'argument'):
            return 'STR', 'VoiceOver announcement'
        if base in SWIFTUI_LOC_CALLS and label in LOC_LABELS:
            if is_expr and not ternary_only(rest):
                return 'EXPR', f'{base}({rest[:40]})'
            return 'LOC', base
        table = sigs.get(base)
        if table:
            k = table.get(label or '_') or (table.get(first_param_name(table)) if label is None else None)
            if k == 'loc':
                return ('EXPR' if is_expr and not ternary_only(rest) else 'LOC'), f'{base}({label})'
            if k == 'str+conv':
                return 'LOC', f'{base}({label or "_"}) looks it up'
            if k == 'strv':
                return 'STRV', f'{base}({label or "_"}: String, shown as-is)'
            if k == 'str':
                return 'STR', f'{base}({label or "_"}: String)'
        return 'STR', f'{callee or "?"}({label or "_"})'
    # statement inside a { } block
    line_start = masked.rfind('\n', 0, lit.start) + 1
    before = masked[line_start:lit.start]
    am = re.search(r'\b(?:let|var)\s+\w+\s*(?::\s*([\w.?<>\[\]]+))?\s*=\s*$', before)
    if am:
        t = am.group(1) or 'String'
        return ('LOC', 'typed let') if TYPE_LOC.search(t) else ('STR', 'let/var')
    if re.search(r'(?<![=!<>])=\s*$', before):
        pm = re.search(r'(\w+)\s*=\s*$', before)
        return 'STR', f'assign {pm.group(1) if pm else ""}'
    if re.search(r'[?:]\s*$', before) and not re.search(r'\bcase\b[^:]*:\s*$', before) and not re.search(r'\bdefault\s*:\s*$', before):
        pass  # ternary branch in a returned expression; fall through to the owning declaration
    for b in reversed(stack):
        if masked[b] != '{':
            break
        t = decl_type_for_block(masked, b)
        if t == 'loc':
            return 'LOC', 'returns LocalizedStringKey'
        if t == 'str':
            return 'STR', 'returns String'
        if t in ('other', 'closure'):
            return 'STR', 'closure/other'
    return 'STR', 'statement'


def ternary_only(rest):
    """True when the argument is `cond ? "a" : "b"` with only literal branches.

    Xcode extracts (and SwiftUI localizes) both branches in that case. A branch
    that is a variable makes the whole expression a String, shown as-is.
    """
    if '+' in rest or '??' in rest:
        return False
    q = rest.find('?')
    if q < 0:
        return False
    tail = rest[q + 1:]
    # the literal under test was cut out of `rest`; what remains of the
    # branches must be empty or another literal
    branches = [b.strip() for b in tail.split(':')]
    return all(b == '' or re.fullmatch(r'"\s*"', b) for b in branches)


def first_param_name(table):
    return next(iter(table), None)


# ---------------------------------------------------------------- prose filter

IDENTIFIER = re.compile(r'^[\w.\-/:@#%$&=+*]+$')


def is_prose(key):
    text = key.replace('\x00', '').strip()
    if not re.search(r'[A-Za-z]{2,}', text):
        return False
    if text.startswith(('http', 'mailto:', 'tel:', 'applevis://', 'com.', 'applevis.', '<', '{', 'node--', 'comment--')):
        return False
    if re.search(r'\x00\s+[A-Za-z]{2,}|[A-Za-z]{2,}\s+\x00', key):
        return True  # "5 apps", "Active 3 days ago"
    if ' ' not in text and '\n' not in text:
        if re.match(r'^[A-Z][a-z]+[.…!?]?$', text) or re.match(r'^[A-Z][a-z]+(?:[A-Z][a-z]+)*$', text) and text in ('AppleVis',):
            return text not in ('AppleVis', 'VoiceOver', 'Siri', 'Mouse', 'Midnight', 'Default', 'GET', 'POST')
        return False
    if re.search(r'\b(SELECT|WHERE|filter\[|fields\[|page\[)\b', text):
        return False
    return True


# ---------------------------------------------------------------- catalog

def load_catalog(path=CATALOG):
    if not os.path.exists(path):
        return {}, []
    data = json.load(open(path, encoding='utf-8'))['strings']
    norm = collections.defaultdict(list)
    problems = []
    for k, v in data.items():
        if v.get('shouldTranslate') is False:
            norm[cat_norm(k)].append((k, True))
            continue
        locs = v.get('localizations') or {}
        missing = []
        for l in LANGS:
            e = locs.get(l)
            if not e:
                missing.append(l)
            elif 'stringUnit' in e:
                if not (e['stringUnit'].get('value') or '').strip() and k.strip():
                    missing.append(l)
                elif spec(e['stringUnit']['value']) != spec(k) and '%#@' not in k:
                    problems.append(('placeholder', k, l))
                elif '${applicationName}' in k and '${applicationName}' not in e['stringUnit']['value']:
                    problems.append(('Siri phrase lost ${applicationName}', k, l))
            elif 'variations' not in e:
                missing.append(l)
        if missing and k.strip() and re.search(r'[A-Za-z]{2,}', k):
            problems.append(('missing', k, ','.join(missing) if len(missing) < 22 else 'all'))
        norm[cat_norm(k)].append((k, not missing))
    return norm, problems


def cat_norm(k):
    return re.sub(r'%(\d+\$)?(lld|ld|llu|lu|d|@|lf|f|u|\.\d+f)', '\x00', k)


def spec(s):
    return sorted(re.sub(r'\d+\$', '', m) for m in re.findall(r'%(?:\d+\$)?(?:lld|ld|llu|lu|d|@|lf|f|u|\.\d+f)', s))


# ---------------------------------------------------------------- main

PLURAL_RE = re.compile(r'==\s*1\s*\?\s*"[^"]*"\s*:\s*"[^"]*"|!=\s*1\s*\?\s*"[^"]*"\s*:\s*"[^"]*"|\+\s*"s"')


def run(show_all=False, out_json=None, collect=None, quiet=False):
    """Scan everything. `collect`, if given, receives (path, src, lit, kind, detail, in_cat) for each GAP."""
    files = []
    for base in SOURCES:
        for d, _, fs in os.walk(base):
            for f in fs:
                if f.endswith('.swift'):
                    p = os.path.join(d, f)
                    src = open(p, encoding='utf-8').read().replace('\r\n', '\n')
                    lits, masked = lex(src)
                    files.append((p, src, masked, lits))
    sigs = collect_signatures([(p, s, m) for p, s, m, _ in files])
    catalog, cat_problems = load_catalog()
    siri_cat, siri_problems = load_catalog(SIRI_CATALOG)
    share_cat, share_problems = load_catalog(SHARE_CATALOG)

    findings = collections.defaultdict(list)
    for p, src, masked, lits in files:
        rel = os.path.relpath(p, ROOT).replace(os.sep, '/')
        fname = os.path.basename(p)
        stacks = build_stacks(masked, [l.start for l in lits])
        for m in PLURAL_RE.finditer(src):
            if masked[m.start()] == ' ':
                continue  # inside a comment
            findings['PLURAL'].append((rel, src.count('\n', 0, m.start()) + 1, m.group(0), ''))
        if fname in DESIGN_EXEMPT_FILES or fname in TEAM_FACING_FILES:
            continue
        for lit in lits:
            gap_before = len(findings['GAP'])
            if not is_prose(lit.key):
                continue
            if fname in PROMPT_FILES and (PROMPT_HINTS.search(lit.key) or lit.multiline):
                continue
            kind, detail = classify(p, src, masked, lit, stacks.get(lit.start, []), sigs, None)
            if kind in ('SKIP',) or any(detail.startswith(t.split(':')[0]) and 'context' in detail for t in TEAM_FACING_ARGS):
                continue
            if fname in DETECTION_FILES and not any(f'({l})' in detail or detail.endswith(l) for l in DETECTION_UI_LABELS) and kind != 'LOC':
                continue
            if any(fname == f and re.search(rx, lit.key) for f, rx in TEAM_FACING) or NAMES.match(lit.key.strip()):
                continue
            if '/Networking/' in rel and ' ' not in lit.key.strip():
                continue  # HTTP header names and similar tokens
            if fname in PROMPT_FILES and kind != 'LOC' and not re.match(r"^(Couldn't|Can't|Apple Intelligence|This feature|Summar|Translat|Rewrit)", lit.key):
                findings['PROMPT'].append((rel, lit.line, lit.key[:80], 'model prompt text (not shown)'))
                continue
            if kind == 'RAW':
                findings['VERIFY'].append((rel, lit.line, lit.key[:160], 'enum raw value: translated only if never shown via .rawValue'))
                continue
            hits = catalog.get(cat_norm(lit.key), [])
            in_cat = any(ok for _, ok in hits)
            partial = bool(hits) and not in_cat
            where = 'ADMIN' if fname in ADMIN_FILES else ''
            row = (rel, lit.line, lit.key.replace('\x00', '{…}')[:160], detail)
            if 'AppleVisShareExtension' in rel:
                ok = any(t for _, t in share_cat.get(cat_norm(lit.key), []))
                if kind != 'LOC':
                    findings['GAP'].append(row[:3] + (f'share extension: plain String, wrap in String(localized:) · {detail}',))
                elif not ok:
                    findings['SURFACE'].append(row[:3] + ('missing or untranslated in AppleVisShareExtension/Localizable.xcstrings',))
            elif kind == 'SIRI':
                key = lit.key.replace('\x00', '${applicationName}')
                if not any(t for _, t in siri_cat.get(cat_norm(key), [])):
                    findings['SURFACE'].append(row[:3] + ('Siri phrase missing or untranslated in AppShortcuts.xcstrings',))
            elif where:
                findings['ADMIN'].append(row)
            elif kind == 'LOC':
                if not in_cat:
                    findings['GAP'].append(row[:3] + (('untranslated in catalog' if partial else 'not in catalog') + f' · {detail}',))
            elif kind == 'EXPR':
                findings['GAP'].append(row[:3] + (f'built by an expression, shown as-is · {detail}',))
            elif kind == 'NESTED':
                findings['GAP' if not in_cat else 'VERIFY'].append(row[:3] + ('text inside an interpolation',))
            elif kind == 'STRV':
                findings['GAP'].append(row[:3] + ((f'shown as-is (in catalog but never looked up)' if in_cat else 'plain String, not in catalog') + f' · {detail}',))
            elif kind == 'VERBATIM':
                findings['VERIFY'].append(row)
            else:  # STR
                if in_cat:
                    findings['VERIFY'].append(row)
                else:
                    findings['GAP'].append(row[:3] + (f'plain String, not in catalog · {detail}',))
            if collect is not None and len(findings['GAP']) > gap_before:
                collect.append((p, src, lit, kind, detail, in_cat))
    for name, probs in (('Localizable.xcstrings', cat_problems), ('AppShortcuts.xcstrings', siri_problems),
                        ('AppleVisShareExtension/Localizable.xcstrings', share_problems)):
        for kind, k, extra in probs:
            findings['CATALOG'].append((name, 0, k[:120], f'{kind}: {extra}'))

    if quiet:
        return findings
    order = ['GAP', 'PLURAL', 'CATALOG', 'SURFACE'] + (['VERIFY', 'ADMIN'] if show_all else [])
    for cat in order:
        rows = findings.get(cat, [])
        print(f'\n=== {cat} ({len(rows)})')
        for f, ln, text, detail in sorted(rows):
            print(f'{f}:{ln}  {text!r}  [{detail}]')
    print('\nSUMMARY ' + ' '.join(f'{c}={len(findings.get(c, []))}' for c in ['GAP', 'PLURAL', 'CATALOG', 'SURFACE', 'VERIFY', 'ADMIN']))
    if out_json:
        json.dump({c: findings.get(c, []) for c in findings}, open(out_json, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    return findings


def main():
    args = sys.argv[1:]
    findings = run('--all' in args, args[args.index('--json') + 1] if '--json' in args else None)
    sys.exit(1 if findings.get('GAP') or findings.get('CATALOG') else 0)


if __name__ == '__main__':
    main()
