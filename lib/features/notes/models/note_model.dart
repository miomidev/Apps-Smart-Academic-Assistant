import '../../courses/models/course_model.dart';

enum NoteType { voice, document }

class NoteModel {
  final String id;
  final String userId;
  final String? courseId;
  final CourseModel? course;
  final String title;
  final String? content;
  final NoteType type;
  final String? language;
  final int? durationSeconds;
  final String? fileUrl;
  final String? fileName;
  final String? mimeType;
  final int? fileSize;
  final String? suggestedCourseId;
  final double? confidenceScore;
  final DateTime createdAt;

  NoteModel({
    required this.id,
    required this.userId,
    this.courseId,
    this.course,
    required this.title,
    this.content,
    required this.type,
    this.language,
    this.durationSeconds,
    this.fileUrl,
    this.fileName,
    this.mimeType,
    this.fileSize,
    this.suggestedCourseId,
    this.confidenceScore,
    required this.createdAt,
  });

  static NoteType parseType(String? val) {
    if (val?.toUpperCase() == 'DOCUMENT') {
      return NoteType.document;
    }
    return NoteType.voice;
  }

  static String typeToString(NoteType type) {
    return type == NoteType.document ? 'DOCUMENT' : 'VOICE';
  }

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      courseId: json['courseId'] as String? ?? json['course_id'] as String?,
      course: json['course'] != null
          ? CourseModel.fromJson(json['course'] as Map<String, dynamic>)
          : null,
      title: json['title'] as String,
      content: json['content'] as String?,
      type: parseType(json['type']?.toString()),
      language: json['language'] as String?,
      durationSeconds: (json['durationSeconds'] ?? json['duration_seconds']) as int?,
      fileUrl: json['fileUrl'] as String? ?? json['file_url'] as String?,
      fileName: json['fileName'] as String? ?? json['file_name'] as String?,
      mimeType: json['mimeType'] as String? ?? json['mime_type'] as String?,
      fileSize: (json['fileSize'] ?? json['file_size']) as int?,
      suggestedCourseId: json['suggestedCourseId'] as String? ?? json['suggested_course_id'] as String?,
      confidenceScore: (json['confidenceScore'] ?? json['confidence_score'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'courseId': courseId,
      'title': title,
      'content': content,
      'type': typeToString(type),
      'language': language,
      'durationSeconds': durationSeconds,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'mimeType': mimeType,
      'fileSize': fileSize,
      'suggestedCourseId': suggestedCourseId,
      'confidenceScore': confidenceScore,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
