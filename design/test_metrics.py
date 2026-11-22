import json
import tempfile
import unittest
from pathlib import Path

from design import metrics
from design.metrics import link_counts, raw_counts, render_counts, spec_offscale


class MetricsTests(unittest.TestCase):
    def test_raw_counts_excludes_generated_and_exempt_sources(self):
        with tempfile.TemporaryDirectory() as tmp:
            lib = Path(tmp) / "lib"
            (lib / "theme").mkdir(parents=True)
            (lib / "services/export").mkdir(parents=True)
            (lib / "a.dart").write_text(
                "TextStyle(fontSize: 14); SizedBox(height: 8); "
                "EdgeInsets.all(16); BorderRadius.circular(4); "
                "Colors.red; Colors.transparent"
            )
            (lib / "theme/t.dart").write_text("TextStyle(fontSize: 1)")
            (lib / "services/export/pdf_service.dart").write_text("fontSize: 9")
            (lib / "a.g.dart").write_text("fontSize: 3")
            self.assertEqual(
                raw_counts(str(lib)),
                {"fontSize": 1, "TextStyle": 1, "EdgeInsets": 1, "SizedBox": 1, "radius": 1, "Colors": 1},
            )

    def test_raw_counts_respects_reasons_and_exact_exemption(self):
        with tempfile.TemporaryDirectory() as tmp:
            lib = Path(tmp)
            (lib / "screens").mkdir()
            (lib / "screens/pdf_service.dart").write_text("Colors.red\n")
            (lib / "a.dart").write_text("fontSize: 13, // ds-allow: PDF export\nfontSize: 13, // ds-allow:\n")
            counts = raw_counts(str(lib))
            self.assertEqual(1, counts["fontSize"])
            self.assertEqual(1, counts["Colors"])

    def test_recursive_spec_files_include_nested_routes_and_skip_dotfiles(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "nested").mkdir()
            (root / "nested/screen.json").write_text('{"route": "/screen"}')
            (root / ".hidden.json").write_text('{"route": "/hidden"}')
            self.assertEqual(1, sum(1 for path in metrics.spec_files(root) if json.loads(path.read_text()).get("route")))

    def test_render_counts_handles_missing_and_populated_data(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            empty = root / "empty"
            empty.mkdir()
            self.assertEqual(render_counts(str(empty), str(root / "missing.lock")), {
                "rendered": 0, "locked": 0, "passing": 0, "locked_passing": 0, "matrix_ok": 0, "matrix_total": 0,
            })
            render = root / "render"
            render.mkdir()
            (render / "a@dark-412-1.00.json").write_text("{}")
            (render / "parity.json").write_text(json.dumps({"a": {"pass": True}}))
            (render / "matrix.json").write_text(json.dumps({
                "a@light-360-1.00": "ok", "a@light-360-1.30": "overflow",
            }))
            lock = root / "lock.txt"
            lock.write_text("a\n")
            self.assertEqual(render_counts(str(render), str(lock)), {
                "rendered": 1, "locked": 1, "passing": 1, "locked_passing": 1, "matrix_ok": 1, "matrix_total": 2,
            })

    def test_link_counts_tracks_reuse_and_connect_links(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            widgets, screens = root / "widgets", root / "screens"
            widgets.mkdir()
            screens.mkdir()
            (widgets / "components.dart").write_text(
                "class AppCard extends StatelessWidget {}\n"
                "class Foo extends StatelessWidget {}\n"
                "class StableSlotText extends StatelessWidget {}\n"
            )
            (screens / "screen.dart").write_text(
                "AppCard( AppCard( AppCard( Foo( Foo( Foo( "
                "StableSlotText( StableSlotText( StableSlotText( "
                "StableSlotText( StableSlotText("
            )
            connect = root / "connect.json"
            connect.write_text(json.dumps({"links": [
                {"component": "Card", "name": "AppCard"},
                {"component": "Icon/add", "name": "Icons.add"},
            ]}))
            self.assertEqual(link_counts(str(connect), str(widgets), str(screens)), {
                "reused": ["AppCard", "Foo"],
                "linked": ["AppCard"],
                "unlinked": ["Foo"],
                "name_mismatches": 1,
            })

    def test_spec_offscale_counts_values_outside_tokens(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            specs = root / "specs"
            specs.mkdir()
            tokens = root / "tokens.json"
            tokens.write_text(json.dumps({"spacing": {"sm": 8}, "radius": {"small": 8}}))
            (specs / "sample.json").write_text(json.dumps([
                {"t": "row", "pad": [8, 6, 8, 8], "gap": 10, "radius": 8,
                 "c": [{"t": "box", "radius": 4}]}
            ]))
            self.assertEqual(spec_offscale(str(specs), str(tokens)), 3)


if __name__ == "__main__":
    unittest.main()


class KpiMappingTest(unittest.TestCase):
    """Pins each KPI to its source, so a key cannot silently report another number."""

    def test_summarize_maps_each_kpi(self):
        links = {"reused": ["A", "B", "C"], "linked": ["A"], "unlinked": ["B", "C"], "name_mismatches": 15}
        renders = {"rendered": 2, "locked": 3, "passing": 2, "locked_passing": 1, "matrix_ok": 5, "matrix_total": 8}
        k = metrics.summarize(links, renders, 33, 179, {"fontSize": 1})
        self.assertEqual(k["k1"], "1/3")
        self.assertEqual(k["k2"], "2/33")
        self.assertEqual(k["k3"], 1)
        self.assertEqual(k["k4"], 179)
        self.assertEqual(k["k6"], 15)
        self.assertEqual(k["k7"], "5/8")

    def test_zero_is_never_off_scale(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "specs").mkdir()
            (root / "tokens.json").write_text(json.dumps({"spacing": {"sm": 8}, "radius": {"small": 8}}))
            (root / "specs" / "a.json").write_text(json.dumps({"body": [{"t": "row", "pad": [0, 6, 0, 8], "radius": [0, 0, 4, 4]}]}))
            self.assertEqual(metrics.spec_offscale(str(root / "specs"), str(root / "tokens.json")), 3)

    def test_rendered_counts_keys_not_cells(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            for cell in ("a@dark-412-1.00", "a@light-360-1.30", "b@dark-412-1.00"):
                (root / f"{cell}.json").write_text("{}")
            (root / "parity.json").write_text(json.dumps({"a": {"pass": True}, "b": {"pass": True}}))
            (root / "lock.txt").write_text("a\n")
            r = metrics.render_counts(str(root), str(root / "lock.txt"))
            self.assertEqual((r["rendered"], r["passing"], r["locked_passing"]), (2, 2, 1))

class SurfaceMetricsTest(unittest.TestCase):
    def test_render_coverage_counts_listed_keys_over_specced_surfaces(self):
        with tempfile.TemporaryDirectory() as tmp:
            keys = Path(tmp) / 'render_keys.txt'
            keys.write_text('# comment\nlogin\n\ntag_input_dialog\n')
            surfaces = Path(tmp) / 'surfaces.json'
            surfaces.write_text(json.dumps([{'spec': 'a.json'}, {'spec': 'b.json'}, {'spec': 'b.json'}, {'spec': None}]))
            self.assertEqual(metrics.render_coverage(keys, surfaces), '2/2')

    def test_surface_counts_use_inventory_including_unspecced(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'surfaces.json'
            path.write_text(json.dumps([{'spec': 'a.json'}, {'spec': None}, {'spec': None}]))
            self.assertEqual(metrics.surface_counts(path), (3, 2))
