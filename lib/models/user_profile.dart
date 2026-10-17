enum UserRole {
  admin,
  coordinator,
  staff;

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'staff':
        return UserRole.staff;
      case 'coordinator':
      default:
        return UserRole.coordinator;
    }
  }

  String toNameString() {
    switch (this) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.coordinator:
        return 'Student Coordinator';
      case UserRole.staff:
        return 'Staff Member';
    }
  }
}

class UserProfile {
  final String id;
  final String fullName;
  final UserRole role;
  final bool active;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.active,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'User',
      role: UserRole.fromString(json['role'] as String? ?? 'coordinator'),
      active: json['active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'role': role.name,
      'active': active,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
