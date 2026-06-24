/// Pure helpers for the desktop wiki panel. No Flutter UI deps so they are
/// trivially testable.

/// Strips a leading Hugo front-matter block (YAML `---` or TOML `+++`) from
/// [raw], returning the markdown body. Returns [raw] unchanged if there is no
/// recognizable front matter.
String stripFrontMatter(String raw) {
  final s = raw.trimLeft();
  for (final delim in const ['---', '+++']) {
    if (s.startsWith(delim)) {
      final close = s.indexOf('\n$delim', delim.length);
      if (close != -1) {
        final bodyStart = s.indexOf('\n', close + 1);
        return bodyStart == -1 ? '' : s.substring(bodyStart + 1).trimLeft();
      }
    }
  }
  return raw;
}

const _sections = [
  'home',
  'songs',
  'bands',
  'setlists',
  'profile',
  'metronome',
  'tuner',
];

/// Maps a router [path] to a wiki key, or `_index` when nothing matches.
String wikiKeyForPath(String path) {
  for (final key in _sections) {
    if (path.startsWith('/main/$key')) return key;
  }
  return '_index';
}

/// Asset path for a wiki [key] (single source shared with Hugo).
String wikiAssetForKey(String key) => 'site/content/wiki/$key.md';
