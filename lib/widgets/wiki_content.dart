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
/// Matches `/main/<key>` anywhere in [path] (not just the start) so a leading
/// base-href/fragment prefix (e.g. `/app/main/home`) still resolves correctly.
String wikiKeyForPath(String path) {
  for (final key in _sections) {
    if (path.contains('/main/$key')) return key;
  }
  return '_index';
}

/// Asset path for a wiki [key] (single source shared with Hugo).
String wikiAssetForKey(String key) => 'site/content/wiki/$key.md';

/// All bundled wiki page slugs. Superset of [_sections] — includes pages that
/// have no dedicated app route (e.g. `concert-mode`) but are reachable as links.
const _pages = <String>{
  'home',
  'songs',
  'bands',
  'setlists',
  'profile',
  'metronome',
  'tuner',
  'concert-mode',
};

/// Maps a markdown link [href] to a bundled wiki key, or `null` when the link is
/// external/unknown (the caller should open those in a new browser tab instead
/// of swapping panel content). Internal wiki links in the bundled markdown are
/// relative slugs like `home/`, `concert-mode/`, or `songs.md`.
String? wikiKeyForHref(String href) {
  final h = href.trim();
  if (h.isEmpty) return null;
  final lower = h.toLowerCase();
  if (lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('mailto:') ||
      lower.startsWith('//')) {
    return null; // external — open in a new tab
  }
  var s = h.split('#').first.split('?').first;
  if (s.endsWith('.md')) s = s.substring(0, s.length - 3);
  s = s.replaceAll(RegExp(r'/+$'), '');
  if (s.isEmpty) return '_index';
  final seg = s.split('/').last;
  if (seg == '_index' || seg == 'index') return '_index';
  return _pages.contains(seg) ? seg : null;
}
