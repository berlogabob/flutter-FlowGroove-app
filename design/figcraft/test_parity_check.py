import tempfile
import json
import subprocess
import sys
import unittest
from pathlib import Path

from design.figcraft.parity_check import compare, dart_strings, debug_only_labels, fixture_literals, in_debug_conditional, lib_literals, row_ordered, static
from design.figcraft.spec_tree import flatten


class ParityCheckTests(unittest.TestCase):
    def run_cli(self, *, rendered_text, lock_key):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / "design/figcraft/specs").mkdir(parents=True)
            (root / "design/render").mkdir(parents=True)
            (root / "lib").mkdir()
            (root / "design/render_keys.txt").write_text("screen\n", encoding="utf-8")
            (root / "design/parity_lock.txt").write_text(lock_key + "\n", encoding="utf-8")
            (root / "design/figcraft/specs/screen.json").write_text(
                json.dumps({"top": [{"t": "text", "v": "Expected"}, {"t": "text", "v": "Second"}]}),
                encoding="utf-8",
            )
            (root / "design/render/screen@dark-412-1.00.json").write_text(
                json.dumps({"texts": [rendered_text, "Second"], "kinds": []}), encoding="utf-8"
            )
            (root / "lib/labels.dart").write_text("const label = 'Expected'; const second = 'Second';", encoding="utf-8")
            script = Path(__file__).with_name("parity_check.py")
            return subprocess.run(
                [sys.executable, str(script)], cwd=root, text=True,
                capture_output=True, check=False,
            )

    def test_dart_strings_skip_comments_and_keep_literals_after_them(self):
        source = "// don't count\nText('Any BPM'); /* \"no\" */ Text(\"a ${b('x')} c\"); Text('-- BPM');"
        self.assertEqual(
            list(dart_strings(source)),
            [("Any BPM", False), ("a ${b('x')} c", True), ("-- BPM", False)],
        )

    def test_cli_locked_key_failure_exits_one_and_prints_key_and_diff(self):
        result = self.run_cli(rendered_text="Wrong", lock_key="screen")

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("screen", result.stdout)
        self.assertIn("Expected", result.stdout)

    def test_cli_locked_passing_key_exits_zero(self):
        result = self.run_cli(rendered_text="Expected", lock_key="screen")

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("parity: 1 rendered, 1 pass, 1 locked, 0 locked failing", result.stdout)

    def test_real_flatten_output_and_modal_spec(self):
        # flatten() returns kinds as strings; a modal spec must keep its flag (F94).
        spec = {"modal": "dialog", "body": [{"t": "dialog", "title": "Save trim?", "c": [{"t": "button", "v": "Trim"}]}]}
        flat = flatten(spec, set())
        dump = {"texts": [{"v": "Home"}, {"v": "Save trim?"}, {"v": "Trim"}],
                "kinds": [{"kind": "dialog"}, {"kind": "button"}, {"kind": "card"}]}
        result = compare(flat, dump, {"Home", "Save trim?", "Trim"})
        self.assertEqual(result["missing"], [])
        self.assertEqual(result["extra"], [])
        self.assertEqual(result["kinds_missing"], [])

    def test_label_repeated_behind_a_sheet_does_not_hide_the_sheet_occurrence(self):
        # "F" is also a weekday letter on the screen behind the sheet.
        flat = {"modal": "sheet", "texts": ["Title", "F", "Eb"], "kinds": []}
        dump = {"texts": [{"v": "F"}, {"v": "Title"}, {"v": "F"}, {"v": "Eb"}], "kinds": []}
        result = compare(flat, dump, {"Title", "F", "Eb"})
        self.assertEqual(result["order"], 1.0)
        self.assertTrue(result["pass"])

    def test_wrong_order_still_fails(self):
        flat = {"texts": ["One", "Two"], "kinds": []}
        dump = {"texts": [{"v": "Two"}, {"v": "One"}], "kinds": []}
        self.assertLess(compare(flat, dump, {"One", "Two"})["order"], 1.0)

    def test_fewer_than_two_shared_labels_is_not_a_pass(self):
        flat = {"texts": ["Only"], "kinds": []}
        dump = {"texts": [{"v": "Only"}], "kinds": []}
        result = compare(flat, dump, {"Only"})
        self.assertFalse(result["pass"])
        self.assertTrue(result["weak"])

    def test_spec_switchrow_matches_code_switch(self):
        flat = {"texts": ["A", "B"], "kinds": ["switchrow"]}
        dump = {"texts": [{"v": "A"}, {"v": "B"}], "kinds": [{"kind": "switch"}]}
        self.assertTrue(compare(flat, dump, {"A", "B"})["pass"])

    def test_compare_identical(self):
        spec = {"texts": [{"v": "All"}, {"v": "Edit"}], "kinds": []}
        dump = {"texts": [{"v": "All"}, {"v": "Edit"}], "kinds": []}
        self.assertEqual(compare(spec, dump, {"All", "Edit"}), {
            "pass": True, "weak": False, "missing": [], "extra": [],
            "kinds_missing": [], "kinds_extra": [], "order": 1.0,
        })

    def test_modal_ignores_extra_backdrop_labels(self):
        spec = {"modal": "dialog", "texts": [{"v": "Edit"}, {"v": "Save"}], "kinds": []}
        dump = {"texts": [{"v": "Back"}, {"v": "Edit"}, {"v": "Save"}], "kinds": []}
        self.assertTrue(compare(spec, dump, {"Back", "Edit", "Save"})["pass"])

    def test_compare_reports_missing_extra_order_and_kind_differences(self):
        spec = {"texts": [{"v": "All"}, {"v": "Edit"}],
                "kinds": [{"kind": "chip"}]}
        cases = [
            ({"texts": [{"v": "Edit"}], "kinds": []}, {"missing": ["All"]}),
            ({"texts": [{"v": "All"}, {"v": "Edit"}, {"v": "Delete"}], "kinds": []},
             {"extra": ["Delete"]}),
            ({"texts": [{"v": "Edit"}, {"v": "All"}], "kinds": []}, {"order": 0.5}),
            ({"texts": [{"v": "All"}, {"v": "Edit"}], "kinds": []},
             {"kinds_missing": ["chip"]}),
        ]
        for dump, expected in cases:
            with self.subTest(expected=expected):
                result = compare(spec, dump, {"All", "Edit", "Delete"})
                for key, value in expected.items():
                    self.assertEqual(result[key], value)
                if "order" in expected:
                    self.assertFalse(result["pass"])

    def test_static_keeps_only_dart_string_literals_without_interpolation(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            dart_file = Path(temp_dir) / "a.dart"
            dart_file.write_text(
                "Text('Add song'); label: \"All\"; Text('Hi $name')",
                encoding="utf-8",
            )

            literals = lib_literals(temp_dir)

        self.assertEqual(literals, {"Add song", "All"})
        self.assertEqual(
            static(["Add song", "First Song", "All"], literals),
            ["Add song", "All"],
        )

    def test_debug_only_labels_are_ignored_but_others_still_extra(self):
        spec = {"texts": [{"v": "Edit"}, {"v": "Save"}], "kinds": []}
        dump = {"texts": [{"v": "Edit"}, {"v": "Dev tools"}, {"v": "Save"}], "kinds": []}
        lits = {"Edit", "Save", "Dev tools"}
        self.assertEqual(["Dev tools"], compare(spec, dump, lits)["extra"])
        self.assertTrue(compare(spec, dump, lits, frozenset({"Dev tools"}))["pass"])
        self.assertEqual(["Other"], compare(spec, {"texts": dump["texts"] + [{"v": "Other"}], "kinds": []},
                                            lits | {"Other"}, frozenset({"Dev tools"}))["extra"])

    def test_in_debug_conditional_proof(self):
        src = """children: [
          if (kDebugMode || _flag)
            CustomButton(label: 'Dev one'),
          Text('Shipped'),
          if (kDebugMode) ...[
            Text('Dev two'),
          ],
          Text('Also shipped'),
        ]"""
        self.assertTrue(in_debug_conditional(src, "Dev one"))
        self.assertTrue(in_debug_conditional(src, "Dev two"))
        self.assertFalse(in_debug_conditional(src, "Shipped"))
        self.assertFalse(in_debug_conditional(src, "Also shipped"))

    def test_every_listed_debug_only_label_is_inside_kdebugmode_in_its_file(self):
        root = Path(__file__).resolve().parents[2]
        listed = debug_only_labels(root / "design/figcraft/debug_only.txt")
        self.assertTrue(listed)
        for label, source in listed.items():
            text = (root / source).read_text(encoding="utf-8")
            self.assertTrue(in_debug_conditional(text, label), f"{label!r} is not under kDebugMode in {source}")

    def at(self, *items):
        return [{"v": v, "x": x, "y": y} for v, x, y in items]

    def test_sheet_interleaved_with_the_screen_keeps_each_part_in_order(self):
        lits = {"Top", "Mid", "Bottom", "Sheet", "Ok"}
        spec = {"texts": ["Top", "Mid", "Bottom", "Sheet", "Ok"], "overlay_from": 3, "kinds": []}
        dump = {"texts": self.at(("Top", 0, 10), ("Sheet", 0, 50), ("Mid", 0, 60), ("Ok", 0, 70), ("Bottom", 0, 90)),
                "kinds": []}
        self.assertEqual(1.0, compare(spec, dump, lits)["order"])
        # Without the overlay marker the same dump is out of order.
        self.assertLess(compare({"texts": spec["texts"], "kinds": []}, dump, lits)["order"], 1.0)
        # Order inside a part still counts.
        swapped = {"texts": self.at(("Top", 0, 10), ("Mid", 0, 20), ("Ok", 0, 50), ("Sheet", 0, 60), ("Bottom", 0, 90)),
                   "kinds": []}
        self.assertLess(compare(spec, swapped, lits)["order"], 1.0)

    def test_texts_a_few_px_apart_may_read_as_one_row(self):
        lits = {"Audition", "Loop seam", "Done"}
        spec = {"texts": ["Audition", "Loop seam", "Done"], "kinds": []}
        dump = {"texts": self.at(("Audition", 28, 864.5), ("Done", 337, 864.5), ("Loop seam", 117, 868)), "kinds": []}
        self.assertEqual(1.0, compare(spec, dump, lits)["order"])
        self.assertEqual(["Audition", "Loop seam", "Done"], row_ordered(dump["texts"]))
        # Rows more than the tolerance apart stay in y order, and a real swap still fails.
        far = {"texts": self.at(("Audition", 28, 864.5), ("Done", 337, 870), ("Loop seam", 117, 880)), "kinds": []}
        self.assertEqual(["Audition", "Done", "Loop seam"], row_ordered(far["texts"]))
        self.assertLess(compare(spec, far, lits)["order"], 1.0)

    def test_fixture_strings_rescue_a_weak_frame_only(self):
        spec = {"texts": ["Link to", "Alex", "Sam"], "kinds": []}
        dump = {"texts": ["Link to", "Alex", "Sam"], "kinds": []}
        lits, fixtures = {"Link to"}, {"Alex", "Sam"}
        self.assertTrue(compare(spec, dump, lits)["weak"])
        self.assertTrue(compare(spec, dump, lits, fixtures=fixtures)["pass"])
        # Labels that do not match still fail.
        wrong = {"texts": ["Link to", "Alex", "Kim"], "kinds": []}
        result = compare(spec, wrong, lits, fixtures=fixtures | {"Kim"})
        self.assertFalse(result["pass"])
        self.assertEqual(["Sam"], result["missing"])
        self.assertEqual(["Kim"], result["extra"])
        # A frame with two app literals keeps its data labels out of the comparison.
        solid = {"texts": ["Link to", "Cancel", "Alex"], "kinds": []}
        plain = {"texts": ["Link to", "Cancel", "Sam"], "kinds": []}
        self.assertTrue(compare(solid, plain, {"Link to", "Cancel"}, fixtures=fixtures)["pass"])

    def test_fixture_literals_read_plain_strings_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "fixtures.dart").write_text("final a = 'Alex'; final b = 'Hi $name'; // 'Nope'\n")
            self.assertEqual({"Alex"}, fixture_literals(Path(tmp)))


if __name__ == "__main__":
    unittest.main()
