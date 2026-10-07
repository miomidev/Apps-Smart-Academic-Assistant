import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/course_model.dart';
import '../models/course_slot_model.dart';

final coursesListProvider =
    StateNotifierProvider<CoursesNotifier, AsyncValue<List<CourseModel>>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CoursesNotifier(apiClient);
});

class CoursesNotifier extends StateNotifier<AsyncValue<List<CourseModel>>> {
  final ApiClient _apiClient;

  CoursesNotifier(this._apiClient) : super(const AsyncValue.loading()) {
    loadCourses();
  }

  Future<void> loadCourses() async {
    state = const AsyncValue.loading();
    try {
      final courses = await _apiClient.get<List<CourseModel>>(
        '/courses',
        fromData: (data) {
          final list = data as List<dynamic>;
          return list
              .map((item) => CourseModel.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );
      state = AsyncValue.data(courses);
    } catch (e, st) {
      state = AsyncValue.error(
        e is ApiException ? e.message : 'Gagal memuat mata kuliah: $e',
        st,
      );
    }
  }

  Future<CourseModel?> createCourse({
    required String name,
    String? code,
    String? lecturer,
    required String colorCode,
    String? startDate,
    List<String>? keywords,
    List<CourseSlotModel>? slots,
  }) async {
    try {
      final newCourse = await _apiClient.post<CourseModel>(
        '/courses',
        data: {
          'name': name,
          if (code != null && code.isNotEmpty) 'code': code,
          if (lecturer != null && lecturer.isNotEmpty) 'lecturer': lecturer,
          'colorCode': colorCode,
          if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
          if (keywords != null) 'keywords': keywords,
          if (slots != null) 'slots': slots.map((s) => s.toJson()).toList(),
        },
        fromData: (data) =>
            CourseModel.fromJson(data as Map<String, dynamic>),
      );

      final current = state.value ?? [];
      state = AsyncValue.data([...current, newCourse]);
      return newCourse;
    } catch (e) {
      rethrow;
    }
  }

  Future<CourseModel?> updateCourse({
    required String id,
    String? name,
    String? code,
    String? lecturer,
    String? colorCode,
    String? startDate,
    List<String>? keywords,
    List<CourseSlotModel>? slots,
  }) async {
    try {
      final updated = await _apiClient.patch<CourseModel>(
        '/courses/$id',
        data: {
          if (name != null) 'name': name,
          if (code != null) 'code': code,
          if (lecturer != null) 'lecturer': lecturer,
          if (colorCode != null) 'colorCode': colorCode,
          if (startDate != null) 'startDate': startDate,
          if (keywords != null) 'keywords': keywords,
          if (slots != null) 'slots': slots.map((s) => s.toJson()).toList(),
        },
        fromData: (data) =>
            CourseModel.fromJson(data as Map<String, dynamic>),
      );

      final current = state.value ?? [];
      state = AsyncValue.data(
        current.map((c) => c.id == id ? updated : c).toList(),
      );
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteCourse(String id) async {
    try {
      await _apiClient.delete('/courses/$id');
      final current = state.value ?? [];
      state = AsyncValue.data(current.where((c) => c.id != id).toList());
      return true;
    } catch (e) {
      return false;
    }
  }
}
