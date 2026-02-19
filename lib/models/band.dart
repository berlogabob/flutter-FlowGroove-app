// Sentinel value to detect if a parameter was passed to copyWith
const Object _sentinel = _Sentinel();
class _Sentinel {
  const _Sentinel();
  @override
  String toString() => '_sentinel';
}

class BandMember {
  final String uid;
  final String role;
  final String? displayName;
  final String? email;

  BandMember({
    required this.uid,
    required this.role,
    this.displayName,
    this.email,
  });

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'role': role,
    'displayName': displayName,
    'email': email,
  };

  factory BandMember.fromJson(Map<String, dynamic> json) => BandMember(
    uid: json['uid'] ?? '',
    role: json['role'] ?? 'viewer',
    displayName: json['displayName'],
    email: json['email'],
  );

  static const String roleAdmin = 'admin';
  static const String roleEditor = 'editor';
  static const String roleViewer = 'viewer';
}

class Band {
  final String id;
  final String name;
  final String? description;
  final String createdBy;
  final List<BandMember> members;
  final String? inviteCode;
  final DateTime createdAt;

  Band({
    required this.id,
    required this.name,
    this.description,
    required this.createdBy,
    this.members = const [],
    this.inviteCode,
    required this.createdAt,
  });

  Band copyWith({
    String? id,
    String? name,
    Object? description = _sentinel,
    String? createdBy,
    List<BandMember>? members,
    Object? inviteCode = _sentinel,
    DateTime? createdAt,
  }) {
    return Band(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description == _sentinel ? this.description : description as String?,
      createdBy: createdBy ?? this.createdBy,
      members: members ?? this.members,
      inviteCode: inviteCode == _sentinel ? this.inviteCode : inviteCode as String?,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'createdBy': createdBy,
    'members': members.map((m) => m.toJson()).toList(),
    'inviteCode': inviteCode,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Band.fromJson(Map<String, dynamic> json) => Band(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    description: json['description'],
    createdBy: json['createdBy'] ?? '',
    members:
        (json['members'] as List<dynamic>?)
            ?.map((m) => BandMember.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [],
    inviteCode: json['inviteCode'],
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'])
        : DateTime.now(),
  );
}
