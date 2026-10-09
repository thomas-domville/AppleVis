"""End-to-end test of posting on the live AppleVis site, the way the app does it.

Never commit credentials. Pass them in the environment:

    APPLEVIS_TEST_USER=... APPLEVIS_TEST_PASS=... python tools/live_write_test.py check
    APPLEVIS_TEST_USER=... APPLEVIS_TEST_PASS=... python tools/live_write_test.py run <forum term id>

check  Signs in, lists the account's roles and the forums. Writes nothing.
apps-check
       Signs in, compares the app's category tables with the site's live
       vocabularies, and lists the options on the live Add App forms.
       Writes nothing.
run-app <ios|tv|watch|mac>
       Creates an UNPUBLISHED App Directory entry with the same fields the
       app sends, checks it, and deletes it. The app sends status true; a
       test always sends false, which needs the same permission.
run-app ios real <App Store id> [country]
       Same, but fills the entry from that app's real App Store listing the
       way the app's Submit form does (name, version, devices, description,
       link, category), to reproduce a submission the site refused. Any
       refusal is printed with the site's own reason.
run-subjects <forum term id>
       Same as run, but the comment and the reply are sent with no subject,
       and the subjects the site gives them are printed. Everything is
       deleted at the end. (2026-10-09: what a blank Subject should send.)
run-replies <forum term id>
       Posts the way the app does since 2026-10-09: an UNPUBLISHED topic, a
       comment whose subject is its first words (the app's rule for a blank
       Subject), and a reply to that comment with "Re: <its subject>" and
       the parent link. Checks the subjects, the parent link, the thread
       position, and that the website's own page shows the reply nested
       under the comment. Everything is deleted at the end.
run-replies-app
       Same as run-replies, on an UNPUBLISHED App Directory entry instead of
       a forum topic: app entries, blog posts, guides, podcast episodes, and
       bug reports link replies the same way since 2026-10-09.
run    Creates an UNPUBLISHED topic in the given forum, then a comment, a
       reply to the comment, deletes the reply and comment, and deletes the
       topic. Every step is checked, and anonymous visitors are checked to
       be unable to see the topic. If the site publishes the topic anyway,
       it is deleted at once and the run stops.
"""
import http.cookiejar, json, os, re, sys, time, urllib.error, urllib.request

sys.stdout.reconfigure(encoding='utf-8')
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
SITE = 'https://www.applevis.com/'

auth = ''
for dirpath, _, files in os.walk(os.path.join(ROOT, 'AppleVis', 'Sources')):
    if 'CloudflareBypass.swift' in files:
        auth = re.search(r'"([0-9a-f]{20})"', open(os.path.join(dirpath, 'CloudflareBypass.swift'), encoding='utf-8').read()).group(1)
BASE_HEADERS = {
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 AppleVis/2026',
    'Accept-Language': 'en-US,en;q=0.9', 'Origin': 'https://www.applevis.com', 'Referer': 'https://www.applevis.com/',
    'X-App-Auth': auth,
}
FORUM_COMMENT_TYPE_UUID = 'e793db3b-8546-46b6-a0c8-6b7107c75a1a'  # CommentBundle.forumTopic.typeUuid
TEXT_FORMAT = '8'  # drupalDefaultTextFormat

jar = http.cookiejar.CookieJar()
signed_in = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
anonymous = urllib.request.build_opener()
csrf = ''

def call(opener, method, path, body=None, extra=None):
    headers = dict(BASE_HEADERS)
    headers['Accept'] = 'application/vnd.api+json'
    if extra: headers.update(extra)
    data = None
    if body is not None:
        data = json.dumps(body).encode('utf-8')
        headers.setdefault('Content-Type', 'application/vnd.api+json')
    req = urllib.request.Request(SITE + path, data=data, headers=headers, method=method)
    time.sleep(1)
    try:
        resp = opener.open(req, timeout=30)
        raw = resp.read().decode('utf-8')
        return resp.status, (json.loads(raw) if raw.strip() else {})
    except urllib.error.HTTPError as e:
        raw = e.read().decode('utf-8', 'ignore')
        try: return e.code, json.loads(raw)
        except Exception: return e.code, {'raw': raw[:300]}

