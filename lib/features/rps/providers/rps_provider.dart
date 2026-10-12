import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/notification_service.dart';
import '../../schedules/models/schedule_model.dart';
import '../../schedules/providers/schedules_provider.dart';
import '../models/rps_extraction_model.dart';

final rpsExtractionProvider =
    StateNotifierProvider<RpsNotifier, AsyncValue<RpsExtractionResult?>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RpsNotifier(apiClient, ref);
});

class RpsNotifier extends StateNotifier<AsyncValue<RpsExtractionResult?>> {
  final ApiClient _apiClient;
  final Ref _ref;

  RpsNotifier(this._apiClient, this._ref) : super(const AsyncValue.data(null));

  Future<RpsExtractionResult?> parseRpsPdf({
    required String courseId,
    required String filePath,
    required String fileName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
        ),
      });

      final result = await _apiClient.uploadFile<RpsExtractionResult>(
        '/courses/$courseId/rps/extract',
        formData: formData,
        fromData: (data) =>
            RpsExtractionResult.fromJson(data as Map<String, dynamic>),
      );

      state = AsyncValue.data(result);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      rethrow;
    }
  }

  Future<int> confirmAndScheduleBulk({
    required String courseId,
    required List<ExtractedMeeting> meetings,
    String? defaultStartTime,
    String? defaultEndTime,
  }) async {
    final List<Map<String, dynamic>> items = [];

    final now = DateTime.now();

    for (final meeting in meetings) {
      if (!meeting.isSelected) continue;

      // Class schedule
      final meetingDate = meeting.date ??
          now.add(Duration(days: 7 * (meeting.meetingNumber - 1)));

      items.add({
        'title': 'Pertemuan ${meeting.meetingNumber}: ${meeting.topic}',
        'type': 'KULIAH',
        'date': DateFormat('yyyy-MM-dd').format(meetingDate),
        'startTime': defaultStartTime ?? '08:00',
        'endTime': defaultEndTime ?? '09:40',
        'reminderMinutes': 30,
        'description': meeting.subTopics.isNotEmpty
            ? meeting.subTopics.join('\n')
            : null,
      });

      // Tasks for this meeting
      for (final task in meeting.tasks) {
        final taskDate = task.deadline ?? meetingDate.add(const Duration(days: 7));
        items.add({
          'title': task.title,
          'type': task.type.toUpperCase() == 'UJIAN' ? 'UJIAN' : 'TUGAS',
          'date': DateFormat('yyyy-MM-dd').format(taskDate),
          'startTime': '23:59',
          'reminderMinutes': 1440, // 1 day before
        });
      }
    }

    if (items.isEmpty) return 0;

    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/schedules/bulk',
        data: {
          'courseId': courseId,
          'items': items,
        },
        fromData: (data) => data as Map<String, dynamic>,
      );

      // Refresh schedules list
      _ref.read(schedulesListProvider.notifier).loadSchedules();

      // Schedule local notifications for newly created schedules if returned
      final rawSchedules = response['schedules'] as List<dynamic>?;
      if (rawSchedules != null) {
        for (final item in rawSchedules) {
          final sched = ScheduleModel.fromJson(item as Map<String, dynamic>);
          NotificationService.scheduleReminder(
            id: sched.id.hashCode,
            title: 'Pengingat ${sched.title}',
            body: 'Jadwal perkuliahan / tugas',
            scheduledDate: sched.dueDate,
            minutesBefore: sched.reminderMinutes,
          );
        }
      }

      return items.length;
    } catch (e) {
      rethrow;
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}
