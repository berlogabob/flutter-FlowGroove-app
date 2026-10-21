import 'dart:math' as math;
import 'dart:typed_data';

import '../../../models/midi_song.dart';
import 'drum_map.dart';
import 'drum_samples.dart';
import 'voice_synth.dart';

/// Renders mono PCM, ending at the last note-off or [maxSeconds].
///
/// [bpmScale] is playback BPM / song.initialBpm; 2 plays twice as fast.
/// Drum and voice release tails are clipped to the output length.
Int16List renderMidiTrack({
  required MidiSongData song,
  required MidiTrackData track,
  required MidiRole role,
  int sampleRate = 44100,
  double bpmScale = 1,
  double maxSeconds = 600,
}) {
  if (sampleRate <= 0 || song.ppq <= 0) {
    throw ArgumentError('sampleRate and song.ppq must be positive');
  }
  if (!bpmScale.isFinite || bpmScale <= 0) {
    throw ArgumentError.value(
      bpmScale,
      'bpmScale',
      'Must be finite and positive',
    );
  }
  if (!maxSeconds.isFinite || maxSeconds < 0) {
    throw ArgumentError.value(
      maxSeconds,
      'maxSeconds',
      'Must be finite and non-negative',
    );
  }
  if (track.notes.isEmpty || maxSeconds == 0) return Int16List(0);

  final tempos = [...song.tempos]..sort((a, b) => a.tick.compareTo(b.tick));
  double secondsAt(int tick) {
    var previousTick = 0;
    var microsPerQuarter = 500000;
    var micros = 0.0;
    for (final tempo in tempos) {
      if (tempo.tick > tick) break;
      micros += (tempo.tick - previousTick) * microsPerQuarter / song.ppq;
      previousTick = tempo.tick;
      microsPerQuarter = tempo.microsPerQuarter;
    }
    micros += (tick - previousTick) * microsPerQuarter / song.ppq;
    return micros / 1000000 / bpmScale;
  }

  final notes = <({MidiNote note, int start, int end})>[];
  var length = 0;
  for (final note in track.notes) {
    if (note.tick < 0 || note.dur <= 0) continue;
    final startSeconds = secondsAt(note.tick);
    if (startSeconds >= maxSeconds) continue;
    final start = (startSeconds * sampleRate).round();
    final end =
        (math.min(secondsAt(note.tick + note.dur), maxSeconds) * sampleRate)
            .round();
    if (end <= start) continue;
    notes.add((note: note, start: start, end: end));
    length = math.max(length, end);
  }

  final mix = Float64List(length);
  final samples = <DrumLane, Float32List>{};
  for (final timed in notes) {
    final note = timed.note;
    if (role == MidiRole.drums) {
      final lane = laneForNote(note.pitch);
      if (lane == null) continue;
      final sample = samples.putIfAbsent(
        lane,
        () => drumSample(lane, sampleRate: sampleRate),
      );
      final count = math.min(sample.length, length - timed.start);
      final gain = (note.vel / 127).clamp(0.0, 1.0);
      for (var i = 0; i < count; i++) {
        mix[timed.start + i] += sample[i] * gain;
      }
    } else {
      final duration = timed.end - timed.start;
      // addVoice writes Float32; sum separate voices in Float64 precision.
      final voice = Float32List(
        math.min(
          length - timed.start,
          duration + math.max(2, (sampleRate * 0.03).round()),
        ),
      );
      addVoice(
        voice,
        sampleRate: sampleRate,
        startSample: 0,
        durationSamples: duration,
        pitch: note.pitch,
        velocity01: note.vel / 127,
        role: role,
      );
      for (var i = 0; i < voice.length; i++) {
        mix[timed.start + i] += voice[i];
      }
    }
  }

  final peak = mix.fold<double>(
    0,
    (peak, value) => math.max(peak, value.abs()),
  );
  final gain = peak > 1 ? 1 / peak : 1.0;
  final output = Int16List(length);
  for (var i = 0; i < length; i++) {
    output[i] = (mix[i] * gain * 32767).round().clamp(-32768, 32767);
  }
  return output;
}
