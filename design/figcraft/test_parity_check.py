import tempfile
import json
import subprocess
import sys
import unittest
from pathlib import Path

from design.figcraft.parity_check import compare, lib_literals, static


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
                json.dumps({"top": [{"t": "text", "v": "Expected"}]}),
                encoding="utf-8",
            )
            (root / "design/render/screen@dark-412-1.00.json").write_text(
                json.dumps({"texts": [rendered_text], "kinds": []}), encoding="utf-8"
            )
            (root / "lib/labels.dart").write_text("const label = 'Expected';", encoding="utf-8")
            script = Path(__file__).with_name("parity_check.py")
            return subprocess.run(
                [sys.executable, str(script)], cwd=root, text=True,
                capture_output=True, check=False,
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

    def test_compare_identical(self):
        spec = {"texts": [{"v": "All"}, {"v": "Edit"}], "kinds": []}
        dump = {"texts": [{"v": "All"}, {"v": "Edit"}], "kinds": []}
        self.assertEqual(compare(spec, dump, {"All", "Edit"}), {
            "pass": True, "missing": [], "extra": [],
            "kinds_missing": [], "kinds_extra": [], "order": 1.0,
        })

    def test_modal_ignores_extra_backdrop_labels(self):
        spec = {"modal": "dialog", "texts": [{"v": "Edit"}], "kinds": []}
        dump = {"texts": [{"v": "Back"}, {"v": "Edit"}], "kinds": []}
        self.assertTrue(compare(spec, dump, {"Back", "Edit"})["pass"])

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


if __name__ == "__main__":
    unittest.main()
