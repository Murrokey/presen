class Course {
  final String id;
  final String careerId;
  final int yearLevel;
  final String division;
  final int academicYear;
  final String? careerName;

  Course({
    required this.id,
    required this.careerId,
    required this.yearLevel,
    required this.division,
    required this.academicYear,
    this.careerName,
  });

  String get displayName => '${yearLevel}ro - $division';

  String get fullTitle =>
      careerName != null ? '$displayName $careerName' : displayName;

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id']?.toString() ?? '',
      careerId: json['career_id']?.toString() ?? '',
      yearLevel: json['year_level'] ?? 1,
      division: json['division'] ?? '',
      academicYear: json['academic_year'] ?? DateTime.now().year,
      careerName: json['careers'] != null
          ? json['careers']['name']
          : json['career_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'career_id': careerId,
      'year_level': yearLevel,
      'division': division,
      'academic_year': academicYear,
    };
  }
}
