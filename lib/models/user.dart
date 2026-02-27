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
  @JsonKey(defaultValue: '')
  final String uid;
  final String? displayName;
  final String? email;
  final String? photoURL;
  @JsonKey(defaultValue: [])
  final List<String> bandIds;
  @JsonKey(defaultValue: [])
  final List<String> baseTags; // Role tags: guitarist, vocalist, drummer, etc.
  @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)
  final DateTime createdAt;

  AppUser({
    required this.uid,
    this.displayName,
    this.email,
    this.photoURL,
    this.bandIds = const [],
    this.baseTags = const [],
    required this.createdAt,
  });

  AppUser copyWith({
    String? uid,
    Object? displayName = _sentinel,
    Object? email = _sentinel,
    Object? photoURL = _sentinel,
    List<String>? bandIds,
    List<String>? baseTags,
    DateTime? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      displayName: displayName == _sentinel
          ? this.displayName
          : displayName as String?,
      email: email == _sentinel ? this.email : email as String?,
      photoURL: photoURL == _sentinel ? this.photoURL : photoURL as String?,
      bandIds: bandIds ?? this.bandIds,
      baseTags: baseTags ?? this.baseTags,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => _$AppUserToJson(this);

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);
}

DateTime _parseDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  return DateTime.parse(value as String);
}

String? _dateTimeToJson(DateTime? value) => value?.toIso8601String();
