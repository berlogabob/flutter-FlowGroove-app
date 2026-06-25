import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/widgets/wiki_content.dart';

void main() {
  group('stripFrontMatter', () {
    test('removes YAML front matter', () {
      const raw = '---\ntitle: "Home"\n---\n\n# Home\nbody';
      expect(stripFrontMatter(raw), '# Home\nbody');
    });
    test('removes TOML front matter', () {
      const raw = '+++\ntitle = "Home"\n+++\nBody only';
      expect(stripFrontMatter(raw), 'Body only');
    });
    test('returns input unchanged when no front matter', () {
      const raw = '# Home\nbody';
      expect(stripFrontMatter(raw), '# Home\nbody');
    });
  });

  group('wikiKeyForPath', () {
    test('maps a section path to its key', () {
      expect(wikiKeyForPath('/main/songs/123'), 'songs');
      expect(wikiKeyForPath('/main/home'), 'home');
      expect(wikiKeyForPath('/main/metronome'), 'metronome');
    });
    test('resolves even with a base-href/fragment prefix', () {
      // Regression: hash strategy leaked `/app/...` paths that broke startsWith.
      expect(wikiKeyForPath('/app/main/home'), 'home');
      expect(wikiKeyForPath('/app/main/songs/123'), 'songs');
    });
    test('falls back to _index for unknown paths', () {
      expect(wikiKeyForPath('/login'), '_index');
      expect(wikiKeyForPath('/'), '_index');
      expect(wikiKeyForPath('/app/'), '_index');
    });
  });

  test('wikiAssetForKey builds the asset path', () {
    expect(wikiAssetForKey('songs'), 'site/content/wiki/songs.md');
    expect(wikiAssetForKey('_index'), 'site/content/wiki/_index.md');
  });
}
