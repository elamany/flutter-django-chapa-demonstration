import 'package:equatable/equatable.dart';

import '../data/models/user.dart';

/// Every state the UI can render.
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state before anything has happened.
final class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Something is loading (login, register, logout, bootstrap).
final class AuthLoading extends AuthState {
  const AuthLoading();
}

/// A real, active, logged-in user.
final class AuthAuthenticated extends AuthState {
  final AppUser user;

  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

/// Logged in but the account is deactivated.
/// Separate from AuthFailure because the UI needs a different screen
/// ("contact support" instead of "login form with error banner").
final class AuthInactive extends AuthState {
  final String reason;

  const AuthInactive([
    this.reason = 'Your account has been deactivated. Please contact support.',
  ]);

  @override
  List<Object?> get props => [reason];
}

/// No session. Show the login screen.
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Login/register failed for a reason the user can fix
/// (wrong password, username taken, network error).
final class AuthFailure extends AuthState {
  final String message;

  const AuthFailure(this.message);

  @override
  List<Object?> get props => [message];
}