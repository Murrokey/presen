class Career {
  final String id;
  final String name;
  final int durationYears;
  final bool isActive;

  Career({
    required this.id,
    required this.name,
    this.durationYears = 3,
    this.isActive = true,
  });

  factory Career.fromJson(Map<String, dynamic> json) {
    return Career(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      durationYears: json['duration_years'] ?? 3,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'duration_years': durationYears,
      'is_active': isActive,
    };
  }
}