def sign_in():
    global csrf
    user, pw = os.environ.get('APPLEVIS_TEST_USER'), os.environ.get('APPLEVIS_TEST_PASS')
    if not user or not pw:
        sys.exit('Set APPLEVIS_TEST_USER and APPLEVIS_TEST_PASS.')
    status, body = call(signed_in, 'POST', 'user/login?_format=json', {'name': user, 'pass': pw},
                        {'Content-Type': 'application/json', 'Accept': 'application/json'})
    if status != 200:
        sys.exit(f'Sign-in failed: HTTP {status}')
    csrf = body.get('csrf_token', '')
    uid = body.get('current_user', {}).get('uid')
    print(f'Signed in as {body.get("current_user", {}).get("name")} (uid {uid}).')
    return uid

def check():
    uid = sign_in()
    status, body = call(signed_in, 'GET', f'jsonapi/user/user?filter[drupal_internal__uid]={uid}&include=roles')
    roles = [r.get('attributes', {}).get('label') or r.get('id') for r in body.get('included', [])]
    print('Roles:', roles or '(only the default member role)')
    status, body = call(anonymous, 'GET', 'jsonapi/taxonomy_term/forums?fields[taxonomy_term--forums]=name,drupal_internal__tid&sort=name&page[limit]=100')
    print('\nForums (term id: name):')
    for t in body.get('data', []):
        print(f'  {t["attributes"]["drupal_internal__tid"]}: {t["attributes"]["name"]}')

def step(label, ok, detail=''):
    print(('PASS' if ok else 'FAIL'), '|', label, ('| ' + detail) if detail else '')
    return ok

