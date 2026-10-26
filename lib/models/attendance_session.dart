class StudentData {
  final String id;
  final String endpointId;
  final String name;
  bool isPresent;

  StudentData({
    required this.id,
    required this.endpointId,
    required this.name,
    this.isPresent = false,
  });
}

class PendingClass {
  final String teacherName;
  final String course;
  final String subject;
  final String endpointId;

  PendingClass({
    required this.teacherName,
    required this.course,
    required this.subject,
    required this.endpointId,
  });
}

class AttendanceSession {
  final String id;
  final String className;
  final String subject;
  final String code;
  final DateTime date;
  final List<String> students;

  AttendanceSession({
    required this.id,
    required this.className,
    required this.subject,
    this.code = 'UNIVERSAL',
    required this.date,
    required this.students,
  });

  int get presentCount => students.length;

  String get formattedDate {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} - $hour:$minute';
  }

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    return AttendanceSession(
      id:
          json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      className: json['className'] ?? json['class_name'] ?? 'Desconocida',
      subject: json['subject'] ?? '',
      code: json['code'] ?? 'UNIVERSAL',
      date:
          DateTime.tryParse(json['date'] ?? json['created_at'] ?? '') ??
          DateTime.now(),
      students: List<String>.from(json['students'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'className': className,
      'subject': subject,
      'code': code,
      'date': date.toIso8601String(),
      'students': students,
    };
  }
}
