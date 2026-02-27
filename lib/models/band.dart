import 'dart:math';
import 'package:json_annotation/json_annotation.dart';

part 'band.g.dart';

// Sentinel value to detect if a parameter was passed to copyWith
const Object _sentinel = _Sentinel();

class _Sentinel {
  const _Sentinel();
  @override
  String toString() => '_sentinel';
}

@JsonSerializable()
class BandMember {
  @JsonKey(defaultValue: '')
  final String uid;
  @JsonKey(defaultValue: 'viewer')
  final String role; // Permission role: admin, editor, viewer
  final String? displayName;
  final String? email;
  @JsonKey(defaultValue: [])
  final List<String> musicRoles; // Music roles: guitarist, vocalist, drummer, etc.

  BandMember({
    required this.uid,
    required this.role,
    this.displayName,
    this.email,
    this.musicRoles = const [],
  });

  Map<String, dynamic> toJson() => _$BandMemberToJson(this);

  factory BandMember.fromJson(Map<String, dynamic> json) =>
      _$BandMemberFromJson(json);

  BandMember copyWith({
    String? uid,
    String? role,
    String? displayName,
    String? email,
    List<String>? musicRoles,
  }) {
    return BandMember(
      uid: uid ?? this.uid,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      musicRoles: musicRoles ?? this.musicRoles,
    );
  }

  static const String roleAdmin = 'admin';
  static const String roleEditor = 'editor';
  static const String roleViewer = 'viewer';
}

@JsonSerializable()
class Band {
  @JsonKey(defaultValue: '')
  final String id;
  @JsonKey(defaultValue: '')
  final String name;
  final String? description;
  @JsonKey(defaultValue: '')
  final String createdBy;
  @JsonKey(defaultValue: [], fromJson: _membersFromJson, toJson: _membersToJson)
  final List<BandMember> members;
  @JsonKey(defaultValue: [])
  final List<String> memberUids; // Derived from members for efficient rules checking
  @JsonKey(defaultValue: [])
  final List<String> adminUids; // Derived from members for efficient rules checking
  @JsonKey(defaultValue: [])
  final List<String> editorUids; // Derived from members for efficient rules checking
  @JsonKey(defaultValue: [])
  final List<String> tags;
  final String? inviteCode;
  @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)
  final DateTime createdAt;

  Band({
    required this.id,
    required this.name,
    this.description,
    required this.createdBy,
    this.members = const [],
    List<String>? memberUids,
    List<String>? adminUids,
    List<String>? editorUids,
    this.tags = const [],
    this.inviteCode,
    required this.createdAt,
  }) : memberUids = memberUids ?? members.map((m) => m.uid).toList(),
       adminUids =
           adminUids ??
           members
               .where((m) => m.role == BandMember.roleAdmin)
               .map((m) => m.uid)
               .toList(),
       editorUids =
           editorUids ??
           members
               .where((m) => m.role == BandMember.roleEditor)
               .where((m) => m.role != BandMember.roleAdmin)
               .map((m) => m.uid)
               .toList();

  Band copyWith({
    String? id,
    String? name,
    Object? description = _sentinel,
    String? createdBy,
    List<BandMember>? members,
    List<String>? memberUids,
    List<String>? adminUids,
    List<String>? editorUids,
    List<String>? tags,
    Object? inviteCode = _sentinel,
    DateTime? createdAt,
  }) {
    // Use provided members or existing members
    final newMembers = members ?? this.members;
    // Recalculate memberUids, adminUids, and editorUids if members changed and not explicitly provided
    final newMemberUids = memberUids ?? newMembers.map((m) => m.uid).toList();
    final newAdminUids =
        adminUids ??
        newMembers
            .where((m) => m.role == BandMember.roleAdmin)
            .map((m) => m.uid)
            .toList();
    final newEditorUids =
        editorUids ??
        newMembers
            .where((m) => m.role == BandMember.roleEditor)
            .where((m) => m.role != BandMember.roleAdmin)
            .map((m) => m.uid)
            .toList();

    return Band(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description == _sentinel
          ? this.description
          : description as String?,
      createdBy: createdBy ?? this.createdBy,
      members: newMembers,
      memberUids: newMemberUids,
      adminUids: newAdminUids,
      editorUids: newEditorUids,
      tags: tags ?? this.tags,
      inviteCode: inviteCode == _sentinel
          ? this.inviteCode
          : inviteCode as String?,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => _$BandToJson(this);

  factory Band.fromJson(Map<String, dynamic> json) => _$BandFromJson(json);

  /// Generates a unique 6-character invite code using cryptographically secure random.
  ///
  /// The code consists of uppercase letters and digits (36 characters total).
  /// Collision handling should be done at the service layer.
  static String generateUniqueInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    String code = '';
    for (int i = 0; i < 6; i++) {
      code += chars[random.nextInt(chars.length)];
    }
    return code;
  }
}

DateTime _parseDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  return DateTime.parse(value as String);
}

String? _dateTimeToJson(DateTime? value) => value?.toIso8601String();

List<BandMember> _membersFromJson(dynamic value) {
  if (value == null) return [];
  if (value is List<BandMember>) return value;
  return (value as List<dynamic>)
      .map((e) => BandMember.fromJson(e as Map<String, dynamic>))
      .toList();
}

List<Map<String, dynamic>> _membersToJson(List<BandMember> members) {
  return members.map((m) => m.toJson()).toList();
}
