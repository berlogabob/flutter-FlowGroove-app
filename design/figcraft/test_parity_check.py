import tempfile
import unittest
from pathlib import Path

from design.figcraft.parity_check import lib_literals, static


class ParityCheckTests(unittest.TestCase):
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
