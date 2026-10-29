#!/usr/bin/env python3
"""Validate the single activity registry; fail-closed publication gate. Stdlib only."""
import argparse
from collections import Counter
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
DEFAULT = ROOT / 'docs/plans/systemic-ux/activity.json'
STATES = {'queued', 'running', 'review', 'verified', 'blocked', 'failed'}
if not __debug__:
    raise SystemExit('Activity validation requires assertions; optimized mode is forbidden')


def validate(data, root=ROOT):
    issues, tasks = data['issues'], data['tasks']
    assert data['schema'] == 1 and issues and tasks, 'Missing or empty registry'
    assert data['provider']['max_concurrent'] == 1, 'Studio workers must be serial'
    issue_ids = [i['id'] for i in issues]
    ids = [t['id'] for t in tasks]
    assert len(set(ids)) == len(ids) and len(set(issue_ids)) == len(issue_ids), 'Duplicate ID'
    by_id = {t['id']: t for t in tasks}
    for item in issues:
        assert item['status'] in {'open', 'resolved'}, item['id']
        assert item['tasks'] and all(t in by_id for t in item['tasks']), item['id']
        if item['status'] == 'resolved':
            assert item.get('resolution'), 'Resolution evidence required: ' + item['id']
            assert all(by_id[t]['status'] == 'verified' for t in item['tasks']), item['id']
    for task in tasks:
        assert task['status'] in STATES and task['acceptance'], task['id']
        assert all(d in by_id and d != task['id'] for d in task['after']), task['id']
        assert task.get('issue') is None or task['issue'] in issue_ids, task['id']
        if task['status'] in {'running', 'review', 'verified'}:
            assert all(by_id[d]['status'] == 'verified' for d in task['after']), task['id']
        if task['status'] == 'running':
            run = task.get('run') or {}
            assert all(run.get(k) for k in ('id', 'log', 'started_at', 'deadline_at')), task['id']
        if task['executor'] == 'ornith':
            assert task['max_attempts'] == 1 and task['timeout_s'] <= 600, task['id']
            production = [p for p in task['allowed_files'] if p.startswith('lib/')]
            tests = [p for p in task['allowed_files'] if p.startswith('test/')]
            assert len(production) <= 1 and len(tests) <= 1, task['id']
        if task['status'] == 'verified':
            proof = task.get('verification') or {}
            assert proof.get('reviewer') and proof.get('tested_commit') and proof.get('evidence'), task['id']
            if task['executor'] == 'ornith':
                assert proof['reviewer'] == 'hermes', 'Worker cannot verify itself'
                assert (task.get('run') or {}).get('actual_model') == data['provider']['model'], task['id']
            for evidence in proof['evidence']:
                path = (root / evidence).resolve()
                assert path.is_relative_to(root.resolve()) and path.is_file(), evidence
    assert sum(t['status'] == 'running' and t['executor'] == 'ornith' for t in tasks) <= 1
    visiting, done = set(), set()

    def visit(key):
        assert key not in visiting, 'Dependency cycle: ' + key
        if key in done:
            return
        visiting.add(key)
        for dependency in by_id[key]['after']:
            visit(dependency)
        visiting.remove(key)
        done.add(key)

    for key in by_id:
        visit(key)
    return by_id


def blockers(data):
    return ([i['id'] for i in data['issues'] if i['status'] != 'resolved'] +
            [t['id'] for t in data['tasks'] if t['status'] != 'verified'])


def github_open():
    result = subprocess.run(
        ['gh', 'issue', 'list', '--state', 'open', '--limit', '1000', '--json', 'number'],
        cwd=ROOT, capture_output=True, text=True, timeout=30,
    )
    assert result.returncode == 0, 'GitHub inventory unavailable; release blocked'
    rows = json.loads(result.stdout)
    assert len(rows) < 1000, 'GitHub inventory may be truncated; release blocked'
    return [row['number'] for row in rows]


def add(data, path, title, source, severity):
    """Single writer: Hermes owns registry edits; workers only propose new items."""
    taken = {i['id'] for i in data['issues']}
    index = 1
    while f'NEW-{index:03}' in taken:
        index += 1
    key = f'NEW-{index:03}'
    ids = [key + '-R', key + '-V']
    data['issues'].append(dict(id=key, title=title, severity=severity, status='open',
                               source=source, evidence_type='NEW_REQUIRES_TRIAGE',
                               summary='Repeat and classify before implementation.',
                               source_locations=[], tasks=ids, resolution=None))
    for number, task_id in enumerate(ids):
        data['tasks'].append(dict(
            id=task_id, title=title + (' — triage' if number == 0 else ' — verify resolution'),
            status='queued', executor='ornith' if number == 0 else 'hermes',
            kind='research' if number == 0 else 'verification',
            after=[t['id'] for t in data['tasks'] if t['id'] in {'OPS-LAN', 'OPS-RUNNER'}] if number == 0 else [ids[0]], issue=key, read_files=[],
            allowed_files=[f'docs/plans/systemic-ux/reviews/{key}.md'] if number == 0 else [],
            acceptance=['Record reproducible source evidence; add bounded fix/test tasks before closure.'],
            timeout_s=600 if number == 0 else None, max_attempts=1, run=None, verification=None,
        ))
    for task in data['tasks']:
        if task['id'] == 'FINAL-TEST':
            task['after'].append(ids[1])
        if task['id'].startswith('FINAL-'):
            task['status'], task['verification'] = 'queued', None
    data['updated_at'] = datetime.now(timezone.utc).isoformat()
    validate(data)
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    temporary.replace(path)
    history = path.parent / 'HISTORY.md'
    with history.open('a') as stream:
        stream.write(f'\n## {data["updated_at"]} — {key} added\n\n{title}\n\nSource: {source}\n\nRelease remains blocked; final verification invalidated.\n')
    print(key)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['check', 'status', 'gate', 'add'])
    parser.add_argument('--plan', type=Path, default=DEFAULT)
    parser.add_argument('--title')
    parser.add_argument('--source')
    parser.add_argument('--severity', type=int, choices=[1, 2, 3, 4], default=2)
    args = parser.parse_args()
    try:
        data = json.loads(args.plan.read_text())
        validate(data)
        if args.command == 'add':
            assert args.title and args.source, 'add requires --title and --source'
            add(data, args.plan, args.title, args.source, args.severity)
            return 0
        summary = dict(issues=len(data['issues']), tasks=len(data['tasks']),
                       issue_status=dict(Counter(i['status'] for i in data['issues'])),
                       task_status=dict(Counter(t['status'] for t in data['tasks'])))
        print(json.dumps(summary, ensure_ascii=False))
        if args.command == 'gate':
            pending = blockers(data)
            assert not pending, 'RELEASE BLOCKED: ' + ', '.join(pending)
            remote = github_open()
            assert not remote, 'RELEASE BLOCKED: GitHub issues still open: ' + str(remote)
            print('RELEASE GATE PASS — owner publication authorization still required')
        return 0
    except (AssertionError, KeyError, ValueError, TypeError, OSError, subprocess.SubprocessError) as error:
        print('ACTIVITY CHECK FAILED: ' + str(error), file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
