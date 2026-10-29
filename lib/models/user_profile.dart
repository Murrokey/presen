class UserProfile {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final DateTime createdAt;
  final String? enrolledCourseId;
  final String? enrolledCourseName;

  UserProfile({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.role = 'student',
    required this.createdAt,
    this.enrolledCourseId,
    this.enrolledCourseName,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      role: json['role'] ?? 'student',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      enrolledCourseId: json['enrolled_course_id']?.toString(),
      enrolledCourseName: json['enrolled_course_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'role': role,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
