/// Song Lab (#65/#66): the per-song journal — typed entries, member tasks and
/// version snapshots stored as subcollections under a song document
/// (`users/{uid}/songs/{id}/…` or `bands/{bandId}/songs/{id}/…`):
/// `labEntries`, `tasks`, `versions`.
///
/// Conventions match the rest of the models: manual toJson/fromJson,
/// timestamps as local ISO-8601 strings, enums stored by `.name`.
library;

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
  reference;

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
  };

  SongLabEntry copyWith({
    String? title,
    String? body,
    String? status,
    List<String>? attachmentIds,
    List<int>? peaks,
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
