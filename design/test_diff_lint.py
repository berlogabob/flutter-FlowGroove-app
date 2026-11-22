import unittest
import subprocess
import tempfile
from pathlib import Path

from design.diff_lint import bad_lines, main


class DiffLintTests(unittest.TestCase):
    def test_added_raw_spacing_is_reported(self):
        diff = "+++ b/lib/a.dart\n@@ -0,0 +1 @@\n+padding: EdgeInsets.all(13)\n"
        self.assertEqual(1, len(bad_lines(diff)))

    def test_token_spacing_is_allowed(self):
        diff = "+++ b/lib/a.dart\n@@ -0,0 +1 @@\n+padding: MonoPulseSpacing.md\n"
        self.assertEqual([], bad_lines(diff))

    def test_removed_lines_do_not_count(self):
        diff = "--- a/lib/a.dart\n+++ b/lib/a.dart\n@@ -1 +0,0 @@\n-padding: EdgeInsets.all(13)\n"
        self.assertEqual([], bad_lines(diff))

    def test_reasoned_exception_is_allowed(self):
        diff = "+++ b/lib/a.dart\n@@ -0,0 +1 @@\n+padding: EdgeInsets.all(13); // ds-allow: PDF\n"
        self.assertEqual([], bad_lines(diff))

    def test_main_checks_untracked_and_unstaged_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            self.git(repo, "init")
            self.git(repo, "config", "commit.gpgsign", "false")
            (repo / "lib").mkdir()
            (repo / "lib/a.dart").write_text("EdgeInsets.all(13)\n")
            self.assertEqual(1, main([], repo=repo))
            self.git(repo, "add", "lib/a.dart")
            self.git(repo, "commit", "-m", "initial")
            (repo / "lib/a.dart").write_text("fontSize: 13\n")
            self.assertEqual(1, main([], repo=repo))

    def test_main_base_ref_checks_committed_changes(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            self.git(repo, "init")
            self.git(repo, "config", "commit.gpgsign", "false")
            (repo / "lib").mkdir()
            (repo / "lib/a.dart").write_text("safe\n")
            self.git(repo, "add", "lib/a.dart")
            self.git(repo, "commit", "-m", "base")
            self.git(repo, "branch", "base")
            (repo / "lib/a.dart").write_text("Color(0xFF000000)\n")
            self.git(repo, "add", "lib/a.dart")
            self.git(repo, "commit", "-m", "raw color")
            self.assertEqual(1, main(["--base", "HEAD~1"], repo=repo))

    def test_clean_tree_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            self.git(repo, "init")
            self.git(repo, "config", "commit.gpgsign", "false")
            (repo / "lib").mkdir()
            (repo / "lib/a.dart").write_text("safe\n")
            self.git(repo, "add", "lib/a.dart")
            self.git(repo, "commit", "-m", "initial")
            self.assertEqual(0, main([], repo=repo))

    def test_review_patterns_and_exemptions(self):
        cases = [
            ("EdgeInsets.only(\n  left: 13,\n)", 1),
            ("Color.fromARGB(255, 1, 2, 3)", 1),
            ("Color.fromRGBO(1, 2, 3, 0.5)", 1),
            ("EdgeInsetsDirectional.only(start: 13)", 1),
            ("SizedBox.square(dimension: 13)", 1),
            ("SizedBox(key: k, height: 13)", 1),
            ("Color( 0xFF000000)", 1),
            ("fontSize: 13, // ds-allow:", 1),
            ("fontSize: 13, // ds-allow: PDF export", 0),
        ]
        for source, expected in cases:
            with self.subTest(source=source):
                diff = "+++ b/lib/a.dart\n@@ -0,0 +1,3 @@\n" + "".join("+" + line + "\n" for line in source.splitlines())
                hits = bad_lines(diff)
                self.assertEqual(expected, len(hits))
                if hits:
                    self.assertTrue(hits[0].startswith("lib/a.dart:1:"))
        for path, expected in [("lib/screens/pdf_service.dart", 1), ("lib/services/export/pdf_service.dart", 0)]:
            self.assertEqual(expected, len(bad_lines(f"+++ b/{path}\n@@ -0,0 +1 @@\n+Colors.red\n")))

    def test_untracked_unicode_and_invalid_base(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            self.git(repo, "init")
            (repo / "lib").mkdir()
            (repo / "lib/café.dart").write_text("fontSize: 13\n")
            self.assertEqual(1, main([], repo=repo))
            self.assertEqual(2, main(["--base", "origin/nope"], repo=repo))

    @staticmethod
    def git(repo, *args):
        subprocess.run(["git", *args], cwd=repo, check=True, capture_output=True)


if __name__ == "__main__":
    unittest.main()
