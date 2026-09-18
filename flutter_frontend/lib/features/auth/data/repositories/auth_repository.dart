import 'package:dio/dio.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../models/user.dart';

/// All auth-related HTTP calls live here.
///
/// The Bloc layer never touches Dio directly — it calls these methods,
/// gets back a domain object (AppUser) or throws ApiException.
class AuthRepository {
  AuthRepository({DioClient? client}) : _client = client ?? DioClient.instance;

  final DioClient _client;

  // ---------------------------------------------------------------------------
  // Login
  // ---------------------------------------------------------------------------
  /// POST /auth/token/ then GET /auth/me/ to fetch the full user.
  ///
  /// SimpleJWT's login endpoint only returns tokens, not user data,
  /// so we make a second call to /auth/me/ to get id, email, etc.
  Future<AppUser> login({
    required String username,
    required String password,
  }) async {
    try {
      final res = await _client.post(
        'auth/token/',
        data: {'username': username, 'password': password},
      );

      final access = res.data['access'] as String?;
      final refresh = res.data['refresh'] as String?;

      if (access == null || refresh == null) {
        throw const ApiException(
          message: 'Login response was missing tokens.',
        );
      }

      await SecureStorage.saveTokens(access: access, refresh: refresh);

      // Now fetch the full profile.
      return await getCurrentUser();
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Register
  // ---------------------------------------------------------------------------
  /// POST /auth/register/
  ///
  /// On success, we immediately log the user in with the same credentials —
  /// matches the common UX of "sign up → you're in."
  /// TODO: Account verification 
  Future<AppUser> register({
    required String username,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      await _client.post(
        'auth/register/',
        data: {
          'username': username,
          'email': email,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
        },
      );

      return await login(username: username, password: password);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Current user
  /// GET /auth/me/
  Future<AppUser> getCurrentUser() async {
    try {
      final res = await _client.get('auth/me/');
      return AppUser.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Update profile
  /// PATCH /auth/me/ — updates email, first_name, last_name.
  Future<AppUser> updateProfile({
    String? email,
    String? firstName,
    String? lastName,
  }) async {
    final payload = <String, dynamic>{};
    if (email != null) payload['email'] = email;
    if (firstName != null) payload['first_name'] = firstName;
    if (lastName != null) payload['last_name'] = lastName;

    try {
      final res = await _client.patch('auth/me/', data: payload);
      //TODO: if email address is changed reverify user
      return AppUser.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Change password
  // ---------------------------------------------------------------------------
  /// POST /auth/change-password/
  ///
  /// Backend blacklists all existing refresh tokens and returns a new pair
  /// for THIS device. We persist the new pair so the user stays logged in.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    try {
      final res = await _client.post(
        'auth/change-password/',
        data: {
          'old_password': oldPassword,
          'new_password': newPassword,
          'new_password_confirm': newPasswordConfirm,
        },
      );

      final data = res.data['data'];
      if (data is Map) {
        final access = data['access'] as String?;
        final refresh = data['refresh'] as String?;
        if (access != null && refresh != null) {
          await SecureStorage.saveTokens(access: access, refresh: refresh);
        }
      }
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------------------
  /// POST /auth/logout/ then clear local tokens.
  ///
  /// We clear tokens locally even if the network call fails — the user
  /// asked to log out; honor it.
  Future<void> logout() async {
    try {
      final refresh = await SecureStorage.getRefreshToken();
      if (refresh != null && refresh.isNotEmpty) {
        await _client.post('auth/logout/', data: {'refresh': refresh});
      }
    } on DioException {
      // Ignore network errors on logout — we're clearing anyway.
    } finally {
      await SecureStorage.clearTokens();
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  /// DioClient wraps ApiException inside DioException.error so that
  /// handler.reject() (Dio 5.x) accepts it. Unwrap it here so the Bloc
  /// layer only ever sees ApiException.
  ApiException _unwrap(DioException e) {
    if (e.error is ApiException) {
      return e.error as ApiException;
    }
    return ApiException.unknown(e);
  }
}