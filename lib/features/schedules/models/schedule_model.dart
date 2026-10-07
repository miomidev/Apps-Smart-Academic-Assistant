import '../../courses/models/course_model.dart';

enum ScheduleType { classType, task, exam }

class ScheduleModel {
  final String id;
  final String courseId;
  final CourseModel? course;
  final String title;
  final ScheduleType type;
  final int? meetingNumber;
  final DateTime dueDate;
  final bool isCompleted;
  final int reminderMinutes;
  final String source;
  final DateTime createdAt;

  ScheduleModel({
    required this.id,
    required this.courseId,
    this.course,
    required this.title,
    required this.type,
    this.meetingNumber,
    required this.dueDate,
    this.isCompleted = false,
    this.reminderMinutes = 60,
    this.source = 'MANUAL',
    required this.createdAt,
  });

  static ScheduleType parseType(String? val) {
    switch (val?.toUpperCase()) {
      case 'CLASS':
        return ScheduleType.classType;
      case 'TASK':
        return ScheduleType.task;
      case 'EXAM':
        return ScheduleType.exam;
      default:
        return ScheduleType.classType;
    }
  }

  static String typeToString(ScheduleType type) {
    switch (type) {
      case ScheduleType.classType:
        return 'CLASS';
      case ScheduleType.task:
        return 'TASK';
      case ScheduleType.exam:
        return 'EXAM';
    }
  }

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    return ScheduleModel(
      id: json['id'] as String,
      courseId: json['courseId'] as String? ?? json['course_id'] as String? ?? '',
      course: json['course'] != null
          ? CourseModel.fromJson(json['course'] as Map<String, dynamic>)
          : null,
      title: json['title'] as String,
      type: parseType(json['type']?.toString()),
      meetingNumber: (json['meetingNumber'] ?? json['meeting_number']) as int?,
      dueDate: DateTime.tryParse(json['dueDate']?.toString() ?? json['due_date']?.toString() ?? '') ?? DateTime.now(),
      isCompleted: (json['isCompleted'] ?? json['is_completed'] ?? false) as bool,
      reminderMinutes: (json['reminderMinutes'] ?? json['reminder_minutes'] ?? 60) as int,
      source: (json['source'] ?? 'MANUAL') as String,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'courseId': courseId,
      'title': title,
      'type': typeToString(type),
      if (meetingNumber != null) 'meetingNumber': meetingNumber,
      'dueDate': dueDate.toIso8601String(),
      'isCompleted': isCompleted,
      'reminderMinutes': reminderMinutes,
      'source': source,
    };
  }
}
