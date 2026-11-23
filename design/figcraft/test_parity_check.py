import tempfile
import unittest
from pathlib import Path

from design.figcraft.parity_check import compare, lib_literals, static


class ParityCheckTests(unittest.TestCase):
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
