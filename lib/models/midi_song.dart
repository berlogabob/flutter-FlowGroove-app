import '../models/section_span.dart';

enum MidiRole {
  drums,
  bass,
  guitar,
  keys,
  strings,
  vocal,
  lead,
  synth,
  other;

  static MidiRole parse(String? value) => MidiRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => MidiRole.other,
  );
}

/// What to do once a practice loop section finishes.
enum LoopBehavior {
  loop,
  next,
  stop;

  static LoopBehavior parse(String? value) => LoopBehavior.values.firstWhere(
    (behavior) => behavior.name == value,
    orElse: () => LoopBehavior.loop,
  );
}

class MidiNote {
  const MidiNote({
    required this.tick,
    required this.dur,
    required this.pitch,
    required this.vel,
  });

  final int tick;
  final int dur;
  final int pitch;
  final int vel;
}

class TempoChange {
  const TempoChange({required this.tick, required this.microsPerQuarter});

  final int tick;
  final int microsPerQuarter;
}

class TimeSigChange {
  const TimeSigChange({
    required this.tick,
    required this.numerator,
    required this.denominator,
  });

  final int tick;
  final int numerator;
  final int denominator;
}

class MidiTrackData {
  const MidiTrackData({
    required this.index,
    required this.name,
    required this.channel,
    required this.program,
    required this.notes,
    this.hasTrackName = true,
  });

  final int index;
  final String name;
  final int channel;
  final int program;
  final List<MidiNote> notes;
  // Distinguishes file names from the parser's numbered placeholder.
  final bool hasTrackName;

  int get noteCount => notes.length;
  int get minPitch => notes.isEmpty
      ? 0
      : notes.map((note) => note.pitch).reduce((a, b) => a < b ? a : b);
  int get maxPitch => notes.isEmpty
      ? 0
      : notes.map((note) => note.pitch).reduce((a, b) => a > b ? a : b);
}

class MidiSongData {
  const MidiSongData({
    required this.ppq,
    required this.tempos,
    required this.timeSigs,
    required this.tracks,
    this.markers = const [],
  });

  final int ppq;
  final List<TempoChange> tempos;
  final List<TimeSigChange> timeSigs;
  final List<MidiTrackData> tracks;
  final List<({int tick, String text})> markers;

  double get initialBpm => tempos.isEmpty || tempos.first.tick != 0
      ? 120.0
      : 60000000 / tempos.first.microsPerQuarter;
}

const _unchanged = Object();

/// Stored track settings and statistics, including optional replacement notes.
class MidiTrackMeta {
  const MidiTrackMeta({
    required this.index,
    required this.name,
    required this.channel,
    required this.program,
    required this.detectedRole,
    required this.noteCount,
    required this.minPitch,
    required this.maxPitch,
    this.roleOverride,
    this.editedNotes,
    this.programOverride,
    this.mute = false,
    this.volume = 1.0,
  }) : assert(volume >= 0 && volume <= 1, 'Volume must be between 0 and 1');

