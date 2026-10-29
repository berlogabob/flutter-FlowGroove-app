import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/screens/songs/midi_import_screen.dart';
import 'package:flowgroove/services/midi_song_import.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _preview = MidiImportPreview(
  data: MidiSongData(
    ppq: 480,
    tempos: [TempoChange(tick: 0, microsPerQuarter: 500000)],
    timeSigs: [TimeSigChange(tick: 0, numerator: 4, denominator: 4)],
    tracks: [
      MidiTrackData(
        index: 0,
        name: 'Studio drums',
        channel: 9,
        program: 0,
        notes: [MidiNote(tick: 0, dur: 120, pitch: 36, vel: 100)],
      ),
      MidiTrackData(
        index: 1,
        name: 'Electric bass',
        channel: 0,
        program: 33,
        notes: [MidiNote(tick: 0, dur: 480, pitch: 40, vel: 90)],
      ),
    ],
  ),
  meta: MidiSongMeta(
    ppq: 480,
    initialBpm: 120,
    tracks: [
      MidiTrackMeta(
        index: 0,
        name: 'Studio drums',
        channel: 9,
        program: 0,
        detectedRole: MidiRole.drums,
        noteCount: 1,
        minPitch: 36,
        maxPitch: 36,
      ),
      MidiTrackMeta(
        index: 1,
        name: 'Electric bass',
        channel: 0,
        program: 33,
        detectedRole: MidiRole.bass,
        noteCount: 1,
        minPitch: 40,
        maxPitch: 40,
      ),
    ],
  ),
);

Future<void> _openImport(
  WidgetTester tester, {
  required Future<void> Function(MidiSongMeta) onSave,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => MidiImportScreen(
                    preview: _preview,
                    title: 'Import MIDI',
                    onSave: onSave,
                  ),
                ),
              );
            },
            child: const Text('Open import'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open import'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('rows render the drums and bass track names', (tester) async {
    await _openImport(tester, onSave: (_) async {});

    expect(find.text('Studio drums'), findsOneWidget);
    expect(find.text('Electric bass'), findsOneWidget);
    expect(find.byType(DropdownButton<MidiRole>), findsNWidgets(2));
  });

  testWidgets('changing bass to guitar saves the role override', (
    tester,
  ) async {
    final saved = <MidiSongMeta>[];
    await _openImport(tester, onSave: (meta) async => saved.add(meta));

    final dropdown = find.byType(DropdownButton<MidiRole>).last;
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guitar').last);
    await tester.pumpAndSettle();
    expect(saved, isEmpty);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(saved.single.tracks[1].name, 'Electric bass');
    expect(saved.single.tracks[1].roleOverride, MidiRole.guitar);
    expect(saved.single.tracks[1].detectedRole, MidiRole.bass);
    expect(saved.single.tracks[0].roleOverride, isNull);
  });

  testWidgets('muting drums saves the mute setting for that track', (
    tester,
  ) async {
    final saved = <MidiSongMeta>[];
    await _openImport(tester, onSave: (meta) async => saved.add(meta));

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
      isFalse,
    );
    expect(saved, isEmpty);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(saved.single.tracks[0].name, 'Studio drums');
    expect(saved.single.tracks[0].mute, isTrue);
    expect(saved.single.tracks[1].mute, isFalse);
  });

  testWidgets('save errors appear inline and keep the import screen open', (
    tester,
  ) async {
    var saveCalls = 0;
    final error = StateError('Could not save MIDI');
    await _openImport(
      tester,
      onSave: (_) async {
        saveCalls++;
        throw error;
      },
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saveCalls, 1);
    expect(find.byType(MidiImportScreen), findsOneWidget);
    expect(find.text('Open import'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(MidiImportScreen),
        matching: find.text(error.toString()),
      ),
      findsOneWidget,
    );
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Studio drums'), findsOneWidget);
    expect(find.text('Electric bass'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
