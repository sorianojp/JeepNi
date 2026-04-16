enum UserRole { student, driver, admin }

UserRole userRoleFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'student':
      return UserRole.student;
    case 'driver':
      return UserRole.driver;
    case 'admin':
      return UserRole.admin;
    default:
      return UserRole.student;
  }
}

class UserModel {
  final String id;
  final String email;
  final String name;
  final UserRole role;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    UserRole? role,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
    );
  }

  factory UserModel.fromFirestore(String id, Map<String, dynamic> data) {
    return UserModel(
      id: id,
      email: data['email'] as String? ?? '',
      name: data['name'] as String? ?? id,
      role: userRoleFromValue(data['role']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'email': email, 'name': name, 'role': role.name};
  }
}
