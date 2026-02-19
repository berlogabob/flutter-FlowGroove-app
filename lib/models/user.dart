// Sentinel value to detect if a parameter was passed to copyWith
const Object _sentinel = _Sentinel();

class _Sentinel {
  const _Sentinel();
  @override
  String toString() => '_sentinel';
}

class AppUser {
  final String uid;
  final String? displayName;
  final String? email;
  final String? photoURL;
  final List<String> bandIds;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    this.displayName,
    this.email,
    this.photoURL,
    this.bandIds = const [],
    required this.createdAt,
  });

  AppUser copyWith({
    String? uid,
    Object? displayName = _sentinel,
    Object? email = _sentinel,
    Object? photoURL = _sentinel,
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
      bandIds: bandIds ?? this.bandIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'displayName': displayName,
    'email': email,
    'photoURL': photoURL,
    'bandIds': bandIds,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    uid: json['uid'] ?? '',
    displayName: json['displayName'],
    email: json['email'],
    photoURL: json['photoURL'],
    bandIds: (json['bandIds'] as List<dynamic>?)?.cast<String>() ?? [],
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'])
        : DateTime.now(),
  );
}
