import json
import tempfile
import unittest
from pathlib import Path

from design import surfaces


class SurfaceTests(unittest.TestCase):
    def test_inventory_includes_routes_and_unique_modal_calls(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'lib/router').mkdir(parents=True)
            (root / 'lib/screens').mkdir()
            (root / 'design/figcraft/specs').mkdir(parents=True)
            (root / 'lib/router/routes.dart').write_text("GoRoute(path: '/home', builder: (c, s) => HomeScreen()),\n")
            (root / 'lib/screens/home.dart').write_text('''
void openSheet() { showModalBottomSheet(builder: (context) => SheetWidget()); }
void openDialog() { showDialog(builder: (context) => DialogWidget()); }
void helper() { showDialog(builder: (context) => HelperWidget()); }
void use() { helper(); helper(); }
''')
            (root / 'design/figcraft/specs/home.json').write_text(json.dumps({'source': 'lib/screens/home.dart:2'}))
            found = surfaces.inventory(root)
            self.assertEqual(4, len(found))
            self.assertEqual({'route': 1, 'sheet': 1, 'dialog': 2}, {k: sum(s['kind'] == k for s in found) for k in ('route', 'sheet', 'dialog')})
            self.assertTrue(any(s['key'] == '/home' for s in found))
            self.assertTrue(any(s['spec'] == 'design/figcraft/specs/home.json' for s in found))

    def test_nested_routes_have_full_paths(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'lib/router').mkdir(parents=True)
            (root / 'design/figcraft/specs').mkdir(parents=True)
            (root / 'lib/router/routes.dart').write_text("GoRoute(path: '/songs', routes: [GoRoute(path: ':id')]), GoRoute(path: '/bands', routes: [GoRoute(path: ':id')])")
            self.assertEqual({'/songs', '/songs/:id', '/bands', '/bands/:id'}, {s['key'] for s in surfaces.inventory(root)})

    def test_check_detects_stale_inventory(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'lib/router').mkdir(parents=True)
            (root / 'design/figcraft/specs').mkdir(parents=True)
            (root / 'design/surfaces.json').write_text('[]\n')
            (root / 'lib/router/routes.dart').write_text("GoRoute(path: '/home', builder: (c, s) => HomeScreen()),")
            self.assertFalse(surfaces.check(root))


if __name__ == '__main__':
    unittest.main()
