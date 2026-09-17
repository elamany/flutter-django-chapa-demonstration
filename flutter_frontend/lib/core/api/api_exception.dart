/// Typed exception used across the app for all API-related failures.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? details;

  const ApiException({
    required this.message,
    this.statusCode,
    this.details,
  });

  /// User-friendly message for common HTTP status codes.
  factory ApiException.fromStatus(int? status, {String? serverMessage}) {
    final msg = serverMessage?.trim().isNotEmpty == true
        ? serverMessage!
        : _defaultMessage(status);

    return ApiException(message: msg, statusCode: status);
  }

  /// Network-level failure (no connection, timeout, DNS).
  factory ApiException.network() => const ApiException(
        message: 'Network error. Please check your connection.',
      );

  /// Something we didn't anticipate. Always log details for this one.
  factory ApiException.unknown([Object? error]) => ApiException(
        message: 'Something went wrong. Please try again.',
        details: {'raw': error.toString()},
      );

  static String _defaultMessage(int? status) {
    switch (status) {
      case 400:
        return 'Invalid request.';
      case 401:
        return 'Your session has expired. Please log in again.';
      case 403:
        return 'You do not have permission to do that.';
      case 404:
        return 'Not found.';
      case 500:
      case 502:
      case 503:
        return 'Server error. Please try again later.';
      default:
        return 'Request failed.';
    }
  }

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message)';
}