def run(tid, with_subjects=True):
    sign_in()
    w = {'X-CSRF-Token': csrf}
    status, body = call(anonymous, 'GET', f'jsonapi/taxonomy_term/forums?filter[drupal_internal__tid]={tid}')
    terms = body.get('data', [])
    if not terms: sys.exit(f'No forum with term id {tid}.')
    forum_uuid, forum_name = terms[0]['id'], terms[0]['attributes']['name']
    print(f'Forum: {forum_name}\n')

    stamp = time.strftime('%Y-%m-%d %H:%M')
    topic_body = {'data': {'type': 'node--forum', 'attributes': {
        'title': f'App test, please ignore ({stamp})',
        'body': {'value': 'Automated test of the AppleVis app. This topic is unpublished and will be deleted in a moment.', 'format': TEXT_FORMAT},
        'status': False,
    }, 'relationships': {'taxonomy_forums': {'data': {'type': 'taxonomy_term--forums', 'id': forum_uuid}}}}}
    status, body = call(signed_in, 'POST', 'jsonapi/node/forum', topic_body, w)
    if not step('Create topic', status == 201, f'HTTP {status}'):
        print(json.dumps(body)[:500]); return
    topic = body['data']; tid_uuid = topic['id']
    published = topic['attributes'].get('status')
    forum_rel = (topic['relationships'].get('taxonomy_forums', {}).get('data') or {}).get('id')
    step('Topic has its forum', forum_rel == forum_uuid)
    if published:
        step('Topic is unpublished', False, 'the site published it anyway: deleting now and stopping')
        status, _ = call(signed_in, 'DELETE', f'jsonapi/node/forum/{tid_uuid}', None, w)
        step('Emergency delete', status == 204, f'HTTP {status}')
        return
    step('Topic is unpublished', True)
    status, _ = call(anonymous, 'GET', f'jsonapi/node/forum/{tid_uuid}')
    step('Hidden from anonymous visitors', status in (403, 404), f'HTTP {status}')

    try:
        comment_body = {'data': {'type': 'comment--comment_forum', 'attributes': {
            'entity_type': 'node', 'field_name': 'comment_forum',
            'comment_body': {'value': 'Automated test comment.', 'format': TEXT_FORMAT}},
            'relationships': {'entity_id': {'data': {'type': 'node--forum', 'id': tid_uuid}},
                              'comment_type': {'data': {'type': 'comment_type--comment_type', 'id': FORUM_COMMENT_TYPE_UUID}}}}}
        if with_subjects:
            comment_body['data']['attributes']['subject'] = 'Test comment'
        status, body = call(signed_in, 'POST', 'jsonapi/comment/comment_forum', comment_body, w)
        comment_id = body.get('data', {}).get('id') if status == 201 else None
        step('Post a comment on the topic', bool(comment_id), f'HTTP {status}')
        if comment_id and not with_subjects:
            print('   Subject the site gave the comment:', repr(body['data']['attributes'].get('subject')))
        elif not comment_id:
            print('   ', json.dumps(body)[:400])

        reply_id = None
        if comment_id:
            reply = json.loads(json.dumps(comment_body))
            if with_subjects:
                reply['data']['attributes']['subject'] = 'Test reply'
            else:
                reply['data']['attributes'].pop('subject', None)
            reply['data']['attributes']['comment_body']['value'] = 'Automated test reply to the comment.'
            reply['data']['relationships']['pid'] = {'data': {'type': 'comment--comment_forum', 'id': comment_id}}
            status, body = call(signed_in, 'POST', 'jsonapi/comment/comment_forum', reply, w)
            reply_id = body.get('data', {}).get('id') if status == 201 else None
            parent = ((body.get('data', {}).get('relationships', {}).get('pid', {}) or {}).get('data') or {}).get('id')
            step('Reply to the comment', bool(reply_id), f'HTTP {status}')
            if reply_id and not with_subjects:
                print('   Subject the site gave the reply:', repr(body['data']['attributes'].get('subject')))
            step('Reply is linked to its comment', parent == comment_id)

        if reply_id:
            status, _ = call(signed_in, 'DELETE', f'jsonapi/comment/comment_forum/{reply_id}', None, w)
            step('Delete the reply', status == 204, f'HTTP {status}')
        if comment_id:
            status, _ = call(signed_in, 'DELETE', f'jsonapi/comment/comment_forum/{comment_id}', None, w)
            step('Delete the comment', status == 204, f'HTTP {status}')
    finally:
        status, _ = call(signed_in, 'DELETE', f'jsonapi/node/forum/{tid_uuid}', None, w)
        step('Delete the topic', status == 204, f'HTTP {status}')
        status, _ = call(signed_in, 'GET', f'jsonapi/node/forum/{tid_uuid}')
        step('Topic is gone', status == 404, f'HTTP {status}')

def app_subject(body, parent=None):
    """CommentSubject.make, for a blank Subject field."""
    if parent:
        base = parent
        while base.lower().startswith('re:'):
            base = base[3:].strip()
        return ('Re: ' + base)[:64]
    lines = [l for l in body.splitlines() if not l.strip().startswith('>') and not l.strip().endswith(' wrote:')]
    words = ' '.join(' '.join(lines).split())
    if len(words) <= 29:
        return words
    cut = words[:28]
    return (cut[:cut.rfind(' ')] if ' ' in cut else cut).strip() + '\u2026'