  factory MidiTrackMeta.fromJson(Map<String, dynamic> json) => MidiTrackMeta(
    index: (json['index'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    channel: (json['channel'] as num?)?.toInt() ?? 0,
    program: (json['program'] as num?)?.toInt() ?? 0,
    detectedRole: MidiRole.parse(json['detectedRole'] as String?),
    roleOverride: json['roleOverride'] == null
        ? null
        : MidiRole.parse(json['roleOverride'] as String?),
    editedNotes:
        json['editedNotes'] == null ||
            (json['editedNotes'] as List).length % 4 != 0
        ? null
        : (json['editedNotes'] as List)
              .map((value) => (value as num).toInt())
              .toList(),
    programOverride: (json['programOverride'] as num?)?.clamp(0, 127).toInt(),
    mute: json['mute'] as bool? ?? false,
    volume: (json['volume'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 1.0,
    noteCount: (json['noteCount'] as num?)?.toInt() ?? 0,
    minPitch: (json['minPitch'] as num?)?.toInt() ?? 0,
    maxPitch: (json['maxPitch'] as num?)?.toInt() ?? 0,
  );

  final int index;
  final String name;
  final int channel;
  final int program;
  final MidiRole detectedRole;
  final MidiRole? roleOverride;

  /// Replaces file notes with flat quads: tick, duration, pitch, velocity.
  final List<int>? editedNotes;
  final int? programOverride;
  final bool mute;
  final double volume;
  final int noteCount;
  final int minPitch;
  final int maxPitch;

  MidiRole get effectiveRole => roleOverride ?? detectedRole;

  int get effectiveProgram => programOverride ?? program;

  MidiTrackMeta copyWith({
    int? index,
    String? name,
    int? channel,
    int? program,
    MidiRole? detectedRole,
    Object? roleOverride = _unchanged,
    Object? editedNotes = _unchanged,
    Object? programOverride = _unchanged,
    bool? mute,
    double? volume,
    int? noteCount,
    int? minPitch,
    int? maxPitch,
  }) => MidiTrackMeta(
    index: index ?? this.index,
    name: name ?? this.name,
    channel: channel ?? this.channel,
    program: program ?? this.program,
    detectedRole: detectedRole ?? this.detectedRole,
    roleOverride: identical(roleOverride, _unchanged)
        ? this.roleOverride
        : roleOverride as MidiRole?,
    editedNotes: identical(editedNotes, _unchanged)
        ? this.editedNotes
        : editedNotes as List<int>?,
    programOverride: identical(programOverride, _unchanged)
        ? this.programOverride
        : programOverride as int?,
    mute: mute ?? this.mute,
    volume: volume ?? this.volume,
    noteCount: noteCount ?? this.noteCount,
    minPitch: minPitch ?? this.minPitch,
    maxPitch: maxPitch ?? this.maxPitch,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'index': index,
    'name': name,
    'channel': channel,
    'program': program,
    'detectedRole': detectedRole.name,
    if (roleOverride != null) 'roleOverride': roleOverride!.name,
    if (editedNotes != null) 'editedNotes': editedNotes,
    if (programOverride != null) 'programOverride': programOverride,
    'mute': mute,
    'volume': volume,
    'noteCount': noteCount,
    'minPitch': minPitch,
    'maxPitch': maxPitch,
  };
}

/// Serializable song metadata, without parsed note events.
class MidiSongMeta {
  const MidiSongMeta({
    required this.ppq,
    required this.initialBpm,
    required this.tracks,
    this.fileUrl,
    this.loopSpan = const SectionSpan(sectionId: '', startBar: 0, bars: 0),
    this.loopBehavior = LoopBehavior.loop,
    this.startBar = 0,
    this.sectionMap = const [],
    this.useFileTempo = false,
    this.endBehavior = 'loop',
  });

  factory MidiSongMeta.fromJson(Map<String, dynamic> json) => MidiSongMeta(
    fileUrl: json['fileUrl'] as String?,
    ppq: (json['ppq'] as num?)?.toInt() ?? 480,
    initialBpm: (json['initialBpm'] as num?)?.toDouble() ?? 120.0,
    loopSpan: _loopSpanFromJson(json['loopSpan']),
    loopBehavior: LoopBehavior.parse(json['loopBehavior'] as String?),
    startBar: (json['startBar'] as num?)?.toInt() ?? 0,
    sectionMap:
        (json['sectionMap'] as List<dynamic>?)
            ?.map((span) => SectionSpan.fromJson(span as Map<String, dynamic>))
            .toList() ??
        <SectionSpan>[],
    useFileTempo: json['useFileTempo'] as bool? ?? false,
    endBehavior: LoopBehavior.parse(json['endBehavior'] as String?).name,
    tracks:
        (json['tracks'] as List<dynamic>?)
            ?.map(
              (track) => MidiTrackMeta.fromJson(track as Map<String, dynamic>),
            )
            .toList() ??
        <MidiTrackMeta>[],
  );

  static const int schemaVersion = 1;

  final String? fileUrl;
  final int ppq;
  final double initialBpm;
  final SectionSpan loopSpan;
  final LoopBehavior loopBehavior;
  final int startBar;
  final List<SectionSpan> sectionMap;
  final bool useFileTempo;
  final String endBehavior;
  final List<MidiTrackMeta> tracks;

  MidiSongMeta copyWith({
    Object? fileUrl = _unchanged,
    int? ppq,
    double? initialBpm,
    SectionSpan? loopSpan,
    LoopBehavior? loopBehavior,
    int? startBar,
    List<SectionSpan>? sectionMap,
    bool? useFileTempo,
    String? endBehavior,
    List<MidiTrackMeta>? tracks,
  }) => MidiSongMeta(
    fileUrl: identical(fileUrl, _unchanged) ? this.fileUrl : fileUrl as String?,
    ppq: ppq ?? this.ppq,
    initialBpm: initialBpm ?? this.initialBpm,
    loopSpan: loopSpan ?? this.loopSpan,
    loopBehavior: loopBehavior ?? this.loopBehavior,
    startBar: startBar ?? this.startBar,
    sectionMap: sectionMap ?? this.sectionMap,
    useFileTempo: useFileTempo ?? this.useFileTempo,
    endBehavior: endBehavior ?? this.endBehavior,
    tracks: tracks ?? this.tracks,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    if (fileUrl != null) 'fileUrl': fileUrl,
    'ppq': ppq,
    'initialBpm': initialBpm,
    'loopSpan': loopSpan.toJson(),
    'loopBehavior': loopBehavior.name,
    'startBar': startBar,
    'sectionMap': sectionMap.map((span) => span.toJson()).toList(),
    'useFileTempo': useFileTempo,
    'endBehavior': endBehavior,
    'tracks': tracks.map((track) => track.toJson()).toList(),
  };
}

SectionSpan _loopSpanFromJson(Object? value) => value is Map<String, dynamic>
    ? SectionSpan.fromJson(value)
    : const SectionSpan(sectionId: '', startBar: 0, bars: 0);
