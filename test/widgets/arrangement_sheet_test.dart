import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/models/section.dart';
import 'package:flowgroove/models/section_span.dart';
import 'package:flowgroove/models/song.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/providers/data/data_providers.dart';
import 'package:flowgroove/providers/data/midi_song_provider.dart';
import 'package:flowgroove/providers/permissions_provider.dart';
import 'package:flowgroove/repositories/firestore_lab_repository.dart';
import 'package:flowgroove/widgets/metronome/backing_sheet.dart';
import 'package:flowgroove/widgets/midi/arrangement_sheet.dart';
import 'package:flowgroove/widgets/midi/midi_song_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mocks.mocks.dart';

const _data = MidiSongData(
  ppq: 480,
  tempos: [TempoChange(tick: 0, microsPerQuarter: 483871)],
  timeSigs: [],
  tracks: [
    MidiTrackData(
      index: 0,
      name: 'Piano',
      channel: 0,
      program: 0,
      notes: [MidiNote(tick: 0, dur: 480 * 4 * 16, pitch: 60, vel: 100)],
    ),
  ],
);

SongLabEntry _entry({String? bandId, List<SectionSpan> spans = const []}) =>
    SongLabEntry(
      id: 'midi',
      songId: 'song',
      bandId: bandId,
      type: LabEntryType.midi,
      title: 'Practice song',
      authorId: 'user',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      midiSong: MidiSongMeta(
        fileUrl: 'https://example.com/song.mid',
        ppq: 480,
        initialBpm: 124,
        tracks: const [],
        sectionMap: spans,
      ),
    );

final _song = Song(
  id: 'song',
  title: 'Practice song',
  artist: 'Artist',
  ourBPM: 100,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  sections: [
    for (final name in ['Intro', 'Verse', 'Chorus', 'Outro'])
      Section(id: name.toLowerCase(), name: name),
  ],
);

const _spans = [
  SectionSpan(sectionId: 'intro', startBar: 0, bars: 4),
  SectionSpan(sectionId: 'verse', startBar: 4, bars: 4),
  SectionSpan(sectionId: 'chorus', startBar: 8, bars: 4),
  SectionSpan(sectionId: 'outro', startBar: 12, bars: 4),
];

class _Repository extends FirestoreLabRepository {
  _Repository()
    : super(firestore: MockFirebaseFirestore(), auth: MockFirebaseAuth());

  final saved = <(SongLabEntry, String?)>[];
  bool fail = false;

  @override
  Future<void> saveEntry(SongLabEntry entry, {String? bandId}) async {
    if (fail) throw StateError('Save failed');
    saved.add((entry, bandId));
  }
}

Future<void> _pump(
  WidgetTester tester,
  SongLabEntry entry,
  _Repository repository, {
  bool canEdit = true,
  bool canEditBand = true,
  bool backing = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        songsProvider.overrideWith((ref) => Stream.value([_song])),
        bandSongsProvider.overrideWith((ref, id) => Stream.value([_song])),
        midiSongProvider(entry).overrideWith((ref) async => _data),
        labEntriesProvider.overrideWith((ref, key) => Stream.value([entry])),
        labRepositoryProvider.overrideWithValue(repository),
        canEditProvider.overrideWithValue(canEdit),
        canEditBandProvider.overrideWith((ref, id) => canEditBand),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => backing
                    ? BackingSheet(songId: entry.songId, bandId: entry.bandId)
                    : ArrangementSheet(entry: entry),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save'));
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('prefills 16 bars over four sections as 4/4/4/4', (tester) async {
    await _pump(tester, _entry(), _Repository());

    expect(find.text('4'), findsNWidgets(4));
    for (final section in _song.sections) {
      expect(find.text('${section.name} bars'), findsOneWidget);
    }
    expect(
      find.text('16 bars · 1 instruments · 0 lead-in bars'),
      findsOneWidget,
    );
    expect(find.text('Use 124 BPM?'), findsOneWidget);
    expect(find.text('File starts at bar 0'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  for (final bandId in [null, 'band']) {
    testWidgets('Save persists spans for ${bandId ?? 'personal'} song', (
      tester,
    ) async {
      final entry = _entry(bandId: bandId);
      final repository = _Repository();
      await _pump(tester, entry, repository, canEdit: bandId == null);
      await _save(tester);

      expect(repository.saved, hasLength(1));
      final (saved, scope) = repository.saved.single;
      expect(scope, bandId);
      expect(saved.id, entry.id);
      expect(saved.midiSong!.sectionMap, _spans);
      expect(saved.midiSong!.startBar, 0);
      expect(saved.midiSong!.useFileTempo, isFalse);
      expect(saved.midiSong!.endBehavior, 'loop');
      expect(saved.midiSong!.fileUrl, entry.midiSong!.fileUrl);
      expect(find.byType(ArrangementSheet), findsNothing);
    });
  }

  testWidgets('edited controls are persisted with sequential spans', (
    tester,
  ) async {
    final repository = _Repository();
    await _pump(tester, _entry(), repository);
    await tester.tap(find.byType(Switch));
    await tester.tap(find.byTooltip('Increase File starts at bar 0'));
    await tester.tap(find.byTooltip('Increase Intro bars'));
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('stop').last);
    await tester.pumpAndSettle();
    await _save(tester);

    final meta = repository.saved.single.$1.midiSong!;
    expect(meta.startBar, 1);
    expect(meta.useFileTempo, isTrue);
    expect(meta.endBehavior, 'stop');
    expect(meta.sectionMap.map((span) => span.bars), [5, 4, 4, 4]);
    expect(meta.sectionMap.map((span) => span.startBar), [0, 5, 9, 13]);
  });

  for (final bandId in [null, 'band']) {
    testWidgets(
      '${bandId ?? 'personal'} viewer has no Save or editable controls',
      (tester) async {
        final repository = _Repository();
        await _pump(
          tester,
          _entry(bandId: bandId),
          repository,
          canEdit: bandId != null,
          canEditBand: false,
        );

        expect(find.text('Save'), findsNothing);
        expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
        for (final button in tester.widgetList<IconButton>(
          find.byType(IconButton),
        )) {
          expect(button.onPressed, isNull);
        }
        expect(
          tester
              .widget<DropdownButtonFormField<String>>(
                find.byType(DropdownButtonFormField<String>),
              )
              .onChanged,
          isNull,
        );
        expect(repository.saved, isEmpty);
      },
    );
  }

  testWidgets('save failure keeps the sheet open and allows retry', (
    tester,
  ) async {
    final repository = _Repository()..fail = true;
    await _pump(tester, _entry(), repository);
    await _save(tester);

    expect(find.textContaining('Save failed'), findsOneWidget);
    expect(find.byType(ArrangementSheet), findsOneWidget);
    repository.fail = false;
    await _save(tester);
    expect(repository.saved.single.$1.midiSong!.sectionMap, _spans);
  });

  testWidgets('first MIDI selection opens arrangement from backing sheet', (
    tester,
  ) async {
    await _pump(tester, _entry(), _Repository(), backing: true);
    await tester.tap(find.text('Practice song'));
    await tester.pumpAndSettle();

    expect(find.byType(ArrangementSheet), findsOneWidget);
    expect(find.byType(MidiSongPanel), findsNothing);
    expect(find.text('4'), findsNWidgets(4));
  });
}
