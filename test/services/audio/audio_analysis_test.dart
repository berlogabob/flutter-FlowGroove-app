import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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
}