def run_replies(tid):
    sign_in()
    w = {'X-CSRF-Token': csrf}
    status, body = call(anonymous, 'GET', f'jsonapi/taxonomy_term/forums?filter[drupal_internal__tid]={tid}')
    terms = body.get('data', [])
    if not terms: sys.exit(f'No forum with term id {tid}.')
    forum_uuid, forum_name = terms[0]['id'], terms[0]['attributes']['name']
    print(f'Forum: {forum_name}\n')
    stamp = time.strftime('%Y-%m-%d %H:%M')
    topic_body = {'data': {'type': 'node--forum', 'attributes': {
        'title': f'App test, please ignore ({stamp})',
        'body': {'value': 'Automated test of the AppleVis app. This topic is unpublished and will be deleted in a moment.', 'format': TEXT_FORMAT},
        'status': False,
    }, 'relationships': {'taxonomy_forums': {'data': {'type': 'taxonomy_term--forums', 'id': forum_uuid}}}}}
    status, body = call(signed_in, 'POST', 'jsonapi/node/forum', topic_body, w)
    if not step('Create topic', status == 201, f'HTTP {status}'):
        print(json.dumps(body)[:500]); return
    topic = body['data']; topic_uuid = topic['id']; nid = topic['attributes'].get('drupal_internal__nid')
    if topic['attributes'].get('status'):
        step('Topic is unpublished', False, 'published anyway: deleting now')
        call(signed_in, 'DELETE', f'jsonapi/node/forum/{topic_uuid}', None, w)
        return
    step('Topic is unpublished', True)
    status, _ = call(anonymous, 'GET', f'jsonapi/node/forum/{topic_uuid}')
    step('Hidden from anonymous visitors', status in (403, 404), f'HTTP {status}')

    def comment(text, subject, parent_uuid=None):
        payload = {'data': {'type': 'comment--comment_forum', 'attributes': {
            'entity_type': 'node', 'field_name': 'comment_forum', 'subject': subject,
            'comment_body': {'value': text, 'format': TEXT_FORMAT}},
            'relationships': {'entity_id': {'data': {'type': 'node--forum', 'id': topic_uuid}},
                              'comment_type': {'data': {'type': 'comment_type--comment_type', 'id': FORUM_COMMENT_TYPE_UUID}}}}}
        if parent_uuid:
            payload['data']['relationships']['pid'] = {'data': {'type': 'comment--comment_forum', 'id': parent_uuid}}
        return call(signed_in, 'POST', 'jsonapi/comment/comment_forum', payload, w)

    made = []
    try:
        text1 = 'Automated test comment from the AppleVis app. Please ignore it.'
        subject1 = app_subject(text1)
        status, body = comment(text1, subject1)
        c1 = body.get('data') if status == 201 else None
        step('Post a comment (blank Subject, so its first words)', bool(c1), f'HTTP {status}')
        if not c1:
            print('   ', json.dumps(body)[:400]); return
        made.append(c1['id'])
        a1 = c1['attributes']
        step('Comment subject saved', a1.get('subject') == subject1, repr(a1.get('subject')))

        text2 = 'Oliver wrote:\n> Automated test comment.\n\nAutomated test reply to that comment.'
        subject2 = app_subject(text2, parent=a1.get('subject'))
        status, body = comment(text2, subject2, parent_uuid=c1['id'])
        c2 = body.get('data') if status == 201 else None
        step('Reply to the comment', bool(c2), f'HTTP {status}')
        if not c2:
            print('   ', json.dumps(body)[:400]); return
        made.append(c2['id'])
        a2 = c2['attributes']
        parent = ((c2.get('relationships', {}).get('pid', {}) or {}).get('data') or {}).get('id')
        step('Reply subject is Re: and the comment subject', a2.get('subject') == subject2, repr(a2.get('subject')))
        step('Reply is linked to its comment', parent == c1['id'])
        t1, t2 = (a1.get('thread') or ''), (a2.get('thread') or '')
        step('Reply is threaded under the comment, like a website reply', t2.startswith(t1.rstrip('/') + '.'), f'{t1} then {t2}')

        h = dict(BASE_HEADERS); h['Accept'] = 'text/html'
        req = urllib.request.Request(SITE + f'node/{nid}', headers=h)
        page = signed_in.open(req, timeout=30).read().decode('utf-8', 'ignore')
        c1_id, c2_id = a1.get('drupal_internal__cid'), a2.get('drupal_internal__cid')
        i1, i2 = page.find(f'comment-{c1_id}'), page.find(f'comment-{c2_id}')
        step('Website page shows both', i1 != -1 and i2 != -1, f'{i1} {i2}')
        # The site lists comments flat; a reply carries "In reply to
        # <comment>" linking its parent (checked against a website reply).
        j = page.find('<article', i2 + 10) if i2 != -1 else -1
        reply_html = page[i2:j if j != -1 else i2 + 8000] if i2 != -1 else ''
        step('Website page shows the reply as In reply to the comment',
             'comment__in-reply-to' in reply_html and f'/comment/{c1_id}' in reply_html)
        step('Website page shows the reply subject', subject2 in page)
    finally:
        for cid in reversed(made):
            status, _ = call(signed_in, 'DELETE', f'jsonapi/comment/comment_forum/{cid}', None, w)
            step('Delete a test comment', status == 204, f'HTTP {status}')
        status, _ = call(signed_in, 'DELETE', f'jsonapi/node/forum/{topic_uuid}', None, w)
        step('Delete the topic', status == 204, f'HTTP {status}')
        status, _ = call(signed_in, 'GET', f'jsonapi/node/forum/{topic_uuid}')
        step('Topic is gone', status == 404, f'HTTP {status}')

