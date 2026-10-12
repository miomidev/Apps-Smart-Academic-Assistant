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
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyVoiceDraftText = 'voice_draft_text';
  static const String _keyVoiceDraftTimestamp = 'voice_draft_timestamp';
  static const String _keyVoiceDraftDuration = 'voice_draft_duration';
  static const String _keyVoiceDraftCourseId = 'voice_draft_course_id';
  static const String _keySpeechLanguage = 'speech_language';
  static const String _keyDefaultReminderMinutes = 'default_reminder_minutes';

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

  // --- Onboarding ---
  bool isOnboardingCompleted() {
    return _prefs.getBool(_keyOnboardingCompleted) ?? false;
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    await _prefs.setBool(_keyOnboardingCompleted, completed);
  }

  // --- Voice Draft & Crash Recovery ---
  Map<String, dynamic>? getVoiceDraft() {
    final text = _prefs.getString(_keyVoiceDraftText);
    final timestamp = _prefs.getInt(_keyVoiceDraftTimestamp);
    final duration = _prefs.getInt(_keyVoiceDraftDuration) ?? 0;
    final courseId = _prefs.getString(_keyVoiceDraftCourseId);

    if (text == null || text.trim().isEmpty || timestamp == null) {
      return null;
    }

    final draftAge = DateTime.now().millisecondsSinceEpoch - timestamp;
    // Expire draft if older than 24 hours (PRD 5.1.A)
    if (draftAge > 24 * 60 * 60 * 1000) {
      clearVoiceDraft();
      return null;
    }

    return {
      'text': text,
      'timestamp': timestamp,
      'duration': duration,
      'courseId': courseId,
    };
  }

  Future<void> saveVoiceDraft({
    required String text,
    required int durationSeconds,
    String? courseId,
  }) async {
    if (text.trim().isEmpty) return;
    await _prefs.setString(_keyVoiceDraftText, text);
    await _prefs.setInt(
        _keyVoiceDraftTimestamp, DateTime.now().millisecondsSinceEpoch);
    await _prefs.setInt(_keyVoiceDraftDuration, durationSeconds);
    if (courseId != null) {
      await _prefs.setString(_keyVoiceDraftCourseId, courseId);
    } else {
      await _prefs.remove(_keyVoiceDraftCourseId);
    }
  }

  Future<void> clearVoiceDraft() async {
    await _prefs.remove(_keyVoiceDraftText);
    await _prefs.remove(_keyVoiceDraftTimestamp);
    await _prefs.remove(_keyVoiceDraftDuration);
    await _prefs.remove(_keyVoiceDraftCourseId);
  }

  // --- Settings: Speech Language & Reminders ---
  String getSpeechLanguage() {
    return _prefs.getString(_keySpeechLanguage) ?? 'id-ID';
  }

  Future<void> setSpeechLanguage(String lang) async {
    await _prefs.setString(_keySpeechLanguage, lang);
  }

  int getDefaultReminderMinutes() {
    return _prefs.getInt(_keyDefaultReminderMinutes) ?? 60;
  }

  Future<void> setDefaultReminderMinutes(int minutes) async {
    await _prefs.setInt(_keyDefaultReminderMinutes, minutes);
  }

  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
