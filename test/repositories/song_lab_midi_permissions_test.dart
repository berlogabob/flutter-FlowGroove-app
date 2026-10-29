import 'dart:async';

import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/permissions_provider.dart';
import 'package:flowgroove/screens/songs/midi_import_screen.dart';
import 'package:flowgroove/screens/songs/song_lab_screen.dart';
import 'package:flowgroove/services/audio/audio_file_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _permissionProvider = NotifierProvider<_Permission, bool>(
  _Permission.new,
);

class _Permission extends Notifier<bool> {
  @override
  bool build() => true;

  bool get allowed => state;
  set allowed(bool value) => state = value;
}

void main() {
  final defaultAudioFileCache = audioFileCache;
  setUp(() => audioFileCache = (_, _) async => null);
  tearDown(() => audioFileCache = defaultAudioFileCache);

  const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
  final song = Song(
    id: 'song',
    title: 'Song',
    artist: 'Artist',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final bytes = Uint8List.fromList([
    ...'MThd'.codeUnits,
    0,
    0,
    0,
    6,
    0,
    0,
    0,
    1,
    0,
    96,
    ...'MTrk'.codeUnits,
    0,
    0,
    0,
    8,
    0,
    0x99,
    36,
    100,
    0,
    0xff,
    0x2f,
    0,
  ]);
  final pickedFile = [
    {'name': 'song.mid', 'size': bytes.length, 'bytes': bytes, 'path': null},
  ];

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    bool canEdit = true,
    String? bandId,
    bool canEditBand = false,
  }) async {
    final container = ProviderContainer(
      overrides: [
        canEditProvider.overrideWith((ref) => ref.watch(_permissionProvider)),
        canEditBandProvider.overrideWith((ref, id) => canEditBand),
        labEntriesProvider.overrideWith((ref, key) => Stream.value([])),
      ],
    );
    container.read(_permissionProvider.notifier).allowed = canEdit;
    addTearDown(container.dispose);
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: SongLabScreen(song: song, bandId: bandId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('personal MIDI import follows app edit permission changes', (
    tester,
  ) async {
    final container = await pump(tester, canEdit: false);
    expect(find.text('Import MIDI'), findsNothing);

    container.read(_permissionProvider.notifier).allowed = true;
    await tester.pumpAndSettle();
    expect(find.text('Import MIDI'), findsOneWidget);
    final import = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Import MIDI'))
        .onPressed!;

    var pickerCalls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      pickerCalls++;
      return null;
    });
    container.read(_permissionProvider.notifier).allowed = false;
    import(); // A callback retained before permission was revoked.
    await tester.pumpAndSettle();
    expect(find.text('Import MIDI'), findsNothing);
    expect(pickerCalls, 0);
  });

  testWidgets('personal import rechecks permission after picking a file', (
    tester,
  ) async {
    final container = await pump(tester);
    final picked = Completer<Object?>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) => picked.future,
    );
    await tester.tap(find.text('Import MIDI'));
    await tester.pump();
    container.read(_permissionProvider.notifier).allowed = false;
    picked.complete(pickedFile);
    await tester.pumpAndSettle();
    expect(find.byType(MidiImportScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('personal import rechecks permission before saving the preview', (
    tester,
  ) async {
    final container = await pump(tester);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => pickedFile,
    );
    await tester.tap(find.text('Import MIDI'));
    await tester.pumpAndSettle();
    expect(find.byType(MidiImportScreen), findsOneWidget);

    container.read(_permissionProvider.notifier).allowed = false;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(MidiImportScreen), findsOneWidget);
    expect(
      find.textContaining('You do not have permission to import MIDI'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final allowed in [false, true]) {
    testWidgets('band import still uses band edit permission ($allowed)', (
      tester,
    ) async {
      await pump(tester, bandId: 'band', canEditBand: allowed);
      expect(find.text('Import MIDI'), allowed ? findsOneWidget : findsNothing);
    });
  }
}