APP_TYPES = {
    'ios': ('ios_app_directory', 'taxonomy_vocabulary_1', 'vocabulary_1', 'categoryUUIDs'),
    'tv': ('tv_directory', 'field_category_tv', 'apple_tb_app_directory', 'tvCategoryUUIDs'),
    'watch': ('watch_directory', 'field_category_watch', 'apple_watch_app_directory', 'watchCategoryUUIDs'),
    'mac': ('mac_app_directory', 'taxonomy_vocabulary_16', 'vocabulary_16', 'macCategoryUUIDs'),
}

def swift_table(name):
    src = open(os.path.join(ROOT, 'AppleVis', 'Sources', 'Networking', 'Endpoints', 'AppEndpoints.swift'), encoding='utf-8').read()
    block = re.search(r'static let ' + name + r': \[String: String\] = \[(.*?)\n    \]', src, re.S).group(1)
    return dict(re.findall(r'"([^"]+)": "([0-9a-f-]{36})"', block))

def apps_check():
    sign_in()
    for platform, (node, field, vocab, table) in APP_TYPES.items():
        app = swift_table(table)
        status, body = call(signed_in, 'GET', f'jsonapi/taxonomy_term/{vocab}?fields[taxonomy_term--{vocab}]=name&page[limit]=100')
        live = {t['attributes']['name'].replace(' & ', ' and '): t['id'] for t in body.get('data', [])}
        bad = [n for n, u in app.items() if live.get(n) != u]
        extra = [n for n in live if n not in app]
        print(f'{platform}: {len(app)} app categories, {len(live)} live (HTTP {status})',
              ('| mismatched: ' + ', '.join(bad)) if bad else '| all match',
              ('| live only: ' + ', '.join(extra)) if extra else '')
        headers = dict(BASE_HEADERS); headers['Accept'] = 'text/html'
        req = urllib.request.Request(SITE + f'node/add/{node}', headers=headers)
        time.sleep(1)
        try:
            html = signed_in.open(req, timeout=30).read().decode('utf-8', 'ignore')
        except urllib.error.HTTPError as e:
            print(f'  form: HTTP {e.code}'); continue
        print('  form has a Published checkbox:', 'name="status[value]"' in html)
        for sel in re.finditer(r'<select[^>]*name="(field_[a-z_0-9]+)[^"]*"[^>]*>(.*?)</select>', html, re.S):
            opts = re.findall(r'<option[^>]*value="([^"]*)"', sel.group(2))
            if sel.group(1).startswith('field_category') or len(opts) > 30: continue
            print(f'  {sel.group(1)}: {opts}')
        for box in sorted(set(re.findall(r'name="(field_device_used)\[([^\]]+)\]"', html))):
            print('  checkbox', box)

def app_attributes(platform, stamp):
    rich = lambda v: {'value': v, 'format': TEXT_FORMAT}
    a = {'title': f'App test, please ignore ({stamp})',
         'field_comments': rich('Automated test of the AppleVis app. This entry is unpublished and will be deleted in a moment.'),
         'body': {'value': 'Test description.', 'summary': '', 'format': TEXT_FORMAT},
         'field_cost': 'Free'}
    if platform in ('ios', 'watch', 'mac'):
        a['field_version'] = '1.0'
        a['field_link2'] = {'uri': 'https://apps.apple.com/app/id1', 'title': ''}
    if platform == 'ios':
        a.update({'field_device_used': ['iPhone', '1'], 'field_ios_version': '26.0',
                  'field_voiceover': 'VoiceOver reads all page elements.',
                  'field_labelling': 'All buttons are clearly labeled.',
                  'field_usability': 'The app is fully accessible with VoiceOver and is easy to navigate and use.'})
    elif platform == 'tv':
        a['field_usability_tv'] = 'Fully Accessible'
    elif platform == 'watch':
        a.update({'field_watchos_version': '26.0', 'field_usability_watch': 'Fully Accessible'})
    elif platform == 'mac':
        a.update({'field_osx_version': '26.0',
                  'field_usability': 'The app is fully accessible with VoiceOver and is easy to navigate and use.'})
    return a

