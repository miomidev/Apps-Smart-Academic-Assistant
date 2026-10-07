import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences has not been initialized');
});

final storageServiceProvider = Provider<StorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StorageService(prefs);
});

class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static const String _keyToken = 'auth_token';
  static const String _keyBaseUrl = 'base_url';
  static const String _keyUserJson = 'cached_user';
  static const String _keyOfflineNotes = 'offline_notes';
  static const String _keyPendingNotes = 'pending_notes';

  String getToken() {
    return _prefs.getString(_keyToken) ?? ApiConfig.devToken;
  }

  Future<void> setToken(String token) async {
    await _prefs.setString(_keyToken, token);
  }

  Future<void> removeToken() async {
    await _prefs.remove(_keyToken);
  }

  String getBaseUrl() {
    return _prefs.getString(_keyBaseUrl) ?? ApiConfig.getDefaultBaseUrl();
  }

  Future<void> setBaseUrl(String url) async {
    await _prefs.setString(_keyBaseUrl, url);
  }

  String? getCachedUserJson() {
    return _prefs.getString(_keyUserJson);
  }

  Future<void> setCachedUserJson(String jsonStr) async {
    await _prefs.setString(_keyUserJson, jsonStr);
  }

  List<String> getOfflineNotes() => _prefs.getStringList(_keyOfflineNotes) ?? [];
  Future<void> setOfflineNotes(List<String> notes) =>
      _prefs.setStringList(_keyOfflineNotes, notes);

  List<String> getPendingNotes() => _prefs.getStringList(_keyPendingNotes) ?? [];
  Future<void> setPendingNotes(List<String> notes) =>
      _prefs.setStringList(_keyPendingNotes, notes);

  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
