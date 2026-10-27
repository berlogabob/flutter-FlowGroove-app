import 'dart:typed_data';

import 'package:flowgroove/models/midi_pattern.dart';
import 'package:flowgroove/models/section_span.dart';
import 'package:flowgroove/providers/data/backing_transport_provider.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/services/audio/backing_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backing_transport_test.dart' show FakeBackingEngine, FakeMetronome;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeBackingEngine engine;
  late ProviderContainer container;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    engine = FakeBackingEngine();
    container = ProviderContainer(
      overrides: [
        backingEngineProvider.overrideWithValue(engine),
        metronomeProvider.overrideWith(FakeMetronome.new),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await engine.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  test('song audio loads as a stem with drums tiled under it', () async {
    final transport = container.read(backingTransportProvider.notifier);
    final audio = Int16List(40000)..fillRange(0, 40000, 1000);
    const spans = [SectionSpan(sectionId: 'verse', startBar: 0, bars: 4)];
    await transport.attachAudio(
      audio: audio,
      spans: spans,
      drums: MidiPattern(
        name: 'Rock',
        bars: 1,
        beatsPerBar: 4,
        stepsPerBeat: 4,
        hits: const [MidiHit(step: 0, note: 36, vel: 100)],
      ),
    );
    final stems = engine.loads.single;
    expect(stems.names, ['Song', 'Drums']);
    expect(stems.stems.first, same(audio));
    expect(stems.stems.last, hasLength(audio.length));
    expect(container.read(backingTransportProvider).spans, spans);

    await transport.launch('verse');
    final launch = engine.commands.single;
    expect(launch.kind, BackingKind.launch);
    expect((launch.fromBar, launch.bars, launch.loop), (0, 4, true));

    transport.setSpans(const [
      SectionSpan(sectionId: 'run', startBar: 0, bars: 8),
    ]);
    expect(container.read(backingTransportProvider).spans.single.bars, 8);
  });
}
