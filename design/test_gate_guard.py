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

    def test_removed_ratchet_key_and_deleted_gate_files_are_rejected(self):
        self.assertTrue(violations({"design/ratchets.json": '{"k4": 3, "k5": {"Colors": 9}}'},
                                   {"design/ratchets.json": '{"k4": 3}'}))
        self.assertTrue(violations({"design/ratchets.json": '{"k4": 3}'}, {}))
        self.assertTrue(violations({"design/parity_lock.txt": "home\n"}, {}))
        self.assertEqual([], violations({"design/stable_layout_allow.txt": "a\n"}, {}))

    def test_commented_out_expect_and_file_skips_are_rejected(self):
        path = "test/sample_test.dart"
        self.assertTrue(violations({path: "expect(a, 1);\nexpect(b, 2);"}, {path: "expect(a, 1);\n// expect(b, 2);"}))
        self.assertTrue(violations({path: "expect(a, 1);\n/* x */ expect(b, 2);"}, {path: "/* expect(a, 1);\n*/ expect(b, 2);"}))
        self.assertTrue(violations({path: "void main() {}"}, {path: "@Skip('later')\nvoid main() {}"}))
        self.assertTrue(violations({path: "void main() {}"}, {path: "void main() { markTestSkipped('x'); }"}))

    def _repo(self, tmp):
        repo = Path(tmp)

        def git(*args):
            subprocess.run(["git", "-c", "commit.gpgsign=false", *args], cwd=repo, check=True, capture_output=True)

        git("init", "-q")
        git("config", "user.email", "t@example.com")
        git("config", "user.name", "t")
        return repo, git

    def test_renamed_test_file_is_still_compared(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo, git = self._repo(tmp)
            (repo / "test").mkdir()
            body = "".join(f"final v{i} = {i};\n" for i in range(30))
            (repo / "test/a_test.dart").write_text(body + "expect(1, 1);\nexpect(2, 2);\n")
            git("add", "-A")
            git("commit", "-qm", "base")
            git("mv", "test/a_test.dart", "test/b_test.dart")
            (repo / "test/b_test.dart").write_text(body + "expect(1, 1);\n")  # similar enough for rename detection
            git("add", "-A")
            self.assertEqual(1, main([], repo))

    def test_unresolvable_base_fails_instead_of_passing(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo, git = self._repo(tmp)
            (repo / "a.txt").write_text("a")
            git("add", "-A")
            git("commit", "-qm", "base")
            self.assertEqual(2, main(["--base", "origin/nope"], repo))

    def test_approval_must_be_its_own_line(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo, git = self._repo(tmp)
            (repo / "design").mkdir()
            (repo / "design/ratchets.json").write_text('{"k4": 3}')
            git("add", "-A")
            git("commit", "-qm", "base")
            (repo / "design/ratchets.json").write_text('{"k4": 4}')
            git("commit", "-qam", "raise: no Design-Approved: needed")
            self.assertEqual(1, main(["--base", "HEAD~1"], repo))

    def test_clean_input_has_no_violations(self):
        self.assertEqual([], violations({"lib/a.dart": "same"}, {"lib/a.dart": "same"}))


if __name__ == "__main__":
    unittest.main()
