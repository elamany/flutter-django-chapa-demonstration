import 'dart:async';

import 'package:dio/dio.dart';

import '../constants.dart';
import '../storage/secure_storage.dart';
import 'api_exception.dart';

/// Central Dio instance for the whole app.
///
/// Responsibilities:
///   1. Attach the access token to every outgoing request.
///   2. On 401, silently call /auth/token/refresh/ and retry the request.
///   3. Prevent multiple concurrent refreshes (thundering herd).
///   4. When refresh fails for real, notify the app (so AuthBloc can log out).
///   5. Normalize every error into an ApiException (carried inside DioException).
///
/// All feature repositories go through this instance — never `Dio()` directly.
class DioClient {
  DioClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Accept': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );
  }

  static final DioClient instance = DioClient._();

  late final Dio _dio;

  /// Called when refresh fails permanently. AuthBloc registers here so it can
  /// emit AuthUnauthenticated and push the user to Login.
  VoidCallback? onSessionExpired;

  // Endpoints that must NOT receive an Authorization header
  // and must NOT trigger the refresh flow.
  static const _authFreeEndpoints = <String>[
    'auth/register/',
    'auth/token/',
    'auth/token/refresh/',
  ];

  bool _isAuthFree(String path) =>
      _authFreeEndpoints.any((endpoint) => path.contains(endpoint));

  // Refresh coordination
  Completer<bool>? _refreshCompleter;

  // onRequest — attach token
  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isAuthFree(options.path)) {
      final token = await SecureStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  // onError — retry once after refresh
  Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;

    // Not a 401 → convert and reject
    if (response?.statusCode != 401) {
      return handler.reject(_wrapAsDioException(err));
    }

    // 401 on an auth endpoint (bad login, blacklisted refresh) → don't retry
    if (_isAuthFree(err.requestOptions.path)) {
      return handler.reject(_wrapAsDioException(err));
    }

    // Already retried this exact request once → session is dead
    if (err.requestOptions.extra['_retried'] == true) {
      await _handleRefreshFailure();
      return handler.reject(_wrapAsDioException(err));
    }

    // Try to refresh
    final refreshed = await _refreshAccessToken();

    if (!refreshed) {
      await _handleRefreshFailure();
      return handler.reject(_wrapAsDioException(err));
    }

    // Retry the original request with the new access token
    try {
      final retryResponse = await _retry(err.requestOptions);
      return handler.resolve(retryResponse);
    } on DioException catch (retryErr) {
      return handler.reject(_wrapAsDioException(retryErr));
    }
  }

  // The refresh call itself
  Future<bool> _refreshAccessToken() async {
    // Someone else is already refreshing — wait for their result
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();

    try {
      final refresh = await SecureStorage.getRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        _refreshCompleter!.complete(false);
        return false;
      }

      // Use a fresh Dio so we don't recurse through this interceptor
      final bare = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
      final res = await bare.post(
        'auth/token/refresh/',
        data: {'refresh': refresh},
      );

      final newAccess = res.data['access'] as String?;
      if (newAccess == null || newAccess.isEmpty) {
        _refreshCompleter!.complete(false);
        return false;
      }

      await SecureStorage.saveAccessToken(newAccess);

      // NOTE: SimpleJWT's refresh endpoint only returns a new access token, not a new refresh token.
      _refreshCompleter!.complete(true);
      return true;
    } catch (_) {
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions options) async {
    final token = await SecureStorage.getAccessToken();

    final retryOptions = options.copyWith(
      headers: {
        ...options.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      },
      extra: {
        ...options.extra,
        '_retried': true,
      },
    );

    return _dio.fetch(retryOptions);
  }

  // Refresh failed → clear tokens and notify the app
  Future<void> _handleRefreshFailure() async {
    await SecureStorage.clearTokens();
    onSessionExpired?.call();
  }

  // Convert DioException → DioException that carries ApiException
  DioException _wrapAsDioException(DioException err) {
    return DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: _toApiException(err), 
      message: err.message,
    );
  }

  ApiException _toApiException(DioException err) {
    final response = err.response;

    if (response == null) {
      return ApiException.network();
    }

    final status = response.statusCode;
    final serverMessage = _extractServerMessage(response.data);

    return ApiException.fromStatus(status, serverMessage: serverMessage);
  }

  /// DRF errors come in a few shapes:
  ///   {"detail": "..."}
  ///   {"field": ["error 1", "error 2"]}
  ///   {"non_field_errors": ["..."]}
  ///   "raw string"
  String? _extractServerMessage(dynamic data) {
    if (data == null) return null;

    if (data is String) return data;

    if (data is Map) {
      final detail = data['detail'];
      if (detail is String) return detail;

      for (final value in data.values) {
        if (value is List && value.isNotEmpty) {
          final first = value.first;
          if (first is String) return first;
        }
        if (value is String) return value;
      }
    }

    return null;
  }

  // Public API — what repositories call
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) =>
      _dio.get(path, queryParameters: query);

  Future<Response<dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) =>
      _dio.post(path, data: data, queryParameters: query);

  Future<Response<dynamic>> patch(
    String path, {
    Object? data,
  }) =>
      _dio.patch(path, data: data);

  Future<Response<dynamic>> put(
    String path, {
    Object? data,
  }) =>
      _dio.put(path, data: data);

  Future<Response<dynamic>> delete(String path) => _dio.delete(path);
}

/// Minimal alias so we don't need to import Flutter here.
typedef VoidCallback = void Function();