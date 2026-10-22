import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../../models/midi_song.dart';
import '../../../utils/bar_math.dart';
import 'midi_song_meta_builder.dart';
import 'midi_track_renderer.dart';

/// Builds mono stems on a constant target-tempo grid (bars are zero-based).
/// Source tempo changes are flattened so every song bar stays on that grid.
/// Release tails are truncated at the final bar line.
Future<Map<String, Int16List>> buildBackingStems({
  required MidiSongData song,
  required double renderBpm,
  MidiSongMeta? meta,
  int sampleRate = 44100,
  int ticksPerBar = 4,
  double? intervalMicros,
  FutureOr<void> Function()? yieldHook,
}) async {
  final interval = intervalMicros ?? 60000000 / renderBpm;
  final bpmScale = renderBpm / song.initialBpm;
  if (sampleRate <= 0 ||
      song.ppq <= 0 ||
      ticksPerBar <= 0 ||
      !renderBpm.isFinite ||
      renderBpm <= 0 ||
      !bpmScale.isFinite ||
      bpmScale <= 0 ||
      !interval.isFinite ||
      interval <= 0 ||
      ticksPerBar * tickIntervalFrames(interval, sampleRate) < 1) {
    throw ArgumentError('Invalid backing tempo or grid');
  }
  final settings = buildMidiSongMeta(song, previous: meta);
  var endTick = 0;
  for (final track in song.tracks) {
    for (final note in track.notes) {
      if (note.tick >= 0 && note.dur > 0) {
        endTick = math.max(endTick, note.tick + note.dur);
      }
    }
  }
  final secondsPerTick = 60 / renderBpm / song.ppq;
  final songBars =
      endTick * secondsPerTick * 1000000 / (ticksPerBar * interval);
  // Floating-point tempo conversion must not add a bar to an exact boundary.
  final nearestBar = songBars.round();
  final bars = (songBars - nearestBar).abs() < 1e-9
      ? nearestBar
      : songBars.ceil();
  final length = barStartFrame(
    bar: bars,
    ticksPerBar: ticksPerBar,
    intervalMicros: interval,
    sampleRate: sampleRate,
    epochFrame: 0,
  );
  final gridSong = MidiSongData(
    ppq: song.ppq,
    tempos: [
      TempoChange(
        tick: 0,
        microsPerQuarter: (60000000 / song.initialBpm).round(),
      ),
    ],
    timeSigs: song.timeSigs,
    tracks: song.tracks,
  );
  final mixes = <String, Float64List>{};
  final pause = yieldHook ?? () => Future<void>.delayed(Duration.zero);

  for (var t = 0; t < song.tracks.length; t++) {
    final track = song.tracks[t];
    final setting = settings.tracks[t];
    if (!setting.mute && track.notes.isNotEmpty && length > 0) {
      final role = setting.effectiveRole;
      final name = switch (role) {
        MidiRole.drums => 'Drums',
        MidiRole.bass => 'Bass',
        MidiRole.vocal || MidiRole.lead => 'Lead',
        _ => 'Harmony',
      };
      final mix = mixes.putIfAbsent(name, () => Float64List(length));
      for (final note in track.notes) {
        if (note.tick < 0 || note.dur <= 0) continue;
        final start = (note.tick * secondsPerTick * sampleRate).round();
        if (start >= length) continue;
        final voiceTrack = MidiTrackData(
          index: track.index,
          name: track.name,
          channel: track.channel,
          program: track.program,
          notes: [
            MidiNote(tick: 0, dur: note.dur, pitch: note.pitch, vel: note.vel),
          ],
        );
        // Re-render the prefix to preserve phase and release across yields.
        for (var offset = 0; start + offset < length; offset += sampleRate) {
          final end = math.min(offset + sampleRate, length - start);
          final pcm = renderMidiTrack(
            song: gridSong,
            track: voiceTrack,
            role: role,
            sampleRate: sampleRate,
            bpmScale: bpmScale,
            maxSeconds: end / sampleRate,
          );
          for (var i = offset; i < math.min(end, pcm.length); i++) {
            mix[start + i] += pcm[i] * setting.volume;
          }
          await pause();
          if (pcm.length < end) break;
        }
      }
    }
    await pause();
  }

  final stems = <String, Int16List>{};
  for (final entry in mixes.entries) {
    var peak = 0.0;
    for (var offset = 0; offset < length; offset += sampleRate) {
      final end = math.min(offset + sampleRate, length);
      for (var i = offset; i < end; i++) {
        peak = math.max(peak, entry.value[i].abs());
      }
      await pause();
    }
    final gain = peak > 32767 ? 32767 / peak : 1.0;
    final pcm = Int16List(length);
    for (var offset = 0; offset < length; offset += sampleRate) {
      final end = math.min(offset + sampleRate, length);
      for (var i = offset; i < end; i++) {
        pcm[i] = (entry.value[i] * gain).round().clamp(-32768, 32767);
      }
      await pause();
    }
    stems[entry.key] = pcm;
  }
  return stems;
}
