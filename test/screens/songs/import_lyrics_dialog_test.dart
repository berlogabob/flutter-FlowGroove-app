import 'package:flowgroove/screens/songs/components/import_lyrics_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final resultHolder = <Future<ImportedSong?>>[];

  Future<void> pumpAndOpen(
    WidgetTester tester, {
    String? seedTitle,
    String? seedArtist,
  }) async {
    resultHolder.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                resultHolder.add(
                  showModalBottomSheet<ImportedSong>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => ImportLyricsDialog(
                      seedTitle: seedTitle,
                      seedArtist: seedArtist,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('ImportLyricsDialog JSON paste (#73)', () {
    testWidgets('valid Song JSON parses to sections + metadata', (
      tester,
    ) async {
      await pumpAndOpen(tester);

      const jsonText = '''
{ "schemaVersion": 1, "songs": [ {
  "title": "Test Song", "artist": "Test Band", "ourKey": "Am", "ourBPM": 120,
  "sections": [ { "name": "Verse 1", "duration": 4,
                  "chordChart": "[Am]hello [F]world" } ]
} ] }''';
      await tester.enterText(find.byType(TextField), jsonText);
      await tester.pumpAndSettle();

      expect(find.textContaining('Test Song'), findsWidgets);
      expect(find.text('Verse 1'), findsWidgets);

      await tester.ensureVisible(find.text('Import 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import 1'));
      await tester.pumpAndSettle();
      expect(
        find.byType(ImportLyricsDialog),
        findsNothing,
        reason: 'sheet should pop on Import',
      );
      final imported = await resultHolder.single;
      expect(imported!.title, 'Test Song');
      expect(imported.artist, 'Test Band');
      expect(imported.ourKey, 'Am');
      expect(imported.ourBpm, 120);
      expect(imported.sections.single.chordChart, '[Am]hello [F]world');
    });

    testWidgets('ChordPro paste still parses (regression)', (tester) async {
      await pumpAndOpen(tester);

      await tester.enterText(
        find.byType(TextField),
        '{title: My Song}\n{key: Dm}\n'
        '{start_of_verse: Verse 1}\n[Dm]line\n{end_of_verse}',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('My Song'), findsWidgets);
      expect(find.text('Verse 1'), findsWidgets);
    });

    testWidgets('Copy AI prompt copies a seeded prompt', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pumpAndOpen(
        tester,
        seedTitle: 'Hey Joe',
        seedArtist: 'Jimi Hendrix',
      );

      await tester.ensureVisible(find.text('Copy AI prompt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy AI prompt'));
      await tester.pumpAndSettle();

      expect(copied, hasLength(1));
      expect(copied.single, contains('"Hey Joe"'));
      expect(copied.single, contains('"Jimi Hendrix"'));
      expect(copied.single, contains('schemaVersion'));
    });
  });
}
