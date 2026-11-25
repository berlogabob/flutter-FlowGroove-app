// Metronome and tuner: MT-02, MT-03, MT-04, MT-08.
import 'dart:async';

import 'package:flowgroove/models/metronome_state.dart';
import 'package:flowgroove/providers/data/metronome_provider.dart';
import 'package:flowgroove/providers/tuner_provider.dart';
import 'package:flowgroove/router/app_router.dart';
import 'package:flowgroove/screens/metronome_screen.dart';
import 'package:flowgroove/screens/tuner_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'check.dart';

Future<ProviderContainer> _openMetronome(WidgetTester tester) async {
  final c = await bootApp(tester);
  unawaited(appRouter.push('/main/metronome'));
  await see(tester, find.byType(MetronomeScreen), 'metronome screen');
  await pause(tester, 800); // the route is still sliding in when the screen first exists
  return c;
}

void registerMetronomeChecks() {
  check('MT-02', 'BPM change applies while playing', (tester) async {
    final c = await _openMetronome(tester);
    MetronomeNotifier n() => c.read(metronomeProvider.notifier);
    bool playing() => c.read(metronomeProvider).isPlaying;
    int bpm() => c.read(metronomeProvider).bpm;
    try {
      final start = bpm();
      await tapOn(tester, find.byIcon(Icons.play_arrow), 'play button');
      await pumpUntil(tester, playing, what: 'metronome playing');
      await tapOn(tester, find.text('+5'), '+5 button');
      await tapOn(tester, find.text('+1'), '+1 button');
      if (bpm() != start + 6) fail('expected BPM ${start + 6} after +5 and +1 from $start; observed ${bpm()}');
      if (!playing()) fail('metronome stopped when the BPM changed (BPM ${bpm()})');
      await see(tester, label('${start + 6}'), 'tempo ${start + 6} shown on the dial');
      await tapOn(tester, find.text('−5'), '−5 button');
      await tapOn(tester, find.text('−1'), '−1 button');
      if (bpm() != start) fail('expected BPM $start after −5 and −1; observed ${bpm()}');
      await tester.pump(const Duration(seconds: 1));
      if (!playing()) fail('metronome stopped by itself after tempo changes');
    } finally {
      if (playing()) n().stop();
    }
  });

  check('MT-03', 'Time signature / subdivision change', (tester) async {
    final c = await _openMetronome(tester);
    MetronomeState s() => c.read(metronomeProvider);
    final beats = s().accentBeats;
    final subs = s().regularBeats;
    final plus = byKey('main-beats-increment');
    await see(tester, plus, 'beats "+" button');
    await tapOn(tester, plus, 'beats "+" button');
    await pause(tester, 500);
    if (s().accentBeats != beats + 1) fail('expected ${beats + 1} beats after tapping "+"; observed ${s().accentBeats}');
    if (!found(byKey('main_beat_dot_$beats'))) fail('expected a new beat dot main_beat_dot_$beats after "+"');
    await tapOn(tester, byKey('main-beats-decrement'), 'beats "-" button');
    await pause(tester, 500);
    if (s().accentBeats != beats) fail('expected $beats beats after "-"; observed ${s().accentBeats}');
    if (found(byKey('main_beat_dot_$beats'))) fail('beat dot main_beat_dot_$beats still shown after "-"');
    await tapOn(tester, byKey('subdivisions-increment'), 'subdivisions "+" button');
    await pause(tester, 500);
    if (s().regularBeats != subs + 1) fail('expected ${subs + 1} subdivisions after "+"; observed ${s().regularBeats}');
    if (!found(byKey('subdivision_dot_$subs'))) fail('expected subdivision dot subdivision_dot_$subs after "+"');
    await tapOn(tester, byKey('subdivisions-decrement'), 'subdivisions "-" button');
    await pause(tester, 500);
    if (s().regularBeats != subs) fail('expected $subs subdivisions after "-"; observed ${s().regularBeats}');
  });

  check('MT-04', 'Launchpad: pads, mute, solo', (tester) async {
    throw CheckSkip(
      'the launchpad only appears for a song with a MIDI backing track; the seed has none, '
      'and MIDI import (MD-01) is outside this batch',
    );
  });

  check('MT-08', 'Tuner tone plays the chosen note', (tester) async {
    final c = await bootApp(tester);
    unawaited(appRouter.push('/main/tuner'));
    await see(tester, find.byType(TunerScreen), 'tuner screen');
    TunerState s() => c.read(tunerProvider);
    try {
      await tapOn(tester, find.text('Tone'), 'Tone mode');
      await tapOn(tester, find.byType(DropdownButton<String>), 'note dropdown');
      await tapOn(tester, find.text('E').last, 'note E');
      await pause(tester, 300);
      final note = s().note;
      final freq = s().frequency;
      if (note != 'E4' || (freq - 329.63).abs() > 0.1) {
        fail('expected note E4 at 329.63 Hz after choosing E; observed $note at ${freq.toStringAsFixed(2)} Hz');
      }
      await tapOn(tester, find.byIcon(Icons.play_arrow), 'play tone button');
      await eventually(
        tester,
        () async => s(),
        (t) => t.isPlaying,
        'tone playing',
        seconds: 5,
        show: (t) => 'isPlaying ${t.isPlaying}, starting ${t.isStarting}, error ${t.errorMessage}',
      );
      if ((s().frequency - 329.63).abs() > 0.1) fail('playing ${s().frequency} Hz, expected 329.63 Hz');
      await see(tester, find.byIcon(Icons.stop), 'stop button while the tone plays');
    } finally {
      if (s().isPlaying) await c.read(tunerProvider.notifier).togglePlaying();
    }
  });
}
