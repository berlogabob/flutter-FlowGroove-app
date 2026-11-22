import json
import tempfile
import unittest
from pathlib import Path

from design.ratchet import check, update_baseline, unspecced_screens


class RatchetTests(unittest.TestCase):
    def test_check_reports_growth_and_allows_decreases(self):
        self.assertEqual(check({"k4": 180}, {"k4": 179}), ["k4 grew 179 -> 180"])
        self.assertEqual(check({"k4": 170}, {"k4": 179}), [])

    def test_update_only_lowers_values(self):
        with tempfile.TemporaryDirectory() as tmp:
            baseline = Path(tmp) / "ratchets.json"
            baseline.write_text(json.dumps({"k4": 179}))
            update_baseline({"k4": 170}, baseline)
            self.assertEqual(json.loads(baseline.read_text()), {"k4": 170})
            baseline.write_text(json.dumps({"k4": 179}))
            update_baseline({"k4": 190}, baseline)
            self.assertEqual(json.loads(baseline.read_text()), {"k4": 179})

    def test_new_screen_without_spec_counts_as_growth(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            screens = root / "lib/screens"
            specs = root / "design/figcraft/specs"
            screens.mkdir(parents=True)
            specs.mkdir(parents=True)
            (screens / "new_screen.dart").write_text("class NewScreen {}")
            (specs / "home.json").write_text(json.dumps({"source": "lib/screens/home_screen.dart"}))
            self.assertEqual(unspecced_screens(screens, specs), 1)
            self.assertEqual(check({"unspecced_screens": 1}, {"unspecced_screens": 0}),
                             ["unspecced_screens grew 0 -> 1"])

    def test_spec_source_with_line_anchor_covers_its_screen(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            screens = root / "lib/screens"
            specs = root / "design/figcraft/specs"
            screens.mkdir(parents=True)
            specs.mkdir(parents=True)
            (screens / "sheet_screen.dart").write_text("class SheetScreen {}")
            (specs / "sheet.json").write_text(json.dumps({"source": "lib/screens/sheet_screen.dart:122"}))
            self.assertEqual(unspecced_screens(screens, specs), 0)


if __name__ == "__main__":
    unittest.main()


class SurfaceRatchetTests(unittest.TestCase):
    def test_current_counts_ratchet_unspecced_surfaces_from_inventory(self):
        repo = Path(__file__).resolve().parent.parent
        expected = sum(item["spec"] is None for item in json.loads((repo / "design/surfaces.json").read_text()))
        from design.ratchet import current_counts
        self.assertEqual(current_counts(repo)["unspecced_surfaces"], expected)

