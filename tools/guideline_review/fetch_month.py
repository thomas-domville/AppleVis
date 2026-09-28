"""Read-only fetch of the last N days of AppleVis posts and comments, using
the same JSON:API queries (and sparse fieldsets) as the in-app Guideline
Violation Check. Sequential, one request at a time, with a short pause."""
import json, time, sys, urllib.request, urllib.parse, datetime, os

DAYS = int(sys.argv[1]) if len(sys.argv) > 1 else 30
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), sys.argv[2] if len(sys.argv) > 2 else 'month.json')
BASE = 'https://www.applevis.com/jsonapi/'
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 AppleVis/2026',
    'Accept-Language': 'en-US,en;q=0.9',
    'Origin': 'https://www.applevis.com',
    'Referer': 'https://www.applevis.com/',
    'X-App-Auth': '2ff01dc7bf35469d93c6',
    'Accept': 'application/vnd.api+json',
}
STREAMS = [
    ('forum', 'comment_forum'), ('blog2', 'comment_node_blog2'), ('guides', 'comment_node_guides'),
    ('podcast', 'comment_node_podcast'), ('ios_app_directory', 'comment_node_ios_app_directory'),
    ('tv_directory', 'comment_node_tv_directory'), ('watch_directory', 'comment_node_watch_directory'),
    ('mac_app_directory', 'comment_node_mac_app_directory'), ('ios_bug_report', 'comment_node_ios_bug_report'),
    ('os_x_bug_report', 'comment_node_os_x_bug_report'),
]
cutoff = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=DAYS)
requests = 0

def get(path, query):
    global requests
    url = BASE + path + '?' + urllib.parse.urlencode(query)
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=60) as r:
        requests += 1
        data = json.load(r)
    time.sleep(0.4)
    return data

def created(node):
    return datetime.datetime.fromisoformat(node['attributes']['created'].replace('Z', '+00:00'))

def body_of(attr):
    v = attr or {}
    return (v.get('processed') or v.get('value') or '') if isinstance(v, dict) else str(v)

items = []
for node_type, bundle in STREAMS:
    for kind, path, fields in [
        ('post', f'node/{node_type}', {f'fields[node--{node_type}]': 'title,body,created,path,drupal_internal__nid,uid'}),
        ('comment', f'comment/{bundle}', {f'fields[comment--{bundle}]': 'comment_body,created,name,drupal_internal__cid,uid,entity_id',
                                           f'fields[node--{node_type}]': 'title,path,drupal_internal__nid'}),
    ]:
        page = 0
        while page < 100:
            q = {'sort': '-created', 'page[limit]': '50', 'page[offset]': str(page * 50),
                 'include': 'uid' if kind == 'post' else 'uid,entity_id', 'fields[user--user]': 'display_name,name'}
            q.update(fields)
            try:
                d = get(path, q)
            except Exception as e:
                print('  failed', path, page, e); break
            data = d.get('data', [])
            if not data: break
            inc = {x['id']: x for x in d.get('included', [])}
            done = False
            for n in data:
                if created(n) < cutoff:
                    done = True; break
                a = n['attributes']
                uid = ((n.get('relationships', {}).get('uid') or {}).get('data') or {}).get('id')
                author = (inc.get(uid, {}).get('attributes', {}) or {}).get('display_name') or a.get('name') or ''
                if kind == 'post':
                    items.append({'id': f'{node_type}-post-{n["id"]}', 'type': node_type, 'kind': 'post', 'isReply': False,
                                  'title': a.get('title', ''), 'author': author, 'created': a['created'],
                                  'text': body_of(a.get('body'))})
                else:
                    pid = ((n.get('relationships', {}).get('entity_id') or {}).get('data') or {}).get('id')
                    parent = inc.get(pid, {}).get('attributes', {}) or {}
                    cid = a.get('drupal_internal__cid')
                    items.append({'id': f'{bundle}-comment-{n["id"]}', 'type': node_type, 'kind': 'comment', 'isReply': True,
                                  'title': parent.get('title', ''), 'author': author, 'created': a['created'],
                                  'url': f'https://www.applevis.com/comment/{cid}#comment-{cid}' if cid else '',
                                  'text': body_of(a.get('comment_body'))})
            if done: break
            page += 1
        print(f'{node_type:20} {kind:8} total items so far: {len(items)}  requests: {requests}', flush=True)

json.dump(items, open(OUT, 'w', encoding='utf-8'), ensure_ascii=False)
print('saved', len(items), 'items with', requests, 'requests to', OUT)
