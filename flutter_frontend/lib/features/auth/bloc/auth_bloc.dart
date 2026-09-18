import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({AuthRepository? repository})
      : _repository = repository ?? AuthRepository(),
        super(const AuthInitial()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthSessionExpired>(_onSessionExpired);

    DioClient.instance.onSessionExpired = () {
      add(const AuthSessionExpired());
    };
  }

  final AuthRepository _repository;

  // ---------------------------------------------------------------------------
  // App start — check for existing session. Never fails to "AuthFailure" —
  // either the user is authenticated or they're a guest.
  // ---------------------------------------------------------------------------
  Future<void> _onStarted(
    AuthStarted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final token = await SecureStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      emit(const AuthUnauthenticated());
      return;
    }

    try {
      final user = await _repository.getCurrentUser();

      if (!user.isActive) {
        await SecureStorage.clearTokens();
        emit(const AuthInactive());
        return;
      }

      emit(AuthAuthenticated(user));
    } on ApiException {
      // Any failure during bootstrap → treat as guest. Don't clear tokens
      // on network errors — the first API call will retry refresh anyway.
      // Only clear on explicit 401.
      // (DioClient already clears tokens for real 401-after-refresh-fails.)
      emit(const AuthUnauthenticated());
    }
  }

  // ---------------------------------------------------------------------------
  // Login — no AuthLoading emit; the LoginScreen manages its own spinner.
  // ---------------------------------------------------------------------------
  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final user = await _repository.login(
        username: event.username,
        password: event.password,
      );

      if (!user.isActive) {
        await SecureStorage.clearTokens();
        emit(const AuthInactive());
        return;
      }

      emit(AuthAuthenticated(user));
    } on ApiException catch (e) {
      final isInactive = e.statusCode == 401 &&
          e.message.toLowerCase().contains('inactive');

      if (isInactive) {
        emit(const AuthInactive());
      } else {
        emit(AuthFailure(e.message));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Register — same as login.
  // ---------------------------------------------------------------------------
  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final user = await _repository.register(
        username: event.username,
        email: event.email,
        password: event.password,
        firstName: event.firstName,
        lastName: event.lastName,
      );
      emit(AuthAuthenticated(user));
    } on ApiException catch (e) {
      emit(AuthFailure(e.message));
    }
  }

  // ---------------------------------------------------------------------------
  // Logout — clears tokens, then goes to guest mode (still shows MainScaffold).
  // ---------------------------------------------------------------------------
  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _repository.logout();
    emit(const AuthUnauthenticated());
  }

  void _onSessionExpired(
    AuthSessionExpired event,
    Emitter<AuthState> emit,
  ) {
    emit(const AuthUnauthenticated());
  }

  @override
  Future<void> close() {
    if (DioClient.instance.onSessionExpired != null) {
      DioClient.instance.onSessionExpired = null;
    }
    return super.close();
  }
}