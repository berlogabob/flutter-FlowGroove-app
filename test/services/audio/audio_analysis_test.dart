import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flowgroove/models/audio_region.dart';
import 'package:flowgroove/services/audio/audio_analysis.dart';

Int16List buildPCM() {
  const sampleRate = 22050;
  const duration = 20; // seconds
  final samples = sampleRate * duration;
  final pcm = Int16List(samples);
  const bpm = 120.0;
  final intervalSamples = (sampleRate * 60.0 / bpm).round();
  final startMs = 300;
  final startSample = (startMs * sampleRate ~/ 1000);
  const burstMs = 10;
  final burstSamples = (burstMs * sampleRate ~/ 1000);

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
