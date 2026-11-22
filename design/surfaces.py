"""Inventory route and modal surfaces from Dart source and FigCraft specs."""

import argparse
import json
import re
from pathlib import Path


CALL = re.compile(r'\b(GoRoute|showModalBottomSheet|showDialog|DraggableScrollableSheet|show\w*Picker)(?:<[^;()]*>)?\s*\(')
METHOD = re.compile(r'\b(?:Future(?:<[^\n]*?>)?|void|Widget|[A-Z]\w*)\s+(\w+)\s*\([^;{}]*\)\s*(?:async\s*)?\{')
WIDGET = re.compile(r'(?:=>\s*|return\s+)(?:const\s+)?([A-Z]\w*)\s*\(')


def inventory(root: Path) -> list[dict]:
    specs = []
    for path in sorted((root / 'design/figcraft/specs').rglob('*.json')):
        if any(part.startswith('.') for part in path.relative_to(root / 'design/figcraft/specs').parts):
            continue
        data = json.loads(path.read_text(encoding='utf-8'))
        if isinstance(data, dict) and isinstance(data.get('source'), str):
            specs.append((data['source'], path.relative_to(root).as_posix(), data))

    files = sorted((root / 'lib').rglob('*.dart'))
    classes = {}
    for path in files:
        text = path.read_text(encoding='utf-8')
        for name in re.findall(r'\bclass\s+(\w+)', text):
            classes[name] = path.relative_to(root).as_posix()

    def spec_for(source, line):
        matches = [(s, p) for s, p, _ in specs if s.split(':', 1)[0] == source]
        exact = [p for s, p in matches if s == f'{source}:{line}']
        unanchored = [p for s, p in matches if ':' not in s]
        return (exact or unanchored or [None])[0]

    result = []
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
            line = clean.count('\n', 0, match.start()) + 1
            end = match.end()
            depth = 1
            while end < len(clean) and depth:
                depth += (clean[end] == '(') - (clean[end] == ')')
                end += 1
            body = clean[match.end():end]
            widget_match = WIDGET.search(body)
            widget = widget_match.group(1) if widget_match else None
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
                spec = spec_for(classes.get(widget, relative), line)
            else:
                kind = 'sheet' if name in ('showModalBottomSheet', 'DraggableScrollableSheet') else 'dialog' if name == 'showDialog' else 'picker'
                key = f'{path.stem}.{widget or method}'
                spec = spec_for(relative, line)
            result.append({'key': key, 'kind': kind, 'source': f'{relative}:{line}', 'widget': widget or method, 'spec': spec})

    for source, spec, data in specs:
        if isinstance(data.get('state'), str):
            result.append({'key': Path(spec).stem, 'kind': 'state', 'source': source if ':' in source else source + ':1', 'widget': data.get('name', Path(spec).stem), 'spec': spec})
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
