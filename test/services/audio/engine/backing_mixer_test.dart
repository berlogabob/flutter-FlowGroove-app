import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flowgroove/services/audio/engine/backing_mixer.dart';
import 'package:flowgroove/utils/bar_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixtureFile = File('test/fixtures/backing_golden.json');
  final fixture =
      jsonDecode(fixtureFile.readAsStringSync()) as Map<String, dynamic>;
  final sampleRate = fixture['sampleRate'] as int;
  final interval = (fixture['intervalMicros'] as num).toDouble();
  final ticks = fixture['ticksPerBar'] as int;
  final bpm = (fixture['renderBpm'] as num).toDouble();
  int start(int bar) => barStartFrame(
    bar: bar,
    ticksPerBar: ticks,
    intervalMicros: interval,
    sampleRate: sampleRate,
    epochFrame: 0,
  );
  final stems = <String, Int16List>{};
  for (final rule in (fixture['stems'] as List).cast<Map<String, dynamic>>()) {
    final bars = rule['songBars'] as int;
    final pcm = Int16List(start(bars));
    for (var tick = 0; tick < bars * ticks; tick++) {
      pcm[(tick * tickIntervalFrames(interval, sampleRate)).round()] =
          rule['pcm16'] as int;
    }
    stems[rule['name'] as String] = pcm;
  }

  BackingMixer mixer({Map<String, Int16List>? samples}) =>
      BackingMixer(sampleRate)..load(
        stems: samples ?? stems,
        renderBpm: bpm,
        ticksPerBar: ticks,
        intervalMicros: interval,
      );

  void launch(BackingMixer backing, {int fromBar = 0, int bars = 2}) {
    backing.command(
      token: 'test',
      kind: 'launch',
      fromBar: fromBar,
      bars: bars,
      loop: true,
      atBar: 0,
    );
  }

  void render(BackingMixer backing, Float32List out, int frame) {
    backing.mix(
      out: out,
      chunkStart: frame,
      engineBpm: bpm,
      epochFrame: 0,
      ticksPerBar: ticks,
      intervalMicros: interval,
    );
  }

  test('golden fixture stays under 200 KB', () {
    expect(fixtureFile.lengthSync(), lessThan(200 * 1024));
    for (final rule
        in (fixture['stems'] as List).cast<Map<String, dynamic>>()) {
      expect(rule['rule'], 'impulse_at_every_beat');
      expect(rule['amplitude'], 1.0);
    }
  });

  for (final data in (fixture['cases'] as List).cast<Map<String, dynamic>>()) {
    // Both sizes cross beats and bar boundaries at different offsets.
    for (final chunkSize in [4093, 65536]) {
      test('${data['name']} (chunks of $chunkSize)', () {
        final backing = mixer();
        final states = <Map<String, Object>>[];
        backing.onState = (token, state, bar) {
          states.add({
            'token': token,
            'state': state,
            'transportBar': bar,
            if (state == 'stopped') 'reason': backing.stopReason!,
          });
        };
        for (final op
            in (data['operations'] as List).cast<Map<String, dynamic>>()) {
          switch (op['op']) {
            case 'command':
              backing.command(
                token: op['token'] as String,
                kind: op['kind'] as String,
                fromBar: op['fromBar'] as int,
                bars: op['bars'] as int,
                loop: op['loop'] as bool,
                atBar: op['atBar'] as int,
              );
            case 'gain':
              backing.setGain(
                op['stem'] as String,
                (op['gain'] as num).toDouble(),
              );
            case 'mix':
              final first = op['chunkStart'] as int;
              final end = first + (op['frameCount'] as int);
              final actual = <int>[];
              for (var frame = first; frame < end; frame += chunkSize) {
                final out = Float32List(min(chunkSize, end - frame));
                backing.mix(
                  out: out,
                  chunkStart: frame,
                  engineBpm: (op['engineBpm'] as num?)?.toDouble() ?? bpm,
                  epochFrame: op['epochFrame'] as int? ?? 0,
                  ticksPerBar: ticks,
                  intervalMicros:
                      (op['intervalMicros'] as num?)?.toDouble() ?? interval,
                );
                for (var i = 0; i < out.length; i++) {
                  if (out[i] != 0) {
                    actual.add(frame + i);
                    expect(out[i], 32767 / 32768);
                  }
                }
              }
              expect(actual, op['expectedNonZeroFrames']);
              if (data['maxClickGridErrorFrames'] != null) {
                for (final frame in actual) {
                  final tick =
                      (frame / tickIntervalFrames(interval, sampleRate))
                          .round();
                  final click =
                      (tick * tickIntervalFrames(interval, sampleRate)).round();
                  expect(
                    (frame - click).abs(),
                    lessThanOrEqualTo(data['maxClickGridErrorFrames'] as int),
                  );
                }
                expect(end - first, sampleRate * 300);
              }
          }
        }
        expect(states, data['expectedStates']);
      });
    }
  }

  test('mix adds independent stems without clipping or clearing output', () {
    final backing = mixer(
      samples: {
        'drums': Int16List.fromList([16384, -32768]),
        'bass': Int16List.fromList([16384, 16384]),
      },
    );
    launch(backing);
    final out = Float32List.fromList([0.75, 0.75, 0.75]);
    render(backing, out, 0);
    expect(out, [1.75, 0.25, 0.75]);
  });

  test('gain ramp lasts 5 ms and survives chunk splits and retargeting', () {
    final backing = mixer(
      samples: {'drums': Int16List(2000)..fillRange(0, 2000, 16384)},
    );
    launch(backing);
    backing.setGain('drums', 0);
    final first = Float32List(120);
    render(backing, first, 0);
    for (var i = 0; i < first.length; i++) {
      expect(first[i], closeTo(0.5 * (1 - i / 240), 1e-7));
    }
    backing.setGain('drums', 1);
    final next = Float32List(241);
    render(backing, next, 120);
    for (var i = 0; i < next.length; i++) {
      expect(next[i], closeTo(0.25 + 0.25 * i / 240, 1e-7));
    }
    backing.setGain('drums', 0);
    final down = Float32List(241);
    render(backing, down, 361);
    expect(down.first, 0.5);
    expect(down[120], 0.25);
    expect(down.last, 0);
  });

  test('a longer transport bar pads instead of leaking the next song bar', () {
    // Transport bar 0 is one frame longer than song bar 1.
    expect(start(1), start(2) - start(1) + 1);
    final pcm = Int16List(start(3))..fillRange(0, start(3), 16384);
    final backing = mixer(samples: {'drums': pcm});
    launch(backing, fromBar: 1);
    final out = Float32List(3);
    render(backing, out, start(1) - 2);
    expect(out, [0.5, 0, 0.5]);
  });

  test('a shorter transport bar truncates and reanchors the next song bar', () {
    final pcm = Int16List(start(4))
      ..[start(1) - 1] = 16384
      ..[start(1)] = -16384;
    final backing = mixer(samples: {'drums': pcm})
      ..command(
        token: 'test',
        kind: 'launch',
        fromBar: 0,
        bars: 2,
        loop: false,
        atBar: 1,
      );
    final out = Float32List(3);
    render(backing, out, start(2) - 1);
    expect(out, [0, -0.5, 0]);
  });

  test(
    'skipping chunks still reports launch and natural end at their bars',
    () {
      final backing = mixer();
      final states = <String>[];
      backing
        ..onState = (token, state, bar) {
          states.add('$state:$bar');
        }
        ..command(
          token: 'test',
          kind: 'launch',
          fromBar: 0,
          bars: 2,
          loop: false,
          atBar: 3,
        );
      render(backing, Float32List(1), start(8));
      expect(states, ['queued:3', 'playing:3', 'stopped:5']);
    },
  );
}