def real_ios_attributes(app_id, country):
    """What SubmitAppView's applyMetadata fills in for an iOS entry."""
    req = urllib.request.Request(f'https://itunes.apple.com/lookup?id={app_id}&country={country}')
    r = json.loads(urllib.request.urlopen(req, timeout=30).read().decode('utf-8'))['results'][0]
    families = set()
    for d in r.get('supportedDevices', []):
        for fam, val in (('iPhone', 'iPhone'), ('iPad', '1')):
            if d.startswith(fam): families.add(val)
    a = app_attributes('ios', '')
    a.update({'title': r['trackName'] + ' TEST, please ignore',
              'field_version': r['version'],
              'field_cost': 'Free' if not r.get('price') else 'Paid',
              'field_device_used': [v for v in ('iPhone', '1') if v in families],
              'field_link2': {'uri': r['trackViewUrl'], 'title': ''},
              'body': {'value': r['description'], 'summary': '', 'format': TEXT_FORMAT}})
    # Ratings and comments are the submitter's own; pick them at random.
    import random
    a['field_voiceover'] = random.choice(VOICEOVER + ['Not applicable for this app'])
    a['field_labelling'] = random.choice(LABELLING + ['Not applicable for this app'])
    a['field_usability'] = random.choice(USABILITY)
    a['field_comments'] = {'value': random.choice(COMMENTS), 'format': TEXT_FORMAT}
    return a, r.get('primaryGenreName', '')

VOICEOVER = ['VoiceOver reads all page elements.', 'VoiceOver reads most page elements.', 'VoiceOver reads a few page elements.', 'VoiceOver reads no page elements.']
LABELLING = ['All buttons are clearly labeled.', 'Most buttons are clearly labeled.', 'Few buttons are clearly labeled.', 'No buttons are clearly labeled.']
USABILITY = ['The app is fully accessible with VoiceOver and is easy to navigate and use.',
             'The app is fully accessible with VoiceOver, but the interface could be easier to navigate and use.',
             'There are some minor accessibility issues with this app, but they are easy to deal with.',
             'Some parts of the app are accessible with VoiceOver, but not enough to make it usable.']
COMMENTS = ['Automated test. Most of the app works well with VoiceOver, though the player controls are unlabelled.',
            "Automated test. Signing in is fine, but the channel guide can't be reached with swipes.",
            'Automated test. Everything is labelled and easy to use with VoiceOver.']

