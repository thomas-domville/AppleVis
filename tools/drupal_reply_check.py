"""Check the three Drupal handoff items. Credentials stay in environment/memory.

Only temporary follow/recommend records created here are deleted. Existing
records are left intact. --mark-read updates one topic's test-account read
timestamp, which cannot be restored. Prints statuses, never secrets.
"""
import json
import os
from pathlib import Path
import re
import sys
import urllib.parse
import urllib.request
import urllib.error
import live_write_test as api


def query(path, params):
    return path + '?' + urllib.parse.urlencode(params)


def form(opener, ids):
    body = urllib.parse.urlencode([(f'node_ids[{i}]', n) for i, n in enumerate(ids)]).encode()
    headers = dict(api.BASE_HEADERS, **{'Content-Type': 'application/x-www-form-urlencoded',
                                      'Accept': 'application/json', 'X-CSRF-Token': api.csrf})
    request = urllib.request.Request(api.SITE + 'history/get_node_read_timestamps', data=body, headers=headers)
    try:
        with opener.open(request, timeout=30) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, None


def main():
    if not os.environ.get('APPLEVIS_TEST_PASS'):
        memory = Path.home() / '.claude/projects/c--Users-thoma-dev-AppleVis/memory/reference_snorlax_test_account.md'
        match = re.search(r'Username `([^`]+)`, password `([^`]+)`', memory.read_text(encoding='utf-8'))
        if not match:
            raise SystemExit('Test credentials unavailable')
        os.environ['APPLEVIS_TEST_USER'], os.environ['APPLEVIS_TEST_PASS'] = match.groups()
    logout_token = ''
    original_call = api.call
    def capture_login(*args, **kwargs):
        nonlocal logout_token
        status, response = original_call(*args, **kwargs)
        if len(args) > 2 and args[2] == 'user/login?_format=json' and isinstance(response, dict):
            logout_token = response.get('logout_token', '')
        return status, response
    api.call = capture_login
    uid = api.sign_in()
    status, users = api.call(api.signed_in, 'GET', query('jsonapi/user/user', {'filter[drupal_internal__uid]': uid}))
    if status != 200 or not users.get('data'):
        raise SystemExit('Could not resolve signed-in user UUID')
    owner = users['data'][0]['id']
    status, recent = api.call(api.anonymous, 'GET', 'api/v1/forums/recent?page=0')
    rows = recent if isinstance(recent, list) else []
    print('RECENT', status, 'rows', len(rows), 'sticky present', sum('sticky' in x for x in rows),
          'sticky types', sorted(set(type(x.get('sticky')).__name__ for x in rows)),
          'pinned', sum(str(x.get('sticky')) == '1' for x in rows))
    status, topics = api.call(api.signed_in, 'GET', query('jsonapi/node/forum', {
        'page[limit]': '3', 'sort': '-created', 'fields[node--forum]': 'drupal_internal__nid,title,sticky'}))
    forum_nodes = topics.get('data', []) if status == 200 else []
    if not forum_nodes:
        raise SystemExit('No topic available for checks')
    ids = [x['attributes']['drupal_internal__nid'] for x in forum_nodes]
    status, timestamps = form(api.signed_in, ids)
    print('HISTORY signed-in', status, 'valid mapping', isinstance(timestamps, dict) and
          all(isinstance(timestamps.get(str(n)), int) for n in ids),
          'nonzero', sum(v > 0 for v in timestamps.values()) if isinstance(timestamps, dict) else 0)
    status, _ = form(api.anonymous, ids)
    print('HISTORY anonymous', status)
    if '--mark-read' in sys.argv:
        nid = ids[0]
        status, written = api.call(api.signed_in, 'POST', f'history/{nid}/read', {},
                                  {'Content-Type': 'application/json', 'Accept': 'application/json', 'X-CSRF-Token': api.csrf})
        print('HISTORY WRITE', status, 'positive timestamp', isinstance(written, int) and written > 0)
        status, reread = form(api.signed_in, [nid])
        print('HISTORY ROUND TRIP', status, 'timestamp matches', isinstance(reread, dict) and reread.get(str(nid)) == written)
    for bundle, node_path in [('subscribe_node', 'forum'), ('recommend', 'ios_app_directory')]:
        status, existing = api.call(api.signed_in, 'GET', query(f'jsonapi/flagging/{bundle}', {
            'filter[uid.id]': owner, 'include': 'flagged_entity', 'sort': '-created', 'page[limit]': '50'}))
        print('OWN LIST', bundle, status, 'records', len(existing.get('data', [])))
        existing_targets = {str(x.get('attributes', {}).get('entity_id')) for x in existing.get('data', [])}
        status, nodes = api.call(api.signed_in, 'GET', query(f'jsonapi/node/{node_path}', {
            'page[limit]': '10', 'sort': '-created', f'fields[node--{node_path}]': 'drupal_internal__nid'}))
        target = next((x for x in nodes.get('data', []) if str(x['attributes']['drupal_internal__nid']) not in existing_targets), None)
        if not target:
            print('SKIP', bundle, 'no suitable target')
            continue
        nid = target['attributes']['drupal_internal__nid']
        params = {'filter[uid.id]': owner, 'filter[entity_id]': str(nid)}
        status, before = api.call(api.signed_in, 'GET', query(f'jsonapi/flagging/{bundle}', params))
        if status != 200 or before.get('data'):
            print('SKIP', bundle, 'pre-existing or inaccessible record')
            continue
        created = None
        try:
            status, result = api.call(api.signed_in, 'POST', f'jsonapi/flagging/{bundle}', {'data': {
                'type': f'flagging--{bundle}', 'attributes': {'entity_type': 'node', 'entity_id': str(nid)},
                'relationships': {'flagged_entity': {'data': {'type': target['type'], 'id': target['id']}}}
            }}, {'X-CSRF-Token': api.csrf})
            print('CREATE', bundle, status)
            if status != 201:
                continue
            created = result['data']['id']
            created_owner = result['data'].get('relationships', {}).get('uid', {}).get('data') or {}
            print('CREATED OWNER MATCHES', bundle, created_owner.get('id') == owner)
            status, unfiltered = api.call(api.signed_in, 'GET', query(f'jsonapi/flagging/{bundle}', {
                'sort': '-created', 'page[limit]': '50'}))
            print('UNFILTERED LOOKUP', bundle, status, 'created record found',
                  any(x['id'] == created for x in unfiltered.get('data', [])))
            for label, filters in [('uid', {'filter[uid.id]': owner}),
                                   ('entity_id', {'filter[entity_id]': str(nid)}), ('combined', params)]:
                status, found = api.call(api.signed_in, 'GET', query(f'jsonapi/flagging/{bundle}', filters))
                record = next((x for x in found.get('data', []) if x['id'] == created), None)
                relation = (record or {}).get('relationships', {}).get('flagged_entity', {}).get('data', {})
                print('LOOKUP', bundle, label, status, 'created record found', bool(record),
                      'relationship matches', isinstance(relation, dict) and relation.get('id') == target['id'])
            status, _ = api.call(api.anonymous, 'DELETE', f'jsonapi/flagging/{bundle}/{created}', extra={'X-CSRF-Token': api.csrf})
            print('ANONYMOUS DELETE', bundle, status)
        finally:
            if created:
                status, _ = api.call(api.signed_in, 'DELETE', f'jsonapi/flagging/{bundle}/{created}', extra={'X-CSRF-Token': api.csrf})
                print('CLEANUP DELETE', bundle, status)
                check_status, _ = api.call(api.signed_in, 'GET', f'jsonapi/flagging/{bundle}/{created}')
                print('CLEANUP VERIFIED', bundle, status == 204 and check_status == 404)
    status, _ = api.call(api.signed_in, 'POST', query('user/logout', {'_format': 'json', 'token': logout_token}), {},
                         {'X-CSRF-Token': api.csrf, 'Content-Type': 'application/json'})
    print('LOGOUT', status)


if __name__ == '__main__':
    main()
