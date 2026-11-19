import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  static String customBaseUrl = '';

  static String get apiUrl {
    if (customBaseUrl.isNotEmpty) {
      return customBaseUrl;
    }
    if (kIsWeb) {
      return 'http://localhost/voice-expense-tracker/api.php';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2/voice-expense-tracker/api.php';
      }
    } catch (_) {}
    return 'http://localhost/voice-expense-tracker/api.php';
  }
}