def run_app(platform, with_status, real=None):
    node, field, vocab, table = APP_TYPES[platform]
    sign_in()
    w = {'X-CSRF-Token': csrf}
    categories = swift_table(table)
    category_name, category_uuid = next(iter(categories.items()))
    attrs = app_attributes(platform, time.strftime('%Y-%m-%d %H:%M'))
    if real:
        attrs, genre = real_ios_attributes(*real)
        print(f'Using the App Store listing: {attrs["title"]!r}, version {attrs["field_version"]!r}, devices {attrs["field_device_used"]}, category {genre!r}')
        if genre not in categories:
            print('   (the app has no category ID for this name, so like the app this sends no category)')
        category_name, category_uuid = genre, categories.get(genre)
    rels = {field: {'data': {'type': f'taxonomy_term--{vocab}', 'id': category_uuid}}} if category_uuid else {}
    attrs['status'] = False  # never publish a test entry
    doc = {'data': {'type': f'node--{node}', 'attributes': attrs, 'relationships': rels}}
    status, body = call(signed_in, 'POST', f'jsonapi/node/{node}', doc, w)
    if not step(f'Create {platform} entry', status == 201, f'HTTP {status}'):
        for e in body.get('errors', []):
            print('   ', e.get('title'), '|', e.get('detail'), '|', (e.get('source') or {}).get('pointer', ''))
        if not body.get('errors'): print('   ', json.dumps(body)[:500])
        return
    entry = body['data']; uuid = entry['id']
    try:
        published = entry['attributes'].get('status')
        print(f'   stored as {"PUBLISHED" if published else "unpublished"}, nid {entry["attributes"].get("drupal_internal__nid")}')
        if published:
            step('Entry is unpublished', False, 'the site published it: deleting now')
            return
        rel = entry['relationships'].get(field, {}).get('data') or {}
        rel = rel[0] if isinstance(rel, list) and rel else rel
        step(f'Category kept ({category_name})', isinstance(rel, dict) and rel.get('id') == category_uuid)
        for k, v in attrs.items():
            if k in ('status', 'body', 'field_comments', 'title'): continue
            got = entry['attributes'].get(k)
            if isinstance(v, dict): got = (got or {}).get('uri'); v = v['uri']
            step(f'Field {k} stored', got == v, '' if got == v else f'sent {v!r}, got {got!r}')
        status, _ = call(anonymous, 'GET', f'jsonapi/node/{node}/{uuid}')
        step('Hidden from anonymous visitors', status in (403, 404), f'HTTP {status}')
    finally:
        status, _ = call(signed_in, 'DELETE', f'jsonapi/node/{node}/{uuid}', None, w)
        step('Delete the entry', status == 204, f'HTTP {status}')
        status, _ = call(signed_in, 'GET', f'jsonapi/node/{node}/{uuid}')
        step('Entry is gone', status == 404, f'HTTP {status}')

IOS_APP_COMMENT_TYPE_UUID = 'ee475b17-740d-4521-b17f-07ca26fd1ee8'  # CommentBundle.iosApp.typeUuid

