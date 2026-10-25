class Subject {
  final String id;
  final String name;
  final String careerId;
  final int weeklyHours;

  Subject({
    required this.id,
    required this.name,
    required this.careerId,
    this.weeklyHours = 4,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      careerId: json['career_id']?.toString() ?? '',
      weeklyHours: json['weekly_hours'] ?? 4,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'career_id': careerId,
      'weekly_hours': weeklyHours,
    };
  }
}
