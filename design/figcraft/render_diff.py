"""List render cells whose PNG files changed between two directories."""

import argparse
from pathlib import Path


def changed_cells(old_dir: str, new_dir: str) -> list[str]:
    old, new = Path(old_dir), Path(new_dir)
    names = {path.name for directory in (old, new) for path in directory.glob('*.png')}
    return sorted(
        Path(name).stem for name in names
        if not (old / name).is_file() or not (new / name).is_file()
        or (old / name).read_bytes() != (new / name).read_bytes()
    )


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('old_dir')
    parser.add_argument('new_dir')
    args = parser.parse_args()
    cells = changed_cells(args.old_dir, args.new_dir)
    print('\n'.join(cells) if cells else 'No changed cells')
