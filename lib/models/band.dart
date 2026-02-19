import 'dart:math';

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
  final List<String> memberUids;  // Derived from members for efficient rules checking
  final List<String> adminUids;   // Derived from members for efficient rules checking
  final String? inviteCode;
  final DateTime createdAt;

  Band({
    required this.id,
    required this.name,
    this.description,
    required this.createdBy,
    this.members = const [],
    List<String>? memberUids,
    List<String>? adminUids,
    this.inviteCode,
    required this.createdAt,
  }) : memberUids = memberUids ?? members.map((m) => m.uid).toList(),
       adminUids = adminUids ?? members.where((m) => m.role == BandMember.roleAdmin).map((m) => m.uid).toList();

  Band copyWith({
    String? id,
    String? name,
    Object? description = _sentinel,
    String? createdBy,
    List<BandMember>? members,
    List<String>? memberUids,
    List<String>? adminUids,
    Object? inviteCode = _sentinel,
    DateTime? createdAt,
  }) {
    // Use provided members or existing members
    final newMembers = members ?? this.members;
    // Recalculate memberUids and adminUids if members changed and not explicitly provided
    final newMemberUids = memberUids ?? newMembers.map((m) => m.uid).toList();
    final newAdminUids = adminUids ?? newMembers.where((m) => m.role == BandMember.roleAdmin).map((m) => m.uid).toList();
    
    return Band(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description == _sentinel ? this.description : description as String?,
      createdBy: createdBy ?? this.createdBy,
      members: newMembers,
      memberUids: newMemberUids,
      adminUids: newAdminUids,
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
    'memberUids': memberUids,
    'adminUids': adminUids,
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
    memberUids: (json['memberUids'] as List<dynamic>?)?.cast<String>() ?? [],
    adminUids: (json['adminUids'] as List<dynamic>?)?.cast<String>() ?? [],
    inviteCode: json['inviteCode'],
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'])
        : DateTime.now(),
  );

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
