class Subject {
  final String id;
  final String careerId;
  final String name;
  final int yearLevel;
  final int weeklyHours;

  Subject({
    required this.id,
    required this.careerId,
    required this.name,
    required this.yearLevel,
    this.weeklyHours = 4,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id']?.toString() ?? '',
      careerId: json['career_id']?.toString() ?? '',
      name: json['name'] ?? '',
      yearLevel: json['year_level'] ?? 1,
      weeklyHours: json['weekly_hours'] ?? 4,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'career_id': careerId,
      'name': name,
      'year_level': yearLevel,
      'weekly_hours': weeklyHours,
    };
  }
}
