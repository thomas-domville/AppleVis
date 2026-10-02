"""Ask the Mouse regression check against the live applevis.com.

Runs every case in cases.json through the same site searches the app makes
(guides, forums, blogs, bugs, podcasts, the App Directory, and looking an app
up by name) and checks that what the Mouse needs still comes back. Apple
Intelligence can't run here, so this checks the searches it reads from; the
app's own matching rules are covered by AppleVisTests/AskTheMouseMatchingTests.

    python tools/mouse_regression/run.py            check, and compare with the baseline
    python tools/mouse_regression/run.py --record   check, then save results as the new baseline
    python tools/mouse_regression/run.py --only name-   just the cases whose id starts with name-

A case FAILS when none of its expected words is in the results. A case that
passed in the baseline and fails now is a REGRESSION. CHANGED means the top
results moved, which is worth a look but often just new posts.

Cases marked "gap" are subjects AppleVis has no guide on yet, so the Mouse
can only send people elsewhere. They aren't counted as failures; when one
starts passing it's listed as FILLED, and its "gap" mark can be removed. The
open gaps are a ready-made list of guides worth writing.

The site's app headers are read from CloudflareBypass.swift, so no key is
kept here. Requests are spaced out to stay light on the site.
"""
import json, os, re, sys, time, urllib.parse, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
BYPASS = os.path.join(ROOT, 'AppleVis', 'Sources', 'Networking', 'CloudflareBypass.swift')
CASES = os.path.join(HERE, 'cases.json')
BASELINE = os.path.join(HERE, 'baseline.json')
DELAY = 0.5

FULLY = {
    'ios': ('field_voiceover', '=', 'VoiceOver reads all page elements.'),
    'mac': ('field_usability', 'STARTS_WITH', 'The app is fully accessible'),
    'watch': ('field_usability_watch', '=', 'Fully Accessible'),
    'tv': ('field_usability_tv', '=', 'Fully Accessible'),
}
DIRECTORY = {'ios': 'ios_app_directory', 'mac': 'mac_app_directory', 'watch': 'watch_directory', 'tv': 'tv_directory'}


def headers():
    source = open(BYPASS, encoding='utf-8').read()
    agent = re.search(r'static let userAgent = "([^"]+)"', source).group(1)
    secret = re.search(r'static let appAuthSecret = "([^"]+)"', source).group(1)
    origin = 'https://www.applevis.com'
    return {'User-Agent': agent, 'Accept-Language': 'en-US,en;q=0.9', 'Origin': origin,
            'Referer': origin + '/', 'X-App-Auth': secret, 'Accept': 'application/vnd.api+json'}


HEADERS = headers()


def get(path, params):
    url = f'https://www.applevis.com/jsonapi/{path}?' + urllib.parse.urlencode(params)
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=40) as response:
            data = json.load(response)
    except Exception as error:  # reported as a failed case, not a crash
        data = {'data': [], 'error': str(error)}
    time.sleep(DELAY)
    return data


def titles(data):
    return [item['attributes'].get('title', '') for item in data.get('data', [])]


def run_case(case):
    check = case['check']
    if check == 'search':
        data = get('index/solr_site_index', {'filter[fulltext]': case['query'], 'filter[type]': case['type'], 'page[limit]': '10'})
    elif check == 'apps':
        # The app's App Directory search: each keyword in the name or the
        # description, optionally fully accessible only.
        params = {'sort': '-changed', 'page[limit]': '50', 'filter[words][group][conjunction]': 'OR'}
        words = [w.strip() for w in case['keywords'].split(',') if w.strip()]
        if any(len(w) >= 4 for w in words):
            words = [w for w in words if len(w) >= 4]
        for index, word in enumerate(words):
            for field, path in (('title', 'title'), ('body', 'body.value')):
                key = f'filter[{field}{index}][condition]'
                params.update({f'{key}[path]': path, f'{key}[operator]': 'CONTAINS', f'{key}[value]': word, f'{key}[memberOf]': 'words'})
        if case.get('fully'):
            field, operator, value = FULLY[case.get('platform', 'ios')]
            params.update({'filter[voiceover][condition][path]': field, 'filter[voiceover][condition][value]': value})
            if operator != '=':
                params['filter[voiceover][condition][operator]'] = operator
        data = get('node/' + DIRECTORY[case.get('platform', 'ios')], params)
    elif check == 'name':
        # Ask the Mouse looking one app up: names only, and a one- or
        # two-letter name as the start of a name.
        name = case['name']
        short = len(name) <= 2
        data = get('node/ios_app_directory', {
            'sort': '-changed', 'page[limit]': '20',
            'filter[title][condition][path]': 'title',
            'filter[title][condition][operator]': 'STARTS_WITH' if short else 'CONTAINS',
            'filter[title][condition][value]': name + ' ' if short else name})
    else:
        raise ValueError(f"Unknown check {check!r} in case {case['id']}")
    found = titles(data)
    lowered = [t.lower() for t in found]
    expected = case.get('expect_any', [])
    if case.get('expect_none'):
        passed = not found
    else:
        passed = any(word.lower() in t for word in expected for t in lowered)
    return {'passed': passed, 'top': found[:5], 'error': data.get('error')}


def main(argv):
    record = '--record' in argv
    only = argv[argv.index('--only') + 1] if '--only' in argv else ''
    cases = [c for c in json.load(open(CASES, encoding='utf-8')) if c['id'].startswith(only)]
    baseline = json.load(open(BASELINE, encoding='utf-8')) if os.path.exists(BASELINE) else {}
    results, failed, regressions, changed, gaps, filled = {}, [], [], [], [], []
    for number, case in enumerate(cases, 1):
        result = run_case(case)
        results[case['id']] = result
        before = baseline.get(case['id'])
        if case.get('gap'):
            (filled if result['passed'] else gaps).append(case['id'])
            print(f"[{number}/{len(cases)}] {'FILLED' if result['passed'] else 'gap '} {case['id']}: {case.get('question', '')}")
            continue
        mark = 'ok  ' if result['passed'] else 'FAIL'
        if not result['passed']:
            failed.append(case['id'])
            if before and before['passed']:
                regressions.append(case['id'])
                mark = 'REGRESSION'
        elif before and before['top'][:3] != result['top'][:3]:
            changed.append(case['id'])
        print(f"[{number}/{len(cases)}] {mark} {case['id']}: {case.get('question', '')}")
        if not result['passed']:
            print(f"        expected one of {case.get('expect_any')}; got {result['top'] or result['error'] or 'nothing'}")
    checked = len(cases) - len(gaps) - len(filled)
    print(f"\n{checked - len(failed)} of {checked} passed. {len(regressions)} regressions. {len(changed)} with changed top results.")
    print(f"{len(gaps)} known gaps still open. Filled: {', '.join(filled) or 'none'}.")
    for case_id in regressions:
        print(f"  REGRESSION {case_id}: was {baseline[case_id]['top'][:3]}, now {results[case_id]['top'][:3]}")
    for case_id in changed:
        print(f"  changed {case_id}: was {baseline[case_id]['top'][:3]}, now {results[case_id]['top'][:3]}")
    if record:
        merged = {**baseline, **results}
        json.dump(merged, open(BASELINE, 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
        print(f'Baseline saved: {BASELINE}')
    return 1 if regressions else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
