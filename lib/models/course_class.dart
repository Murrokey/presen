class CourseClass {
  final String id;
  final String courseId;
  final String subjectId;
  final String? teacherId;
  final DateTime createdAt;
  final String? courseName;
  final String? subjectName;

  CourseClass({
    required this.id,
    required this.courseId,
    required this.subjectId,
    this.teacherId,
    required this.createdAt,
    this.courseName,
    this.subjectName,
  });

  String get fullTitle => '${courseName ?? ''} - ${subjectName ?? ''}'.trim();

  String get storageEntry => '$id|${courseName ?? ''}|${subjectName ?? ''}';

  factory CourseClass.fromStorageEntry(String entry) {
    final parts = entry.split('|');
    return CourseClass(
      id: parts.isNotEmpty ? parts[0] : '',
      courseId: '',
      subjectId: '',
      createdAt: DateTime.now(),
      courseName: parts.length > 1 ? parts[1] : '',
      subjectName: parts.length > 2 ? parts[2] : '',
    );
  }

  factory CourseClass.fromJson(Map<String, dynamic> json) {
    String? cName;
    if (json['courses'] != null) {
      final c = json['courses'];
      final cLevel = c['year_level'] ?? '';
      final cDiv = c['division'] ?? '';
      final carName = c['careers'] != null ? c['careers']['name'] : '';
      cName = '${cLevel}ro - $cDiv $carName'.trim();
    }

    return CourseClass(
      id: json['id']?.toString() ?? '',
      courseId: json['course_id']?.toString() ?? '',
      subjectId: json['subject_id']?.toString() ?? '',
      teacherId: json['teacher_id']?.toString(),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      courseName: cName ?? json['course_name'],
      subjectName: json['subjects'] != null
          ? json['subjects']['name']
          : json['subject_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,
      'subject_id': subjectId,
      'teacher_id': teacherId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
