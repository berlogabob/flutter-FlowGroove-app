import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

// Sentinel value to detect if a parameter was passed to copyWith
const Object _sentinel = _Sentinel();

class _Sentinel {
  const _Sentinel();
  @override
  String toString() => '_sentinel';
}

@JsonSerializable()
class AppUser {

  AppUser({
    required this.uid,
    required this.createdAt, this.displayName,
    this.email,
    this.photoURL,
    this.photoSource,
    this.accessRole = 'member',
    this.musicRoles = const [],
    this.systemTags = const [],
    this.bandIds = const [],
  });

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);
  @JsonKey(defaultValue: '')
  final String uid;
  final String? displayName;
  final String? email;
  final String? photoURL;
  final String? photoSource;

  /// Access role for the app: 'owner', 'admin', 'member', 'demo'.
  /// Controls what the user can do app-wide.
  @JsonKey(defaultValue: 'member')
  final String accessRole;

  /// Music roles: what this person does musically.
  /// e.g., ['vocalist', 'guitarist', 'sound_engineer'].
  /// Shown on personal page and as default when joining bands.
  @JsonKey(defaultValue: [])
  final List<String> musicRoles;

  /// System tags: internal labels not shown to users.
  /// e.g., ['demo', 'test', 'early_adopter'].
  @JsonKey(defaultValue: [])
  final List<String> systemTags;

  @JsonKey(defaultValue: [])
  final List<String> bandIds;
  @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)
  final DateTime createdAt;

  AppUser copyWith({
    String? uid,
    Object? displayName = _sentinel,
    Object? email = _sentinel,
    Object? photoURL = _sentinel,
    Object? photoSource = _sentinel,
    String? accessRole,
    List<String>? musicRoles,
    List<String>? systemTags,
    List<String>? bandIds,
    DateTime? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      displayName: displayName == _sentinel
          ? this.displayName
          : displayName as String?,
      email: email == _sentinel ? this.email : email as String?,
      photoURL: photoURL == _sentinel ? this.photoURL : photoURL as String?,
      photoSource: photoSource == _sentinel
          ? this.photoSource
          : photoSource as String?,
      accessRole: accessRole ?? this.accessRole,
      musicRoles: musicRoles ?? this.musicRoles,
      systemTags: systemTags ?? this.systemTags,
      bandIds: bandIds ?? this.bandIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => _$AppUserToJson(this);
}

DateTime _parseDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  return DateTime.parse(value as String);
}

String? _dateTimeToJson(DateTime? value) => value?.toIso8601String();
