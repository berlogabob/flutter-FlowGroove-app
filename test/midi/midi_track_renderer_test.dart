import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flowgroove/models/midi_song.dart';
import 'package:flowgroove/services/audio/midi/drum_map.dart';
import 'package:flowgroove/services/audio/midi/drum_samples.dart';
import 'package:flowgroove/services/audio/midi/midi_track_renderer.dart';
import 'package:flowgroove/services/audio/midi/voice_synth.dart';
import 'package:flutter_test/flutter_test.dart';

const a440 = MidiNote(tick: 0, dur: 480, pitch: 69, vel: 127);

Int16List render(
  List<MidiNote> notes, {
  List<TempoChange> tempos = const [],
  MidiRole role = MidiRole.other,
  double bpmScale = 1,
  double maxSeconds = 600,
}) {
  final track = MidiTrackData(
    index: 0,
    name: 'Test',
    channel: 0,
    program: 0,
    notes: notes,
  );
  return renderMidiTrack(
    song: MidiSongData(ppq: 480, tempos: tempos, timeSigs: [], tracks: [track]),
    track: track,
    role: role,
    sampleRate: 8000,
    bpmScale: bpmScale,
    maxSeconds: maxSeconds,
  );
}

int peak(Int16List samples) =>
    samples.fold<int>(0, (peak, sample) => math.max(peak, sample.abs()));

void main() {
  test('empty track returns empty Int16 PCM', () {
    expect(render([]), isEmpty);
  });

  test('440 Hz note uses default tempo and includes the full release', () {
    final output = render([a440]);
    expect(output, isA<Int16List>());
    expect(output.length, 4240);
    expect(peak(output), greaterThan(1000));
    final voice = Float32List(4240);
    addVoice(
      voice,
      sampleRate: 8000,
      startSample: 0,
      durationSamples: 4000,
      pitch: 69,
      velocity01: 1,
      role: MidiRole.other,
    );
    expect(output.skip(4000), contains(isNot(0)));
    expect(
      output.skip(4000),
      orderedEquals(voice.skip(4000).map((v) => (v * 32767).round())),
    );
    expect(output.last, 0);
    final crossings = <int>[];
    for (var i = 101; i < 3100; i++) {
      if (output[i - 1] <= 0 && output[i] > 0) crossings.add(i);
    }
    final frequency =
        (crossings.length - 1) * 8000 / (crossings.last - crossings.first);
    expect(frequency, closeTo(440, 1));
  });

  const tempos = [
    TempoChange(tick: 0, microsPerQuarter: 500000),
    TempoChange(tick: 480, microsPerQuarter: 250000),
  ];

  test('note after tempo change starts at integrated sample position', () {
    const note = MidiNote(tick: 960, dur: 480, pitch: 69, vel: 127);
    final output = render([note], tempos: tempos);
    // 0.5 s before the change + 0.25 s after it = frame 6000.
    expect(output.length, 8240);
    expect(output.take(6000).every((sample) => sample == 0), isTrue);
    final reference = render([a440]);
    expect(output.sublist(6000, 8000), orderedEquals(reference.take(2000)));
    expect(output[6001], isNot(0));
  });

  test('duration crossing a tempo change integrates both tempos', () {
    const note = MidiNote(tick: 240, dur: 720, pitch: 69, vel: 127);
    final output = render([note], tempos: tempos);
    expect(output.length, 6240); // 0.25 s start, 0.75 s note-off + release.
    expect(output.take(2000).every((sample) => sample == 0), isTrue);
    expect(peak(output), greaterThan(0));
  });

  test('bpmScale 2 halves note duration and offsets, preserving release', () {
    expect(render([a440], bpmScale: 2).length, 2240);
    final output = render(
      [const MidiNote(tick: 960, dur: 480, pitch: 69, vel: 127)],
      tempos: tempos,
      bpmScale: 2,
    );
    expect(output.length, 4240);
    expect(output.take(3000).every((sample) => sample == 0), isTrue);
    expect(output[3001], isNot(0));
  });

  test('maxSeconds clips a sustained note and drops hits at or past cap', () {
    final output = render([
      const MidiNote(tick: 0, dur: 1920, pitch: 69, vel: 127),
      const MidiNote(tick: 960, dur: 480, pitch: 60, vel: 127),
      const MidiNote(tick: 1440, dur: 480, pitch: 60, vel: 127),
    ], maxSeconds: 1);
    expect(output.length, 8000);
    expect(
      output,
      orderedEquals(
        render([
          const MidiNote(tick: 0, dur: 1920, pitch: 69, vel: 127),
        ], maxSeconds: 1),
      ),
    );
    expect(
      render([
        const MidiNote(tick: 960, dur: 480, pitch: 60, vel: 127),
      ], maxSeconds: 1),
      isEmpty,
    );
  });

  test('drums reuse lane samples with velocity and no loop wrap', () {
    final output = render([
      const MidiNote(tick: 240, dur: 240, pitch: 36, vel: 64),
    ], role: MidiRole.drums);
    final sample = drumSample(DrumLane.kick, sampleRate: 8000);
    expect(output.length, 2000 + sample.length);
    expect(output.take(2000).every((sample) => sample == 0), isTrue);
    expect(peak(output), greaterThan(0));
    expect(
      output.sublist(2000),
      orderedEquals(sample.map((v) => (v * 64 / 127 * 32767).round())),
    );
  });

  test('a final one-tick drum hit includes its full sample', () {
    for (final pitch in [36, 38, 42, 46, 48, 45, 41, 49, 51]) {
      final lane = laneForNote(pitch)!;
      final sample = drumSample(lane, sampleRate: 8000);
      final output = render([
        MidiNote(tick: 480, dur: 1, pitch: pitch, vel: 127),
      ], role: MidiRole.drums);
      expect(output.length, 4000 + sample.length, reason: lane.name);
      expect(output.take(4000).every((v) => v == 0), isTrue);
      expect(
        output.skip(4000),
        orderedEquals(sample.map((v) => (v * 32767).round())),
        reason: lane.name,
      );
    }
  });

  test('maxSeconds clips drum and voice tails', () {
    const hit = MidiNote(tick: 480, dur: 1, pitch: 49, vel: 127);
    expect(
      render([hit], role: MidiRole.drums, maxSeconds: 0.6),
      orderedEquals(render([hit], role: MidiRole.drums).take(4800)),
    );
    expect(
      render([a440], maxSeconds: 0.51),
      orderedEquals(render([a440]).take(4080)),
    );
  });

  test('unmapped drum notes are silent', () {
    expect(render([a440], role: MidiRole.drums).every((v) => v == 0), isTrue);
  });

  test('quiet output keeps its gain; clipping mixes are scaled into int16', () {
    final single = render([a440]);
    final doubleVoice = render([a440, a440]);
    expect(peak(single), lessThan(10000));
    expect(peak(doubleVoice), closeTo(peak(single) * 2, 1));
    for (final role in MidiRole.values) {
      final note = role == MidiRole.drums
          ? const MidiNote(tick: 0, dur: 480, pitch: 38, vel: 127)
          : a440;
      final output = render(List.filled(64, note), role: role);
      expect(peak(output), 32767, reason: role.name);
      expect(output.every((v) => v >= -32768 && v <= 32767), isTrue);
    }
  });
}
