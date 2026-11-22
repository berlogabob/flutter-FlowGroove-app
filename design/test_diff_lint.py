import unittest

from design.diff_lint import bad_lines


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


if __name__ == "__main__":
    unittest.main()
