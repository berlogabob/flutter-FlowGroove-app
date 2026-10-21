import 'dart:math' as math;
import 'dart:typed_data';

import '../../../models/midi_song.dart';

/// Adds a mono note, followed by a 30 ms release, to [buf].
///
/// [startSample] may be negative; synthesis keeps its timing when writes are
/// clipped to the buffer. [durationSamples] is the time before note-off.
/// Drums use the triangle fallback; sampled percussion is rendered separately.
void addVoice(
  Float32List buf, {
  required int sampleRate,
  required int startSample,
  required int durationSamples,
  required int pitch,
  required double velocity01,
  required MidiRole role,
}) {
  if (buf.isEmpty || durationSamples <= 0 || startSample >= buf.length) return;
  if (sampleRate <= 0) {
    throw ArgumentError.value(sampleRate, 'sampleRate', 'Must be positive');
  }
  if (!velocity01.isFinite || velocity01 <= 0) return;

  final frequency = 440 * math.pow(2, (pitch - 69) / 12);
  if (!frequency.isFinite || frequency <= 0 || frequency >= sampleRate / 2) {
    return;
  }
  final release = math.max(2, (sampleRate * 0.03).round());
  final total = durationSamples + release;
  final end = math.min(total, buf.length - startSample);
  if (startSample + total <= 0) return;

  final gain = velocity01.clamp(0.0, 1.0) * 0.25;
  final plucked = role == MidiRole.guitar || role == MidiRole.bass;
  final bowed = role == MidiRole.strings || role == MidiRole.synth;
  final singing = role == MidiRole.vocal || role == MidiRole.lead;
  final attackSeconds = bowed ? 0.03 : (singing ? 0.02 : 0.003);
  final attack = math.max(1, (sampleRate * attackSeconds).round());
  final step = 2 * math.pi * frequency / sampleRate;

  // Averaging in the feedback loop contributes another half-sample of delay.
  final delay = Float64List(
    plucked ? math.max(2, (sampleRate / frequency - 0.5).round()) : 0,
  );
  var seed = (pitch & 0x7fffffff) + 1;
  for (var i = 0; i < delay.length; i++) {
    seed = (seed * 16807) % 2147483647;
    delay[i] = seed / 2147483647 * 2 - 1;
  }

  var cursor = 0;
  var phase = 0.0;
  var bassLow = 0.0;
  final bassAlpha = 1 - math.exp(-2 * math.pi * frequency * 3 / sampleRate);
  for (var i = 0; i < end; i++) {
    final t = i / sampleRate;
    var value = 0.0;
    if (plucked) {
      value = delay[cursor];
      final next = (cursor + 1) % delay.length;
      delay[cursor] = (value + delay[next]) * 0.498;
      cursor = next;
      if (role == MidiRole.bass) {
        bassLow += bassAlpha * (value - bassLow);
        value = bassLow;
      }
    } else if (role == MidiRole.keys) {
      for (var n = 1; n <= 4; n++) {
        if (frequency * n >= sampleRate / 2) break;
        value += math.sin(phase * n) * math.exp(-t * (2 + n)) / n;
      }
      value /= 2.084;
    } else if (bowed) {
      for (var n = 1; n <= 6; n++) {
        if (frequency * n * 1.003 >= sampleRate / 2) break;
        value += (math.sin(phase * n) + math.sin(phase * n * 1.003)) / (2 * n);
      }
      value /= 2.45;
    } else if (singing) {
      value = math.sin(phase);
      if (frequency * 2 * 1.004 < sampleRate / 2) {
        value += 0.3 * math.sin(phase * 2);
      }
      if (frequency * 3 * 1.004 < sampleRate / 2) {
        value += 0.15 * math.sin(phase * 3);
      }
      value /= 1.45;
    } else {
      value = 2 / math.pi * math.asin(math.sin(phase));
    }

    final fadeIn = math.min(1, i / attack);
    final fadeOut = i < durationSamples ? 1.0 : (total - 1 - i) / (release - 1);
    final index = startSample + i;
    if (index >= 0) buf[index] += value * gain * fadeIn * fadeOut;
    phase += step * (singing ? 1 + 0.004 * math.sin(2 * math.pi * 5.5 * t) : 1);
  }
}
