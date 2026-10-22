import 'dart:async';

import 'package:flowgroove/models/metronome_state.dart';
import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/models/song_lab.dart';
import 'package:flowgroove/providers/data/backing_transport_provider.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/providers/data/midi_song_practice_provider.dart';
import 'package:flowgroove/widgets/midi/midi_song_panel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backing_transport_test.dart' show FakeBackingEngine;

class _Metronome extends MetronomeNotifier {
  @override
  MetronomeState build() => MetronomeState.initial();
}

class _Practice extends MidiSongPracticeNotifier {
  _Practice(super.entry, {required this.usesBackingTransport});

  @override
  final bool usesBackingTransport;

  @override
  MidiSongPracticeState build() => const MidiSongPracticeState();

  @override
  Future<void> loadEntry({
    FutureOr<void> Function(SongLabEntry)? onPersist,
  }) async {}
}

void main() {
  for (final platform in TargetPlatform.values) {
    test('selects backing transport only on Android ($platform)', () {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final engine = FakeBackingEngine();
      final container = ProviderContainer(
        overrides: [backingEngineProvider.overrideWithValue(engine)],
      );
      addTearDown(() async {
        container.dispose();
        await engine.dispose();
      });
      expect(
        container.read(useBackingTransportProvider),
        kIsWeb || platform == TargetPlatform.android,
      );
    });
  }

  for (final backing in [true, false]) {
    testWidgets('panel playback controls follow the selected path ($backing)', (
      tester,
    ) async {
      final engine = FakeBackingEngine();
      addTearDown(engine.dispose);
      final entry = SongLabEntry(
        id: 'midi',
        songId: 'song',
        type: LabEntryType.midi,
        title: 'Practice song',
        authorId: 'author',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        midiSong: const MidiSongMeta(ppq: 96, initialBpm: 120, tracks: []),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            backingEngineProvider.overrideWithValue(engine),
            useBackingTransportProvider.overrideWithValue(backing),
            midiSongPracticeProvider(entry).overrideWith(
              () => _Practice(entry, usesBackingTransport: backing),
            ),
            metronomeProvider.overrideWith(_Metronome.new),
          ],
          child: MaterialApp(
            home: Scaffold(body: MidiSongPanel(entry: entry)),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Mixer'), backing ? findsOneWidget : findsNothing);
      expect(find.text('Play'), backing ? findsNothing : findsOneWidget);
      expect(
        find.byType(FilledButton),
        backing ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
