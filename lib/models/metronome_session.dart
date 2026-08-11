enum MetronomeSessionCompletion { stopped, navigated, lifecycle, playbackError }

class MetronomeSession {
  const MetronomeSession({
    required this.id,
    required this.startedAt,
    required this.startBpm,
    this.endedAt,
    this.presetId,
    this.songId,
    this.setlistId,
    this.endBpm,
    this.elapsedSeconds = 0,
    this.barCount = 0,
    this.usedTapTempo = false,
    this.usedTempoRamp = false,
    this.usedCountIn = false,
    this.completion,
  });

  factory MetronomeSession.fromJson(Map<String, dynamic> json) {
    return MetronomeSession(
      id: json['id'] as String? ?? '',
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.parse(json['endedAt'] as String),
      presetId: json['presetId'] as String?,
      songId: json['songId'] as String?,
      setlistId: json['setlistId'] as String?,
      startBpm: (json['startBpm'] as num?)?.toInt() ?? 120,
      endBpm: (json['endBpm'] as num?)?.toInt(),
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
      barCount: (json['barCount'] as num?)?.toInt() ?? 0,
      usedTapTempo: json['usedTapTempo'] as bool? ?? false,
      usedTempoRamp: json['usedTempoRamp'] as bool? ?? false,
      usedCountIn: json['usedCountIn'] as bool? ?? false,
      completion: json['completion'] == null
          ? null
          : MetronomeSessionCompletion.values.firstWhere(
              (value) => value.name == json['completion'],
            ),
    );
  }

  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? presetId;
  final String? songId;
  final String? setlistId;
  final int startBpm;
  final int? endBpm;
  final int elapsedSeconds;
  final int barCount;
  final bool usedTapTempo;
  final bool usedTempoRamp;
  final bool usedCountIn;
  final MetronomeSessionCompletion? completion;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
    if (presetId != null) 'presetId': presetId,
    if (songId != null) 'songId': songId,
    if (setlistId != null) 'setlistId': setlistId,
    'startBpm': startBpm,
    if (endBpm != null) 'endBpm': endBpm,
    'elapsedSeconds': elapsedSeconds,
    'barCount': barCount,
    'usedTapTempo': usedTapTempo,
    'usedTempoRamp': usedTempoRamp,
    'usedCountIn': usedCountIn,
    if (completion != null) 'completion': completion!.name,
  };
}
