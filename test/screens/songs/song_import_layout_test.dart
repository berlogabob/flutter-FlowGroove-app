import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/screens/songs/components/csv_import_export/song_import_dialog.dart';
import 'package:flowgroove/screens/songs/song_merge_dialog.dart';
import 'package:flowgroove/services/matching/song_merge_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Song song(String id, String title) => Song(
    id: id,
    title: title,
    artist: 'The Artist With A Long Display Name',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  Future<void> setPhoneSize(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('CSV import uses a full-screen mobile layout', (tester) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const SongImportDialog(librarySongs: []),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Import songs from CSV'), findsOneWidget);
    expect(find.text('Select CSV file'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('merge choices stack without horizontal overflow on mobile', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final first = song('first', 'A Very Long Existing Library Song Name');
    final second = song('second', 'Another Very Long Imported Song Name');

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => SongMergeDialog(first: first, second: second),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Merge songs'), findsOneWidget);
    expect(find.byType(RadioListTile<SongMergeSide>), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
