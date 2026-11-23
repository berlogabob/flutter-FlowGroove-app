import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parent))
import build


class RenderSourceTests(unittest.TestCase):
    def test_real_png_prefers_default_render_then_device_capture(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            render, real = root / 'render', root / 'real'
            render.mkdir()
            real.mkdir()
            with patch.multiple(build, RENDER=str(render), REAL=str(real)):
                self.assertIsNone(build.real_png('screen', {}))
                fallback = real / 'screen.png'
                fallback.touch()
                self.assertEqual(build.real_png('screen', {}), str(fallback))
                default = render / 'screen@light-412-1.00.png'
                default.touch()
                self.assertEqual(build.real_png('screen', {'mode': 'light'}), str(default))

    def test_parity_note_reads_results(self):
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(build, 'RENDER', tmp):
                path = Path(tmp) / 'parity.json'
                path.write_text(json.dumps({'ok': {'pass': True}, 'bad': {
                    'pass': False, 'missing': ['a', 'b'], 'extra': ['c'], 'order': 0.8}}))
                self.assertEqual(build.parity_note('ok'), 'parity pass')
                self.assertEqual(build.parity_note('bad'), 'parity: missing 2, extra 1, order 0.80')
                self.assertNotEqual(build.parity_note('unknown'), 'parity pass')

    def test_matrix_places_cells_in_order_with_status_and_missing_cells(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'matrix.json').write_text(json.dumps({'screen@light-360-1.00': 'ok'}))
            (root / 'screen@light-360-1.00.png').touch()
            calls = []
            def execute(command, params):
                calls.append((command, params))
                return {'id': str(len(calls)), 'height': 800}
            with patch.multiple(build, RENDER=tmp, REG=str(root / 'frames.json'), ex=execute,
                                page_ids=lambda: {'Matrix': 'page'}):
                build.matrix(['screen'])
            captions = [p['text'] for c, p in calls if c == 'node.create' and p.get('type') == 'text']
            self.assertEqual(len(captions), 16)
            self.assertEqual(captions[0], 'screen@light-360-1.00 · ok')
            self.assertEqual(captions[-1], 'screen@dark-420-1.30 · missing')
            self.assertEqual(sum(c == 'image.place' for c, _ in calls), 1)
