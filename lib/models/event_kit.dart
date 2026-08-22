/// Event Kit (#52): stage plot, crew/guests and rider attached to a setlist —
/// stored as one inline map on the Setlist doc.
/// Stage is a fixed 3×3 zone grid (v1 — free-drag if beta asks).
///
/// NOTE: `stage` and `rider` are now independently editable by non-members
/// (a sound engineer, a videographer), so this map must only ever be written
/// through dotted field paths — see `FirestoreService.updateEventKitArea`.
/// A whole-document write here silently clobbers whoever else is editing.
library;

import 'event_access.dart';

/// Fixed zone ids, back row (upstage) → front row (audience).
const stageZoneIds = [
  'back-left', 'back-center', 'back-right',
  'mid-left', 'mid-center', 'mid-right',
  'front-left', 'front-center', 'front-right',
];

class StagePlacement {
  const StagePlacement({
    required this.kind,
    required this.label,
    this.uid,
    this.icon,
    this.brand,
  });

  factory StagePlacement.fromJson(Map<String, dynamic> json) =>
      StagePlacement(
        kind: json['kind'] as String? ?? 'equipment',
        label: json['label'] as String? ?? '',
        uid: json['uid'] as String?,
        icon: json['icon'] as String?,
        brand: json['brand'] as String?,
      );

  /// 'member' | 'equipment'.
  final String kind;
  final String label;

  /// Band member uid when [kind] == 'member'.
  final String? uid;

  /// Emoji baked in at add time. Null on plots saved before icons existed —
  /// render those through `StageGear.iconFor(label, kind: kind)`.
  final String? icon;

  /// Optional brand refinement for gear, e.g. 'Ampeg SVT' on a bass amp.
  final String? brand;

  /// Label as shown to humans (UI chips and the event-guide PDF).
  String get displayLabel => brand == null ? label : '$label — $brand';

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'label': label,
    if (uid != null) 'uid': uid,
    if (icon != null) 'icon': icon,
    if (brand != null) 'brand': brand,
  };
}

/// Anyone on the event roster: band members, guest musicians, photographer,
/// manager, +1 guests. [id] is what setlist items reference in
/// `SetlistItem.performerIds`.
class EventPerson {
  const EventPerson({
    required this.id,
    required this.name,
    required this.role,
    this.notes,
    this.uid,
    this.access = const {},
    this.canSuggest = false,
  });

  factory EventPerson.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';
    return EventPerson(
      // ponytail: crew cards saved before ids existed were identified by name.
      id: json['id'] as String? ?? name,
      name: name,
      role: json['role'] as String? ?? '',
      notes: json['notes'] as String?,
      uid: json['uid'] as String?,
      access: sanitizeAccess({
        for (final e in (json['access'] as Map<String, dynamic>? ?? {}).entries)
          if (e.value is String) e.key: e.value as String,
      }),
      canSuggest: json['canSuggest'] as bool? ?? false,
    );
  }

  /// A roster entry with [role]'s default grant already applied.
  factory EventPerson.withRolePreset({
    required String id,
    required String name,
    required String role,
    String? notes,
    String? uid,
  }) {
    final preset = presetForRole(role);
    return EventPerson(
      id: id,
      name: name,
      role: role,
      notes: notes,
      uid: uid,
      access: preset.access,
      canSuggest: preset.canSuggest,
    );
  }

  final String id;
  final String name;
  final String role;
  final String? notes;

  /// Set once this person is a real app user (band member uid).
  final String? uid;

  /// `area -> level` per [EventArea]/[EventAccessLevel]. An absent area is
  /// HIDDEN, so an empty map shows this person nothing.
  final Map<String, String> access;

  /// May propose running-order changes (reorder / add / drop / note) without
  /// being able to make them. Suggesting needs no account; editing does.
  final bool canSuggest;

  bool canView(String area) => canViewArea(access, area);
  bool canEdit(String area) => canEditArea(access, area);

  EventPerson copyWith({
    String? name,
    String? role,
    String? notes,
    String? uid,
    Map<String, String>? access,
    bool? canSuggest,
  }) => EventPerson(
    id: id,
    name: name ?? this.name,
    role: role ?? this.role,
    notes: notes ?? this.notes,
    uid: uid ?? this.uid,
    access: access ?? this.access,
    canSuggest: canSuggest ?? this.canSuggest,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role,
    if (notes != null) 'notes': notes,
    if (uid != null) 'uid': uid,
    if (access.isNotEmpty) 'access': access,
    if (canSuggest) 'canSuggest': canSuggest,
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
