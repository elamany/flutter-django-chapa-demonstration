import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants.dart';

/// Wrapper around FlutterSecureStorage for reading/writing auth tokens.
class SecureStorage {
  SecureStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(), 
  );

  static Future<void> saveAccessToken(String token) =>
      _storage.write(key: ApiConstants.accessTokenKey, value: token);

  static Future<String?> getAccessToken() =>
      _storage.read(key: ApiConstants.accessTokenKey);

  static Future<void> saveRefreshToken(String token) =>
      _storage.write(key: ApiConstants.refreshTokenKey, value: token);

  static Future<String?> getRefreshToken() =>
      _storage.read(key: ApiConstants.refreshTokenKey);

  static Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await Future.wait([
      _storage.write(key: ApiConstants.accessTokenKey, value: access),
      _storage.write(key: ApiConstants.refreshTokenKey, value: refresh),
    ]);
  }

  static Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: ApiConstants.accessTokenKey),
      _storage.delete(key: ApiConstants.refreshTokenKey),
    ]);
  }

  static Future<void> clearAll() => _storage.deleteAll();
}