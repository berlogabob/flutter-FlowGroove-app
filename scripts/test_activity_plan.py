"""Runnable stdlib checks for the activity registry and release hold."""
from contextlib import redirect_stdout
from copy import deepcopy
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import activity_plan as activity


class ActivityChecks(unittest.TestCase):
    def setUp(self):
        self.data = json.loads(activity.DEFAULT.read_text())
        # Synthetic pending fixture: tests must still work after real tasks close.
        for issue in self.data['issues']:
            issue['status'], issue['resolution'], issue['release_blocker'] = 'open', None, True
        for task in self.data['tasks']:
            task['status'], task['run'], task['verification'] = 'queued', None, None

    def test_actual_registry_and_dependency_graph(self):
        activity.validate(json.loads(activity.DEFAULT.read_text()))
        self.assertTrue(activity.blockers(self.data))

    def test_open_roadmap_item_does_not_block(self):
        for issue in self.data['issues']:
            issue['release_blocker'] = False
        self.assertNotIn(self.data['issues'][0]['id'], activity.blockers(self.data))
        self.assertNotIn(self.data['issues'][0]['tasks'][0], activity.blockers(self.data))

    def test_duplicate_task_rejected(self):
        self.data['tasks'].append(deepcopy(self.data['tasks'][0]))
        with self.assertRaises(AssertionError):
            activity.validate(self.data)

    def test_dependency_cycle_rejected(self):
        self.data['tasks'][0]['after'] = [self.data['tasks'][1]['id']]
        with self.assertRaises(AssertionError):
            activity.validate(self.data)

    def test_running_without_metadata_rejected(self):
        next(t for t in self.data['tasks'] if t['id'] == 'OPS-LAN')['status'] = 'running'
        with self.assertRaises(AssertionError):
            activity.validate(self.data)

    def test_worker_cannot_expand_production_scope(self):
        task = next(t for t in self.data['tasks'] if t['kind'] == 'implementation')
        task['allowed_files'].append('lib/unrelated.dart')
        with self.assertRaises(AssertionError):
            activity.validate(self.data)

    def test_resolved_issue_with_open_tasks_rejected(self):
        self.data['issues'][0]['status'] = 'resolved'
        self.data['issues'][0]['resolution'] = 'worker says done'
        with self.assertRaises(AssertionError):
            activity.validate(self.data)

    def test_add_preserves_history_and_expands_final_gate(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'activity.json'
            path.write_text(json.dumps(self.data))
            history = root / 'HISTORY.md'
            history.write_text('Earlier history\n')
            before = (len(self.data['issues']), len(self.data['tasks']))
            with redirect_stdout(io.StringIO()):
                activity.add(self.data, path, 'Observed test problem', 'local-evidence:1', 2)
            saved = json.loads(path.read_text())
            activity.validate(saved)
            self.assertEqual((len(saved['issues']), len(saved['tasks'])), (before[0] + 1, before[1] + 2))
            self.assertTrue(history.read_text().startswith('Earlier history\n'))
            final = next(t for t in saved['tasks'] if t['id'] == 'FINAL-TEST')
            added = saved['issues'][-1]['id']
            self.assertIn(added + '-V', final['after'])
            self.assertIn(added, activity.blockers(saved))

    def test_missing_registry_blocks_gate(self):
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run([sys.executable, str(Path(activity.__file__)), 'gate', '--plan',
                                     str(Path(directory) / 'missing.json')], capture_output=True)
        self.assertNotEqual(result.returncode, 0)

    def test_optimized_python_cannot_remove_safety_checks(self):
        result = subprocess.run([sys.executable, '-O', str(Path(activity.__file__)), 'gate'], capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b'optimized mode is forbidden', result.stderr)

    def test_github_failure_is_not_zero_open_issues(self):
        with patch.object(activity.subprocess, 'run') as run:
            run.return_value.returncode = 1
            with self.assertRaises(AssertionError):
                activity.github_open()

    def test_closed_fixture_passes_only_with_fresh_zero_remote_issues(self):
        data = deepcopy(self.data)
        task = data['tasks'][0]
        task.update(status='verified', after=[], run={'actual_model': data['provider']['model']},
                    verification={'reviewer': 'hermes', 'tested_commit': data['baseline']['source_commit'],
                                  'evidence': ['scripts/test_activity_plan.py']})
        issue = data['issues'][0]
        issue.update(status='resolved', resolution='Fixture verification only', tasks=[task['id']])
        data['issues'], data['tasks'] = [issue], [task]
        activity.validate(data)
        self.assertEqual(activity.blockers(data), [])
        task['verification']['reviewer'] = 'ornith'
        with self.assertRaises(AssertionError):
            activity.validate(data)
        task['verification']['reviewer'] = 'hermes'
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'fixture.json'
            path.write_text(json.dumps(data))
            argv = ['activity_plan.py', 'gate', '--plan', str(path)]
            with patch.object(sys, 'argv', argv), redirect_stdout(io.StringIO()), patch.object(activity, 'github_open', return_value=[42]):
                self.assertEqual(activity.main(), 2)
            with patch.object(sys, 'argv', argv), redirect_stdout(io.StringIO()), patch.object(activity, 'github_open', return_value=[]):
                self.assertEqual(activity.main(), 0)

    def test_publication_make_targets_fail_before_recipes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ['Makefile', 'Makefile.hugo', 'scripts/activity-release.mk', 'scripts/activity_plan.py']:
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(activity.ROOT / name, target)
            registry = root / 'docs/plans/systemic-ux/activity.json'
            registry.parent.mkdir(parents=True)
            registry.write_text(json.dumps(self.data))
            for makefile, goals in [('Makefile', ['release', 'release-all', 'bump-version', 'deploy-pages',
                                                 'deploy-stable', 'deploy-app-hosting', 'deploy-functions',
                                                 'deploy-rules', 'ftp-upload']),
                                    ('Makefile.hugo', ['deploy-all'])]:
                for goal in goals:
                    with self.subTest(makefile=makefile, goal=goal):
                        result = subprocess.run(['make', '-f', makefile, '-n', goal], cwd=root,
                                                capture_output=True, text=True)
                        self.assertNotEqual(result.returncode, 0)
                        self.assertIn('RELEASE BLOCKED', result.stderr)

    def test_nonpublication_dry_run_remains_available(self):
        for goal in ['help', 'test-fast']:
            result = subprocess.run(['make', '-n', goal], cwd=activity.ROOT, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr.decode())


if __name__ == '__main__':
    unittest.main()
