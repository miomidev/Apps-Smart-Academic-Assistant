import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/services/notification_service.dart';
import '../models/schedule_model.dart';

final schedulesListProvider =
    StateNotifierProvider<SchedulesNotifier, AsyncValue<List<ScheduleModel>>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  return SchedulesNotifier(apiClient, notificationService);
});

final todaysSchedulesProvider = Provider<List<ScheduleModel>>((ref) {
  final schedulesAsync = ref.watch(schedulesListProvider);
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

  return schedulesAsync.maybeWhen(
    data: (list) {
      return list.where((s) {
        final localDue = s.dueDate.toLocal();
        return localDue.isAfter(todayStart) && localDue.isBefore(todayEnd);
      }).toList();
    },
    orElse: () => [],
  );
});

final upcomingTasksProvider = Provider<List<ScheduleModel>>((ref) {
  final schedulesAsync = ref.watch(schedulesListProvider);

  return schedulesAsync.maybeWhen(
    data: (list) {
      final tasks = list.where((s) {
        return s.type == ScheduleType.task && !s.isCompleted;
      }).toList();
      tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return tasks;
    },
    orElse: () => [],
  );
});

class SchedulesNotifier extends StateNotifier<AsyncValue<List<ScheduleModel>>> {
  final ApiClient _apiClient;
  final NotificationService _notificationService;

  SchedulesNotifier(this._apiClient, this._notificationService)
      : super(const AsyncValue.loading()) {
    loadSchedules();
  }

  Future<void> loadSchedules() async {
    state = const AsyncValue.loading();
    try {
      final list = await _apiClient.get<List<ScheduleModel>>(
        '/schedules',
        fromData: (data) {
          final List<dynamic> raw = (data is Map<String, dynamic>)
              ? (data['items'] as List<dynamic>? ?? [])
              : (data as List<dynamic>? ?? []);
          return raw
              .map((item) =>
                  ScheduleModel.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(
        e is ApiException ? e.message : 'Gagal memuat jadwal: $e',
        st,
      );
    }
  }

  Future<ScheduleModel?> createSchedule({
    required String courseId,
    required String title,
    required ScheduleType type,
    int? meetingNumber,
    required DateTime dueDate,
    int reminderMinutes = 60,
  }) async {
    try {
      final newSchedule = await _apiClient.post<ScheduleModel>(
        '/schedules',
        data: {
          'courseId': courseId,
          'title': title,
          'type': ScheduleModel.typeToString(type),
          if (meetingNumber != null) 'meetingNumber': meetingNumber,
          'dueDate': dueDate.toUtc().toIso8601String(),
          'reminderMinutes': reminderMinutes,
        },
        fromData: (data) =>
            ScheduleModel.fromJson(data as Map<String, dynamic>),
      );

      final current = state.value ?? [];
      state = AsyncValue.data([...current, newSchedule]);

      // Schedule local push notification
      final reminderTime =
          dueDate.subtract(Duration(minutes: reminderMinutes));
      await _notificationService.scheduleNotification(
        id: newSchedule.id.hashCode,
        title: 'Pengingat: ${newSchedule.title}',
        body: 'Jadwal dimulai dalam $reminderMinutes menit',
        scheduledDate: reminderTime,
      );

      return newSchedule;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> bulkCreateSchedules(List<Map<String, dynamic>> items) async {
    try {
      await _apiClient.post(
        '/schedules/bulk',
        data: {'schedules': items},
      );
      await loadSchedules();
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> toggleComplete(String id) async {
    try {
      final updated = await _apiClient.patch<ScheduleModel>(
        '/schedules/$id/complete',
        fromData: (data) =>
            ScheduleModel.fromJson(data as Map<String, dynamic>),
      );

      final current = state.value ?? [];
      state = AsyncValue.data(
        current.map((s) => s.id == id ? updated : s).toList(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteSchedule(String id) async {
    try {
      await _apiClient.delete('/schedules/$id');
      final current = state.value ?? [];
      state = AsyncValue.data(current.where((s) => s.id != id).toList());
      return true;
    } catch (e) {
      return false;
    }
  }
}
