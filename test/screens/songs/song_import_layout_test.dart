import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/screens/songs/components/csv_import_export/song_import_dialog.dart';
import 'package:flowgroove/screens/songs/song_cluster_merge_screen.dart';
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

    expect(find.text('Import songs (CSV or JSON)'), findsOneWidget);
    expect(find.text('Select CSV file'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cluster merge matrix renders without overflow on mobile (#81)', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final songs = [
      song('first', 'A Very Long Existing Library Song Name'),
      song('second', 'Another Very Long Imported Song Name'),
      song('third', 'Yet Another Variant Of The Same Song'),
    ];

    await tester.pumpWidget(
      MaterialApp(home: SongClusterMergeScreen(songs: songs)),
    );
    await tester.pumpAndSettle();

    // primaryAction replaces the bar's title slot; the Merge button is the
    // visible affordance.
    expect(find.text('Merge'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    // Every field row offers one block per cluster member.
    expect(find.textContaining('Version 3'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
