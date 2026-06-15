enum InstrumentType {
  guitar,
  bass,
  ukulele,
  violin,
  viola,
  cello,
  voice,
  chromatic,
  regional,
  custom,
}

enum TunerPresetScope { local, account, band, song }

class TuningNote {
  final String note;
  final int octave;
  final double targetFrequencyHz;
  final int? stringNumber;

  const TuningNote({
    required this.note,
    required this.octave,
    required this.targetFrequencyHz,
    this.stringNumber,
  });

  String get displayName => '$note$octave';

  factory TuningNote.fromJson(Map<String, dynamic> json) => TuningNote(
    note: json['note'] as String,
    octave: (json['octave'] as num).toInt(),
    targetFrequencyHz: (json['targetFrequencyHz'] as num).toDouble(),
    stringNumber: (json['stringNumber'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'note': note,
    'octave': octave,
    'targetFrequencyHz': targetFrequencyHz,
    if (stringNumber != null) 'stringNumber': stringNumber,
  };
}

class TunerPreset {
  final String id;
  final String name;
  final InstrumentType instrumentType;
  final List<TuningNote> tuningNotes;
  final double referenceHz;
  final int centsTolerance;
  final String? temperament;
  final bool isDefault;
  final TunerPresetScope scope;
  final String? ownerId;
  final String? songId;
  final String? bandId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TunerPreset({
    required this.id,
    required this.name,
    required this.instrumentType,
    required this.tuningNotes,
    required this.createdAt,
    required this.updatedAt,
    this.referenceHz = 440,
    this.centsTolerance = 5,
    this.temperament = 'equal',
    this.isDefault = false,
    this.scope = TunerPresetScope.local,
    this.ownerId,
    this.songId,
    this.bandId,
  });

  TunerPreset copyWith({
    String? id,
    String? name,
    InstrumentType? instrumentType,
    List<TuningNote>? tuningNotes,
    double? referenceHz,
    int? centsTolerance,
    String? temperament,
    bool? isDefault,
    TunerPresetScope? scope,
    String? ownerId,
    String? songId,
    String? bandId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TunerPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      instrumentType: instrumentType ?? this.instrumentType,
      tuningNotes: tuningNotes ?? this.tuningNotes,
      referenceHz: referenceHz ?? this.referenceHz,
      centsTolerance: centsTolerance ?? this.centsTolerance,
      temperament: temperament ?? this.temperament,
      isDefault: isDefault ?? this.isDefault,
      scope: scope ?? this.scope,
      ownerId: ownerId ?? this.ownerId,
      songId: songId ?? this.songId,
      bandId: bandId ?? this.bandId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory TunerPreset.fromJson(Map<String, dynamic> json) => TunerPreset(
    id: json['id'] as String,
    name: json['name'] as String,
    instrumentType: InstrumentType.values.firstWhere(
      (value) => value.name == json['instrumentType'],
      orElse: () => InstrumentType.custom,
    ),
    tuningNotes: (json['tuningNotes'] as List<dynamic>? ?? const [])
        .map(
          (value) =>
              TuningNote.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList(),
    referenceHz: (json['referenceHz'] as num?)?.toDouble() ?? 440,
    centsTolerance: (json['centsTolerance'] as num?)?.toInt() ?? 5,
    temperament: json['temperament'] as String?,
    isDefault: json['isDefault'] as bool? ?? false,
    scope: TunerPresetScope.values.firstWhere(
      (value) => value.name == json['scope'],
      orElse: () => TunerPresetScope.local,
    ),
    ownerId: json['ownerId'] as String?,
    songId: json['songId'] as String?,
    bandId: json['bandId'] as String?,
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now(),
    updatedAt:
        DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
        DateTime.now(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'instrumentType': instrumentType.name,
    'tuningNotes': tuningNotes.map((note) => note.toJson()).toList(),
    'referenceHz': referenceHz,
    'centsTolerance': centsTolerance,
    'temperament': temperament,
    'isDefault': isDefault,
    'scope': scope.name,
    'ownerId': ownerId,
    'songId': songId,
    'bandId': bandId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

class TunerSession {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String mode;
  final String? presetId;
  final String? instrumentType;
  final double referenceHz;
  final double? avgDetectionLatencyMs;
  final double? avgPitchErrorCents;
  final String permissionState;
  final bool completedSuccessfully;

  const TunerSession({
    required this.id,
    required this.startedAt,
    required this.mode,
    required this.referenceHz,
    required this.permissionState,
    this.endedAt,
    this.presetId,
    this.instrumentType,
    this.avgDetectionLatencyMs,
    this.avgPitchErrorCents,
    this.completedSuccessfully = false,
  });
}
