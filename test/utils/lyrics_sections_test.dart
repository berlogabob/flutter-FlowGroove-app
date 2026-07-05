import 'package:flowgroove/utils/lyrics_sections.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty / blank input yields no sections', () {
    expect(lyricsToSections(''), isEmpty);
    expect(lyricsToSections('   \n\n  \n'), isEmpty);
  });

  test('splits blank-line stanzas; repeated stanza becomes a single Chorus', () {
    const lyrics = '''
verse one line a
verse one line b

chorus line a
chorus line b

verse two line a
verse two line b

chorus line a
chorus line b''';

    final parts = lyricsToSections(lyrics);
    expect(parts.map((p) => p.name).toList(),
        ['Verse 1', 'Chorus', 'Verse 2', 'Chorus']);
    // Chorus text is preserved in the chart.
    expect(parts[1].chart, 'chorus line a\nchorus line b');
    expect(parts[0].chart, 'verse one line a\nverse one line b');
  });

  test('single plain stanza is one Verse', () {
    final parts = lyricsToSections('just one block\nof lyrics');
    expect(parts, hasLength(1));
    expect(parts.single.name, 'Verse 1');
  });
}
