"""Inventory route and modal surfaces from Dart source and FigCraft specs."""

import argparse
import json
import re
from pathlib import Path


CALL = re.compile(r'\b(GoRoute|showModalBottomSheet|showDialog|DraggableScrollableSheet|show\w*Picker)(?:<[^;()]*>)?\s*\(')
METHOD = re.compile(r'\b(?:Future(?:<[^\n]*?>)?|void|Widget|[A-Z]\w*)\s+(\w+)\s*\([^;{}]*\)\s*(?:async\s*)?\{')
WRAPPERS = {'StatefulBuilder', 'Builder', 'SafeArea', 'Padding', 'Column', 'Row', 'Material',
            'DraggableScrollableSheet', 'Container', 'SizedBox', 'Center', 'Align', 'Expanded',
            'Flexible', 'SingleChildScrollView', 'Scaffold', 'AlertDialog', 'Dialog', 'Text'}
# Pickers drawn entirely by Flutter/the OS with no app layout: no frame is possible or needed.
SYSTEM_PICKERS = {'showDatePicker', 'showTimePicker', 'showDateRangePicker'}
WIDGET = re.compile(r'(?:=>\s*|return\s+)(?:const\s+)?([A-Z]\w*)\s*\(')


def squash(name):
    # Specs name a frame "Edit Section Dialog" for the widget EditSectionDialog.
    return re.sub(r'[^a-z0-9]', '', str(name).lower())


def inventory(root: Path) -> list[dict]:
    specs = []
    for path in sorted((root / 'design/figcraft/specs').rglob('*.json')):
        if any(part.startswith('.') for part in path.relative_to(root / 'design/figcraft/specs').parts):
            continue
        data = json.loads(path.read_text(encoding='utf-8'))
        if isinstance(data, dict):
            specs.append((data.get('source', ''), path.relative_to(root).as_posix(), data))

    files = sorted((root / 'lib').rglob('*.dart'))
    classes = {}
    widget_classes = set()
    for path in files:
        text = path.read_text(encoding='utf-8')
        widget_classes.update(re.findall(r'\bclass\s+(\w+)\s+extends\s+\w*Widget\b', text))
        for name in re.findall(r'\bclass\s+(\w+)', text):
            classes[name] = path.relative_to(root).as_posix()

    def spec_for(source, line):
        matches = [(s, p) for s, p, _ in specs if s.split(':', 1)[0] == source]
        exact = [p for s, p in matches if s == f'{source}:{line}']
        unanchored = [p for s, p in matches if ':' not in s]
        return (exact or unanchored or [None])[0]

    def norm_route(route):
        # Specs write params as {band}, the router as :id; compare shapes only.
        return re.sub(r'\{[^}]+\}|:\w+', '*', route.rstrip('/'))

    def route_spec(key):
        found = [p for _, p, data in specs if data.get('route') and norm_route(data['route']) == norm_route(key)]
        return found[0] if found else None

    def modal_spec(source, line, widget):
        for spec_source, spec_path, data in specs:
            anchor = re.fullmatch(r'(.+):(\d+)', spec_source)
            if (anchor and anchor.group(1) == source and abs(int(anchor.group(2)) - line) <= 3) or (widget and squash(data.get('name', '')) == squash(widget)):
                return spec_path
        return None

    # show*Picker helpers defined in lib/ (showRolePicker...): the helper's own sheet or dialog is
    # the surface and is inventoried at that call; the helper's definition and its call sites are not.
    helpers = set()
    for path in files:
        helpers.update(re.findall(r'\b(?:Future(?:<[^;(){}]*>)?|void)\s+(show\w*Picker)\s*\(',
                                  path.read_text(encoding='utf-8')))

    result = []
    modal_entries = {}
    keys = set()
    for path in files:
        text = path.read_text(encoding='utf-8')
        relative = path.relative_to(root).as_posix()
        # Ignore comments while preserving positions and line numbers.
        clean = re.sub(r'//[^\n]*|/\*[\s\S]*?\*/', lambda m: re.sub(r'[^\n]', ' ', m.group()), text)
        route_parents = []
        for match in CALL.finditer(clean):
            name = match.group(1)
            if name == 'GoRoute' and not relative.startswith('lib/router/'):
                continue
            if name.startswith('show') and name.endswith('Picker') and re.search(r'\b(?:Future|void)\s+$', clean[max(0, match.start()-40):match.start()]):
                continue
            if name in helpers:
                continue
            line = clean.count('\n', 0, match.start()) + 1
            end = match.end()
            depth = 1
            while end < len(clean) and depth:
                depth += (clean[end] == '(') - (clean[end] == ')')
                end += 1
            body = clean[match.end():end]
            widget_match = WIDGET.search(body)
            widget = widget_match.group(1) if widget_match else None
            if name != 'GoRoute':
                builder = re.search(r'\bbuilder\s*:', body)
                candidate_body = body[builder.end():] if builder else body
                widget = next((m.group(1) for m in re.finditer(r'\b([A-Z]\w*)\s*\(', candidate_body) if m.group(1) in widget_classes and m.group(1) not in WRAPPERS), None)
            methods = list(METHOD.finditer(clean[:match.start()]))
            method = methods[-1].group(1) if methods else name
            if name == 'GoRoute':
                route = re.search(r'\bpath\s*:\s*[\'"]([^\'"]+)', body)
                if not route:
                    continue
                key = route.group(1)
                route_parents = [(stop, parent) for stop, parent in route_parents if match.start() < stop]
                if not key.startswith('/') and route_parents:
                    key = route_parents[-1][1].rstrip('/') + '/' + key
                route_parents.append((end, key))
                kind = 'route'
                spec = route_spec(key) or spec_for(classes.get(widget, relative), line)
            else:
                kind = ('sheet' if name in ('showModalBottomSheet', 'DraggableScrollableSheet')
                        else 'dialog' if name == 'showDialog'
                        else 'system' if name in SYSTEM_PICKERS else 'picker')
                fallback = re.sub(r'^_?show', '', method) or method
                label = widget or fallback
                base = f'{path.stem}.{label}'
                identity = (relative, method, kind, label)
                source = f'{relative}:{line}'
                spec = modal_spec(relative, line, widget)
                if identity in modal_entries:
                    entry = modal_entries[identity]
                    entry.setdefault('sources', [entry['source']]).append(source)
                    entry['spec'] = entry['spec'] or spec
                    continue
                key = base
                suffix = 2
                while key in keys:
                    key = f'{base}#{suffix}'
                    suffix += 1
                widget = label
            entry = {'key': key, 'kind': kind, 'source': f'{relative}:{line}', 'widget': widget or method, 'spec': spec}
            result.append(entry)
            keys.add(key)
            if name != 'GoRoute':
                modal_entries[identity] = entry

    for source, spec, data in specs:
        stem = Path(spec).stem
        if 'state' in data or re.match(r'^(?:metronome|tuner|recorder)(?:_|$)|^(?:song_map|practice)_', stem):
            result.append({'key': stem, 'kind': 'state', 'source': source if re.search(r':\d+$', source) else (source or spec) + ':1', 'widget': data.get('name', stem), 'spec': spec})
    return sorted(result, key=lambda item: (item['source'], item['kind'], item['key']))


def check(root: Path) -> bool:
    path = root / 'design/surfaces.json'
    return path.exists() and json.loads(path.read_text(encoding='utf-8')) == inventory(root)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    if args.check:
        if not check(root):
            print('design/surfaces.json is stale; run python3 design/surfaces.py')
            return 1
    else:
        (root / 'design/surfaces.json').write_text(json.dumps(inventory(root), indent=2) + '\n', encoding='utf-8')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
