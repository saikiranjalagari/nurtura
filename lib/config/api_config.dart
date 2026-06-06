import 'package:flutter/foundation.dart';

/// API base URL for Nurtura backend.
///
/// - Web / desktop: localhost
/// - Android emulator: 10.0.2.2 (maps to your PC's localhost)
/// - Physical phone: pass your PC IP via --dart-define=API_HOST=192.168.x.x
class ApiConfig {
  static const _host = String.fromEnvironment(
    'API_HOST',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_host.isNotEmpty) {
      return 'http://$_host:3000/api';
    }
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android emulator → host machine
        return 'http://10.0.2.2:3000/api';
      case TargetPlatform.iOS:
        return 'http://localhost:3000/api';
      default:
        return 'http://localhost:3000/api';
    }
  }
}
