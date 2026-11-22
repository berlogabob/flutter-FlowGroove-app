import subprocess
import tempfile
import unittest
from pathlib import Path

from design.gate_guard import main, violations


class GateGuardTests(unittest.TestCase):
    def test_higher_ratchet_is_rejected(self):
        self.assertTrue(violations({"design/ratchets.json": '{"k4": 3}'}, {"design/ratchets.json": '{"k4": 4}'}))

    def test_removed_parity_line_is_rejected(self):
        self.assertTrue(violations({"design/parity_lock.txt": "a\nb\n"}, {"design/parity_lock.txt": "a\n"}))

    def test_added_stable_layout_allow_line_is_rejected(self):
        self.assertTrue(violations({"design/stable_layout_allow.txt": "a\n"}, {"design/stable_layout_allow.txt": "a\nb\n"}))

    def test_fewer_test_expectations_are_rejected(self):
        path = "test/sample_test.dart"
        self.assertTrue(violations({path: "expect(a, b);\nexpectLater(a, b);"}, {path: "expect(a, b);"}))

    def test_deleted_test_file_is_rejected_while_its_code_lives(self):
        test, code = "test/widgets/foo_test.dart", "lib/widgets/foo.dart"
        self.assertTrue(violations({test: "expect(a, b);", code: "x"}, {code: "x"}))

    def test_deleted_test_file_with_its_code_is_allowed(self):
        test, code = "test/widgets/foo_test.dart", "lib/widgets/foo.dart"
        self.assertEqual([], violations({test: "expect(a, b);", code: "x"}, {}))

    def test_added_skip_is_rejected(self):
        path = "test/sample_test.dart"
        self.assertTrue(violations({path: "testWidgets('a', (t) async { expect(a, b); });"},
                                   {path: "testWidgets('a', (t) async { expect(a, b); }, skip: true);"}))

    def test_base_mode_checks_pushed_commits_and_honours_approval(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)

            def git(*args):
                subprocess.run(["git", "-c", "commit.gpgsign=false", *args], cwd=repo, check=True, capture_output=True)

            git("init", "-q")
            git("config", "user.email", "t@example.com")
            git("config", "user.name", "t")
            (repo / "design").mkdir()
            (repo / "design/ratchets.json").write_text('{"k4": 3}')
            git("add", "-A")
            git("commit", "-qm", "base")
            (repo / "design/ratchets.json").write_text('{"k4": 4}')
            git("commit", "-qam", "raise")
            self.assertEqual(1, main(["--base", "HEAD~1"], repo))
            git("commit", "-q", "--allow-empty", "-m", "approve\n\nDesign-Approved: user, 2026-11-22")
            self.assertEqual(0, main(["--base", "HEAD~2"], repo))

    def test_clean_input_has_no_violations(self):
        self.assertEqual([], violations({"lib/a.dart": "same"}, {"lib/a.dart": "same"}))


if __name__ == "__main__":
    unittest.main()
