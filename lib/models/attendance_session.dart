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

class AttendanceRecordItem {
  final String studentId;
  final String studentName;
  final bool isPresent;

  AttendanceRecordItem({
    required this.studentId,
    required this.studentName,
    this.isPresent = true,
  });

  factory AttendanceRecordItem.fromJson(Map<String, dynamic> json) {
    String sName = '';
    if (json['user_profiles'] != null) {
      final p = json['user_profiles'];
      sName = '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
    }
    return AttendanceRecordItem(
      studentId: json['student_id']?.toString() ?? '',
      studentName: sName.isNotEmpty ? sName : (json['student_name'] ?? ''),
      isPresent: json['is_present'] ?? true,
    );
  }

  Map<String, dynamic> toJson(String sessionId) {
    return {
      'session_id': sessionId,
      'student_id': studentId,
      'is_present': isPresent,
    };
  }
}

class AttendanceSession {
  final String id;
  final String classId;
  final String code;
  final DateTime sessionDate;
  final DateTime createdAt;
  final String className;
  final String subject;
  final List<String> students;

  AttendanceSession({
    required this.id,
    required this.classId,
    this.code = 'UNIVERSAL',
    required this.sessionDate,
    required this.createdAt,
    this.className = '',
    this.subject = '',
    required this.students,
  });

  int get presentCount => students.length;

  String get formattedDate {
    final day = sessionDate.day.toString().padLeft(2, '0');
    final month = sessionDate.month.toString().padLeft(2, '0');
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '$day/$month/${sessionDate.year} - $hour:$minute';
  }

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    String cName = '';
    String subName = '';

    if (json['course_classes'] != null) {
      final cc = json['course_classes'];
      if (cc['subjects'] != null) {
        subName = cc['subjects']['name'] ?? '';
      }
      if (cc['courses'] != null) {
        final c = cc['courses'];
        final yL = c['year_level'] ?? '';
        final div = c['division'] ?? '';
        final car = c['careers'] != null ? c['careers']['name'] : '';
        cName = '${yL}ro - $div $car'.trim();
      }
    }

    List<String> stdList = [];
    if (json['attendance_records'] != null &&
        json['attendance_records'] is List) {
      for (var r in json['attendance_records']) {
        if (r['user_profiles'] != null) {
          final p = r['user_profiles'];
          final fullName = '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'
              .trim();
          if (fullName.isNotEmpty) stdList.add(fullName);
        }
      }
    } else if (json['students'] != null) {
      stdList = List<String>.from(json['students']);
    }

    return AttendanceSession(
      id:
          json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      classId: json['class_id']?.toString() ?? '',
      code: json['code'] ?? 'UNIVERSAL',
      sessionDate:
          DateTime.tryParse(json['session_date'] ?? '') ?? DateTime.now(),
      createdAt:
          DateTime.tryParse(json['created_at'] ?? json['date'] ?? '') ??
          DateTime.now(),
      className: cName.isNotEmpty
          ? cName
          : (json['className'] ?? json['class_name'] ?? 'Desconocida'),
      subject: subName.isNotEmpty ? subName : (json['subject'] ?? ''),
      students: stdList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_id': classId,
      'code': code,
      'session_date':
          '${sessionDate.year}-${sessionDate.month.toString().padLeft(2, '0')}-${sessionDate.day.toString().padLeft(2, '0')}',
      'created_at': createdAt.toIso8601String(),
    };
  }
}
