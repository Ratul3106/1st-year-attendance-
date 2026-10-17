class Student {
  final String id;
  final String registerNumber;
  final String fullName;
  final bool active;
  final DateTime createdAt;

  Student({
    required this.id,
    required this.registerNumber,
    required this.fullName,
    required this.active,
    required this.createdAt,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as String,
      registerNumber: json['register_number'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      active: json['active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'register_number': registerNumber,
      'full_name': fullName,
      'active': active,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
