/// Song Lab (#65/#66): the per-song journal — typed entries, member tasks and
/// version snapshots stored as subcollections under a song document
/// (`users/{uid}/songs/{id}/…` or `bands/{bandId}/songs/{id}/…`):
/// `labEntries`, `tasks`, `versions`.
///
/// Conventions match the rest of the models: manual toJson/fromJson,
/// timestamps as local ISO-8601 strings, enums stored by `.name`.
library;

import 'audio_region.dart';
import 'midi_pattern.dart';
import 'midi_song.dart';

/// Timeline entry types. The UI quick-adds only note/decision/experiment/
/// problem (v1); the rest exist so other features can append typed entries.
enum LabEntryType {
  note,
  idea,
  decision,
  experiment,
  problem,
  task,
  rehearsalNote,
  recording,
  versionChange,
  reference,
  midi;

  static LabEntryType parse(String? v) => LabEntryType.values.firstWhere(
    (e) => e.name == v,
    orElse: () => LabEntryType.note,
  );
}

/// Per-type lifecycle, one flat enum (ponytail: statuses are strings in
/// Firestore anyway — decision: active/superseded; experiment:
/// planned/tried/accepted/rejected).
enum SongTaskStatus {
  todo,
  doing,
  done,
  blocked,
  skipped;

  static SongTaskStatus parse(String? v) => SongTaskStatus.values.firstWhere(
    (e) => e.name == v,
    orElse: () => SongTaskStatus.todo,
  );
}

DateTime _parseDate(dynamic v) =>
    v is String ? (DateTime.tryParse(v) ?? DateTime.now()) : DateTime.now();
DateTime? _parseDateOrNull(dynamic v) =>
    v is String ? DateTime.tryParse(v) : null;

MidiSongMeta? _parseMidiSong(Object? v) {
  if (v is! Map<String, dynamic>) return null;
  try {
    return MidiSongMeta.fromJson(v);
  } catch (_) {
    return null;
  }
}

/// One timestamped comment on a recording.
typedef AudioMarker = ({int ms, String text});

class SongLabEntry {
  SongLabEntry({
    required this.id,
    required this.songId,
    required this.type,
    required this.authorId,
    required this.createdAt,
    required this.updatedAt,
    this.bandId,
    this.title,
    this.body,
    this.sectionId,
    this.versionId,
    this.status,
    this.tags = const [],
    this.visibility = 'band',
    this.attachmentIds = const [],
    this.peaks = const [],
    this.midi,
    this.midiSong,
    this.grid,
    this.regions = const [],
    this.notes = const [],
  });

