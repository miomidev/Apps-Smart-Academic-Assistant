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
      return 'http://10.0.2.2:3000/api/v1';
    }
    return 'http://localhost:3000/api/v1';
  }

  static String resolveMediaUrl(String path, {String? customBaseUrl}) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final base = customBaseUrl ?? getDefaultBaseUrl();
    final uri = Uri.tryParse(base);
    if (uri != null && uri.hasAuthority) {
      final origin = '${uri.scheme}://${uri.authority}';
      return '$origin${path.startsWith('/') ? path : '/$path'}';
    }
    return path;
  }
}
