import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parent))
import build

CATALOG = json.loads((Path(__file__).parent / 'fc_commands.json').read_text())


def run_all(root, transport, **patches):
    """`build.py all` against the dry transport, with the three index files under `root`."""
    with patch.multiple(build, raw=transport, REG=str(root / '.frames.json'),
                        CREG=str(root / '.components.json'), TOKENS=str(root / '.tokens.json'), **patches):
        return build.main(['all'], dry_dir=str(root))


class ScratchSafetyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)
        self.real = {'.frames.json': '{"Home": "1:2"}', '.components.json': '{"Button": {"a": "1:3"}}',
                     '.tokens.json': '{"Spacing/lg": "VariableID:1:4"}'}
        for name, text in self.real.items():
            (self.root / name).write_text(text)
        self.transport = build.DryTransport(CATALOG)

    def assert_real_untouched(self):
        for name, text in self.real.items():
            self.assertEqual((self.root / name).read_text(), text, name)

    def active(self):
        return [d for d in self.transport.documents if d['active']]

    def test_all_keeps_the_working_index_and_document(self):
        self.assertEqual(run_all(self.root, self.transport), 0)
        self.assertEqual(self.transport.problems, {})
        self.assert_real_untouched()
        self.assertEqual([d['path'] for d in self.active()], ['/dry/working.figcraft'])
        self.assertEqual([d['path'] for d in self.transport.documents], ['/dry/working.figcraft', None])
        scratch = self.root / '.scratch'
        for name in self.real:
            self.assertTrue((scratch / name).exists(), name)
        self.assertNotEqual((scratch / '.frames.json').read_text(), self.real['.frames.json'])

    def test_failed_build_still_restores_the_working_document(self):
        def broken():
            raise ValueError('EmptyState: property Action has no layer')
        with self.assertRaisesRegex(ValueError, 'EmptyState'):
            run_all(self.root, self.transport, build_components=broken)
        self.assert_real_untouched()
        self.assertEqual([d['path'] for d in self.active()], ['/dry/working.figcraft'])

    def test_setup_alone_is_scratch_too(self):
        with patch.multiple(build, raw=self.transport, REG=str(self.root / '.frames.json'),
                            CREG=str(self.root / '.components.json'), TOKENS=str(self.root / '.tokens.json')):
            build.main(['setup'])
        self.assert_real_untouched()
        self.assertEqual([d['path'] for d in self.active()], ['/dry/working.figcraft'])

    def test_saving_or_publishing_is_a_problem(self):
        self.transport.execute('file.saveAs', {'path': '/x'})
        self.transport.execute('library.publish', {})
        self.assertEqual(len(self.transport.problems), 2)


class PropertyCheckTests(unittest.TestCase):
    def setUp(self):
        self.t = build.DryTransport(CATALOG)
        self.main = self.t.execute('node.create', {'type': 'frame', 'name': 'Main'})['id']

    def node(self, kind, name):
        return self.t.execute('node.create', {'type': kind, 'name': name, 'parent': self.main})['id']

    def add(self, **p):
        self.t.execute('component.addProperty', dict(id=self.main, **p))

    def test_text_property_on_text_layer_passes(self):
        self.add(name='Label', type='text', layer=self.node('text', 'Label'))
        self.add(name='Show', type='boolean', layer=self.node('frame', 'Box'))
        self.assertEqual(self.t.problems, {})

    def test_text_property_on_frame_or_nested_instance_is_caught(self):
        button = self.t.execute('node.create', {'type': 'frame', 'name': 'Button'})['id']
        instance = self.t.execute('instance.create', {'component': button})['id']
        self.t.execute('node.reparent', {'ids': [instance], 'parent': self.main})
        self.add(name='A', type='text', layer=self.node('frame', 'Action'))
        self.add(name='B', type='text', layer=instance)
        messages = ' '.join(self.t.problems)
        self.assertIn('FRAME layer', messages)
        self.assertIn('INSTANCE layer', messages)
        self.assertIn('not a text layer', messages)

    def test_unknown_layer_and_type_are_caught(self):
        self.add(name='A', type='text', layer='Dry:999')
        self.add(name='B', type='number', layer=self.node('text', 'T'))
        messages = ' '.join(self.t.problems)
        self.assertIn('unknown layer', messages)
        self.assertIn('boolean|text|instanceSwap|variant|slot', messages)

    def test_layer_may_be_named_inside_the_component(self):
        self.node('text', 'icon/add')
        self.add(name='Icon', type='text', layer='icon/add')
        self.assertEqual(self.t.problems, {})


if __name__ == '__main__':
    unittest.main()
