class CandidateCourse {
  final String courseId;
  final String courseName;
  final double score;
  final double confidence;

  CandidateCourse({
    required this.courseId,
    required this.courseName,
    required this.score,
    required this.confidence,
  });

  factory CandidateCourse.fromJson(Map<String, dynamic> json) {
    return CandidateCourse(
      courseId: json['courseId'] as String? ?? json['course_id'] as String? ?? '',
      courseName: json['courseName'] as String? ?? json['course_name'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AutoTagResult {
  final String? suggestedCourseId;
  final String? suggestedCourseName;
  final double confidenceScore;
  final List<String> matchedKeywords;
  final bool isTimeMatched;
  final List<CandidateCourse> candidates;

  AutoTagResult({
    this.suggestedCourseId,
    this.suggestedCourseName,
    required this.confidenceScore,
    required this.matchedKeywords,
    this.isTimeMatched = false,
    required this.candidates,
  });

  factory AutoTagResult.fromJson(Map<String, dynamic> json) {
    var rawKws = json['matchedKeywords'] as List<dynamic>? ?? [];
    var rawCands = json['candidates'] as List<dynamic>? ?? [];

    return AutoTagResult(
      suggestedCourseId: json['suggestedCourseId'] as String? ?? json['courseId'] as String?,
      suggestedCourseName: json['suggestedCourseName'] as String? ?? json['courseName'] as String?,
      confidenceScore: (json['confidenceScore'] as num? ?? json['confidence'] as num?)?.toDouble() ?? 0.0,
      matchedKeywords: rawKws.map((e) => e.toString()).toList(),
      isTimeMatched: (json['isTimeMatched'] ?? false) as bool,
      candidates: rawCands
          .map((c) => CandidateCourse.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}
