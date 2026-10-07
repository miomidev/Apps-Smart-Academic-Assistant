class CourseSlotModel {
  final String? id;
  final String? courseId;
  final int dayOfWeek; // 1 = Senin, 7 = Minggu
  final String startTime; // "08:00"
  final String endTime; // "09:40"
  final String? room;

  CourseSlotModel({
    this.id,
    this.courseId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.room,
  });

  String get dayName {
    switch (dayOfWeek) {
      case 1:
        return 'Senin';
      case 2:
        return 'Selasa';
      case 3:
        return 'Rabu';
      case 4:
        return 'Kamis';
      case 5:
        return 'Jumat';
      case 6:
        return 'Sabtu';
      case 7:
        return 'Minggu';
      default:
        return 'Hari-$dayOfWeek';
    }
  }

  factory CourseSlotModel.fromJson(Map<String, dynamic> json) {
    return CourseSlotModel(
      id: json['id'] as String?,
      courseId: json['courseId'] as String? ?? json['course_id'] as String?,
      dayOfWeek: (json['dayOfWeek'] ?? json['day_of_week'] ?? 1) as int,
      startTime: (json['startTime'] ?? json['start_time'] ?? '08:00') as String,
      endTime: (json['endTime'] ?? json['end_time'] ?? '09:40') as String,
      room: json['room'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      if (room != null) 'room': room,
    };
  }
}
