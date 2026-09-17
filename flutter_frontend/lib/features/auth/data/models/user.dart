import 'package:equatable/equatable.dart';

/// The authenticated user, as returned by:
///   - POST /auth/token/  (only username, we fetch the rest from /auth/me/)
///   - GET  /auth/me/
///   - PATCH /auth/me/
class AppUser extends Equatable {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final bool isStaff;
  final bool isSuperuser;
  final bool isActive;

  const AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.isStaff,
    required this.isSuperuser,
    required this.isActive,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      username: (json['username'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      firstName: (json['first_name'] ?? '') as String,
      lastName: (json['last_name'] ?? '') as String,
      isStaff: (json['is_staff'] ?? false) as bool,
      isSuperuser: (json['is_superuser'] ?? false) as bool,
      isActive: (json['is_active'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'is_staff': isStaff,
        'is_superuser': isSuperuser,
        'is_active': isActive,
      };

  /// For edit-profile PATCH — only these three fields are editable.
  Map<String, dynamic> toEditableJson() => {
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
      };

  AppUser copyWith({
    String? email,
    String? firstName,
    String? lastName,
  }) =>
      AppUser(
        id: id,
        username: username,
        email: email ?? this.email,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        isStaff: isStaff,
        isSuperuser: isSuperuser,
        isActive: isActive,
      );

  String get displayName {
    final full = '$firstName $lastName'.trim();
    return full.isEmpty ? username : full;
  }

  @override
  List<Object?> get props => [
        id,
        username,
        email,
        firstName,
        lastName,
        isStaff,
        isSuperuser,
        isActive,
      ];
}