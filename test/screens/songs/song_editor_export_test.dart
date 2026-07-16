import 'package:flowgroove/models/section.dart';
import 'package:flowgroove/screens/songs/song_editor_screen.dart';
import 'package:flowgroove/services/export/pdf_service.dart';
import 'package:flowgroove/services/export/setlist_export_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpEditor(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SongEditorScreen(
          title: 'Test Song',
          sections: [Section(id: 's1', name: 'Verse', duration: 2)],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Song editor export menu (#79)', () {
    testWidgets('menu offers Export PDF and Export ChordPro', (tester) async {
      await pumpEditor(tester);

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      expect(find.text('Export PDF'), findsOneWidget);
      expect(find.text('Export ChordPro'), findsOneWidget);
      // Pre-existing items stay.
      expect(find.text('Add section'), findsOneWidget);
      expect(find.text('Import lyrics & chords'), findsOneWidget);
    });

    testWidgets('Export PDF opens the song-sheet layout picker', (
      tester,
    ) async {
      await pumpEditor(tester);

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export PDF'));
      await tester.pumpAndSettle();

      expect(find.text('As is'), findsOneWidget);
      expect(find.text('Compact'), findsOneWidget);
      expect(find.text('Fit everything on one A4 page'), findsOneWidget);
    });
  });

  group('pickSongSheetPdfLayout', () {
    Future<SetlistPdfLayout?> pickVia(
      WidgetTester tester,
      String option,
    ) async {
      SetlistPdfLayout? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                picked = await pickSongSheetPdfLayout(context);
              },
              child: const Text('pick'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('pick'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option));
      await tester.pumpAndSettle();
      return picked;
    }

    testWidgets('"As is" returns detailed', (tester) async {
      expect(await pickVia(tester, 'As is'), SetlistPdfLayout.detailed);
    });

    testWidgets('"Compact" returns compact (fit one A4)', (tester) async {
      expect(await pickVia(tester, 'Compact'), SetlistPdfLayout.compact);
    });
  });
}
