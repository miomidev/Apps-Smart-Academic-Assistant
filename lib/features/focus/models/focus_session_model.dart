import '../../courses/models/course_model.dart';

enum FocusStatus { completed, failed }

class FocusSessionModel {
  final String id;
  final String userId;
  final String? courseId;
  final CourseModel? course;
  final int durationMinutes;
  final int actualMinutes;
  final FocusStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? notes;

  FocusSessionModel({
    required this.id,
    required this.userId,
    this.courseId,
    this.course,
    required this.durationMinutes,
    required this.actualMinutes,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.notes,
  });

  static FocusStatus parseStatus(String? val) {
    if (val?.toUpperCase() == 'FAILED') return FocusStatus.failed;
    return FocusStatus.completed;
  }

  static String statusToString(FocusStatus s) {
    return s == FocusStatus.failed ? 'FAILED' : 'COMPLETED';
  }

  factory FocusSessionModel.fromJson(Map<String, dynamic> json) {
    return FocusSessionModel(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      courseId: json['courseId'] as String? ?? json['course_id'] as String?,
      course: json['course'] != null
          ? CourseModel.fromJson(json['course'] as Map<String, dynamic>)
          : null,
      durationMinutes:
          (json['durationMinutes'] ?? json['duration_minutes'] as num?)?.toInt() ?? 25,
      actualMinutes:
          (json['actualMinutes'] ?? json['actual_minutes'] as num?)?.toInt() ?? 0,
      status: parseStatus(json['status']?.toString()),
      startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? '') ?? DateTime.now(),
      endedAt: json['endedAt'] != null
          ? DateTime.tryParse(json['endedAt'].toString())
          : null,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'courseId': courseId,
      'durationMinutes': durationMinutes,
      'actualMinutes': actualMinutes,
      'status': statusToString(status),
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'notes': notes,
    };
  }
}

class FocusDailyStat {
  final String dayName;
  final DateTime date;
  final int minutes;

  FocusDailyStat({
    required this.dayName,
    required this.date,
    required this.minutes,
  });

  factory FocusDailyStat.fromJson(Map<String, dynamic> json) {
    return FocusDailyStat(
      dayName: json['dayName'] as String? ?? json['day'] as String? ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      minutes: (json['minutes'] as num?)?.toInt() ?? 0,
    );
  }
}

class FocusStatsSummary {
  final int totalMinutes;
  final int totalSessions;
  final int completedSessions;
  final int failedSessions;
  final int currentStreak;
  final List<FocusDailyStat> dailyStats;

  FocusStatsSummary({
    required this.totalMinutes,
    required this.totalSessions,
    required this.completedSessions,
    required this.failedSessions,
    required this.currentStreak,
    required this.dailyStats,
  });

  factory FocusStatsSummary.fromJson(Map<String, dynamic> json) {
    final rawDaily = json['dailyStats'] as List<dynamic>? ?? [];

    return FocusStatsSummary(
      totalMinutes: (json['totalMinutes'] as num?)?.toInt() ?? 0,
      totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 0,
      completedSessions: (json['completedSessions'] as num?)?.toInt() ?? 0,
      failedSessions: (json['failedSessions'] as num?)?.toInt() ?? 0,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      dailyStats: rawDaily
          .map((d) => FocusDailyStat.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
}
