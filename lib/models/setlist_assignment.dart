import 'package:json_annotation/json_annotation.dart';

part 'setlist_assignment.g.dart';

@JsonSerializable()
class SetlistAssignment {
  @JsonKey(defaultValue: '')
  final String oderId;
  final String? roleOverride;
  final String? keyOverride;
  final String? notes;

  SetlistAssignment({
    required this.oderId,
    this.roleOverride,
    this.keyOverride,
    this.notes,
  });

  SetlistAssignment copyWith({
    String? oderId,
    String? roleOverride,
    String? keyOverride,
    String? notes,
    bool clearRoleOverride = false,
    bool clearKeyOverride = false,
    bool clearNotes = false,
  }) {
    return SetlistAssignment(
      oderId: oderId ?? this.oderId,
      roleOverride: clearRoleOverride
          ? null
          : (roleOverride ?? this.roleOverride),
      keyOverride: clearKeyOverride ? null : (keyOverride ?? this.keyOverride),
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }

  Map<String, dynamic> toJson() => _$SetlistAssignmentToJson(this);

  factory SetlistAssignment.fromJson(Map<String, dynamic> json) =>
      _$SetlistAssignmentFromJson(json);
}
