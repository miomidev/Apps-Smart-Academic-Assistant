import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/services/screen_pinning_service.dart';
import '../models/focus_session_model.dart';

final focusSessionsProvider = StateNotifierProvider<FocusSessionsNotifier,
    AsyncValue<List<FocusSessionModel>>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return FocusSessionsNotifier(apiClient);
});

final focusStatsProvider =
    FutureProvider.autoDispose<FocusStatsSummary>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  try {
    return await apiClient.get<FocusStatsSummary>(
      '/focus-sessions/stats/summary',
      fromData: (data) =>
          FocusStatsSummary.fromJson(data as Map<String, dynamic>),
    );
  } catch (e) {
    // Return empty fallback
    return FocusStatsSummary(
      totalMinutes: 0,
      totalSessions: 0,
      completedSessions: 0,
      failedSessions: 0,
      currentStreak: 0,
      dailyStats: [],
    );
  }
});

class FocusSessionsNotifier
    extends StateNotifier<AsyncValue<List<FocusSessionModel>>> {
  final ApiClient _apiClient;
  final Uuid _uuid = const Uuid();

  FocusSessionsNotifier(this._apiClient) : super(const AsyncValue.loading()) {
    loadSessions();
  }

  Future<void> loadSessions() async {
    state = const AsyncValue.loading();
    try {
      final list = await _apiClient.get<List<FocusSessionModel>>(
        '/focus-sessions',
        fromData: (data) {
          final raw = data as List<dynamic>;
          return raw
              .map((e) =>
                  FocusSessionModel.fromJson(e as Map<String, dynamic>))
              .toList();
        },
      );
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(
        e is ApiException ? e.message : 'Gagal memuat sesi fokus: $e',
        st,
      );
    }
  }

  Future<FocusSessionModel> recordSession({
    String? id,
    String? courseId,
    required int durationMinutes,
    required int actualMinutes,
    required FocusStatus status,
    required DateTime startedAt,
    DateTime? endedAt,
    String? notes,
  }) async {
    final sessionId = id ?? _uuid.v4();

    try {
      final session = await _apiClient.post<FocusSessionModel>(
        '/focus-sessions',
        data: {
          'id': sessionId,
          if (courseId != null) 'courseId': courseId,
          'durationMinutes': durationMinutes,
          'actualMinutes': actualMinutes,
          'status': FocusSessionModel.statusToString(status),
          'startedAt': startedAt.toIso8601String(),
          'endedAt': (endedAt ?? DateTime.now()).toIso8601String(),
          if (notes != null) 'notes': notes,
        },
        fromData: (data) =>
            FocusSessionModel.fromJson(data as Map<String, dynamic>),
      );

      final current = state.value ?? [];
      state = AsyncValue.data([session, ...current]);
      return session;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> enableDistractionBlocking() async {
    try {
      await WakelockPlus.enable();
      await ScreenPinningService.startLockTask();
    } catch (_) {}
  }

  Future<void> disableDistractionBlocking() async {
    try {
      await WakelockPlus.disable();
      await ScreenPinningService.stopLockTask();
    } catch (_) {}
  }
}