  factory SongLabEntry.fromJson(Map<String, dynamic> json) => SongLabEntry(
    id: json['id'] as String? ?? '',
    songId: json['songId'] as String? ?? '',
    bandId: json['bandId'] as String?,
    type: LabEntryType.parse(json['type'] as String?),
    title: json['title'] as String?,
    body: json['body'] as String?,
    sectionId: json['sectionId'] as String?,
    versionId: json['versionId'] as String?,
    status: json['status'] as String?,
    tags: (json['tags'] as List?)?.whereType<String>().toList() ?? const [],
    authorId: json['authorId'] as String? ?? '',
    visibility: json['visibility'] as String? ?? 'band',
    createdAt: _parseDate(json['createdAt']),
    updatedAt: _parseDate(json['updatedAt']),
    attachmentIds:
        (json['attachmentIds'] as List?)?.whereType<String>().toList() ??
        const [],
    peaks:
        (json['peaks'] as List?)
            ?.whereType<num>()
            .map((v) => v.toInt())
            .toList() ??
        const [],
    midi: json['midi'] as Map<String, dynamic>?,
    midiSong: _parseMidiSong(json['midiSong']),
    grid: json['grid'] is Map<String, dynamic>
        ? AudioGrid.fromJson(json['grid'] as Map<String, dynamic>)
        : null,
    notes:
        (json['notes'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(
              (n) => (ms: (n['ms'] as num).toInt(), text: n['text'] as String),
            )
            .toList() ??
        const [],
    regions:
        (json['regions'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(AudioRegion.fromJson)
            .toList() ??
        const [],
  );

  final String id;
  final String songId;

  /// Duplicated on band-song entries for band-wide collection-group queries.
  final String? bandId;
  final LabEntryType type;
  final String? title;
  final String? body;

  /// Optional binding to a song [Section.id].
  final String? sectionId;

  /// Set on `versionChange` entries.
  final String? versionId;

  /// Type-specific lifecycle: decision `active`/`superseded`; experiment
  /// `planned`/`tried`/`accepted`/`rejected`. Null for plain notes.
  final String? status;
  final List<String> tags;
  final String authorId;

  /// 'private' | 'band'.
  final String visibility;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> attachmentIds;

  /// Waveform bars (0..255) for `recording` entries, captured while recording.
  /// ~800 bytes on the doc, which is what lets the audio note editor draw a
  /// waveform without downloading the audio. Empty for legacy/attached takes.
  final List<int> peaks;

  /// Serialized [MidiPattern] for `midi` entries.
  final Map<String, dynamic>? midi;

  final MidiSongMeta? midiSong;

  /// Tempo grid for a `recording`'s practice regions; null = seconds only.
  final AudioGrid? grid;

  /// Named practice regions on a `recording`, sorted and gapless.
  final List<AudioRegion> regions;

  final List<AudioMarker> notes;

  MidiPattern? get pattern => midi == null ? null : MidiPattern.fromJson(midi!);

  Map<String, dynamic> toJson() => {
    'id': id,
    'songId': songId,
    if (bandId != null) 'bandId': bandId,
    'type': type.name,
    if (title != null) 'title': title,
    if (body != null) 'body': body,
    if (sectionId != null) 'sectionId': sectionId,
    if (versionId != null) 'versionId': versionId,
    if (status != null) 'status': status,
    'tags': tags,
    'authorId': authorId,
    'visibility': visibility,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'attachmentIds': attachmentIds,
    if (peaks.isNotEmpty) 'peaks': peaks,
    if (notes.isNotEmpty)
      'notes': [
        for (final n in notes) {'ms': n.ms, 'text': n.text},
      ],
    if (midi != null) 'midi': midi,
    if (midiSong != null) 'midiSong': midiSong!.toJson(),
    if (grid != null) 'grid': grid!.toJson(),
    // Written on every recording save: saves merge, so an emptied list must
    // overwrite the stored one.
    if (type == LabEntryType.recording)
      'regions': [for (final r in regions) r.toJson()],
  };

  SongLabEntry copyWith({
    String? title,
    String? body,
    String? status,
    List<String>? attachmentIds,
    List<int>? peaks,
    Map<String, dynamic>? midi,
    MidiSongMeta? midiSong,
    AudioGrid? grid,
    bool clearGrid = false,
    List<AudioRegion>? regions,
    List<AudioMarker>? notes,
  }) => SongLabEntry(
    id: id,
    songId: songId,
    bandId: bandId,
    type: type,
    title: title ?? this.title,
    body: body ?? this.body,
    sectionId: sectionId,
    versionId: versionId,
    status: status ?? this.status,
    tags: tags,
    authorId: authorId,
    visibility: visibility,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
    attachmentIds: attachmentIds ?? this.attachmentIds,
    peaks: peaks ?? this.peaks,
    midi: midi ?? this.midi,
    midiSong: midiSong ?? this.midiSong,
    grid: clearGrid ? null : grid ?? this.grid,
    regions: regions ?? this.regions,
    notes: notes ?? this.notes,
  );
}

class SongTask {
  SongTask({
    required this.id,
    required this.songId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.bandId,
    this.assignedToUserId,
    this.status = SongTaskStatus.todo,
    this.sectionId,
    this.dueAt,
    this.priority = 0,
  });

  factory SongTask.fromJson(Map<String, dynamic> json) => SongTask(
    id: json['id'] as String? ?? '',
    songId: json['songId'] as String? ?? '',
    bandId: json['bandId'] as String?,
    assignedToUserId: json['assignedToUserId'] as String?,
    title: json['title'] as String? ?? '',
    status: SongTaskStatus.parse(json['status'] as String?),
    sectionId: json['sectionId'] as String?,
    dueAt: _parseDateOrNull(json['dueAt']),
    priority: (json['priority'] as num?)?.toInt() ?? 0,
    createdAt: _parseDate(json['createdAt']),
    updatedAt: _parseDate(json['updatedAt']),
  );

  final String id;
  final String songId;
  final String? bandId;
  final String? assignedToUserId;
  final String title;
  final SongTaskStatus status;
  final String? sectionId;
  final DateTime? dueAt;
  final int priority;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOpen =>
      status == SongTaskStatus.todo ||
      status == SongTaskStatus.doing ||
      status == SongTaskStatus.blocked;

  Map<String, dynamic> toJson() => {
    'id': id,
    'songId': songId,
    if (bandId != null) 'bandId': bandId,
    if (assignedToUserId != null) 'assignedToUserId': assignedToUserId,
    'title': title,
    'status': status.name,
    if (sectionId != null) 'sectionId': sectionId,
    if (dueAt != null) 'dueAt': dueAt!.toIso8601String(),
    'priority': priority,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  SongTask copyWith({
    String? title,
    SongTaskStatus? status,
    String? assignedToUserId,
    DateTime? dueAt,
  }) => SongTask(
    id: id,
    songId: songId,
    bandId: bandId,
    assignedToUserId: assignedToUserId ?? this.assignedToUserId,
    title: title ?? this.title,
    status: status ?? this.status,
    sectionId: sectionId,
    dueAt: dueAt ?? this.dueAt,
    priority: priority,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}

class SongVersion {
  SongVersion({
    required this.id,
    required this.songId,
    required this.name,
    required this.createdAt,
    this.bandId,
    this.status = 'archived',
    this.bpm,
    this.key,
    this.structureSnapshot,
    this.lyricsSnapshot,
    this.notes,
  });

  factory SongVersion.fromJson(Map<String, dynamic> json) => SongVersion(
    id: json['id'] as String? ?? '',
    songId: json['songId'] as String? ?? '',
    bandId: json['bandId'] as String?,
    name: json['name'] as String? ?? '',
    status: json['status'] as String? ?? 'archived',
    bpm: (json['bpm'] as num?)?.toInt(),
    key: json['key'] as String?,
    structureSnapshot: json['structureSnapshot'] as String?,
    lyricsSnapshot: json['lyricsSnapshot'] as String?,
    notes: json['notes'] as String?,
    createdAt: _parseDate(json['createdAt']),
  );

  final String id;
  final String songId;
  final String? bandId;
  final String name;

  /// 'current' | 'archived' — exactly one version should be current.
  final String status;
  final int? bpm;
  final String? key;

  /// Song-map summary at snapshot time (section names/durations).
  final String? structureSnapshot;

  /// Full ChordPro document at snapshot time ([songToChordPro]).
  final String? lyricsSnapshot;
  final String? notes;
  final DateTime createdAt;

  bool get isCurrent => status == 'current';

  Map<String, dynamic> toJson() => {
    'id': id,
    'songId': songId,
    if (bandId != null) 'bandId': bandId,
    'name': name,
    'status': status,
    if (bpm != null) 'bpm': bpm,
    if (key != null) 'key': key,
    if (structureSnapshot != null) 'structureSnapshot': structureSnapshot,
    if (lyricsSnapshot != null) 'lyricsSnapshot': lyricsSnapshot,
    if (notes != null) 'notes': notes,
    'createdAt': createdAt.toIso8601String(),
  };
}
