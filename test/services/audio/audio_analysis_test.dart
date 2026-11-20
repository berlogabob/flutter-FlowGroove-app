import 'dart:math';
import 'dart:typed_data';

import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/services/audio/audio_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

Int16List buildPCM() {
  const sampleRate = 22050;
  const duration = 20; // seconds
  const samples = sampleRate * duration;
  final pcm = Int16List(samples);
  const bpm = 120.0;
  final intervalSamples = (sampleRate * 60.0 / bpm).round();
  const startMs = 300;
  const startSample = startMs * sampleRate ~/ 1000;
  const burstMs = 10;
  const burstSamples = burstMs * sampleRate ~/ 1000;

  var i = 0;
  for (var t = startSample; t < samples - burstSamples; t += intervalSamples) {
    final loud = (i % 4 == 0);
    final value = loud ? 30000 : 12000;
    for (var b = 0; b < burstSamples; b++) {
      pcm[t + b] = (b % 2 == 0) ? value : -value;
    }
    i++;
  }
  return pcm;
}

void main() {
  final pcm = buildPCM();

  test('snapBpm prefers nearby whole BPM, otherwise tenths', () {
    expect(snapBpm(87.03), 87);
    expect(snapBpm(86.96), 87);
    expect(snapBpm(123.5), 123.5);
    expect(snapBpm(87.06), 87.1);
  });

  test('estimateGrid matches 120 BPM and 300 ms downbeat', () {
    final grid = estimateGrid(pcm, 22050);
    expect(grid, isNotNull);
    expect(
      (grid!.bpm - 120).abs() <= 0.5,
      isTrue,
      reason: 'bpm was ${grid.bpm}',
    );
    expect(
      (grid.firstDownbeatMs - 300).abs() <= 20,
      isTrue,
      reason: 'downbeat was ${grid.firstDownbeatMs} ms',
    );
  });

  for (final bpm in [170, 163, 75]) {
    test('estimateGrid recovers $bpm BPM without a hint', () {
      // At this rate the old search picks half tempo for both fast trains.
      const sampleRate = 16875;
      final train = Int16List(sampleRate * 20);
      for (var beat = 0; ; beat++) {
        final onset = ((0.3 + beat * 60 / bpm) * sampleRate).round();
        if (onset >= train.length) break;
        train[onset] = beat % 4 == 0 ? 30000 : 12000;
      }

      expect(estimateGrid(train, sampleRate)!.bpm, closeTo(bpm, 0.5));
    });
  }

  test('3+3+2 pulse at 80 keeps the bar rather than the dotted ghost beat', () {
    const sr = 22050;
    final dotted = Int16List(sr * 48);
    for (var bar = 0; bar < 16; bar++) {
      for (final eighth in [0, 3, 6]) {
        final start = ((0.3 + bar * 3 + eighth * 0.375) * sr).round();
        for (var j = 0; j < 220 && start + j < dotted.length; j++) {
          dotted[start + j] = j.isEven ? 24000 : -24000;
        }
      }
    }
    expect(estimateGrid(dotted, sr)!.bpm, closeTo(80, 0.5));
  });
  test(
    'meter interpolates fractional lags and preserves tied and short inputs',
    () {
      const rate = 100.0;
      final dotted = List<double>.filled(4800, 0);
      for (var bar = 0; bar < 16; bar++) {
        for (final eighth in [0, 3, 6]) {
          dotted[((0.37 + bar * 3 + eighth * 0.375) * rate).round()] =
              eighth == 0 ? 2 : 1;
        }
      }
      List<double> competing(double accent, double pulse) {
        final strength = [...dotted];
        for (var bar = 0; bar < 16; bar++) {
          strength[((0.37 + bar * 3) * rate).round()] += accent - 2;
        }
        for (var k = 0; k <= 84; k++) {
          strength[((0.37 + k * 0.5625) * rate).round()] += pulse;
        }
        return strength;
      }

      expect(meterBpm(competing(2, 0.8), rate, 80 * 4 / 3), 80);
      expect(meterBpm(competing(5, 1.5), rate, 80 * 4 / 3), 80);
      expect(meterBpm(List.filled(1000, 0), rate, 120), 120);
      expect(meterBpm([], rate, 120), 120);
      expect(meterBpm([0, 0], 0, 120), 120);
    },
  );
  test('only a first kick within a quarter beat overrides the comb', () {
    expect(kickDownbeatIndex(5.1, 0.1, 0.5, 3), 2);
    expect(kickDownbeatIndex(5.35, 0.1, 0.5, 3), 3);
    expect(kickDownbeatIndex(5.35, 0.1, 0.5, 0), 0);
    expect(kickDownbeatIndex(5.225, 0.1, 0.5, 3), 2);
    expect(kickDownbeatIndex(4.975, 0.1, 0.5, 3), 2);
    expect(kickDownbeatIndex(null, 0.1, 0.5, 3), 3);
    expect(kickDownbeatIndex(-0.4, 0.1, 0.5, 0), 3);
  });
  test('first kick matches reference entry and fallback cases', () {
    final low = [
      for (var i = 0; i < 2000; i++)
        if (i / 100 < 5.1)
          1e-10
        else
          0.1 * exp(-((i / 100 - 5.1 + 1e-9) % 0.5) / 0.08),
    ];
    expect(kickEntrySeconds(low, 100), closeTo(5.1, 0.011));
    expect(kickEntrySeconds([], 100), isNull);
    expect(kickEntrySeconds([0, 0, 0], 100), isNull);
    final weak = [
      for (var i = 1; i <= 100; i++)
        if (i > 6 && i.isEven) 100.0 else 0.0001,
    ];
    weak[0] = 0;
    weak[2] = 0.0002;
    weak[4] = 0.0004;
    expect(kickEntrySeconds(weak, 10), 0.4);
    expect(kickEntrySeconds([0.0001, 0.001, 0.1, 100], 1), 1);
  });
  test('detectOnsets finds one click per beat (±1), first near 300 ms', () {
    final onsets = detectOnsets(pcm, 22050);
    // Clicks every 500 ms from 300 ms to 19 800 ms: 40.
    expect(onsets.length, inInclusiveRange(39, 41));
    expect(onsets.isNotEmpty, isTrue);
    expect(
      (onsets.first - 300).abs() <= 15,
      isTrue,
      reason: 'first onset was ${onsets.first} ms',
    );
  });

  test('estimateGrid puts the downbeat on the low thump despite backbeats', () {
    const sampleRate = 22050;
    const startMs = 300;
    final bandPcm = Int16List(sampleRate * 20);
    final noise = Random(12);
    for (var eighth = 0; ; eighth++) {
      final start = ((startMs + eighth * 250) * sampleRate / 1000).round();
      if (start >= bandPcm.length) break;
      final thump = eighth % 8 == 0;
      final backbeat = eighth % 8 == 2 || eighth % 8 == 6;
      final length = (sampleRate * (thump ? 0.1 : 0.01)).round();
      for (var i = 0; i < length && start + i < bandPcm.length; i++) {
        final t = i / sampleRate;
        final hat = i < sampleRate * 0.006
            ? 1200 * (2 * noise.nextDouble() - 1)
            : 0.0;
        final hit = thump
            ? 24000 * sin(2 * pi * 60 * t) * exp(-t / 0.04)
            : backbeat
            ? 24000 * (2 * noise.nextDouble() - 1)
            : 0.0;
        bandPcm[start + i] = (hit + hat).round();
      }
    }

    final grid = estimateGrid(bandPcm, sampleRate);
    expect(grid, isNotNull);
    expect(grid!.bpm, closeTo(120, 0.5));
    expect(
      grid.firstDownbeatMs,
      closeTo(startMs, 20),
      reason: 'downbeat should follow the thump, not the clicks on 2 and 4',
    );
  });

  test('trusted first kick overrides a stronger later downbeat comb', () {
    const sr = 22050;
    final band = Int16List(sr * 20);
    for (var beat = 0; beat < 40; beat++) {
      final start = ((0.3 + beat * 0.5) * sr).round();
      for (var i = 0; i < 220 && start + i < band.length; i++) {
        band[start + i] =
            (16000 * sin(2 * pi * 2000 * i / sr) * sin(pi * i / 220)).round();
      }
    }
    for (var i = (1.3 * sr).round(); i < band.length; i++) {
      band[i] += (2000 * sin(2 * pi * 60 * i / sr)).round();
    }
    for (final ms in [1300, for (var t = 2300; t < 20000; t += 2000) t]) {
      final start = ms * sr ~/ 1000;
      for (var i = 0; i < sr ~/ 5 && start + i < band.length; i++) {
        final value =
            band[start + i] +
            18000 * sin(2 * pi * 60 * i / sr) * exp(-i / sr / 0.04);
        band[start + i] = value.round().clamp(-32768, 32767);
      }
    }
    expect(estimateGrid(band, sr)!.firstDownbeatMs, closeTo(1300, 20));
  });
  test('estimateGrid takes the octave from the song BPM', () {
    expect(estimateGrid(pcm, 22050, hintBpm: 240)!.bpm, closeTo(240, 1));
    expect(estimateGrid(pcm, 22050, hintBpm: 60)!.bpm, closeTo(60, 0.5));
    // Not an octave of the hint: keep what was heard.
    expect(estimateGrid(pcm, 22050, hintBpm: 100)!.bpm, closeTo(120, 0.5));
  });

  test('estimateGrid returns null for PCM shorter than 4 seconds', () {
    final shortPcm = Int16List(2 * 22050);
    expect(estimateGrid(shortPcm, 22050), isNull);
  });

  test('sectionCuts finds where a quiet part turns loud and back', () {
    // 120 BPM: 2 s bars. 16 quiet bars of a soft tone, 16 loud bars of
    // noise with hits, 16 quiet bars again.
    const rate = 22050;
    final song = Int16List(48 * 2 * rate);
    final random = Random(7);
    for (var i = 0; i < song.length; i++) {
      final bar = i ~/ (2 * rate);
      song[i] = bar >= 16 && bar < 32
          ? (random.nextDouble() * 2 - 1) *
                (i % (rate ~/ 2) < 800 ? 20000 : 6000) ~/
                1
          : (sin(2 * pi * 220 * i / rate) * 1500).round();
    }
    final cuts = sectionCuts(song, rate, grid: const AudioGrid(bpm: 120));
    expect(topSectionCuts(cuts, 2), [32000, 64000]);
    expect(cuts.first.strength, greaterThan(1));
    expect(suggestedSectionCuts(cuts, songSections: 3), 2);
    expect(suggestedSectionCuts(cuts), greaterThanOrEqualTo(2));
  });
}
