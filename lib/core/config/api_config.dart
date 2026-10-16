class ApiConfig {
  static const String devToken = 'dev-token';
  static const String defaultTimezone = 'Asia/Jakarta';
  static const String cloudProductionBaseUrl =
      'https://pendar.miomidev.com/api/v1';

  static String getDefaultBaseUrl() {
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    // Default to the live cloud production server
    return cloudProductionBaseUrl;
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
