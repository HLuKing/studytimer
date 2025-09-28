class StudySession {
  final String id;
  final String subjectId;
  final DateTime startTime;
  final DateTime? endTime;
  final String date; // YYYY-MM-DD format for easier filtering
  final int studyDuration; // seconds
  final int breakDuration; // seconds

  StudySession({
    required this.id,
    required this.subjectId,
    required this.startTime,
    this.endTime,
    required this.date,
    this.studyDuration = 0,
    this.breakDuration = 0,
  });

  factory StudySession.fromJson(Map<String, dynamic> json) {
    return StudySession(
      id: json['id'],
      subjectId: json['subjectId'] ?? '1',
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      date: json['date'],
      studyDuration: json['studyDuration'] ?? 0,
      breakDuration: json['breakDuration'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subjectId': subjectId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'date': date,
      'studyDuration': studyDuration,
      'breakDuration': breakDuration,
    };
  }
}