import 'metronome_tempo_range.dart';

enum TempoRampCadence { bars, seconds }

class TempoRamp {
  const TempoRamp({
    required this.id,
    required this.name,
    required this.startBpm,
    required this.targetBpm,
    required this.stepBpm,
    required this.cadence,
    required this.every,
    this.loop = false,
  });

  factory TempoRamp.fromJson(Map<String, dynamic> json) => TempoRamp(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    startBpm: (json['startBpm'] as num?)?.toInt() ?? 120,
    targetBpm: (json['targetBpm'] as num?)?.toInt() ?? 120,
    stepBpm: (json['stepBpm'] as num?)?.toInt() ?? 1,
    cadence: TempoRampCadence.values.firstWhere(
      (value) => value.name == json['cadence'],
      orElse: () => TempoRampCadence.bars,
    ),
    every: (json['every'] as num?)?.toInt() ?? 1,
    loop: json['loop'] as bool? ?? false,
  );

  final String id;
  final String name;
  final int startBpm;
  final int targetBpm;
  final int stepBpm;
  final TempoRampCadence cadence;
  final int every;
  final bool loop;

  bool get increases => targetBpm > startBpm;

  void validate() {
    if (name.trim().isEmpty) throw ArgumentError('Ramp name must not be empty');
    if (!MetronomeTempoRange.contains(startBpm) ||
        !MetronomeTempoRange.contains(targetBpm)) {
      throw ArgumentError(
        'Ramp BPM must be within ${MetronomeTempoRange.label}',
      );
    }
    if (startBpm == targetBpm) {
      throw ArgumentError('Ramp start and target BPM must differ');
    }
    if (stepBpm <= 0) throw ArgumentError('Ramp step must be positive');
    if (every <= 0) throw ArgumentError('Ramp cadence must be positive');
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'startBpm': startBpm,
    'targetBpm': targetBpm,
    'stepBpm': stepBpm,
    'cadence': cadence.name,
    'every': every,
    'loop': loop,
  };
}

class TempoRampController {
  TempoRamp? _ramp;
  int _bars = 0;
  int _seconds = 0;

  TempoRamp? get activeRamp => _ramp;
  bool get isActive => _ramp != null;

  int start(TempoRamp ramp) {
    ramp.validate();
    _ramp = ramp;
    _bars = 0;
    _seconds = 0;
    return ramp.startBpm;
  }

  void stop() {
    _ramp = null;
    _bars = 0;
    _seconds = 0;
  }

  int? onBar(int currentBpm) {
    final ramp = _ramp;
    if (ramp == null || ramp.cadence != TempoRampCadence.bars) return null;
    _bars++;
    return _bars % ramp.every == 0 ? _step(currentBpm, ramp) : null;
  }

  int? onSecond(int currentBpm) {
    final ramp = _ramp;
    if (ramp == null || ramp.cadence != TempoRampCadence.seconds) return null;
    _seconds++;
    return _seconds % ramp.every == 0 ? _step(currentBpm, ramp) : null;
  }

  int _step(int currentBpm, TempoRamp ramp) {
    final delta = ramp.increases ? ramp.stepBpm : -ramp.stepBpm;
    final candidate = currentBpm + delta;
    final reached = ramp.increases
        ? candidate >= ramp.targetBpm
        : candidate <= ramp.targetBpm;
    if (!reached) return MetronomeTempoRange.clamp(candidate);
    if (ramp.loop) return ramp.startBpm;
    stop();
    return ramp.targetBpm;
  }
}
