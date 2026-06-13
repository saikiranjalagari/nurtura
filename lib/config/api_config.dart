import 'package:flutter/foundation.dart';

/// API base URL for Nurtura backend.
///
/// Production mobile builds:
///   --dart-define=API_BASE_URL=https://your-api.onrender.com/api
///
/// Local dev on a physical phone (same Wi‑Fi):
///   --dart-define=API_HOST=192.168.x.x
class ApiConfig {
  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const _host = String.fromEnvironment(
    'API_HOST',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_baseUrl.isNotEmpty) {
      return _baseUrl;
    }
    if (_host.isNotEmpty) {
      return 'http://$_host:3000/api';
    }
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000/api';
      case TargetPlatform.iOS:
        return 'http://localhost:3000/api';
      default:
        return 'http://localhost:3000/api';
    }
  }
}
