import 'package:equatable/equatable.dart';

/// Everything the UI can ask the AuthBloc to do.
///
/// Sealed class → the compiler forces us to handle every subclass,
/// and Dart 3 pattern matching can switch exhaustively over them.
sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once at app start to check for an existing session.
final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

/// Fired when the user submits the login form.
final class AuthLoginRequested extends AuthEvent {
  final String username;
  final String password;

  const AuthLoginRequested({
    required this.username,
    required this.password,
  });

  @override
  List<Object?> get props => [username, password];
}

/// Fired when the user submits the register form.
final class AuthRegisterRequested extends AuthEvent {
  final String username;
  final String email;
  final String password;
  final String firstName;
  final String lastName;

  const AuthRegisterRequested({
    required this.username,
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
  });

  @override
  List<Object?> get props => [
        username,
        email,
        password,
        firstName,
        lastName,
      ];
}

/// Fired when the user taps "Log out".
final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Fired internally (from DioClient's onSessionExpired callback)
/// when token refresh has failed permanently.
final class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
}