import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String devToken = 'dev-token';
  static const String defaultTimezone = 'Asia/Jakarta';

  static String getDefaultBaseUrl() {
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:3000/api/v1';
    }
    if (Platform.isAndroid) {
      return 'http://192.168.1.12:3000/api/v1';
    }
    return 'http://localhost:3000/api/v1';
  }
}
