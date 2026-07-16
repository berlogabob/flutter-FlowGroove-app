/// Event Kit (#52): stage plot, crew/guests and rider attached to a setlist —
/// stored as one inline map on the Setlist doc (no rules changes needed).
/// Stage is a fixed 3×3 zone grid (v1 — free-drag if beta asks).
library;

/// Fixed zone ids, back row (upstage) → front row (audience).
const stageZoneIds = [
  'back-left', 'back-center', 'back-right',
  'mid-left', 'mid-center', 'mid-right',
  'front-left', 'front-center', 'front-right',
];

class StagePlacement {
  const StagePlacement({required this.kind, required this.label, this.uid});

  factory StagePlacement.fromJson(Map<String, dynamic> json) =>
      StagePlacement(
        kind: json['kind'] as String? ?? 'equipment',
        label: json['label'] as String? ?? '',
        uid: json['uid'] as String?,
      );

  /// 'member' | 'equipment'.
  final String kind;
  final String label;

  /// Band member uid when [kind] == 'member'.
  final String? uid;

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'label': label,
    if (uid != null) 'uid': uid,
  };
}

/// Non-band people: photographer, videographer, manager, +1 guests.
class EventPerson {
  const EventPerson({
    required this.name,
    required this.role,
    this.notes,
    this.uid,
  });

  factory EventPerson.fromJson(Map<String, dynamic> json) => EventPerson(
    name: json['name'] as String? ?? '',
    role: json['role'] as String? ?? '',
    notes: json['notes'] as String?,
    uid: json['uid'] as String?,
  );

  final String name;
  final String role;
  final String? notes;
  final String? uid;

  Map<String, dynamic> toJson() => {
    'name': name,
    'role': role,
    if (notes != null) 'notes': notes,
    if (uid != null) 'uid': uid,
  };
}

class RiderItem {
  const RiderItem({
    required this.label,
    this.qty,
    this.notes,
    this.done = false,
  });

  factory RiderItem.fromJson(Map<String, dynamic> json) => RiderItem(
    label: json['label'] as String? ?? '',
    qty: (json['qty'] as num?)?.toInt(),
    notes: json['notes'] as String?,
    done: json['done'] as bool? ?? false,
  );

  final String label;
  final int? qty;
  final String? notes;
  final bool done;

  RiderItem copyWith({String? label, int? qty, String? notes, bool? done}) =>
      RiderItem(
        label: label ?? this.label,
        qty: qty ?? this.qty,
        notes: notes ?? this.notes,
        done: done ?? this.done,
      );

  Map<String, dynamic> toJson() => {
    'label': label,
    if (qty != null) 'qty': qty,
    if (notes != null) 'notes': notes,
    'done': done,
  };
}

class EventKit {
  const EventKit({
    this.stage = const {},
    this.people = const [],
    this.rider = const [],
  });

  factory EventKit.fromJson(Map<String, dynamic> json) => EventKit(
    stage: {
      for (final e in (json['stage'] as Map<String, dynamic>? ?? {}).entries)
        if (stageZoneIds.contains(e.key))
          e.key: [
            for (final p in (e.value as List? ?? []))
              if (p is Map)
                StagePlacement.fromJson(Map<String, dynamic>.from(p)),
          ],
    },
    people: [
      for (final p in (json['people'] as List? ?? []))
        if (p is Map) EventPerson.fromJson(Map<String, dynamic>.from(p)),
    ],
    rider: [
      for (final r in (json['rider'] as List? ?? []))
        if (r is Map) RiderItem.fromJson(Map<String, dynamic>.from(r)),
    ],
  );

  /// zoneId → placements. Only [stageZoneIds] keys are valid.
  final Map<String, List<StagePlacement>> stage;
  final List<EventPerson> people;
  final List<RiderItem> rider;

  bool get isEmpty => stage.isEmpty && people.isEmpty && rider.isEmpty;

  EventKit copyWith({
    Map<String, List<StagePlacement>>? stage,
    List<EventPerson>? people,
    List<RiderItem>? rider,
  }) => EventKit(
    stage: stage ?? this.stage,
    people: people ?? this.people,
    rider: rider ?? this.rider,
  );

  Map<String, dynamic> toJson() => {
    'stage': {
      for (final e in stage.entries)
        if (e.value.isNotEmpty)
          e.key: e.value.map((p) => p.toJson()).toList(),
    },
    'people': people.map((p) => p.toJson()).toList(),
    'rider': rider.map((r) => r.toJson()).toList(),
  };
}
