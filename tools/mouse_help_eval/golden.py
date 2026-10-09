"""Ask the Mouse's golden questions: one check to run before each release.

    python golden.py            compare with the saved snapshot
    python golden.py --update   save today's results as the new snapshot
    python golden.py --add-new  add searches the snapshot doesn't have yet

1. Runs the Help and How-To question tests (test_help_questions.py and
   test_howto_questions.py, offline).
2. Repeats every live-site search from the three question batches
   (read-only, about one request a second) and compares the top results with
   golden.json. A question whose results came back empty, or lost results
   that used to be there, is listed, so a change that hurts the Mouse's
   searching shows up before release.

Only the searching is checked. Apple Intelligence's wording runs on device.
golden.json holds public page titles only, so it can be committed.
"""
import json, os, subprocess, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.stdout.reconfigure(encoding='utf-8')
import live_site_questions as L1
import live_site_questions_2 as L2
import live_site_questions_3 as L3
import live_site_questions_4 as L4
import live_site_questions_5 as L5

SNAPSHOT = os.path.join(HERE, 'golden.json')


def searches():
    """Every (label, kind, run) search in the three batches."""
    out = []
    for question, plan in L1.QUESTIONS:
        for phrase, kind in plan.get('site', []):
            out.append((f'{question} | {kind} "{phrase}"', lambda p=phrase, k=kind: L1.site(p, k, 5)))
        if 'apps' in plan:
            kw, platform, cat, full = plan['apps']
            out.append((f'{question} | apps {platform} "{kw}"', lambda a=(kw, platform, cat, full): L1.apps(*a)))
    for question, phrase, kinds, _app in L2.QUESTIONS:
        for kind in kinds:
            out.append((f'{question} | {kind} "{phrase}"', lambda p=phrase, k=kind: L1.site(p, k, 5)))
    for question, phrase, kinds, app in L3.QUESTIONS:
        for kind in kinds:
            out.append((f'{question} | {kind} "{phrase}"', lambda p=phrase, k=kind: L1.site(p, k, 5)))
        if app:
            kw, platform, cat, full = app
            out.append((f'{question} | apps {platform} "{kw}"', lambda a=(kw, platform, cat, full): L1.apps(*a)))
    # Batch 4 (2026-10-08): App Directory questions, ranked the way the app
    # ranks them, as the 15 apps Apple Intelligence is given.
    # Batch 5 (2026-10-09): more kinds of App Directory questions, ranked the
    # same way.
    for question, app, sites, name in L4.QUESTIONS + L5.QUESTIONS:
        if app:
            kw, platform, cat, full = app
            def ranked(a=(kw, platform, cat, full)):
                top, err, _ = L4.mouse_apps(*a)
                return [t for t, _tier in top], err
            out.append((f'{question} | mouse apps {platform} "{kw}"', ranked))
        for phrase, kind in sites or []:
            out.append((f'{question} | {kind} "{phrase}"', lambda p=phrase, k=kind: L1.site(p, k, 5)))
        if name:
            out.append((f'{question} | app named "{name}"', lambda n=name: L2.app_by_name(n)))
    return out


def main():
    update = '--update' in sys.argv
    # Saves only searches the snapshot doesn't have yet, so adding a batch
    # doesn't reset what the older ones are compared with.
    add_new = '--add-new' in sys.argv
    print('1. Help questions')
    # The How-To Library questions, and the everyday question batches,
    # too (2026-10-09).
    for script in ('test_help_questions.py', 'test_howto_questions.py', 'test_question_batches.py'):
        help_run = subprocess.run([sys.executable, os.path.join(HERE, script)],
                                  capture_output=True, text=True, encoding='utf-8')
        summary = [l for l in help_run.stdout.splitlines() if 'passed' in l]
        failures = [l for l in help_run.stdout.splitlines() if l.startswith(' - ')]
        print('  ', script, summary[-1] if summary else help_run.stdout[-300:])
        for line in failures:
            print('  ', line)

    print('\n2. Live-site searches (read-only)')
    saved = json.load(open(SNAPSHOT, encoding='utf-8')) if os.path.exists(SNAPSHOT) else {}
    now, problems = {}, []
    for label, run in searches():
        titles, err = run()
        # App Directory questions keep all 15 apps Apple Intelligence reads:
        # an app that moved from third to twelfth is still read, so only
        # leaving the 15 counts as lost (2026-10-09).
        keep = 15 if '| mouse apps ' in label else 5
        titles = list(titles[:keep]) if titles else []
        now[label] = titles
        if err:
            problems.append(f'ERROR  {label}: {err}')
        elif not titles:
            problems.append(f'EMPTY  {label}')
        elif label in saved:
            lost = [t for t in saved[label][:3] if t not in titles]
            if lost:
                problems.append(f'LOST   {label}: {"; ".join(lost)}')
        time.sleep(0.5)
    print(f'   {len(now)} searches')
    for p in problems:
        print('  ', p)
    if not problems:
        print('   All searches still find what they found before.')
    if update:
        json.dump(now, open(SNAPSHOT, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
        print(f'\nSaved {len(now)} searches as the new snapshot.')
    elif add_new:
        added = {k: v for k, v in now.items() if k not in saved and v}
        json.dump({**saved, **added}, open(SNAPSHOT, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
        print(f'\nAdded {len(added)} new searches to the snapshot.')


if __name__ == '__main__':
    main()
