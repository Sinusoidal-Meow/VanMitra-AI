import 'user_role.dart';

/// User profile in VanMitra-AI supporting all 12 FRA/CFR roles
class User {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final String villageId;
  final String? tehsil;
  final String? district;
  final String? state;
  final String? memberId; // Links to VillageMember for attendance
  final String preferredLanguage; // 'en', 'hi', 'mr'
  final DateTime createdAt;
  final bool hasFaceEnrolled;

  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.villageId,
    this.tehsil = 'Jawhar',
    this.district = 'Palghar',
    this.state = 'Maharashtra',
    this.memberId,
    this.preferredLanguage = 'mr',
    required this.createdAt,
    this.hasFaceEnrolled = false,
  });

  User copyWith({
    String? name,
    UserRole? role,
    String? villageId,
    String? tehsil,
    String? district,
    String? state,
    String? memberId,
    String? preferredLanguage,
    bool? hasFaceEnrolled,
  }) {
    return User(
      id: id,
      email: email,
      name: name ?? this.name,
      role: role ?? this.role,
      villageId: villageId ?? this.villageId,
      tehsil: tehsil ?? this.tehsil,
      district: district ?? this.district,
      state: state ?? this.state,
      memberId: memberId ?? this.memberId,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      createdAt: createdAt,
      hasFaceEnrolled: hasFaceEnrolled ?? this.hasFaceEnrolled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role.name,
        'villageId': villageId,
        'tehsil': tehsil,
        'district': district,
        'state': state,
        'memberId': memberId,
        'preferredLanguage': preferredLanguage,
        'createdAt': createdAt.toIso8601String(),
        'hasFaceEnrolled': hasFaceEnrolled,
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String? ?? '',
        name: json['name'] as String? ?? '',
        role: UserRoleExtension.parse(json['role'] as String?),
        villageId: json['villageId'] as String? ?? 'ozhar_jawhar_palghar',
        tehsil: json['tehsil'] as String? ?? 'Jawhar',
        district: json['district'] as String? ?? 'Palghar',
        state: json['state'] as String? ?? 'Maharashtra',
        memberId: json['memberId'] as String?,
        preferredLanguage: json['preferredLanguage'] as String? ?? 'mr',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        hasFaceEnrolled: json['hasFaceEnrolled'] as bool? ?? false,
      );
}
