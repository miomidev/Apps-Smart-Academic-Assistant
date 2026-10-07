import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/auto_tag_result.dart';
import '../models/note_model.dart';

final notesListProvider =
    StateNotifierProvider<NotesNotifier, AsyncValue<List<NoteModel>>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NotesNotifier(apiClient);
});

class NotesNotifier extends StateNotifier<AsyncValue<List<NoteModel>>> {
  final ApiClient _apiClient;
  final Uuid _uuid = const Uuid();

  NotesNotifier(this._apiClient) : super(const AsyncValue.loading()) {
    loadNotes();
  }

  Future<void> loadNotes() async {
    state = const AsyncValue.loading();
    try {
      final list = await _apiClient.get<List<NoteModel>>(
        '/notes',
        fromData: (data) {
          final List<dynamic> raw = (data is Map<String, dynamic>)
              ? (data['items'] as List<dynamic>? ?? [])
              : (data as List<dynamic>? ?? []);
          return raw
              .map((item) => NoteModel.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(
        e is ApiException ? e.message : 'Gagal memuat catatan: $e',
        st,
      );
    }
  }

  Future<AutoTagResult?> suggestCourse({
    required String content,
    DateTime? createdAt,
  }) async {
    try {
      final result = await _apiClient.post<AutoTagResult>(
        '/notes/suggest-course',
        data: {
          'content': content,
          'createdAt': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
        },
        fromData: (data) =>
            AutoTagResult.fromJson(data as Map<String, dynamic>),
      );
      return result;
    } catch (e) {
      return null;
    }
  }

  Future<NoteModel?> createNote({
    String? id,
    String? courseId,
    required String title,
    String? content,
    NoteType type = NoteType.voice,
    String? language = 'id-ID',
    int? durationSeconds,
    String? fileUrl,
    String? fileName,
    String? mimeType,
    int? fileSize,
    String? suggestedCourseId,
    double? confidenceScore,
  }) async {
    final noteId = id ?? _uuid.v4();

    try {
      final newNote = await _apiClient.post<NoteModel>(
        '/notes',
        data: {
          'id': noteId,
          if (courseId != null) 'courseId': courseId,
          'title': title,
          if (content != null) 'content': content,
          'type': NoteModel.typeToString(type),
          if (language != null) 'language': language,
          if (durationSeconds != null) 'durationSeconds': durationSeconds,
          if (fileUrl != null) 'fileUrl': fileUrl,
          if (fileName != null) 'fileName': fileName,
          if (mimeType != null) 'mimeType': mimeType,
          if (fileSize != null) 'fileSize': fileSize,
          if (suggestedCourseId != null) 'suggestedCourseId': suggestedCourseId,
          if (confidenceScore != null) 'confidenceScore': confidenceScore,
        },
        fromData: (data) => NoteModel.fromJson(data as Map<String, dynamic>),
      );

      final current = state.value ?? [];
      state = AsyncValue.data([newNote, ...current]);
      return newNote;
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> uploadAudioFile({
    required String filePath,
    required String fileName,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
        ),
      });

      final res = await _apiClient.uploadFile<Map<String, dynamic>>(
        '/notes/upload',
        formData: formData,
        fromData: (data) => data as Map<String, dynamic>,
      );
      return res['fileUrl'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<NoteModel?> uploadDocument({
    required String filePath,
    required String fileName,
    required String title,
    String? courseId,
  }) async {
    try {
      final formData = FormData.fromMap({
        'title': title,
        if (courseId != null) 'courseId': courseId,
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
        ),
      });

      final newNote = await _apiClient.uploadFile<NoteModel>(
        '/notes/document',
        formData: formData,
        fromData: (data) => NoteModel.fromJson(data as Map<String, dynamic>),
      );

      final current = state.value ?? [];
      state = AsyncValue.data([newNote, ...current]);
      return newNote;
    } catch (e) {
      rethrow;
    }
  }

  Future<NoteModel?> updateNote({
    required String id,
    String? title,
    String? content,
    String? courseId,
  }) async {
    try {
      final updated = await _apiClient.patch<NoteModel>(
        '/notes/$id',
        data: {
          if (title != null) 'title': title,
          if (content != null) 'content': content,
          'courseId': courseId,
        },
        fromData: (data) => NoteModel.fromJson(data as Map<String, dynamic>),
      );

      final current = state.value ?? [];
      state = AsyncValue.data(
        current.map((n) => n.id == id ? updated : n).toList(),
      );
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteNote(String id) async {
    try {
      await _apiClient.delete('/notes/$id');
      final current = state.value ?? [];
      state = AsyncValue.data(current.where((n) => n.id != id).toList());
      return true;
    } catch (e) {
      return false;
    }
  }
}
