import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({AuthRepository? repository})  : _repository = repository ?? AuthRepository(), super(const AuthInitial()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthSessionExpired>(_onSessionExpired);

    // When DioClient gives up on refresh, tell the Bloc to log out.
    DioClient.instance.onSessionExpired = () {
      add(const AuthSessionExpired());
    };
  }

  final AuthRepository _repository;

  // ---------------------------------------------------------------------------
  // App start — check for an existing session
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
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        // Token was bad and refresh couldn't save us.
        await SecureStorage.clearTokens();
        emit(const AuthUnauthenticated());
      } else {
        emit(AuthFailure(e.message));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Login
  // ---------------------------------------------------------------------------
  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

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
      // Backend rejects inactive users at /auth/token/ with
      // message "User is inactive" and code "user_inactive".
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
  // Register
  // ---------------------------------------------------------------------------
  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final user = await _repository.register(
        username: event.username,
        email: event.email,
        password: event.password,
      );
      emit(AuthAuthenticated(user));
    } on ApiException catch (e) {
      emit(AuthFailure(e.message));
    }
  }

  // ---------------------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------------------
  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    await _repository.logout();
    emit(const AuthUnauthenticated());
  }

  // ---------------------------------------------------------------------------
  // Session expired (from DioClient callback)
  // ---------------------------------------------------------------------------
  void _onSessionExpired(
    AuthSessionExpired event,
    Emitter<AuthState> emit,
  ) {
    emit(const AuthUnauthenticated());
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------
  @override
  Future<void> close() {
    // Don't leave a dangling callback pointing at a closed Bloc.
    if (DioClient.instance.onSessionExpired != null) {
      DioClient.instance.onSessionExpired = null;
    }
    return super.close();
  }
}