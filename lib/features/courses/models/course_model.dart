import 'course_slot_model.dart';

class CourseModel {
  final String id;
  final String name;
  final String? code;
  final String? lecturer;
  final String colorCode;
  final String? startDate;
  final List<String> keywords;
  final List<CourseSlotModel> slots;
  final DateTime createdAt;

  String get colorHex => colorCode;

  CourseModel({
    required this.id,
    required this.name,
    this.code,
    this.lecturer,
    String? colorCode,
    String? colorHex,
    this.startDate,
    List<String>? keywords,
    List<CourseSlotModel>? slots,
    DateTime? createdAt,
  })  : colorCode = colorCode ?? colorHex ?? '#4F46E5',
        keywords = keywords ?? const [],
        slots = slots ?? const [],
        createdAt = createdAt ?? DateTime.now();

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    var rawSlots = json['slots'] as List<dynamic>? ?? [];
    List<CourseSlotModel> slotsList = rawSlots
        .map((s) => CourseSlotModel.fromJson(s as Map<String, dynamic>))
        .toList();

    var rawKeywords = json['keywords'] as List<dynamic>? ?? [];
    List<String> keywordsList =
        rawKeywords.map((k) => k.toString()).toList();

    return CourseModel(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String?,
      lecturer: json['lecturer'] as String?,
      colorCode: json['colorCode'] as String? ?? json['color_code'] as String? ?? '#4F46E5',
      startDate: json['startDate'] as String? ?? json['start_date'] as String?,
      keywords: keywordsList,
      slots: slotsList,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'lecturer': lecturer,
      'colorCode': colorCode,
      'startDate': startDate,
      'keywords': keywords,
      'slots': slots.map((s) => s.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
