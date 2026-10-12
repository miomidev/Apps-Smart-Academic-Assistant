class ExtractedTask {
  final String title;
  final DateTime? deadline;
  final String type; // TUGAS, KUIS, PROYEK

  ExtractedTask({
    required this.title,
    this.deadline,
    this.type = 'TUGAS',
  });

  factory ExtractedTask.fromJson(Map<String, dynamic> json) {
    return ExtractedTask(
      title: json['title'] as String? ?? 'Tugas',
      deadline: json['deadline'] != null
          ? DateTime.tryParse(json['deadline'].toString())
          : null,
      type: json['type'] as String? ?? 'TUGAS',
    );
  }
}

class ExtractedMeeting {
  final int meetingNumber;
  final String topic;
  final List<String> subTopics;
  final DateTime? date;
  final List<ExtractedTask> tasks;
  bool isSelected;

  ExtractedMeeting({
    required this.meetingNumber,
    required this.topic,
    required this.subTopics,
    this.date,
    required this.tasks,
    this.isSelected = true,
  });

  factory ExtractedMeeting.fromJson(Map<String, dynamic> json) {
    final rawSubs = json['subTopics'] as List<dynamic>? ??
        json['activities'] as List<dynamic>? ??
        [];
    final rawTasks = json['tasks'] as List<dynamic>? ?? [];

    final tasksList = rawTasks
        .map((t) => ExtractedTask.fromJson(t as Map<String, dynamic>))
        .toList();

    if (tasksList.isEmpty && json['hasTask'] == true) {
      final taskDesc = json['taskDescription'] as String? ?? 'Tugas Perkuliahan';
      tasksList.add(ExtractedTask(
        title: taskDesc,
        type: json['isExam'] == true ? 'UJIAN' : 'TUGAS',
      ));
    }

    final parsedDate = json['date'] != null
        ? DateTime.tryParse(json['date'].toString())
        : (json['suggestedDate'] != null
            ? DateTime.tryParse(json['suggestedDate'].toString())
            : null);

    return ExtractedMeeting(
      meetingNumber: (json['meetingNumber'] ?? json['meeting_number'] as num?)?.toInt() ?? 1,
      topic: json['topic'] as String? ?? '',
      subTopics: rawSubs.map((e) => e.toString()).toList(),
      date: parsedDate,
      tasks: tasksList,
      isSelected: true,
    );
  }
}

class RpsExtractionResult {
  final String courseId;
  final String? courseName;
  final String? lecturer;
  final List<ExtractedMeeting> meetings;

  RpsExtractionResult({
    required this.courseId,
    this.courseName,
    this.lecturer,
    required this.meetings,
  });

  factory RpsExtractionResult.fromJson(Map<String, dynamic> json) {
    final rawMeetings = json['meetings'] as List<dynamic>? ?? [];
    return RpsExtractionResult(
      courseId: json['courseId'] as String? ?? json['course_id'] as String? ?? '',
      courseName: json['courseName'] as String? ?? json['course_name'] as String?,
      lecturer: json['lecturer'] as String?,
      meetings: rawMeetings
          .map((m) => ExtractedMeeting.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}
