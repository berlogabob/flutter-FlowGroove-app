import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/services/json/song_ai_prompt.dart';

void main() {
  test('prompt states the FlowGroove Song JSON contract', () {
    final p = songImportPrompt();
    expect(p, contains('FlowGroove'));
    expect(p, contains('schemaVersion'));
    expect(p, contains('chordChart'));
    expect(p, contains('ChordPro'));
    expect(p, contains('40–300')); // BPM range constraint
  });

  test('seeds the prompt with a provided title and artist', () {
    final p = songImportPrompt(title: 'Zombie', artist: 'The Cranberries');
    expect(p, contains('"Zombie"'));
    expect(p, contains('"The Cranberries"'));
  });

  test('falls back gracefully with no title/artist', () {
    expect(songImportPrompt(), contains('the song I name'));
  });
}
