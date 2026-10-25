class CourseClass {
  final String id;
  final String courseYear;
  final String careerName;
  final String subjectName;
  final String teacherId;

  CourseClass({
    required this.id,
    required this.courseYear,
    required this.careerName,
    required this.subjectName,
    this.teacherId = '',
  });

  String get fullCourseName => '$courseYear $careerName';

  String get storageEntry => '$courseYear|$careerName|$subjectName';

  factory CourseClass.fromStorageEntry(String entry) {
    final parts = entry.split('|');
    return CourseClass(
      id: entry,
      courseYear: parts.isNotEmpty ? parts[0] : '',
      careerName: parts.length > 1 ? parts[1] : '',
      subjectName: parts.length > 2 ? parts[2] : '',
    );
  }

  factory CourseClass.fromJson(Map<String, dynamic> json) {
    return CourseClass(
      id: json['id']?.toString() ?? '',
      courseYear: json['course_year'] ?? '',
      careerName: json['career_name'] ?? '',
      subjectName: json['subject_name'] ?? '',
      teacherId: json['teacher_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course_year': courseYear,
      'career_name': careerName,
      'subject_name': subjectName,
      'teacher_id': teacherId,
    };
  }
}
