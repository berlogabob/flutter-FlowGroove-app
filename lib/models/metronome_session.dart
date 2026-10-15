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
    this.midiEntryId,
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
      midiEntryId: json['midiEntryId'] as String?,
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
  final String? midiEntryId;
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
    if (midiEntryId != null) 'midiEntryId': midiEntryId,
    'startBpm': startBpm,
    if (endBpm != null) 'endBpm': endBpm,
    'elapsedSeconds': elapsedSeconds,
    'barCount': barCount,
    'usedTapTempo': usedTapTempo,
    'usedTempoRamp': usedTempoRamp,
    'usedCountIn': usedCountIn,
    if (completion != null) 'completion': completion!.name,
  };

  MetronomeSession copyWith({
    String? id,
    DateTime? startedAt,
    DateTime? endedAt,
    String? presetId,
    String? songId,
    String? setlistId,
    String? midiEntryId,
    int? startBpm,
    int? endBpm,
    int? elapsedSeconds,
    int? barCount,
    bool? usedTapTempo,
    bool? usedTempoRamp,
    bool? usedCountIn,
    MetronomeSessionCompletion? completion,
  }) {
    return MetronomeSession(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      presetId: presetId ?? this.presetId,
      songId: songId ?? this.songId,
      setlistId: setlistId ?? this.setlistId,
      midiEntryId: midiEntryId ?? this.midiEntryId,
      startBpm: startBpm ?? this.startBpm,
      endBpm: endBpm ?? this.endBpm,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      barCount: barCount ?? this.barCount,
      usedTapTempo: usedTapTempo ?? this.usedTapTempo,
      usedTempoRamp: usedTempoRamp ?? this.usedTempoRamp,
      usedCountIn: usedCountIn ?? this.usedCountIn,
      completion: completion ?? this.completion,
    );
  }
}
