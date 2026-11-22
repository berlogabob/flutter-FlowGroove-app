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

    def test_modal_matching_keys_and_state_specs(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'lib/screens').mkdir(parents=True)
            specs = root / 'design/figcraft/specs'
            specs.mkdir(parents=True)
            (root / 'lib/screens/profile.dart').write_text("""class FirstSheet extends StatelessWidget {}
void showFirst() {
  showDialog(builder: (c) => SafeArea(child: FirstSheet()));
  showDialog(builder: (c) => SafeArea(child: FirstSheet()));
}
void showSecond() {
  showDialog(builder: (c) => Padding(child: FirstSheet()));
}
void showFallback() {
  showDialog(builder: (c) => Column(children: []));
}
""")
            (specs / 'profile.json').write_text(json.dumps({'source': 'lib/screens/profile.dart', 'name': 'ProfileScreen'}))
            (specs / 'first.json').write_text(json.dumps({'source': 'lib/other.dart', 'name': 'FirstSheet'}))
            (specs / 'near.json').write_text(json.dumps({'source': 'lib/screens/profile.dart:9'}))
            (specs / 'metronome.json').write_text(json.dumps({'name': 'Metronome'}))
            (specs / 'practice_paused.json').write_text(json.dumps({'name': 'Paused'}))
            (specs / 'extra.json').write_text(json.dumps({'state': 'ready'}))
            found = surfaces.inventory(root)
            modals = sorted((s for s in found if s['kind'] == 'dialog'), key=lambda s: int(s['source'].rsplit(':', 1)[1]))
            self.assertEqual(['profile.FirstSheet', 'profile.FirstSheet#2', 'profile.Fallback'], [s['key'] for s in modals])
            self.assertEqual(2, len(modals[0]['sources']))
            self.assertEqual('design/figcraft/specs/first.json', modals[0]['spec'])
            self.assertEqual('design/figcraft/specs/near.json', modals[2]['spec'])
            self.assertEqual({'metronome', 'practice_paused', 'extra'}, {s['key'] for s in found if s['kind'] == 'state'})

    def test_unanchored_screen_spec_does_not_cover_modal(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'lib').mkdir()
            specs = root / 'design/figcraft/specs'
            specs.mkdir(parents=True)
            (root / 'lib/profile.dart').write_text('void showMenu() { showDialog(builder: (c) => MenuSheet()); }')
            (specs / 'profile.json').write_text(json.dumps({'source': 'lib/profile.dart', 'name': 'ProfileScreen'}))
            self.assertIsNone(surfaces.inventory(root)[0]['spec'])

    def test_non_widget_constructors_are_not_surface_widgets(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'lib').mkdir()
            (root / 'design/figcraft/specs').mkdir(parents=True)
            (root / 'lib/sample.dart').write_text(
                'void showMenu() { showDialog(builder: (c) => Column(children: [TextStyle()])); }'
            )
            self.assertEqual('sample.Menu', surfaces.inventory(root)[0]['key'])

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
