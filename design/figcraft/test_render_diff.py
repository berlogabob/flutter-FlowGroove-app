import tempfile
import unittest
from pathlib import Path

from design.figcraft.render_diff import changed_cells


class RenderDiffTest(unittest.TestCase):
    def test_changed_png_bytes(self):
        with tempfile.TemporaryDirectory() as old, tempfile.TemporaryDirectory() as new:
            for directory in (Path(old), Path(new)):
                (directory / 'b@light-360-1.00.png').write_bytes(b'identical')
            (Path(old) / 'a@dark-412-1.00.png').write_bytes(b'old')
            (Path(new) / 'a@dark-412-1.00.png').write_bytes(b'new')
            self.assertEqual(changed_cells(old, new), ['a@dark-412-1.00'])

    def test_added_and_removed_cells_are_changed(self):
        with tempfile.TemporaryDirectory() as old, tempfile.TemporaryDirectory() as new:
            (Path(old) / 'removed.png').write_bytes(b'old')
            (Path(new) / 'added.png').write_bytes(b'new')
            self.assertEqual(changed_cells(old, new), ['added', 'removed'])


if __name__ == '__main__':
    unittest.main()
