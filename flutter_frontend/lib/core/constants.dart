class ApiConstants {
  ApiConstants._();

  /// Base URL of your Django backend.
  ///
  /// Choose the one that matches how you're running Flutter:
  ///
  /// Android emulator:   http://10.0.2.2:8000/api/v1/
  /// iOS simulator:      http://127.0.0.1:8000/api/v1/
  /// Physical device:    http://<your-lan-ip>:8000/api/v1/
  /// Flutter web:        http://127.0.0.1:8000/api/v1/
  /// Cloudflare tunnel:  https://<tunnel>.trycloudflare.com/api/v1/
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1/';

  /// Keys used to store tokens in secure storage.
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
}

class ChapaConstants {
  ChapaConstants._();

  /// Chapa PUBLIC key — safe to embed in the mobile app.
  /// Get it from https://dashboard.chapa.co → Settings → API Keys.
  /// Now i use web view so this is not needed
  static const String publicKey = 'CHAPUBK-your public key if you use native ui for chapa';
}
