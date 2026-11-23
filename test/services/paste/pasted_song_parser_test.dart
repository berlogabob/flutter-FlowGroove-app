import 'package:flowgroove/services/paste/pasted_song_parser.dart';
import 'package:flutter_test/flutter_test.dart';

List<PastedSong> _p(String text) => parsePastedSongs(text).songs;

void main() {
  test('Apple Notes numbered list with blank lines', () {
    expect(
      _p('1. Snowman - Sia\n\n2) White Christmas – Kelly Clarkson\n3 Santa'),
      [
        const PastedSong('Snowman', 'Sia'),
        const PastedSong('White Christmas', 'Kelly Clarkson'),
        const PastedSong('3 Santa'),
      ],
    );
  });

  test('zero-padded numbers are markers, plain numbers are titles', () {
    expect(_p('01 Wonderwall\n99 Problems\n7 Rings - Ariana Grande'), [
      const PastedSong('Wonderwall'),
      const PastedSong('99 Problems'),
      const PastedSong('7 Rings', 'Ariana Grande'),
    ]);
  });

  test('Keep checkboxes and bullets', () {
    expect(
      _p(
        '[ ] Yesterday\n[x] Help!\n☐ Let It Be\n✓ Hey Jude\n- Imagine\n* Michelle\n• Girl\n– Something',
      ),
      [
        for (final t in [
          'Yesterday',
          'Help!',
          'Let It Be',
          'Hey Jude',
          'Imagine',
          'Michelle',
          'Girl',
          'Something',
        ])
          PastedSong(t),
      ],
    );
  });

  test('WhatsApp / Telegram CRLF, tabs and emoji bullets', () {
    expect(
      _p(
        '🎵 Hotel California — Eagles\r\n🎸\tBlack   Dog\r\n✅ Nothing Else Matters\r\n1️⃣ One',
      ),
      [
        const PastedSong('Hotel California', 'Eagles'),
        const PastedSong('Black Dog'),
        const PastedSong('Nothing Else Matters'),
        const PastedSong('One'),
      ],
    );
  });

  test('Cyrillic titles', () {
    expect(_p('1. Группа крови - Кино\n- Звезда по имени Солнце'), [
      const PastedSong('Группа крови', 'Кино'),
      const PastedSong('Звезда по имени Солнце'),
    ]);
  });

  test('dash needs spaces; first split only; "by" is not split', () {
    expect(_p('Rock-n-Roll\nA - B - C\nHallelujah by Jeff Buckley'), [
      const PastedSong('Rock-n-Roll'),
      const PastedSong('A', 'B - C'),
      const PastedSong('Hallelujah by Jeff Buckley'),
    ]);
  });

  test('duplicates (case-insensitive) and punctuation-only lines dropped', () {
    expect(
      _p('Imagine\n---\nimagine\n***\n...\nIMAGINE - Lennon\nImagine - lennon'),
      [const PastedSong('Imagine'), const PastedSong('IMAGINE', 'Lennon')],
    );
  });

  test('empty input and cap', () {
    expect(_p('  \n\n'), isEmpty);
    final r = parsePastedSongs(
      [for (var i = 0; i < 250; i++) 'Song $i'].join('\n'),
    );
    expect(r.songs.length, maxPastedSongs);
    expect(r.truncated, isTrue);
    expect(parsePastedSongs('A\nB').truncated, isFalse);
  });
}