def run_replies_app():
    node, field, vocab, table = APP_TYPES['ios']
    sign_in()
    w = {'X-CSRF-Token': csrf}
    categories = swift_table(table)
    category_name, category_uuid = next(iter(categories.items()))
    attrs = app_attributes('ios', time.strftime('%Y-%m-%d %H:%M'))
    attrs['status'] = False
    rels = {field: {'data': {'type': f'taxonomy_term--{vocab}', 'id': category_uuid}}}
    status, body = call(signed_in, 'POST', f'jsonapi/node/{node}', {'data': {'type': f'node--{node}', 'attributes': attrs, 'relationships': rels}}, w)
    if not step('Create an unpublished App Directory entry', status == 201, f'HTTP {status}'):
        print('   ', json.dumps(body)[:500]); return
    entry = body['data']; uuid = entry['id']; nid = entry['attributes'].get('drupal_internal__nid')
    made = []
    bundle = 'comment_node_ios_app_directory'
    try:
        if entry['attributes'].get('status'):
            step('Entry is unpublished', False, 'published anyway: deleting now'); return
        step('Entry is unpublished', True)
        status, _ = call(anonymous, 'GET', f'jsonapi/node/{node}/{uuid}')
        step('Hidden from anonymous visitors', status in (403, 404), f'HTTP {status}')

        def comment(text, subject, parent_uuid=None):
            payload = {'data': {'type': f'comment--{bundle}', 'attributes': {
                'entity_type': 'node', 'field_name': bundle, 'subject': subject,
                'comment_body': {'value': text, 'format': TEXT_FORMAT}},
                'relationships': {'entity_id': {'data': {'type': f'node--{node}', 'id': uuid}},
                                  'comment_type': {'data': {'type': 'comment_type--comment_type', 'id': IOS_APP_COMMENT_TYPE_UUID}}}}}
            if parent_uuid:
                payload['data']['relationships']['pid'] = {'data': {'type': f'comment--{bundle}', 'id': parent_uuid}}
            return call(signed_in, 'POST', f'jsonapi/comment/{bundle}', payload, w)

        text1 = 'Automated test comment from the AppleVis app. Please ignore it.'
        subject1 = app_subject(text1)
        status, body = comment(text1, subject1)
        c1 = body.get('data') if status == 201 else None
        step('Post a comment', bool(c1), f'HTTP {status}')
        if not c1:
            print('   ', json.dumps(body)[:400]); return
        made.append(c1['id'])
        a1 = c1['attributes']

        text2 = 'Automated test reply to that comment.'
        subject2 = app_subject(text2, parent=a1.get('subject'))
        status, body = comment(text2, subject2, parent_uuid=c1['id'])
        c2 = body.get('data') if status == 201 else None
        step('Reply to the comment', bool(c2), f'HTTP {status}')
        if not c2:
            print('   ', json.dumps(body)[:400]); return
        made.append(c2['id'])
        a2 = c2['attributes']
        parent = ((c2.get('relationships', {}).get('pid', {}) or {}).get('data') or {}).get('id')
        step('Reply subject is Re: and the comment subject', a2.get('subject') == subject2, repr(a2.get('subject')))
        step('Reply is linked to its comment', parent == c1['id'])
        t1, t2 = (a1.get('thread') or ''), (a2.get('thread') or '')
        step('Reply is threaded under the comment', t2.startswith(t1.rstrip('/') + '.'), f'{t1} then {t2}')

        status, listed = call(signed_in, 'GET', f'jsonapi/comment/{bundle}?filter[entity_id.id]={uuid}&sort=created')
        ids = {d['id']: ((d.get('relationships', {}).get('pid', {}) or {}).get('data') or {}).get('id') for d in listed.get('data', [])}
        step('Reading the comments back gives the reply its parent, as the app reads them', ids.get(c2['id']) == c1['id'])

        h = dict(BASE_HEADERS); h['Accept'] = 'text/html'
        req = urllib.request.Request(SITE + f'node/{nid}', headers=h)
        page = signed_in.open(req, timeout=30).read().decode('utf-8', 'ignore')
        c1_id, c2_id = a1.get('drupal_internal__cid'), a2.get('drupal_internal__cid')
        i2 = page.find(f'id="comment-{c2_id}"')
        j = page.find('<article', i2 + 10) if i2 != -1 else -1
        reply_html = page[i2:j if j != -1 else i2 + 8000] if i2 != -1 else ''
        step('Website page shows the reply as In reply to the comment',
             'comment__in-reply-to' in reply_html and f'/comment/{c1_id}' in reply_html)
    finally:
        for cid in reversed(made):
            status, _ = call(signed_in, 'DELETE', f'jsonapi/comment/{bundle}/{cid}', None, w)
            step('Delete a test comment', status == 204, f'HTTP {status}')
        status, _ = call(signed_in, 'DELETE', f'jsonapi/node/{node}/{uuid}', None, w)
        step('Delete the entry', status == 204, f'HTTP {status}')
        status, _ = call(signed_in, 'GET', f'jsonapi/node/{node}/{uuid}')
        step('Entry is gone', status == 404, f'HTTP {status}')

if __name__ == '__main__':
    if len(sys.argv) >= 2 and sys.argv[1] == 'check':
        check()
    elif len(sys.argv) >= 2 and sys.argv[1] == 'apps-check':
        apps_check()
    elif len(sys.argv) >= 3 and sys.argv[1] == 'run-app' and sys.argv[2] in APP_TYPES:
        real = None
        if len(sys.argv) >= 5 and sys.argv[3] == 'real':
            real = (sys.argv[4], sys.argv[5] if len(sys.argv) >= 6 else 'us')
        run_app(sys.argv[2], len(sys.argv) >= 4 and sys.argv[3] == 'status', real)
    elif len(sys.argv) >= 2 and sys.argv[1] == 'run-replies-app':
        run_replies_app()
    elif len(sys.argv) >= 3 and sys.argv[1] == 'run-replies':
        run_replies(int(sys.argv[2]))
    elif len(sys.argv) >= 3 and sys.argv[1] == 'run-subjects':
        run(int(sys.argv[2]), with_subjects=False)
    elif len(sys.argv) >= 3 and sys.argv[1] == 'run':
        run(int(sys.argv[2]))
    else:
        print(__doc__)
